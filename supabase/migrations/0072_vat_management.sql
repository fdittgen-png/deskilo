-- SPDX-License-Identifier: 0BSD
-- VAT. Until now the app could only say "no VAT charged" — an EN 16931
-- export from a VAT-registered workspace was refused outright, because
-- declaring a zero a seller does owe is a false statement.
--
-- THE RULE, once and everywhere: **prices are VAT-INCLUSIVE**. What the
-- owner types on a service, a package or a fee band is what the member
-- pays; the tax is EXTRACTED from it for the documents. That choice is
-- deliberate:
--   * turning VAT on never changes what anyone owes — the same money, now
--     with the tax shown;
--   * the ledger, the statement and the quota machinery keep working on
--     the amounts they already hold, so there is one truth about money;
--   * a coworking advertises "250 €/month", not "208,33 € + VAT".
--
-- THE SPLIT, once and everywhere (mirrored in Dart, pinned by test):
--     net = round(gross × 100 / (100 + percent));  vat = gross − net
-- applied PER LINE. Every total is then a plain sum of lines, so the VAT
-- breakdown, the net total and the payable amount all tie back to the
-- ledger without a reconciliation step.
--
-- Credits (payments, reimbursements) carry no VAT: they are movements of
-- money, not supplies.
--
-- NOT YET applied to the hosted reference project.

