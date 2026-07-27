-- SPDX-License-Identifier: 0BSD
-- Payment-LINKED matching (field decision): the user never types an
-- amount — the match maps the invoice to a REGISTERED payment (a
-- confirmed ledger payment credit, which is also where online payments
-- land after settlement). Each payment can settle at most one invoice.
-- And a PAID invoice is DEFINITIVE: it can no longer be voided or
-- replaced — corrections stop at the match.

-- 1. The consumed payment, one invoice per payment.
alter table public.invoice_matches
  add column payment_ledger_id uuid
    references public.ledger_entries(id) on delete restrict;
create unique index invoice_matches_payment_unique
  on public.invoice_matches (payment_ledger_id)
  where payment_ledger_id is not null;

-- 2. match_invoice v2: amount comes FROM the selected payment.
drop function public.match_invoice(uuid, int, text, text);
create function public.match_invoice(
  p_invoice_id uuid,
  p_payment_ledger_id uuid,
  p_resolution text,
  p_note text default ''
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_invoice public.invoices;
  v_payment public.ledger_entries;
  v_paid int;
  v_actor public.members;
  v_actor_name text;
  v_note text := btrim(coalesce(p_note, ''));
  v_has_policy boolean;
  v_event_id uuid;
  v_credit_id uuid := null;
begin
  select * into v_invoice from public.invoices where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'unknown invoice'; end if;
  if v_invoice.voided_at is not null then
    raise exception 'invoice is voided';
  end if;
  if exists (select 1 from public.invoice_matches
              where invoice_id = p_invoice_id) then
    raise exception 'invoice already matched';
  end if;
  select * into v_actor from public.members
    where workspace_id = v_invoice.workspace_id and user_id = auth.uid()
      and status = 'active' and (is_admin or is_owner);
  if v_actor.id is null then raise exception 'not an admin of this workspace'; end if;
  if not public.is_owner_of(v_invoice.workspace_id) and not coalesce(
    (select w.feature_flags -> 'adminInvoicing' = to_jsonb(true)
       from public.workspaces w where w.id = v_invoice.workspace_id), false) then
    raise exception 'admins may not issue invoices here';
  end if;

  -- The REGISTERED payment being mapped (field decision: never a typed
  -- amount). Must belong to the invoice's member, be a confirmed
  -- payment credit, and not already settle another invoice.
  select * into v_payment from public.ledger_entries
    where id = p_payment_ledger_id
      and workspace_id = v_invoice.workspace_id
      and member_id = v_invoice.member_id
      and kind = 'credit' and category = 'payment';
  if v_payment.id is null then raise exception 'unknown payment'; end if;
  if exists (select 1 from public.invoice_matches
              where payment_ledger_id = p_payment_ledger_id) then
    raise exception 'payment already matched';
  end if;
  v_paid := v_payment.amount_cents;

  if p_resolution not in
      ('exact','over_forced','over_credit_note','under_accepted') then
    raise exception 'unknown resolution';
  end if;
  if p_resolution = 'exact' and v_paid <> v_invoice.total_cents then
    raise exception 'amount does not match the invoice';
  end if;
  if p_resolution in ('over_forced','over_credit_note')
     and v_paid <= v_invoice.total_cents then
    raise exception 'amount does not exceed the invoice';
  end if;
  if p_resolution = 'under_accepted'
     and v_paid >= v_invoice.total_cents then
    raise exception 'amount is not below the invoice';
  end if;
  if p_resolution in ('over_forced','under_accepted') and v_note = '' then
    raise exception 'a note is required';
  end if;

  select coalesce(display_name, '') into v_actor_name
    from public.profiles where id = v_actor.user_id;

  if p_resolution = 'over_credit_note' then
    insert into public.ledger_entries
      (workspace_id, member_id, kind, category, amount_cents,
       description, period)
    values
      (v_invoice.workspace_id, v_invoice.member_id, 'credit',
       'adjustment', v_paid - v_invoice.total_cents,
       'Credit note ' || v_invoice.number
         || case when v_note = '' then '' else ' — ' || v_note end,
       to_char(now(), 'YYYY-MM'))
    returning id into v_credit_id;
  end if;

  v_has_policy := exists (
    select 1 from public.validation_policies vp
    where vp.workspace_id = v_invoice.workspace_id
      and vp.event_type = 'invoice_payment');

  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id,
     payload, status, decided_at)
  values
    (v_invoice.workspace_id, 'invoice_payment', 'submitted',
     v_actor.id, v_invoice.member_id,
     jsonb_build_object(
       'invoice_id', v_invoice.id,
       'number', v_invoice.number,
       'due_cents', v_invoice.total_cents,
       'paid_cents', v_paid,
       'amount_cents', v_paid,
       'payment_ledger_id', p_payment_ledger_id,
       'resolution', p_resolution,
       'note', v_note),
     case when v_has_policy then 'pending' else 'confirmed' end,
     case when v_has_policy then null else now() end)
  returning id into v_event_id;

  insert into public.invoice_matches
    (workspace_id, invoice_id, paid_cents, resolution, note, status,
     event_id, credit_ledger_id, payment_ledger_id, by_name)
  values
    (v_invoice.workspace_id, p_invoice_id, v_paid, p_resolution,
     v_note, case when v_has_policy then 'pending' else 'confirmed' end,
     v_event_id, v_credit_id, p_payment_ledger_id, v_actor_name);
