-- SPDX-License-Identifier: 0BSD
-- Additional payments onto a PARTIALLY PAID invoice (#506). A partial
-- invoice stays open (#504); new payments keep coming in and must be
-- matchable against the REMAINING amount — maybe until fully paid,
-- maybe the rest is written off (#504). The invoice_matches row becomes
-- the AGGREGATE (paid_cents = everything applied so far); the new
-- invoice_match_payments table records every consumed payment for the
-- audit trail and the never-consume-twice guard.

create table public.invoice_match_payments (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id)
    on delete cascade,
  invoice_id uuid not null references public.invoices(id)
    on delete cascade,
  payment_ledger_id uuid not null unique
    references public.ledger_entries(id) on delete cascade,
  amount_cents int not null check (amount_cents >= 0),
  resolution text not null check (resolution in
    ('exact','over_forced','over_credit_note','under_accepted')),
  note text not null default '',
  event_id uuid references public.events(id) on delete set null,
  credit_ledger_id uuid references public.ledger_entries(id)
    on delete set null,
  matched_at timestamptz not null default now(),
  by_name text not null default ''
);
create index invoice_match_payments_invoice_idx
  on public.invoice_match_payments (invoice_id);
create index invoice_match_payments_workspace_idx
  on public.invoice_match_payments (workspace_id);

alter table public.invoice_match_payments enable row level security;
create policy invoice_match_payments_select
  on public.invoice_match_payments
  for select using (
    public.is_admin_of(workspace_id)
    or exists (select 1
                 from public.invoices i
                 join public.members m on m.id = i.member_id
                where i.id = invoice_match_payments.invoice_id
                  and m.user_id = auth.uid())
  );
-- No write policies: writes only through match_invoice /
-- respond_to_event.

-- Backfill: every existing match consumed exactly one payment.
insert into public.invoice_match_payments
  (workspace_id, invoice_id, payment_ledger_id, amount_cents,
   resolution, note, event_id, credit_ledger_id, matched_at, by_name)
select workspace_id, invoice_id, payment_ledger_id, paid_cents,
       resolution, note, event_id, credit_ledger_id, matched_at, by_name
  from public.invoice_matches
 where payment_ledger_id is not null
on conflict (payment_ledger_id) do nothing;

-- match_invoice v3: the 0068 body, generalized — an invoice with a
-- STANDING partial match accepts further payments against the
-- REMAINING amount. The junction row is written immediately (it
-- reserves the payment even while a quorum decides); the aggregate is
-- updated on confirmation (immediately when no policy applies).
create or replace function public.match_invoice(
  p_invoice_id uuid,
  p_payment_ledger_id uuid,
  p_resolution text,
  p_note text default ''
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_invoice public.invoices;
  v_existing public.invoice_matches;
  v_payment public.ledger_entries;
  v_paid int;
  v_due int;
  v_actor public.members;
  v_actor_name text;
  v_note text := btrim(coalesce(p_note, ''));
  v_has_policy boolean;
  v_event_id uuid;
  v_credit_id uuid := null;
  v_additional boolean := false;
begin
  select * into v_invoice from public.invoices where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'unknown invoice'; end if;
  if v_invoice.voided_at is not null then
    raise exception 'invoice is voided';
  end if;
  select * into v_existing from public.invoice_matches
    where invoice_id = p_invoice_id;
  if v_existing.invoice_id is not null then
    -- #506 — only a STANDING partial (not written off) accepts more.
    if v_existing.status <> 'confirmed'
       or v_existing.resolution <> 'under_accepted'
       or v_existing.writeoff_at is not null then
      raise exception 'invoice already matched';
    end if;
    v_additional := true;
    v_due := v_invoice.total_cents - v_existing.paid_cents;
  else
    v_due := v_invoice.total_cents;
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

  select * into v_payment from public.ledger_entries
    where id = p_payment_ledger_id
      and workspace_id = v_invoice.workspace_id
      and member_id = v_invoice.member_id
      and kind = 'credit' and category = 'payment';
  if v_payment.id is null then raise exception 'unknown payment'; end if;
  if exists (select 1 from public.invoice_match_payments
              where payment_ledger_id = p_payment_ledger_id) then
    raise exception 'payment already matched';
  end if;
  v_paid := v_payment.amount_cents;

  if p_resolution not in
      ('exact','over_forced','over_credit_note','under_accepted') then
    raise exception 'unknown resolution';
  end if;
  -- All amount rules compare against what is STILL DUE (#506).
  if p_resolution = 'exact' and v_paid <> v_due then
    raise exception 'amount does not match the invoice';
  end if;
  if p_resolution in ('over_forced','over_credit_note')
     and v_paid <= v_due then
    raise exception 'amount does not exceed the invoice';
  end if;
  if p_resolution = 'under_accepted' and v_paid >= v_due then
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
       'adjustment', v_paid - v_due,
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
       'due_cents', v_due,
       'paid_cents', v_paid,
       'amount_cents', v_paid,
       'payment_ledger_id', p_payment_ledger_id,
       'resolution', p_resolution,
       'note', v_note,
       'additional', v_additional),
     case when v_has_policy then 'pending' else 'confirmed' end,
     case when v_has_policy then null else now() end)
  returning id into v_event_id;

  -- The junction row reserves the payment even while pending.
  insert into public.invoice_match_payments
    (workspace_id, invoice_id, payment_ledger_id, amount_cents,
     resolution, note, event_id, credit_ledger_id, by_name)
  values
    (v_invoice.workspace_id, p_invoice_id, p_payment_ledger_id, v_paid,
     p_resolution, v_note, v_event_id, v_credit_id, v_actor_name);

  if v_additional then
    -- The aggregate moves only when the payment stands.
    if not v_has_policy then
      update public.invoice_matches
        set paid_cents = paid_cents + v_paid,
            resolution = p_resolution,
            note = case when v_note = '' then note else v_note end,
            payment_ledger_id = p_payment_ledger_id,
            credit_ledger_id = coalesce(v_credit_id, credit_ledger_id),
            matched_at = now(),
            by_name = v_actor_name
        where invoice_id = p_invoice_id;
    end if;
  else
    insert into public.invoice_matches
      (workspace_id, invoice_id, paid_cents, resolution, note, status,
       event_id, credit_ledger_id, payment_ledger_id, by_name)
    values
      (v_invoice.workspace_id, p_invoice_id, v_paid, p_resolution,
       v_note, case when v_has_policy then 'pending' else 'confirmed' end,
       v_event_id, v_credit_id, p_payment_ledger_id, v_actor_name);
  end if;
end;
$$;
revoke execute on function
  public.match_invoice(uuid, uuid, text, text) from public, anon;

-- respond_to_event v-next: the 0100 body (generated from it verbatim)
-- + the #506 additional-payment branches: reject releases the reserved
-- payment (junction row + its credit note); confirm applies the
-- addition to the aggregate match.
create or replace function public.respond_to_event(
  p_event_id uuid,
  p_accept boolean
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_event public.events;
  v_caller public.members;
  v_policy record;
  v_subject_decides boolean;
  v_in_pool boolean;
  v_pool_size int;
  v_required int;
  v_accepts int;
  v_subject_ok boolean;
  v_owner_ok boolean;
begin
  select e.* into v_event from public.events e where e.id = p_event_id;
  if v_event.id is null then raise exception 'unknown event'; end if;
  if v_event.status <> 'pending' then raise exception 'already decided'; end if;

  select m.* into v_caller from public.members m
    where m.workspace_id = v_event.workspace_id and m.user_id = auth.uid()
      and m.status = 'active';
  if v_caller.id is null then raise exception 'not a member'; end if;
  if exists (select 1 from public.event_decisions d
              where d.event_id = p_event_id and d.member_id = v_caller.id) then
    raise exception 'you already decided this event';
  end if;

  select * into v_policy from public.validation_policies
    where workspace_id = v_event.workspace_id and event_type = v_event.type;
  if v_policy is null then
    select * into v_policy from public.validation_policies
      where workspace_id = v_event.workspace_id and event_type is null;
  end if;
  if v_policy is null then
    select null::uuid as id, v_event.workspace_id as workspace_id,
           null::text as event_type, 1 as required_count,
           true as admins_may_validate, '{}'::uuid[] as eligible_admin_ids,
           false as owner_required
      into v_policy;
  end if;

  v_subject_decides := v_event.type = 'reservation'
    or (v_event.type in ('payment','service_charge')
        and v_event.actor_member_id <> v_event.subject_member_id);

  select count(*) into v_pool_size from public.members m
    where m.workspace_id = v_event.workspace_id and m.status = 'active'
      and m.id not in (v_event.actor_member_id, v_event.subject_member_id)
      and (m.is_owner or (m.is_admin and v_policy.admins_may_validate
           and (cardinality(v_policy.eligible_admin_ids) = 0
                or m.id = any(v_policy.eligible_admin_ids))));

  v_in_pool := (v_caller.is_owner or (v_caller.is_admin and v_policy.admins_may_validate
                and (cardinality(v_policy.eligible_admin_ids) = 0
                     or v_caller.id = any(v_policy.eligible_admin_ids))))
    and (v_caller.id <> v_event.subject_member_id
         or (not v_subject_decides and v_pool_size = 0))
    and v_caller.id <> v_event.actor_member_id;
  if v_pool_size = 0
     and v_caller.id <> v_event.actor_member_id
     and (v_caller.is_owner or (v_caller.is_admin and v_policy.admins_may_validate)) then
    v_pool_size := 1;
  end if;

  if v_subject_decides and v_caller.id = v_event.subject_member_id then
    null;
  elsif v_in_pool then
    null;
  else
    raise exception 'you are not an eligible validator for this event';
  end if;

  insert into public.event_decisions (event_id, member_id, decision)
  values (p_event_id, v_caller.id, case when p_accept then 'accept' else 'reject' end);

  if not p_accept then
    update public.events set status = 'rejected', decided_at = now()
      where id = p_event_id;
    if v_event.reservation_id is not null then
      update public.reservations set status = 'cancelled'
        where id = v_event.reservation_id and status in ('reserved','checked_in');
    end if;
    if v_event.type = 'member_join' then
      update public.members set status = 'exited'
        where id = v_event.subject_member_id and status = 'pending';
    end if;
    if v_event.type = 'invoice_payment' then
      delete from public.ledger_entries
        where id = (select credit_ledger_id from public.invoice_matches
                     where event_id = v_event.id);
      delete from public.invoice_matches where event_id = v_event.id;
      -- #506 — an ADDITIONAL payment leaves no match row; its credit
      -- note and its payment reservation are released here.
      delete from public.ledger_entries
        where id in (select credit_ledger_id
                       from public.invoice_match_payments
                      where event_id = v_event.id
                        and credit_ledger_id is not null);
      delete from public.invoice_match_payments
        where event_id = v_event.id;
    end if;
    return;
  end if;

  select count(*) into v_accepts from public.event_decisions
    where event_id = p_event_id and decision = 'accept';
  v_required := greatest(1, least(v_policy.required_count,
    v_pool_size + case when v_subject_decides then 1 else 0 end));
  v_subject_ok := not v_subject_decides or exists (
    select 1 from public.event_decisions d
    where d.event_id = p_event_id and d.decision = 'accept'
      and d.member_id = v_event.subject_member_id);
  v_owner_ok := not v_policy.owner_required or exists (
    select 1 from public.event_decisions d
    join public.members m on m.id = d.member_id
    where d.event_id = p_event_id and d.decision = 'accept' and m.is_owner);

  if v_accepts >= v_required and v_subject_ok and v_owner_ok then
    update public.events set status = 'confirmed', decided_at = now()
      where id = p_event_id;

    if v_event.type in ('payment','expense') then
      insert into public.ledger_entries
        (workspace_id, member_id, kind, category, amount_cents, description,
         period, event_id, occurred_on)
      values (
        v_event.workspace_id, v_event.subject_member_id, 'credit',
        case when v_event.type = 'payment' then 'payment' else 'expense' end,
        (v_event.payload->>'amount_cents')::int,
        coalesce(v_event.payload->>'note', ''),
        coalesce(v_event.payload->>'period', to_char(now(), 'YYYY-MM')),
        v_event.id,
        (v_event.payload->>'paid_on')::date
      );
    elsif v_event.type = 'service_charge' then
      insert into public.ledger_entries
        (workspace_id, member_id, kind, category, amount_cents, description,
         period, event_id, vat_percent)
      values (
        v_event.workspace_id, v_event.subject_member_id, 'charge', 'service',
        (v_event.payload->>'amount_cents')::int,
        (v_event.payload->>'name') || ' x' || (v_event.payload->>'quantity'),
        coalesce(v_event.payload->>'period', to_char(now(), 'YYYY-MM')),
        v_event.id,
        (v_event.payload->>'vat_percent')::numeric
      );
    elsif v_event.type = 'quota' then
      insert into public.quota_extensions
        (workspace_id, member_id, period, half_days, event_id)
      values (
        v_event.workspace_id, v_event.subject_member_id,
        v_event.payload->>'period',
        (v_event.payload->>'half_days')::int,
        v_event.id
      );
    elsif v_event.type = 'role_change' then
      update public.members
        set is_admin = (v_event.payload->>'make_admin')::boolean
        where id = v_event.subject_member_id;
    elsif v_event.type = 'member_join' then
      update public.members set status = 'active'
        where id = v_event.subject_member_id and status = 'pending';
    elsif v_event.type = 'invoice_payment' then
      update public.invoice_matches set status = 'confirmed'
        where event_id = v_event.id;
      -- #506 — a validated ADDITIONAL payment lands on the aggregate.
      if coalesce(v_event.payload->>'additional', 'false') = 'true' then
        update public.invoice_matches m
          set paid_cents = m.paid_cents + jr.amount_cents,
              resolution = jr.resolution,
              note = case when jr.note = '' then m.note else jr.note end,
              payment_ledger_id = jr.payment_ledger_id,
              credit_ledger_id =
                coalesce(jr.credit_ledger_id, m.credit_ledger_id),
              matched_at = now(),
              by_name = jr.by_name
          from public.invoice_match_payments jr
          where jr.event_id = v_event.id
            and m.invoice_id = jr.invoice_id;
      end if;
    elsif v_event.type = 'reservation_delete' then
      update public.reservations set status = 'cancelled'
        where id = (v_event.payload->>'reservation_id')::uuid
          and status in ('reserved','checked_in','completed');
    elsif v_event.type = 'invoice_writeoff' then
      -- #504 — the validated write-off: the remainder is forgiven and
      -- the invoice finally reads CLOSED (partially paid, remainder
      -- cancelled).
      update public.invoice_matches
        set writeoff_at = now(), writeoff_event_id = v_event.id
        where invoice_id = (v_event.payload->>'invoice_id')::uuid
          and resolution = 'under_accepted' and writeoff_at is null;
    end if;
  end if;
end;
$$;
