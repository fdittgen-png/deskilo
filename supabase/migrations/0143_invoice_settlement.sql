-- SPDX-License-Identifier: 0BSD
-- #804 — several open invoices regrouped into ONE the member pays.
--
-- A member with a subscription invoice, an end-of-month invoice and last
-- month's leftover receives three demands for one relationship. Settling
-- them produces a single document that carries their sum, and the three
-- stop being separately owed: payment matches the settlement, and dunning
-- chases the settlement instead of chasing each source.
--
-- WHAT A SETTLEMENT IS NOT. The sources are not voided and not replaced.
-- They stay in the archive exactly as issued — that is the whole point of
-- an immutable invoice — and each gains a pointer to the document that
-- settled it. So the trail runs both ways: from a source to the demand
-- that now covers it, and from the settlement to every position of every
-- invoice inside it, snapshotted at the moment of regrouping.
--
-- VAT IS NOT RESTATED. Each source already declared its own tax, and a
-- settlement that taxed the same supply again would double-declare it.
-- The settlement is a consolidation of AMOUNTS OWED, so its lines carry
-- 0% and its vat_totals are empty; the tax lives on the sources, which
-- the document names.

alter table public.invoices
  add column if not exists settled_by_invoice_id uuid
    references public.invoices(id) on delete restrict;

-- The positions of every source, frozen when they were regrouped, so the
-- settlement remains readable even if a source is later corrected.
alter table public.invoices
  add column if not exists settles jsonb;

create index if not exists invoices_settled_by_idx
  on public.invoices (settled_by_invoice_id)
  where settled_by_invoice_id is not null;

comment on column public.invoices.settled_by_invoice_id is
  '#804 - the settlement invoice that now carries this one''s balance.';
comment on column public.invoices.settles is
  '#804 - snapshot of the sources: number, period, kind, total and lines.';

-- ---------------------------------------------------------------- immutability
-- An invoice may be updated in exactly one way today: voiding stamps a
-- date on it. Settling stamps a POINTER, and for the same reason — the
-- document itself does not change, its lifecycle does. The trigger has to
-- be told, or settle_invoices cannot write its own back-reference.
--
-- Caught by the live harness on the first run of settle_invoices.
create or replace function public.invoices_immutable()
returns trigger language plpgsql as $$
begin
  if tg_op = 'UPDATE'
     and old.voided_at is null
     and new.voided_at is not null
     and (to_jsonb(old) - 'voided_at' - 'voided_by_name')
       = (to_jsonb(new) - 'voided_at' - 'voided_by_name') then
    return new;
  end if;
  -- #804 — the settlement back-pointer, once, and nothing else with it.
  if tg_op = 'UPDATE'
     and old.settled_by_invoice_id is null
     and new.settled_by_invoice_id is not null
     and (to_jsonb(old) - 'settled_by_invoice_id')
       = (to_jsonb(new) - 'settled_by_invoice_id') then
    return new;
  end if;
  raise exception 'invoices are immutable';
end;
$$;

