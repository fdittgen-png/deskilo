-- SPDX-License-Identifier: 0BSD
-- A recorded payment had no date and no target month: the ledger stamped
-- it the moment it was typed in and booked it to `to_char(now())`. A
-- transfer made on the 3rd and entered on the 26th therefore landed on the
-- wrong day AND — at a month boundary — on the wrong bill and the wrong
-- invoice, which the 0067/0068 matching then had to work around.
--
-- Two facts, declared by the payer:
--   * WHEN the money moved → `ledger_entries.occurred_on` (a DATE: what
--     matters is the day, in the payer's own calendar, not an instant);
--   * WHICH month it settles → the ledger `period`, which decides the
--     statement and the invoice the credit belongs to.
--
-- `created_at` stays exactly what it was: the audit stamp of the booking.
--
-- Applied to staging 2026-07-27 as two migration rows
-- (`payment_date_and_period` = sections 1–3, `invoice_annex_occurred_on`
-- = section 4); this file is the single source of truth for a rebuild.

-- 1. The business date beside the audit stamp. Nullable on purpose:
-- pre-0070 rows have none, and entries where booking IS the event (an
-- online payment settling, a credit note) keep falling back to created_at.
alter table public.ledger_entries add column occurred_on date;

comment on column public.ledger_entries.occurred_on is
  'The day the money actually moved, as declared by the payer. NULL = '
  'the booking date (created_at) is the truth. Never rewrites created_at, '
  'which stays the audit stamp.';

-- 2. record_payment v3: the two declared facts ride in the event payload
-- until the quorum confirms. Both optional — an old client keeps the old
-- behaviour exactly (today, current month).
drop function if exists public.record_payment(uuid, uuid, int, text, text);
create function public.record_payment(
  p_workspace_id uuid,
  p_member_id uuid,
  p_amount_cents int,
  p_note text default '',
  p_method text default '',
  p_paid_on date default null,
  p_period text default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_actor public.members;
  v_event_id uuid;
  v_paid_on date := coalesce(p_paid_on, current_date);
  v_period text := coalesce(p_period, to_char(now(), 'YYYY-MM'));
begin
  select * into v_actor from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_actor.id is null then raise exception 'not an active member'; end if;
  if p_amount_cents <= 0 then raise exception 'amount must be positive'; end if;
  if v_actor.id <> p_member_id and not (v_actor.is_admin or v_actor.is_owner) then
    raise exception 'only admins record payments for others';
  end if;
  -- Free-form-but-bounded method tag; the app sends one of the
  -- PaymentMethod enum wire names ('' = not specified, old clients).
  if length(p_method) > 32 then raise exception 'method too long'; end if;
  if v_period !~ '^[0-9]{4}-[0-9]{2}$' then raise exception 'invalid period'; end if;
  -- Money cannot have moved tomorrow. One day of slack absorbs the gap
  -- between the server's UTC date and a workspace east of it.
  if v_paid_on > current_date + 1 then
    raise exception 'payment date is in the future';
  end if;
  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  values (
    p_workspace_id, 'payment', 'submitted', v_actor.id, p_member_id,
    jsonb_build_object(
      'amount_cents', p_amount_cents,
      'note', p_note,
      'method', p_method,
      'paid_on', v_paid_on,
      'period', v_period
    ),
    'pending'
  ) returning id into v_event_id;
  return v_event_id;
end;
$$;

-- Same hardening as 0004/0008/0019: only signed-in members may call it.
revoke execute on function
  public.record_payment(uuid, uuid, int, text, text, date, text)
  from public, anon;

-- 3. respond_to_event: the 0067 body, with the payment/expense ledger
-- insert reading the two declared facts out of the payload. Everything
-- else is verbatim — a payload without them behaves exactly as before.
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
    and (v_caller.id <> v_event.actor_member_id or v_pool_size = 0);
  if v_pool_size = 0 and (v_caller.is_owner or (v_caller.is_admin and v_policy.admins_may_validate)) then
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
      -- 0070: the payer's own date and target month when the payload
      -- carries them; the old behaviour (today, current month) when not.
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
        (workspace_id, member_id, kind, category, amount_cents, description, period, event_id)
      values (
        v_event.workspace_id, v_event.subject_member_id, 'charge', 'service',
        (v_event.payload->>'amount_cents')::int,
        (v_event.payload->>'name') || ' x' || (v_event.payload->>'quantity'),
        coalesce(v_event.payload->>'period', to_char(now(), 'YYYY-MM')),
        v_event.id
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
      -- the validated welcome: the pending membership becomes active
      update public.members set status = 'active'
        where id = v_event.subject_member_id and status = 'pending';
    elsif v_event.type = 'invoice_payment' then
      update public.invoice_matches set status = 'confirmed'
        where event_id = v_event.id;
    end if;
  end if;
end;
$$;

-- 4. The invoice ANNEX (0064) dates its movements the same way: what the
-- member reads on the annex must be the day the money moved. Body = the
-- 0069 create_invoice v7 verbatim, with that one date expression changed.
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
  v_parties jsonb;
  v_tz text;
  v_period_start timestamptz;
  v_period_end timestamptz;
  v_total int := 0;
  v_count int;
  v_number text;
  v_member_name text;
  v_member_address text;
  v_member_country text;
  v_member_vat text;
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
  select coalesce(display_name, ''), coalesce(address, ''),
         coalesce(country_code, ''), coalesce(vat_id, '')
    into v_member_name, v_member_address, v_member_country, v_member_vat
    from public.profiles where id = v_subject.user_id;
  select coalesce(display_name, '') into v_issuer_name
    from public.profiles where id = v_actor.user_id;

  v_parties := jsonb_build_object(
    'seller', jsonb_build_object(
      'name', v_workspace.name,
      'street', coalesce(nullif(v_workspace.street, ''),
                         coalesce(v_workspace.address, '')),
      'city', coalesce(v_workspace.city, ''),
      'postal_code', coalesce(v_workspace.postal_code, ''),
      'country', v_workspace.country_code,
      'vat_id', coalesce(v_workspace.vat_id, ''),
      'legal_id', coalesce(v_workspace.legal_id, ''),
      'vat_regime', coalesce(v_workspace.vat_regime, 'not_subject'),
      'tax_exemption_reason',
        coalesce(v_workspace.tax_exemption_reason, '')),
    'buyer', jsonb_build_object(
      'name', v_member_name,
      'street', v_member_address,
      'country', coalesce(nullif(v_member_country, ''),
                          v_workspace.country_code),
      'vat_id', v_member_vat));

  if p_detailed then
    v_tz := v_workspace.timezone;
    v_period_start := to_timestamp(p_period || '-01', 'YYYY-MM-DD') at time zone v_tz;
    v_period_end := (to_timestamp(p_period || '-01', 'YYYY-MM-DD') + interval '1 month') at time zone v_tz;
    v_details := jsonb_build_object(
      'ledger', coalesce((
        select jsonb_agg(jsonb_build_object(
            -- 0070: the day the money moved, not the day it was booked.
            'on', coalesce(le.occurred_on, le.created_at::date)::text,
            'category', le.category,
            'description', le.description,
            'amount_cents', case when le.kind = 'credit'
                                 then -le.amount_cents
                                 else le.amount_cents end)
          order by coalesce(le.occurred_on, le.created_at::date), le.created_at)
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
      v_replaces_number, coalesce(v_details::text, ''),
      v_parties::text),
      'UTF8'), 'sha256'), 'hex');

  insert into public.invoices
    (id, workspace_id, member_id, issuer_member_id, number, period, title,
     lines, total_cents, currency, member_name, member_address,
     workspace_name, workspace_address, issuer_name, signature,
     replaces_invoice_id, replaces_number, details, parties)
  values
    (v_id, p_workspace_id, v_subject.id, v_actor.id, v_number, p_period,
     p_period, v_lines, v_total, v_workspace.currency_code,
     v_member_name, v_member_address, v_workspace.name,
     coalesce(v_workspace.address, ''), v_issuer_name, v_signature,
     p_replaces, v_replaces_number, v_details, v_parties);
  return v_id;
end;
$$;
revoke execute on function
  public.create_invoice(uuid, uuid, text, uuid, boolean) from public, anon;
