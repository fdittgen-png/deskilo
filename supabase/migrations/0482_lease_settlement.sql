-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0482 (#2569, C2a) -- the year-end settlement of a lease's service charges.
--
-- The lessor bills the real costs of a period against the advances the space
-- paid. A settlement records the period, the advances the lease's schedules
-- produced in it, the actual amount billed, and the balance:
--   balance > 0   the space owes the lessor the difference: ONE expected
--                 occurrence (a one-off schedule of origin workspace_contract,
--                 listed in the term history as an "other" charge) on the day
--                 the lessor asked for it;
--   balance <= 0  nothing is owed: the credit is recorded and shown, and the
--                 purchase side (#2575) matches it when the lessor's credit
--                 note arrives.
-- A settlement is final (never edited or deleted) and two settlements of one
-- lease never cover the same days. Nothing here moves cash.

create table public.lease_settlements (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null,
  lease_id uuid not null,
  period_start date not null,
  period_end date not null,
  advances_cents bigint not null check (advances_cents >= 0),
  actual_cents bigint not null check (actual_cents >= 0),
  balance_cents bigint not null,
  due_on date not null,
  term_id uuid references public.lease_terms(id),
  created_by uuid references public.members(id),
  foreign key (workspace_id, lease_id) references public.premises_leases (workspace_id, id),
  check (period_end >= period_start),
  check (due_on >= period_end),
  check (balance_cents = actual_cents - advances_cents),
  check ((balance_cents > 0) = (term_id is not null)),
  constraint lease_settlements_no_overlap
    exclude using gist (lease_id with =, daterange(period_start, period_end, '[]') with &&)
);
select public.ensure_system_columns('lease_settlements');
create index lease_settlements_lease on public.lease_settlements (lease_id, period_start);

alter table public.lease_settlements enable row level security;
revoke all on public.lease_settlements from public, anon, authenticated;
grant select on public.lease_settlements to authenticated;
create policy lease_settlements_select on public.lease_settlements
  for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewFinances', 'manageLease'])));
create policy mcp_delegated_deny on public.lease_settlements as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create or replace function public.lease_settlements_guard()
returns trigger language plpgsql as $fn$
begin
  raise exception 'a lease settlement is final: it is never edited or deleted';
end;
$fn$;
revoke execute on function public.lease_settlements_guard() from public, anon, authenticated;
create trigger lease_settlements_guard
  before update or delete on public.lease_settlements
  for each row execute function public.lease_settlements_guard();

-- ── the command ─────────────────────────────────────────────────────────
create or replace function public.settle_lease_charges_v1(
  p_workspace_id uuid, p_lease_id uuid, p_revision int, p_period_start date, p_period_end date,
  p_actual_cents bigint, p_due_on date, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  l public.premises_leases;
  v_advances bigint;
  v_balance bigint;
  v_name text;
  v_label text;
  v_schedule uuid;
  v_term uuid;
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  v_me := public.lease_actor(p_workspace_id, true);
  v_digest := md5(v_me::text || coalesce(p_lease_id::text, '') || coalesce(p_revision, 0)::text
                  || coalesce(p_period_start::text, '') || coalesce(p_period_end::text, '')
                  || coalesce(p_actual_cents, -1)::text || coalesce(p_due_on::text, ''));
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'lease_settlement', v_digest);
  if v_done is not null then return v_done; end if;
  perform pg_advisory_xact_lock(hashtext(p_workspace_id::text));

  select * into l from public.premises_leases
   where id = p_lease_id and workspace_id = p_workspace_id for update;
  if l.id is null then raise exception 'unknown lease'; end if;
  if l.revision <> coalesce(p_revision, 0) then raise exception 'stale revision'; end if;
  if l.status = 'draft' then raise exception 'a lease with no term has nothing to settle'; end if;
  if p_period_start is null or p_period_end is null or p_period_end < p_period_start
     or p_period_end - p_period_start > 400 then
    raise exception 'the settled period is at most 400 days';
  end if;
  if p_period_end > current_date then raise exception 'a period is settled once it is over'; end if;
  if coalesce(p_actual_cents, -1) < 0 then raise exception 'the billed amount cannot be negative'; end if;
  if p_due_on is null or p_due_on < p_period_end then
    raise exception 'the settlement is due on or after the end of the period';
  end if;
  if exists (select 1 from public.lease_settlements s
              where s.lease_id = l.id and daterange(s.period_start, s.period_end, '[]')
                    && daterange(p_period_start, p_period_end, '[]')) then
    raise exception 'that period is already settled';
  end if;

  -- The advances are the occurrences the schedules have produced: bring them up to date first.
  perform public.sweep_expense_schedules(p_workspace_id);
  select coalesce(sum(o.amount_cents), 0) into v_advances
    from public.expense_occurrences o
    join public.lease_terms t on t.schedule_id = o.schedule_id
   where t.lease_id = l.id and t.kind = 'service_charge_advance'
     and o.status <> 'rejected' and o.due_on between p_period_start and p_period_end;
  v_balance := p_actual_cents - v_advances;

  if v_balance > 0 then
    if v_balance > 2147483647 then raise exception 'the balance is too large'; end if;
    select s.name into v_name from public.suppliers s where s.id = l.supplier_id;
    v_label := 'Settlement ' || p_period_start::text || ' to ' || p_period_end::text;
    insert into public.expense_schedules
      (workspace_id, member_id, supplier_id, title, description, amount_cents, starts_on, ends_on,
       unit, every, repeat_count, status, next_due, origin, contract_id)
    values (l.workspace_id, l.responsible_member_id, l.supplier_id,
            left('Service charge settlement — ' || v_name, 80), l.premises, v_balance::int,
            p_due_on, p_due_on, 'month', 1, 1, 'active', p_due_on, 'workspace_contract', l.id)
    returning id into v_schedule;
    insert into public.lease_terms
      (workspace_id, lease_id, kind, label, amount_cents, every_months, effective_from, effective_to,
       schedule_id, created_by)
    values (l.workspace_id, l.id, 'other', v_label, v_balance::int, 1, p_due_on, p_due_on, v_schedule, v_me)
    returning id into v_term;
  end if;

  insert into public.lease_settlements
    (workspace_id, lease_id, period_start, period_end, advances_cents, actual_cents, balance_cents,
     due_on, term_id, created_by)
  values (l.workspace_id, l.id, p_period_start, p_period_end, v_advances, p_actual_cents, v_balance,
          p_due_on, v_term, v_me);
  update public.premises_leases set revision = revision + 1 where id = l.id returning * into l;

  v_result := public.premises_lease_json(l);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'lease_settlement', v_digest, v_result);
end;
$fn$;
revoke execute on function public.settle_lease_charges_v1(uuid, uuid, int, date, date, bigint, date, uuid)
  from public, anon;
grant execute on function public.settle_lease_charges_v1(uuid, uuid, int, date, date, bigint, date, uuid)
  to authenticated;

-- ── the reading shows the settlements ───────────────────────────────────
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text language plpgsql as $f$
begin
  if position(p_old in p_def) = 0 then return null; end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public, anon;

do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.premises_lease_json(public.premises_leases)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$    'occurrences_after_end', case when$a$,
    $a$    'settlements', coalesce((select jsonb_agg(jsonb_build_object(
        'id', s.id, 'period_start', s.period_start, 'period_end', s.period_end,
        'advances_cents', s.advances_cents, 'actual_cents', s.actual_cents,
        'balance_cents', s.balance_cents, 'credit_cents', greatest(-s.balance_cents, 0),
        'due_on', s.due_on) order by s.period_start)
        from public.lease_settlements s where s.lease_id = l.id), '[]'::jsonb),
    'occurrences_after_end', case when$a$);
  if v_def is null then raise exception '0482: premises_lease_json anchor missing'; end if;
  execute v_def;
end
$migration$;

select public.set_deskilo_schema_version(482);