-- ---------------------------------------------------------------- settling
create or replace function public.settle_invoices(
  p_workspace_id uuid,
  p_member_id uuid,
  p_invoice_ids uuid[],
  p_note text default ''
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_actor public.members;
  v_subject public.members;
  v_workspace public.workspaces;
  v_latest public.invoices;
  v_lines jsonb := '[]'::jsonb;
  v_settles jsonb := '[]'::jsonb;
  v_total int := 0;
  v_count int;
  v_number text;
  v_id uuid;
  v_signature text;
  v_issuer_name text;
  v_src public.invoices;
  v_n int := 0;
begin
  select * into v_actor from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid()
      and status = 'active' and (is_admin or is_owner);
  if v_actor.id is null then raise exception 'not an admin of this workspace'; end if;
  if not public.has_permission(p_workspace_id, 'issueInvoices') then
    raise exception 'admins may not issue invoices here';
  end if;

  select * into v_subject from public.members
    where id = p_member_id and workspace_id = p_workspace_id;
  if v_subject.id is null then raise exception 'unknown subject member'; end if;

  if p_invoice_ids is null or array_length(p_invoice_ids, 1) is null
     or array_length(p_invoice_ids, 1) < 2 then
    -- One invoice is not a regrouping; it is the invoice.
    raise exception 'settle at least two invoices';
  end if;

  perform pg_advisory_xact_lock(hashtext(p_workspace_id::text));

  for v_src in
    select * from public.invoices
     where id = any(p_invoice_ids)
     order by issued_at, number
  loop
    v_n := v_n + 1;
    if v_src.workspace_id <> p_workspace_id then
      raise exception 'invoice % is not in this workspace', v_src.number;
    end if;
    if v_src.member_id <> p_member_id then
      -- Regrouping across members would produce a demand nobody owes.
      raise exception 'invoice % belongs to another member', v_src.number;
    end if;
    if v_src.voided_at is not null then
      raise exception 'invoice % is void', v_src.number;
    end if;
    if v_src.settled_by_invoice_id is not null then
      raise exception 'invoice % is already settled', v_src.number;
    end if;
    if v_src.kind = 'settlement' then
      raise exception 'invoice % is itself a settlement', v_src.number;
    end if;
    if exists (select 1 from public.invoice_matches m
                where m.invoice_id = v_src.id) then
      -- A paid or part-paid invoice has a match to honour; folding it in
      -- would orphan that payment.
      raise exception 'invoice % already has a payment', v_src.number;
    end if;

    v_total := v_total + v_src.total_cents;
    -- One line per source: what it was, and what it left owing.
    v_lines := v_lines || jsonb_build_object(
      'kind', 'settled_invoice',
      'label', v_src.number,
      'quantity', 1,
      'vat_percent', 0,
      'amount_cents', v_src.total_cents);
    -- …and the whole of it, so the positions stay readable here.
    v_settles := v_settles || jsonb_build_object(
      'invoice_id', v_src.id,
      'number', v_src.number,
      'period', v_src.period,
      'kind', v_src.kind,
      'issued_at', v_src.issued_at,
      'total_cents', v_src.total_cents,
      'currency', v_src.currency,
      'lines', v_src.lines,
      'vat_totals', v_src.vat_totals);
    v_latest := v_src;
  end loop;

  if v_n <> array_length(p_invoice_ids, 1) then
    raise exception 'unknown invoice in the selection';
  end if;

  select * into v_workspace from public.workspaces where id = p_workspace_id;
  select coalesce(display_name, '') into v_issuer_name
    from public.profiles where id = v_actor.user_id;

  select count(*) into v_count from public.invoices
    where workspace_id = p_workspace_id
      and date_part('year', issued_at) = date_part('year', now());
  v_number := 'INV-' || date_part('year', now())::int || '-'
      || lpad((v_count + 1)::text, 4, '0');

  v_id := gen_random_uuid();
  v_signature := encode(extensions.digest(convert_to(concat_ws('|',
      v_id::text, v_number, p_workspace_id::text, v_subject.id::text,
      v_lines::text, v_total::text, v_settles::text,
      now()::date::text, 'settlement'),
      'UTF8'), 'sha256'), 'hex');

  insert into public.invoices
    (id, workspace_id, member_id, issuer_member_id, number, period, title,
     lines, total_cents, currency, member_name, member_address,
     workspace_name, workspace_address, issuer_name, signature,
     parties, vat_totals, kind, settles)
  values
    (v_id, p_workspace_id, p_member_id, v_actor.id, v_number,
     -- No period: a settlement can span months, and pinning it to one
     -- would collide with that month's own invoice in the kind index.
     null, coalesce(nullif(p_note, ''), v_number),
     v_lines, v_total, v_latest.currency,
     v_latest.member_name, v_latest.member_address,
     v_latest.workspace_name, v_latest.workspace_address,
     v_issuer_name, v_signature,
     v_latest.parties,
     -- Empty on purpose: the tax was declared on the sources.
     '[]'::jsonb, 'settlement', v_settles);

  update public.invoices
     set settled_by_invoice_id = v_id
   where id = any(p_invoice_ids);

  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id,
     payload, status)
  values
    (p_workspace_id, 'invoice_payment', 'created', v_actor.id, p_member_id,
     jsonb_build_object(
       'invoice_id', v_id, 'number', v_number, 'kind', 'settlement',
       'amount_cents', v_total, 'currency', v_latest.currency,
       'settled_count', v_n,
       'settled_numbers', (select jsonb_agg(s->>'number')
                             from jsonb_array_elements(v_settles) s)),
     'applied');

  return v_id;
end;
$$;
revoke execute on function
  public.settle_invoices(uuid, uuid, uuid[], text) from public, anon;
grant execute on function
  public.settle_invoices(uuid, uuid, uuid[], text) to authenticated;

-- ---------------------------------------------------------------- dunning
-- A settled invoice is no longer separately owed: the settlement carries
-- its balance, and chasing both would demand the same money twice.
--
-- Patched IN PLACE rather than regenerated. sweep_payment_reminders is
-- ninety lines of push plumbing this change does not touch, and copying
-- it forward to alter one WHERE clause is how a function acquires a
-- transcription bug. The guard makes it idempotent and it fails loudly
-- if 0134's shape ever moves out from under it.
do $patch$
declare
  v_def text;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'sweep_payment_reminders';
  if v_def is null then
    raise exception 'sweep_payment_reminders not found (0134 missing?)';
  end if;
  if position('settled_by_invoice_id is null' in v_def) > 0 then
    raise notice 'dunning already skips settled invoices';
    return;
  end if;
  if position('and not exists (select 1 from public.invoice_matches m' in v_def) = 0 then
    raise exception 'sweep_payment_reminders no longer has the shape 0143 patches';
  end if;
  execute replace(v_def,
    'and not exists (select 1 from public.invoice_matches m',
    'and i.settled_by_invoice_id is null
         and not exists (select 1 from public.invoice_matches m');
  raise notice 'dunning now skips settled invoices';
end $patch$;