-- 1. The rates a workspace charges. Member-readable (they appear on the
-- bill), owner-written through the RPC below.
create table public.vat_rates (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  label text not null check (char_length(label) between 1 and 40),
  -- 0.00–99.99; 0 means the rate itself carries no tax (zero-rated or the
  -- workspace's exemption, per its declared regime).
  percent numeric(5,2) not null check (percent >= 0 and percent < 100),
  -- EN 16931 BT-118 (UNCL5305): S for any taxed rate — reduced rates are
  -- still category S with their own percentage — Z zero-rated, E exempt,
  -- O outside the scope.
  category text not null default 'S' check (category in ('S','Z','E','O')),
  -- Exactly one default per workspace: what subscriptions, overage,
  -- supplements and adjustments use, and what a new service starts with.
  is_default boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create index vat_rates_workspace_idx on public.vat_rates (workspace_id);
create unique index vat_rates_one_default
  on public.vat_rates (workspace_id) where is_default;

alter table public.vat_rates enable row level security;
create policy vat_rates_select on public.vat_rates
  for select using (public.is_member_of(workspace_id));
-- No write policies: writes go through set_vat_rates below.

-- 2. Owner-only, atomic replace of the whole rate set — the same shape as
-- replace_fee_bands. Rates a service still points at are kept alive by
-- their id, so re-saving the set never silently re-taxes a catalogue.
create or replace function public.set_vat_rates(
  p_workspace_id uuid, p_rates jsonb
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_rate jsonb;
  v_defaults int := 0;
  v_keep uuid[] := '{}';
  v_id uuid;
begin
  if not public.is_owner_of(p_workspace_id) then
    raise exception 'not the owner of this workspace';
  end if;
  if p_rates is null or jsonb_typeof(p_rates) <> 'array' then
    raise exception 'rates must be an array';
  end if;
  for v_rate in select * from jsonb_array_elements(p_rates) loop
    if coalesce((v_rate->>'is_default')::boolean, false) then
      v_defaults := v_defaults + 1;
    end if;
  end loop;
  if jsonb_array_length(p_rates) > 0 and v_defaults <> 1 then
    raise exception 'exactly one rate must be the default';
  end if;

  -- Upsert by id so a catalogue entry keeps pointing at the same rate.
  for v_rate in select * from jsonb_array_elements(p_rates) loop
    if (v_rate->>'id') is not null and (v_rate->>'id') <> '' then
      v_id := (v_rate->>'id')::uuid;
      update public.vat_rates
         set label = v_rate->>'label',
             percent = (v_rate->>'percent')::numeric,
             category = coalesce(v_rate->>'category', 'S'),
             -- defaults are cleared first, below, so this cannot collide
             is_default = false,
             active = coalesce((v_rate->>'active')::boolean, true)
       where id = v_id and workspace_id = p_workspace_id;
    else
      insert into public.vat_rates
        (workspace_id, label, percent, category, is_default, active)
      values (
        p_workspace_id,
        v_rate->>'label',
        (v_rate->>'percent')::numeric,
        coalesce(v_rate->>'category', 'S'),
        false,
        coalesce((v_rate->>'active')::boolean, true))
      returning id into v_id;
    end if;
    v_keep := v_keep || v_id;
  end loop;

  -- Rates the owner dropped: deactivate rather than delete when a
  -- catalogue entry or an invoice still refers to them.
  update public.vat_rates set active = false, is_default = false
   where workspace_id = p_workspace_id and not (id = any(v_keep));

  -- And now the single default.
  for v_rate in select * from jsonb_array_elements(p_rates) loop
    if coalesce((v_rate->>'is_default')::boolean, false) then
      update public.vat_rates set is_default = true
       where workspace_id = p_workspace_id
         and (case when (v_rate->>'id') is not null and (v_rate->>'id') <> ''
                   then id = (v_rate->>'id')::uuid
                   else label = v_rate->>'label'
                        and percent = (v_rate->>'percent')::numeric end);
    end if;
  end loop;
end;
$$;
revoke execute on function public.set_vat_rates(uuid, jsonb) from public, anon;

-- 3. The VAT account a FEC books collected tax to (PCG 44571 in France).
alter table public.workspaces
  add column vat_account text not null default ''
    check (char_length(vat_account) <= 20);

-- 4. What each priceable thing is taxed at. NULL = the workspace default,
-- which is also what subscriptions, overage and supplements use.
alter table public.services
  add column vat_rate_id uuid references public.vat_rates(id)
    on delete set null;
alter table public.packages
  add column vat_rate_id uuid references public.vat_rates(id)
    on delete set null;

-- 5. The rate a booked charge was taxed at — stamped when the charge is
-- recorded, like its price. A rate change afterwards must not rewrite
-- what already happened. NULL = resolve to the workspace default at
-- invoice time (pre-0072 rows, adjustments).
alter table public.ledger_entries
  add column vat_percent numeric(5,2)
    check (vat_percent is null or (vat_percent >= 0 and vat_percent < 100));

-- 6. The workspace's default percentage, or 0 when it charges no VAT.
create or replace function public.workspace_default_vat_percent(
  p_workspace_id uuid
) returns numeric language sql stable security definer set search_path = public as $$
  select coalesce(
    (select percent from public.vat_rates
      where workspace_id = p_workspace_id and is_default and active
      limit 1), 0);
$$;

-- 7. record_service_charge v3: the 0016 body plus the service's rate in
-- the payload, so the confirmation books what was agreed at the time.
create or replace function public.record_service_charge(
  p_workspace_id uuid,
  p_subject_member_id uuid,
  p_service_id uuid,
  p_quantity int,
  p_period text default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_actor public.members;
  v_service public.services;
  v_period text;
  v_event_id uuid;
  v_vat numeric;
begin
  select * into v_actor from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_actor.id is null then raise exception 'not an active member'; end if;
  if v_actor.id <> p_subject_member_id and not (v_actor.is_admin or v_actor.is_owner) then
    raise exception 'only admins may add services for other members';
  end if;
  if not exists (
    select 1 from public.members
    where id = p_subject_member_id and workspace_id = p_workspace_id and status = 'active'
  ) then raise exception 'unknown subject member'; end if;

  select * into v_service from public.services
    where id = p_service_id and workspace_id = p_workspace_id;
  if v_service.id is null then raise exception 'unknown service'; end if;
  if not v_service.active then raise exception 'service is inactive'; end if;
  if p_quantity is null or p_quantity < 1 or p_quantity > 999 then
    raise exception 'quantity must be between 1 and 999';
  end if;
  v_period := coalesce(p_period, to_char(now(), 'YYYY-MM'));
  if v_period !~ '^\d{4}-\d{2}$' then raise exception 'period must be YYYY-MM'; end if;

  -- The service's own rate, else the workspace default.
  select coalesce(
      (select percent from public.vat_rates
        where id = v_service.vat_rate_id and active),
      public.workspace_default_vat_percent(p_workspace_id))
    into v_vat;

  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  values (
    p_workspace_id, 'service_charge', 'submitted', v_actor.id, p_subject_member_id,
    jsonb_build_object(
      'service_id', v_service.id,
      'name', v_service.name,
      'price_cents', v_service.price_cents,
      'quantity', p_quantity,
      'amount_cents', v_service.price_cents * p_quantity,
      'vat_percent', v_vat,
      'period', v_period
    ),
    'pending'
  ) returning id into v_event_id;
  return v_event_id;
end;
$$;
revoke execute on function
  public.record_service_charge(uuid, uuid, uuid, int, text) from public, anon;

-- 8. buy_package v2: the 0042 body, stamping the package's rate onto the
-- charge it posts.
create or replace function public.buy_package(
  p_workspace_id uuid, p_package_id uuid
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_member public.members;
  v_pkg public.packages;
  v_tz text;
  v_period text;
  v_ext_id uuid;
  v_vat numeric;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select * into v_member from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_member.id is null then raise exception 'not an active member'; end if;
  if coalesce(v_member.overage_policy, 'blocked') <> 'package' then
    raise exception 'member is not on the package plan';
  end if;

  select * into v_pkg from public.packages
    where id = p_package_id and workspace_id = p_workspace_id and active;
  if v_pkg.id is null then raise exception 'unknown or inactive package'; end if;

  select timezone into v_tz from public.workspaces where id = p_workspace_id;
  v_period := to_char(now() at time zone v_tz, 'YYYY-MM');

  insert into public.quota_extensions
    (workspace_id, member_id, period, half_days)
  values (p_workspace_id, v_member.id, v_period, v_pkg.days * 2)
  returning id into v_ext_id;

  select coalesce(
      (select percent from public.vat_rates
        where id = v_pkg.vat_rate_id and active),
      public.workspace_default_vat_percent(p_workspace_id))
    into v_vat;

  insert into public.ledger_entries
    (workspace_id, member_id, kind, category, amount_cents, description,
     period, vat_percent)
  values (
    p_workspace_id, v_member.id, 'charge', 'package', v_pkg.price_cents,
    v_pkg.name || ' (' || v_pkg.days || 'd)', v_period, v_vat
  );

  return v_ext_id;
end;
$$;
revoke execute on function public.buy_package(uuid, uuid) from public, anon;

-- 9. invoice_lines_for v-next: the 0063 body, every CHARGE line carrying
-- the rate it is taxed at. Credits carry none.
create or replace function public.invoice_lines_for(
  p_member_id uuid,
  p_period text
) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_stmt jsonb;
  v_lines jsonb := '[]'::jsonb;
  v_row record;
  v_workspace uuid;
  v_default numeric;
begin
  v_stmt := public.member_statement(p_member_id, p_period);
  select workspace_id into v_workspace from public.members where id = p_member_id;
  v_default := public.workspace_default_vat_percent(v_workspace);

  if (v_stmt->>'fee_cents')::int > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'subscription',
      'label', v_stmt->>'subscription_pct',
      'quantity', 1,
      'vat_percent', v_default,
      'amount_cents', (v_stmt->>'fee_cents')::int);
  end if;
  if (v_stmt->>'overage_cents')::int > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'overage',
      'label', '',
      'quantity', (v_stmt->>'extra_half_days')::int,
      'vat_percent', v_default,
      'amount_cents', (v_stmt->>'overage_cents')::int);
  end if;
  if coalesce((v_stmt->>'accessory_supplement_cents')::int, 0) > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'accessories', 'label', '', 'quantity', 1,
      'vat_percent', v_default,
      'amount_cents', (v_stmt->>'accessory_supplement_cents')::int);
  end if;
  if coalesce((v_stmt->>'level_supplement_cents')::int, 0) > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'level', 'label', '', 'quantity', 1,
      'vat_percent', v_default,
      'amount_cents', (v_stmt->>'level_supplement_cents')::int);
  end if;
  if coalesce((v_stmt->>'office_supplement_cents')::int, 0) > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'office', 'label', '', 'quantity', 1,
      'vat_percent', v_default,
      'amount_cents', (v_stmt->>'office_supplement_cents')::int);
  end if;
  if coalesce((v_stmt->>'desk_supplement_cents')::int, 0) > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'desk', 'label', '', 'quantity', 1,
      'vat_percent', v_default,
      'amount_cents', (v_stmt->>'desk_supplement_cents')::int);
  end if;

  for v_row in
    select kind, category, description, amount_cents, vat_percent
      from public.ledger_entries
     where member_id = p_member_id
       and period = p_period
       and ((kind = 'charge'
             and category in ('service', 'package', 'adjustment'))
         or (kind = 'credit'
             and category in ('payment', 'expense', 'adjustment')))
     order by created_at
  loop
    v_lines := v_lines || jsonb_build_object(
      'kind', v_row.category,
      'label', v_row.description,
      'quantity', 1,
      -- The rate stamped when the charge was booked; the workspace
      -- default for anything older than 0072 or unstamped. A credit is
      -- money moving, not a supply: no VAT.
      'vat_percent', case when v_row.kind = 'credit' then 0
                          else coalesce(v_row.vat_percent, v_default) end,
      'amount_cents', case when v_row.kind = 'credit'
                           then -v_row.amount_cents
                           else v_row.amount_cents end);
  end loop;

  return v_lines;