end;
$$;
revoke execute on function
  public.match_invoice(uuid, uuid, text, text) from public, anon;

-- 3. A PAID invoice is definitive: voiding refuses (pinned substring).
create or replace function public.void_invoice(p_invoice_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_invoice public.invoices;
  v_actor public.members;
  v_actor_name text;
begin
  select * into v_invoice from public.invoices where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'unknown invoice'; end if;
  if exists (select 1 from public.invoice_matches
              where invoice_id = p_invoice_id) then
    -- 0068: a paid (or awaiting-validation) invoice is definitive.
    raise exception 'invoice is matched';
  end if;
  select * into v_actor from public.members
    where workspace_id = v_invoice.workspace_id and user_id = auth.uid()
      and status = 'active' and (is_admin or is_owner);
  if v_actor.id is null then raise exception 'not an admin of this workspace'; end if;
  if not public.is_owner_of(v_invoice.workspace_id) and not coalesce(
    (select w.feature_flags -> 'adminInvoicing' = to_jsonb(true)
       from public.workspaces w where w.id = v_invoice.workspace_id), false) then
    raise exception 'admins may not issue invoices here';
  end if;
  if v_invoice.voided_at is not null then
    raise exception 'invoice already voided';
  end if;
  select coalesce(display_name, '') into v_actor_name
    from public.profiles where id = v_actor.user_id;
  update public.invoices
     set voided_at = now(), voided_by_name = v_actor_name
   where id = p_invoice_id;
end;
$$;

-- 4. create_invoice v6: replacing a MATCHED invoice refuses too.
create or replace function public.create_invoice(
  p_workspace_id uuid,
  p_member_id uuid,
  p_period text,
  p_replaces uuid default null,
  p_detailed boolean default false
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_actor public.members;
  v_subject public.members;
  v_workspace public.workspaces;
  v_replaced public.invoices;
  v_replaces_number text := '';
  v_lines jsonb;
  v_details jsonb := null;
  v_tz text;
  v_period_start timestamptz;
  v_period_end timestamptz;
  v_total int := 0;
  v_count int;
  v_number text;
  v_member_name text;
  v_member_address text;
  v_issuer_name text;
  v_id uuid;
  v_signature text;
begin
  select * into v_actor from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid()
      and status = 'active' and (is_admin or is_owner);
  if v_actor.id is null then raise exception 'not an admin of this workspace'; end if;
  if not public.is_owner_of(p_workspace_id) and not coalesce(
    (select w.feature_flags -> 'adminInvoicing' = to_jsonb(true)
       from public.workspaces w where w.id = p_workspace_id), false) then
    raise exception 'admins may not issue invoices here';
  end if;

  select * into v_subject from public.members
    where id = p_member_id and workspace_id = p_workspace_id
      and status = 'active' and not is_kiosk;
  if v_subject.id is null then raise exception 'unknown subject member'; end if;
  if p_period is null or p_period !~ '^[0-9]{4}-[0-9]{2}$' then
    raise exception 'invalid period';
  end if;
  -- 0067: one ACTIVE invoice per member+month. Voided (erronée)
  -- invoices free their month; the one being replaced is voided below
  -- in this same transaction, so it does not count either.
  if exists (
    select 1 from public.invoices i
    where i.member_id = v_subject.id and i.period = p_period
      and i.voided_at is null and i.id is distinct from p_replaces
  ) then
    raise exception 'period already invoiced for this member';
  end if;

  v_lines := public.invoice_lines_for(p_member_id, p_period);
  if jsonb_array_length(v_lines) = 0 then
    raise exception 'nothing to invoice for this period';
  end if;
  select coalesce(sum((l->>'amount_cents')::int), 0) into v_total
    from jsonb_array_elements(v_lines) l;

  select * into v_workspace from public.workspaces where id = p_workspace_id;
  select coalesce(display_name, ''), coalesce(address, '')
    into v_member_name, v_member_address
    from public.profiles where id = v_subject.user_id;
  select coalesce(display_name, '') into v_issuer_name
    from public.profiles where id = v_actor.user_id;

  if p_detailed then
    v_tz := v_workspace.timezone;
    v_period_start := to_timestamp(p_period || '-01', 'YYYY-MM-DD') at time zone v_tz;
    v_period_end := (to_timestamp(p_period || '-01', 'YYYY-MM-DD') + interval '1 month') at time zone v_tz;
    v_details := jsonb_build_object(
      'ledger', coalesce((
        select jsonb_agg(jsonb_build_object(
            'on', le.created_at::date::text,
            'category', le.category,
            'description', le.description,
            'amount_cents', case when le.kind = 'credit'
                                 then -le.amount_cents
                                 else le.amount_cents end)
          order by le.created_at)
        from public.ledger_entries le
        where le.member_id = p_member_id and le.period = p_period
      ), '[]'::jsonb),
      'attendance', coalesce((
        select jsonb_agg(jsonb_build_object(
            'starts_at', to_char(r.starts_at at time zone v_tz,
                                 'YYYY-MM-DD"T"HH24:MI'),
            'ends_at', to_char(r.ends_at at time zone v_tz,
                               'YYYY-MM-DD"T"HH24:MI'),
            'status', r.status,
            'space', coalesce(
              (select s.name || ' · ' || d.name
                 from public.seats s
                 join public.desks d on d.id = s.desk_id
                where s.id = r.seat_id),
              (select d.name from public.desks d where d.id = r.desk_id),
              (select o.name from public.offices o where o.id = r.office_id),
              (select l.name from public.levels l where l.id = r.level_id),
              ''))
          order by r.starts_at)
        from public.reservations r
        where r.member_id = p_member_id
          and r.status in ('reserved', 'checked_in', 'completed')
          and r.starts_at >= v_period_start and r.starts_at < v_period_end
      ), '[]'::jsonb));
  end if;

  if p_replaces is not null then
    select * into v_replaced from public.invoices
      where id = p_replaces and workspace_id = p_workspace_id;
    if v_replaced.id is null then raise exception 'unknown invoice'; end if;
    if exists (select 1 from public.invoices
                where replaces_invoice_id = p_replaces) then
      raise exception 'invoice already replaced';
    end if;
    if exists (select 1 from public.invoice_matches
                where invoice_id = p_replaces) then
      -- 0068: a paid invoice is definitive — no replacement either.
      raise exception 'invoice is matched';
    end if;
    if v_replaced.voided_at is null then
      update public.invoices
         set voided_at = now(), voided_by_name = v_issuer_name
       where id = p_replaces;
    end if;
    v_replaces_number := v_replaced.number;
  end if;

  perform pg_advisory_xact_lock(hashtext(p_workspace_id::text));
  select count(*) into v_count from public.invoices
    where workspace_id = p_workspace_id
      and date_part('year', issued_at) = date_part('year', now());
  v_number := 'INV-' || date_part('year', now())::int || '-'
      || lpad((v_count + 1)::text, 4, '0');

  v_id := gen_random_uuid();
  v_signature := encode(extensions.digest(convert_to(concat_ws('|',
      v_id::text, v_number, p_workspace_id::text, v_subject.id::text,
      v_member_name, v_member_address, v_workspace.name,
      coalesce(v_workspace.address, ''), v_issuer_name,
      p_period, v_lines::text, v_total::text, v_workspace.currency_code,
      now()::date::text, coalesce(p_replaces::text, ''),
      v_replaces_number, coalesce(v_details::text, '')),
      'UTF8'), 'sha256'), 'hex');

  insert into public.invoices
    (id, workspace_id, member_id, issuer_member_id, number, period, title,
     lines, total_cents, currency, member_name, member_address,
     workspace_name, workspace_address, issuer_name, signature,
     replaces_invoice_id, replaces_number, details)
  values
    (v_id, p_workspace_id, v_subject.id, v_actor.id, v_number, p_period,
     p_period, v_lines, v_total, v_workspace.currency_code,
     v_member_name, v_member_address, v_workspace.name,
     coalesce(v_workspace.address, ''), v_issuer_name, v_signature,
     p_replaces, v_replaces_number, v_details);
  return v_id;
end;
$$;