end;
$$;
revoke execute on function public.invoice_lines_for(uuid, text)
  from public, anon;

-- 10. The immutable VAT breakdown of an issued invoice.
alter table public.invoices add column vat_totals jsonb;

comment on column public.invoices.vat_totals is
  'Issue-time VAT breakdown, one entry per rate: percent, category, '
  'gross_cents, net_cents, vat_cents. Sums of the PER-LINE split '
  '(net = round(gross*100/(100+percent)); vat = gross-net), so the '
  'breakdown, the net total and the payable amount all tie to the ledger. '
  'NULL on pre-0072 invoices.';

-- 11. respond_to_event: the 0070 body, writing the agreed rate onto the
-- service charge it books.
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
        (workspace_id, member_id, kind, category, amount_cents, description,
         period, event_id, vat_percent)
      values (
        v_event.workspace_id, v_event.subject_member_id, 'charge', 'service',
        (v_event.payload->>'amount_cents')::int,
        (v_event.payload->>'name') || ' x' || (v_event.payload->>'quantity'),
        coalesce(v_event.payload->>'period', to_char(now(), 'YYYY-MM')),
        v_event.id,
        -- 0072: the rate agreed when the charge was recorded.
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

-- 12. create_invoice v9: the 0070 body plus the VAT breakdown, snapshotted
-- into the signed content. The split is per LINE and every total is a sum
-- of lines, so nothing needs reconciling afterwards.
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
  v_vat_totals jsonb;
  v_zero_category text;
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

  -- A 0% line is categorised by the workspace's declared regime, exactly
  -- as before VAT existed: outside the scope, or exempt.
  v_zero_category := case coalesce(v_workspace.vat_regime, 'not_subject')
                       when 'exempt' then 'E' else 'O' end;

  -- One entry per rate. Charges only: a credit is money moving.
  with charges as (
    select coalesce((l->>'vat_percent')::numeric, 0) as percent,
           (l->>'amount_cents')::int as gross,
           round((l->>'amount_cents')::int * 100.0
                 / (100 + coalesce((l->>'vat_percent')::numeric, 0)))::int as net
      from jsonb_array_elements(v_lines) l
     where (l->>'amount_cents')::int > 0
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'percent', percent,
      'category', case when percent > 0 then 'S' else v_zero_category end,
      'gross_cents', gross,
      'net_cents', net,
      'vat_cents', gross - net) order by percent desc), '[]'::jsonb)
    into v_vat_totals
    from (
      select percent, sum(gross)::int as gross, sum(net)::int as net
        from charges group by percent
    ) grouped;

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
      v_parties::text, v_vat_totals::text),
      'UTF8'), 'sha256'), 'hex');

  insert into public.invoices
    (id, workspace_id, member_id, issuer_member_id, number, period, title,
     lines, total_cents, currency, member_name, member_address,
     workspace_name, workspace_address, issuer_name, signature,
     replaces_invoice_id, replaces_number, details, parties, vat_totals)
  values
    (v_id, p_workspace_id, v_subject.id, v_actor.id, v_number, p_period,
     p_period, v_lines, v_total, v_workspace.currency_code,
     v_member_name, v_member_address, v_workspace.name,
     coalesce(v_workspace.address, ''), v_issuer_name, v_signature,
     p_replaces, v_replaces_number, v_details, v_parties, v_vat_totals);
  return v_id;
end;
$$;
revoke execute on function
  public.create_invoice(uuid, uuid, text, uuid, boolean) from public, anon;
