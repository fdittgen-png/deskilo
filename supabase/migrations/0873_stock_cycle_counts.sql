-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (three tables, their guards, commands, readers and a job; events gains a type; event_type_view_permissions,
--  event_type_waits_for_decision and export_my_data are patched at asserted anchors; the workspace export function
--  is restated whole; the settings registry gains two settings)
--
-- #4295 (G9, server side): scheduled cycle counts while the shop stays open.
--
--   * A PLAN names a scope and a schedule. Scope: `places` (these places and every place inside them), `items`
--     (these items, in every real place), or `high_value` (what a place holds of an item is worth at least a threshold:
--     the quantity times the unit cost of its lot; the plan's own threshold, else the setting
--     `stock.cycle_count_high_value_minor`). Schedule: every `interval_days` days from `next_due_on`, or once.
--   * `stock_cycle_counts_due()` (a job, every hour) makes ONE TASK per plan and due day, in the business's own day,
--     lists the lines (item, variant, lot, place) the plan's scope holds, and moves the plan to its next day. A
--     repeated run makes nothing twice.
--   * The counter reads a task with NO quantities (`stock_count_task_v1`): the lines name what to count and where,
--     never what the ledger expects. The right is `countStock` (or `manageStock`): it runs the task reader and the
--     line count only, implies nothing else, and the line count tells a counter who holds neither `manageStock`
--     nor `approveStockAdjustments` that the line is counted, never the baseline or the difference. Counting a line records a count of #4172 (its stable id is the line's), so the
--     stock revision it was counted against, the approval and the idempotent adjustment are that leaf's: a movement
--     between the count and the approval is refused as stale there, and nothing here changes a balance. A line is
--     skipped with a reason. A task is complete when every line is counted or skipped.
--   * An open task still open `stock.cycle_count_overdue_days` days after its due day raises ONE inbox event
--     `stock_count_overdue` for those who manage the stock; it ends when the task is complete or cancelled.
--   * `stock_count_history_v1` says, per item and place, when it was last counted and how many counts were exact.

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('stock.cycle_count_high_value_minor', 'int', '50000'::jsonb, 1, 100000000, 'currency units', 'business', array['workspace'], 'manageStock', null, true, null, 'stock_cycle_counts (#4295)', 'The value, in minor units of the business currency (cents), from which what a place holds of an item counts as high value for a cycle count plan that selects high-value goods and has no threshold of its own: the quantity there times the unit cost of its lot.'),
('stock.cycle_count_overdue_days', 'int', '7'::jsonb, 1, 90, 'days', 'business', array['workspace'], 'manageStock', null, true, null, 'stock_cycle_counts (#4295)', 'How many days a cycle count task may stay open past its due date before the inbox says it is overdue: once per task.')
on conflict (key) do nothing;
-- END GENERATED SEED

-- ── the plans, the tasks and their lines ───────────────────────────────
create table public.stock_count_plans (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 80),
  scope_kind text not null check (scope_kind in ('places', 'items', 'high_value')),
  location_ids uuid[] not null default array[]::uuid[],
  item_ids uuid[] not null default array[]::uuid[],
  high_value_minor bigint check (high_value_minor is null or high_value_minor >= 1),
  interval_days integer check (interval_days is null or interval_days between 1 and 366),
  next_due_on date not null,
  active boolean not null default true,
  unique (workspace_id, id)
);
select public.ensure_system_columns('stock_count_plans');

create table public.stock_count_tasks (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  plan_id uuid not null,
  due_on date not null,
  state text not null default 'open' check (state in ('open', 'complete', 'cancelled')),
  completed_at timestamptz,
  unique (workspace_id, id),
  unique (plan_id, due_on),
  foreign key (workspace_id, plan_id) references public.stock_count_plans (workspace_id, id) on delete cascade
);
select public.ensure_system_columns('stock_count_tasks');

create table public.stock_count_task_lines (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  task_id uuid not null,
  item_id uuid not null,
  variant_id uuid,
  lot_id uuid,
  location_id uuid not null,
  state text not null default 'pending' check (state in ('pending', 'counted', 'skipped')),
  skip_reason text not null default '' check (char_length(skip_reason) <= 300),
  -- the count of #4172 this line was counted as, and how many times it was counted (a cancelled count is counted again)
  attempt integer not null default 1,
  count_id uuid,
  unique (workspace_id, id),
  check ((state = 'skipped') = (skip_reason <> '')),
  foreign key (workspace_id, task_id) references public.stock_count_tasks (workspace_id, id) on delete cascade,
  foreign key (workspace_id, item_id) references public.services (workspace_id, id) on delete cascade,
  foreign key (workspace_id, lot_id) references public.stock_lots (workspace_id, id) on delete cascade,
  foreign key (workspace_id, location_id) references public.stock_locations (workspace_id, id) on delete cascade
);
select public.ensure_system_columns('stock_count_task_lines');
create unique index stock_count_task_lines_once on public.stock_count_task_lines
  (task_id, item_id, variant_id, lot_id, location_id) nulls not distinct;

alter table public.stock_count_plans enable row level security;
alter table public.stock_count_tasks enable row level security;
alter table public.stock_count_task_lines enable row level security;
revoke all on public.stock_count_plans, public.stock_count_tasks, public.stock_count_task_lines from public, anon, authenticated;
grant select on public.stock_count_plans, public.stock_count_tasks, public.stock_count_task_lines to authenticated;
create policy stock_count_plans_select on public.stock_count_plans for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['manageStock']))
         and public.feature_effective(workspace_id, 'stockCycleCounts'));
create policy stock_count_tasks_select on public.stock_count_tasks for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['manageStock']))
         and public.feature_effective(workspace_id, 'stockCycleCounts'));
create policy stock_count_task_lines_select on public.stock_count_task_lines for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['manageStock']))
         and public.feature_effective(workspace_id, 'stockCycleCounts'));
create policy mcp_delegated_deny on public.stock_count_plans as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.stock_count_tasks as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.stock_count_task_lines as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- who may plan and count: whoever manages the stock, while the feature and the counts are on; never an assistant
create or replace function public.stock_cycle_actor(p_workspace_id uuid)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me uuid;
begin
  if auth.uid() is null then
    raise exception 'not allowed to manage the cycle counts' using errcode = 'DKN01';
  end if;
  v_me := public.stock_ops_actor(p_workspace_id);
  if not public.feature_effective(p_workspace_id, 'stockCycleCounts') then
    raise exception 'cycle counts are off in this business' using errcode = 'DKG01';
  end if;
  return v_me;
end;
$fn$;
revoke execute on function public.stock_cycle_actor(uuid) from public, anon, authenticated;

-- who counts a task, blind: whoever holds `countStock` (it implies nothing else) or manages the stock
create or replace function public.stock_blind_actor(p_workspace_id uuid)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me uuid;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed to count stock' using errcode = 'DKN01';
  end if;
  select id into v_me from public.members where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_me is null or not (public.has_permission(p_workspace_id, 'countStock') or public.has_permission(p_workspace_id, 'manageStock')) then
    raise exception 'not allowed to count stock' using errcode = 'DKN01';
  end if;
  if not (public.feature_effective(p_workspace_id, 'stockManagement') and public.feature_effective(p_workspace_id, 'stockCounts')
          and public.feature_effective(p_workspace_id, 'stockCycleCounts')) then
    raise exception 'cycle counts are off in this business' using errcode = 'DKG01';
  end if;
  return v_me;
end;
$fn$;
revoke execute on function public.stock_blind_actor(uuid) from public, anon, authenticated;

-- ── a plan ─────────────────────────────────────────────────────────────
-- Body: {name, scope_kind, location_ids?, item_ids?, high_value_minor?, interval_days?, next_due_on, active?}.
-- The plan id is the caller's, stable: the same id saves the same plan again (a new request id changes it to what
-- the body says, the same request id answers what it answered).
create or replace function public.stock_count_plan_save_v1(
  p_workspace_id uuid, p_request_id uuid, p_plan_id uuid, p_body jsonb
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid := public.stock_cycle_actor(p_workspace_id);
  v_digest text;
  v_done jsonb;
  v_kind text;
  v_locs uuid[] := array[]::uuid[];
  v_items uuid[] := array[]::uuid[];
  v_due date;
  v_interval integer;
  v_value bigint;
  v_x text;
  v_active boolean;
  v_row public.stock_count_plans;
begin
  if p_request_id is null or p_plan_id is null or coalesce(jsonb_typeof(p_body), '') <> 'object' then
    raise exception 'a plan has a request id, its own id and a body' using errcode = 'DKG07';
  end if;
  v_digest := md5(jsonb_build_array(p_plan_id, p_body)::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'stock_count_plan', v_digest);
  if v_done is not null then return v_done; end if;
  v_kind := p_body ->> 'scope_kind';
  if v_kind is null or v_kind not in ('places', 'items', 'high_value')
     or char_length(coalesce(trim(p_body ->> 'name'), '')) not between 1 and 80
     or coalesce(p_body ->> 'next_due_on', '') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    raise exception 'a plan has a name, a scope (places, items or high value) and a due day' using errcode = 'DKG07';
  end if;
  v_due := (p_body ->> 'next_due_on')::date;
  v_interval := nullif(p_body ->> 'interval_days', '')::integer;
  if v_interval is not null and v_interval not between 1 and 366 then
    raise exception 'a plan repeats every 1 to 366 days, or once' using errcode = 'DKG07';
  end if;
  v_value := nullif(p_body ->> 'high_value_minor', '')::bigint;
  if v_value is not null and v_value < 1 then raise exception 'a threshold is at least 1' using errcode = 'DKG07'; end if;
  v_active := coalesce((p_body ->> 'active')::boolean, true);
  for v_x in select jsonb_array_elements_text(coalesce(p_body -> 'location_ids', '[]'::jsonb)) loop
    v_locs := v_locs || v_x::uuid;
  end loop;
  for v_x in select jsonb_array_elements_text(coalesce(p_body -> 'item_ids', '[]'::jsonb)) loop
    v_items := v_items || v_x::uuid;
  end loop;
  if (v_kind = 'places' and cardinality(v_locs) = 0) or (v_kind = 'items' and cardinality(v_items) = 0)
     or cardinality(v_locs) > 200 or cardinality(v_items) > 200 then
    raise exception 'the scope names what to count (at most 200)' using errcode = 'DKG07';
  end if;
  if exists (select 1 from unnest(v_locs) l where not exists (select 1 from public.stock_locations x
                where x.id = l and x.workspace_id = p_workspace_id))
     or exists (select 1 from unnest(v_items) i where not exists (select 1 from public.services x
                where x.id = i and x.workspace_id = p_workspace_id and x.stockable)) then
    raise exception 'the scope names a place or an item of another business or none' using errcode = 'DKG04';
  end if;
  insert into public.stock_count_plans (id, workspace_id, name, scope_kind, location_ids, item_ids, high_value_minor, interval_days, next_due_on, active)
  values (p_plan_id, p_workspace_id, trim(p_body ->> 'name'), v_kind, v_locs, v_items, v_value, v_interval, v_due, v_active)
  on conflict (id) do update
    set name = excluded.name, scope_kind = excluded.scope_kind, location_ids = excluded.location_ids, item_ids = excluded.item_ids,
        high_value_minor = excluded.high_value_minor, interval_days = excluded.interval_days, next_due_on = excluded.next_due_on,
        active = excluded.active
    where public.stock_count_plans.workspace_id = p_workspace_id
  returning * into v_row;
  if v_row.id is null then raise exception 'not a plan of this business' using errcode = 'DKG04'; end if;
  return public.purchase_request_end(p_workspace_id, p_request_id, 'stock_count_plan', v_digest,
    jsonb_build_object('plan_id', v_row.id, 'next_due_on', v_row.next_due_on, 'active', v_row.active));
end;
$fn$;
revoke execute on function public.stock_count_plan_save_v1(uuid, uuid, uuid, jsonb) from public, anon;
grant execute on function public.stock_count_plan_save_v1(uuid, uuid, uuid, jsonb) to authenticated;

-- ── what a plan's scope holds ──────────────────────────────────────────
-- The places of a plan: those named and every place inside them.
create or replace function public.stock_cycle_places(p_workspace_id uuid, p_location_ids uuid[])
returns table (location_id uuid) language sql stable security definer set search_path = public as $fn$
  with recursive tree(id) as (
    select l.id from public.stock_locations l where l.workspace_id = p_workspace_id and l.id = any (p_location_ids)
    union
    select c.id from public.stock_locations c join tree t on c.parent_id = t.id where c.workspace_id = p_workspace_id)
  select id from tree
$fn$;
revoke execute on function public.stock_cycle_places(uuid, uuid[]) from public, anon, authenticated;

-- The lines a plan counts: every non-zero balance of its scope at a real, active place.
create or replace function public.stock_cycle_scope_lines(p_plan_id uuid)
returns table (item_id uuid, variant_id uuid, lot_id uuid, location_id uuid)
language plpgsql stable security definer set search_path = public as $fn$
declare
  p public.stock_count_plans;
  v_threshold bigint;
begin
  select * into p from public.stock_count_plans where id = p_plan_id;
  if p.id is null then return; end if;
  v_threshold := coalesce(p.high_value_minor,
    (public.setting_value(p.workspace_id, 'stock.cycle_count_high_value_minor') #>> '{}')::bigint);
  return query
    select b.item_id, b.variant_id, b.lot_id, b.location_id
      from public.stock_balances b
      join public.stock_locations l on l.id = b.location_id and l.active
      join public.stock_location_kinds k on k.key = l.kind and not k.virtual
      left join public.stock_lots lo on lo.id = b.lot_id
     where b.workspace_id = p.workspace_id and b.quantity <> 0
       and (case p.scope_kind
              when 'places' then b.location_id in (select x.location_id from public.stock_cycle_places(p.workspace_id, p.location_ids) x)
              when 'items' then b.item_id = any (p.item_ids)
              else coalesce(b.quantity * lo.total_cost_minor / nullif(lo.quantity_received, 0), 0) >= v_threshold end)
     order by b.item_id, b.variant_id nulls first, b.lot_id nulls first, b.location_id;
end;
$fn$;
revoke execute on function public.stock_cycle_scope_lines(uuid) from public, anon, authenticated;

-- ── the due job ────────────────────────────────────────────────────────
-- One task per plan and due day, in the business's own day; the plan moves on. A plan whose scope holds nothing
-- makes an empty task that is complete at once. Returns the tasks made. Idempotent: a second run makes nothing.
create or replace function public.stock_cycle_counts_due(p_workspace_id uuid default null)
returns integer language plpgsql security definer set search_path = public as $fn$
declare
  p record;
  v_task uuid;
  v_today date;
  v_n integer := 0;
  v_lines integer;
begin
  for p in
    select * from public.stock_count_plans pl
     where pl.active and (p_workspace_id is null or pl.workspace_id = p_workspace_id)
       and public.feature_effective(pl.workspace_id, 'stockCycleCounts')
     order by pl.workspace_id, pl.id
     for update skip locked
  loop
    v_today := public.workspace_today(p.workspace_id);
    if p.next_due_on > v_today then continue; end if;
    -- a plan that fails does not stop the others: its own savepoint, and the failure is logged
    begin
      v_task := null;
      insert into public.stock_count_tasks (workspace_id, plan_id, due_on) values (p.workspace_id, p.id, p.next_due_on)
      on conflict (plan_id, due_on) do nothing
      returning id into v_task;
      if v_task is not null then
        insert into public.stock_count_task_lines (workspace_id, task_id, item_id, variant_id, lot_id, location_id)
        select p.workspace_id, v_task, s.item_id, s.variant_id, s.lot_id, s.location_id from public.stock_cycle_scope_lines(p.id) s
        on conflict do nothing;
        get diagnostics v_lines = row_count;
        if v_lines = 0 then
          update public.stock_count_tasks set state = 'complete', completed_at = now() where id = v_task;
        end if;
        v_n := v_n + 1;
      end if;
      -- the plan moves on: every n days from the due day (never into the past), or once
      update public.stock_count_plans
         set next_due_on = case when p.interval_days is null then p.next_due_on
                                else greatest(p.next_due_on + p.interval_days, v_today + 1) end,
             active = p.interval_days is not null
       where id = p.id;
    exception when others then
      if left(sqlstate, 2) in ('40', '53') or sqlstate = '55P03' then raise; end if;
      raise warning 'the cycle count plan % was not run (%)', p.id, sqlstate;
    end;
  end loop;
  perform public.stock_cycle_counts_alert(p_workspace_id);
  return v_n;
end;
$fn$;
revoke execute on function public.stock_cycle_counts_due(uuid) from public, anon, authenticated;
grant execute on function public.stock_cycle_counts_due(uuid) to service_role;

-- ── the counter's task: no quantities ──────────────────────────────────
create or replace function public.stock_count_tasks_v1(p_workspace_id uuid, p_state text default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  perform public.stock_blind_actor(p_workspace_id);
  if p_state is not null and p_state not in ('open', 'complete', 'cancelled') then
    raise exception 'a state is open, complete or cancelled' using errcode = 'DKG07';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'task_id', t.id, 'plan_id', t.plan_id, 'plan_name', pl.name, 'due_on', t.due_on, 'state', t.state,
      'lines', (select count(*) from public.stock_count_task_lines x where x.task_id = t.id),
      'pending', (select count(*) from public.stock_count_task_lines x where x.task_id = t.id and x.state = 'pending'))
      order by t.due_on desc, t.id)
      from public.stock_count_tasks t join public.stock_count_plans pl on pl.id = t.plan_id
     where t.workspace_id = p_workspace_id and (p_state is null or t.state = p_state)
  ), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.stock_count_tasks_v1(uuid, text) from public, anon;
grant execute on function public.stock_count_tasks_v1(uuid, text) to authenticated;

-- A task's lines: what to count and where, never what the ledger holds.
create or replace function public.stock_count_task_v1(p_workspace_id uuid, p_task_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  t public.stock_count_tasks;
begin
  perform public.stock_blind_actor(p_workspace_id);
  select * into t from public.stock_count_tasks where id = p_task_id and workspace_id = p_workspace_id;
  if t.id is null then raise exception 'not a task of this business' using errcode = 'DKG04'; end if;
  return jsonb_build_object('task_id', t.id, 'plan_id', t.plan_id, 'due_on', t.due_on, 'state', t.state,
    'lines', coalesce((
      select jsonb_agg(jsonb_build_object(
        'line_id', x.id, 'item_id', x.item_id, 'variant_id', x.variant_id, 'lot_id', x.lot_id,
        'location_id', x.location_id, 'state', x.state, 'skip_reason', x.skip_reason)
        order by x.location_id, x.item_id, x.variant_id nulls first, x.lot_id nulls first, x.id)
        from public.stock_count_task_lines x where x.task_id = t.id), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.stock_count_task_v1(uuid, uuid) from public, anon;
grant execute on function public.stock_count_task_v1(uuid, uuid) to authenticated;

-- a task is complete when every line is counted or skipped
create or replace function public.stock_count_task_close(p_task_id uuid)
returns void language plpgsql security definer set search_path = public as $fn$
begin
  -- the task first: two lines counted at once close it once, whichever commits last
  perform 1 from public.stock_count_tasks where id = p_task_id for update;
  update public.stock_count_tasks t set state = 'complete', completed_at = now()
   where t.id = p_task_id and t.state = 'open'
     and not exists (select 1 from public.stock_count_task_lines x where x.task_id = t.id and x.state = 'pending');
end;
$fn$;
revoke execute on function public.stock_count_task_close(uuid) from public, anon, authenticated;

-- ── counting and skipping a line ───────────────────────────────────────
-- Counting records a count of #4172 whose stable id is the line's: the stock revision it is counted against is
-- recorded there, and the approval and the adjustment are that leaf's.
create or replace function public.stock_cycle_count_line_v1(
  p_workspace_id uuid, p_request_id uuid, p_line_id uuid, p_observed text
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid := public.stock_blind_actor(p_workspace_id);
  v_line public.stock_count_task_lines;
  v_task public.stock_count_tasks;
  v_count uuid;
  v_result jsonb;
begin
  select * into v_line from public.stock_count_task_lines where id = p_line_id and workspace_id = p_workspace_id;
  if v_line.id is null then raise exception 'not a line of this business' using errcode = 'DKG04'; end if;
  perform 1 from public.services where id = v_line.item_id and workspace_id = p_workspace_id for update;
  select * into v_line from public.stock_count_task_lines where id = p_line_id for update;
  select * into v_task from public.stock_count_tasks where id = v_line.task_id;
  if v_task.state <> 'open' then raise exception 'this task is no longer open' using errcode = 'DKG19'; end if;
  if v_line.state = 'skipped' then raise exception 'this line was skipped' using errcode = 'DKG19'; end if;
  -- the count's own identity: the line's, and the attempt (a cancelled count is counted again under the next one)
  v_count := md5(v_line.id::text || ':' || v_line.attempt::text)::uuid;
  v_result := public.stock_count_record_core(p_workspace_id, p_request_id, v_count,
    jsonb_strip_nulls(jsonb_build_object('item_id', v_line.item_id, 'variant_id', v_line.variant_id,
                                          'lot_id', v_line.lot_id, 'location_id', v_line.location_id)),
    p_observed, 'cycle count', v_me);
  update public.stock_count_task_lines set state = 'counted', count_id = v_count where id = v_line.id and state = 'pending';
  perform public.stock_count_task_close(v_line.task_id);
  -- a blind counter is told the line is counted, never what the ledger held or how far off the count was
  if not (public.has_permission(p_workspace_id, 'manageStock') or public.has_permission(p_workspace_id, 'approveStockAdjustments')) then
    v_result := jsonb_build_object('count_id', v_count, 'state', v_result ->> 'state');
  end if;
  return v_result || jsonb_build_object('line_id', v_line.id, 'task_id', v_line.task_id,
    'task_state', (select state from public.stock_count_tasks where id = v_line.task_id));
end;
$fn$;
revoke execute on function public.stock_cycle_count_line_v1(uuid, uuid, uuid, text) from public, anon;
grant execute on function public.stock_cycle_count_line_v1(uuid, uuid, uuid, text) to authenticated;

create or replace function public.stock_cycle_skip_line_v1(
  p_workspace_id uuid, p_request_id uuid, p_line_id uuid, p_reason text
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid := public.stock_blind_actor(p_workspace_id);
  v_digest text;
  v_done jsonb;
  v_line public.stock_count_task_lines;
  v_result jsonb;
begin
  if p_request_id is null or p_line_id is null or char_length(coalesce(trim(p_reason), '')) not between 1 and 300 then
    raise exception 'a line is skipped with a reason of 1 to 300 characters' using errcode = 'DKG07';
  end if;
  v_digest := md5(jsonb_build_array(p_line_id, trim(p_reason))::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'stock_cycle_skip', v_digest);
  if v_done is not null then return v_done; end if;
  select * into v_line from public.stock_count_task_lines where id = p_line_id and workspace_id = p_workspace_id for update;
  if v_line.id is null then raise exception 'not a line of this business' using errcode = 'DKG04'; end if;
  if v_line.state = 'counted' then raise exception 'this line was counted' using errcode = 'DKG19'; end if;
  if (select state from public.stock_count_tasks where id = v_line.task_id) <> 'open' then
    raise exception 'this task is no longer open' using errcode = 'DKG19';
  end if;
  update public.stock_count_task_lines set state = 'skipped', skip_reason = trim(p_reason) where id = v_line.id;
  perform public.stock_count_task_close(v_line.task_id);
  v_result := jsonb_build_object('line_id', v_line.id, 'state', 'skipped',
    'task_state', (select state from public.stock_count_tasks where id = v_line.task_id));
  return public.purchase_request_end(p_workspace_id, p_request_id, 'stock_cycle_skip', v_digest, v_result);
end;
$fn$;
revoke execute on function public.stock_cycle_skip_line_v1(uuid, uuid, uuid, text) from public, anon;
grant execute on function public.stock_cycle_skip_line_v1(uuid, uuid, uuid, text) to authenticated;

-- a count that is cancelled puts its line back to pending (and reopens a task it had completed): it is counted again
create or replace function public.stock_count_cancel_recounts()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_task uuid;
begin
  update public.stock_count_task_lines set state = 'pending', attempt = attempt + 1, count_id = null
   where workspace_id = new.workspace_id and count_id = new.count_id and state = 'counted'
  returning task_id into v_task;
  if v_task is not null then
    update public.stock_count_tasks set state = 'open', completed_at = null where id = v_task and state = 'complete';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.stock_count_cancel_recounts() from public, anon, authenticated;
create trigger stock_counts_cancel_recounts after update of state on public.stock_counts
  for each row when (old.state = 'recorded' and new.state = 'cancelled')
  execute function public.stock_count_cancel_recounts();

-- ── the history ────────────────────────────────────────────────────────
-- Per item and place: when it was last counted, how many counts, how many were exact (no difference).
create or replace function public.stock_count_history_v1(p_workspace_id uuid, p_item_id uuid default null, p_location_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  perform public.stock_cycle_actor(p_workspace_id);
  return coalesce((
    select jsonb_agg(jsonb_build_object('item_id', h.item_id, 'location_id', h.location_id, 'last_counted_at', h.last_at,
      'counts', h.n, 'exact', h.exact) order by h.item_id, h.location_id)
      from (select c.item_id, c.location_id, max(c.created_datetime) as last_at, count(*) as n,
                   count(*) filter (where c.observed_quantity = c.baseline_quantity) as exact
              from public.stock_counts c
             where c.workspace_id = p_workspace_id and c.state <> 'cancelled'
               and (p_item_id is null or c.item_id = p_item_id) and (p_location_id is null or c.location_id = p_location_id)
             group by c.item_id, c.location_id) h
  ), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.stock_count_history_v1(uuid, uuid, uuid) from public, anon;
grant execute on function public.stock_count_history_v1(uuid, uuid, uuid) to authenticated;

-- ── the overdue alert: an inbox event ──────────────────────────────────
do $constraints$
declare r record; v_def text;
begin
  for r in select * from (values
    ('events', 'events_type_check', 'type'),
    ('validation_policies', 'validation_policies_event_type_check', 'event_type')
  ) as c(table_name, constraint_name, column_name) loop
    select pg_get_constraintdef(oid) into v_def from pg_constraint
     where conrelid = ('public.' || r.table_name)::regclass and conname = r.constraint_name;
    if v_def is null or position('CHECK (' in v_def) <> 1 then
      raise exception '0873: the event type constraint % is not there', r.constraint_name using errcode = 'P0001';
    end if;
    if position('stock_count_overdue' in v_def) = 0 then
      execute format('alter table public.%I drop constraint %I', r.table_name, r.constraint_name);
      execute format('alter table public.%I add constraint %I ', r.table_name, r.constraint_name)
        || replace(v_def, 'CHECK (', format('CHECK (%I = %L OR ', r.column_name, 'stock_count_overdue'));
    end if;
  end loop;
end;
$constraints$;

do $patch$
declare
  v_def text;
  v_next text;
begin
  v_def := pg_get_functiondef('public.event_type_view_permissions(text)'::regprocedure);
  v_next := pg_temp.anchor_replace(v_def,
    $o$ else array['manageConfiguration']$o$,
    $n$ when p_type = 'stock_count_overdue' then array['manageStock'] else array['manageConfiguration']$n$);
  if v_next is null then raise exception '0873: the anchor of event_type_view_permissions is not found' using errcode = 'P0001'; end if;
  execute v_next;

  v_def := pg_get_functiondef('public.event_type_waits_for_decision(text)'::regprocedure);
  v_next := pg_temp.anchor_replace(v_def, $o$'settlement_review', 'stock_low'$o$, $n$'settlement_review', 'stock_low', 'stock_count_overdue'$n$);
  if v_next is null then raise exception '0873: the anchor of event_type_waits_for_decision is not found' using errcode = 'P0001'; end if;
  execute v_next;

  v_def := pg_get_functiondef('public.export_my_data(uuid)'::regprocedure);
  v_next := pg_temp.anchor_replace(v_def,
    $o$and e.type not in ('payment_attempt_unreadable', 'stock_low'$o$,
    $n$and e.type not in ('payment_attempt_unreadable', 'stock_low', 'stock_count_overdue'$n$);
  if v_next is null then raise exception '0873: the anchor of export_my_data is not found' using errcode = 'P0001'; end if;
  execute v_next;
end
$patch$;

create unique index events_stock_count_overdue_open_once on public.events ((payload ->> 'task'))
  where type = 'stock_count_overdue' and not (payload ? 'ended');

-- Raises the one notice of each open task past its due day by the setting's days. The owner is its actor and
-- subject (the job has no member); without an active owner nobody is told.
create or replace function public.stock_cycle_counts_alert(p_workspace_id uuid default null)
returns integer language plpgsql security definer set search_path = public as $fn$
declare
  t record;
  v_actor uuid;
  v_n integer := 0;
  v_k integer;
begin
  for t in
    select tk.id, tk.workspace_id, tk.due_on, pl.name
      from public.stock_count_tasks tk join public.stock_count_plans pl on pl.id = tk.plan_id
     where tk.state = 'open' and (p_workspace_id is null or tk.workspace_id = p_workspace_id)
       and public.feature_effective(tk.workspace_id, 'stockCycleCounts')
       and tk.due_on + (public.setting_value(tk.workspace_id, 'stock.cycle_count_overdue_days') #>> '{}')::integer
           < public.workspace_today(tk.workspace_id)
  loop
    select m.id into v_actor from public.members m
     where m.workspace_id = t.workspace_id and m.is_owner and m.status = 'active'
     order by m.joined_at, m.id limit 1;
    if v_actor is null then continue; end if;
    insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
    values (t.workspace_id, 'stock_count_overdue', 'created', v_actor, v_actor,
            jsonb_build_object('task', t.id, 'plan', t.name, 'due_on', t.due_on), 'applied')
    on conflict ((payload ->> 'task')) where type = 'stock_count_overdue' and not (payload ? 'ended') do nothing;
    get diagnostics v_k = row_count;
    v_n := v_n + v_k;
  end loop;
  return v_n;
end;
$fn$;
revoke execute on function public.stock_cycle_counts_alert(uuid) from public, anon, authenticated;

-- a task that is complete or cancelled ends its notice
create or replace function public.stock_count_task_ends_notice()
returns trigger language plpgsql security definer set search_path = '' as $fn$
begin
  update public.events e
     set payload = e.payload || jsonb_build_object('ended', new.state, 'ended_at', now())
   where e.type = 'stock_count_overdue' and e.payload ->> 'task' = new.id::text and not (e.payload ? 'ended');
  return new;
end;
$fn$;
revoke execute on function public.stock_count_task_ends_notice() from public, anon, authenticated;
create trigger stock_count_tasks_end_notice after update of state on public.stock_count_tasks
  for each row when (old.state = 'open' and new.state <> 'open')
  execute function public.stock_count_task_ends_notice();

-- ── the job ────────────────────────────────────────────────────────────
do $cron$
begin
  create extension if not exists pg_cron;
  perform cron.unschedule('deskilo-stock-cycle-counts')
    where exists (select 1 from cron.job where jobname = 'deskilo-stock-cycle-counts');
  perform cron.schedule('deskilo-stock-cycle-counts', '7 * * * *', $job$select public.stock_cycle_counts_due()$job$);
exception when others then
  raise notice 'pg_cron unavailable (%): an operator runs stock_cycle_counts_due() instead', sqlerrm;
end
$cron$;

-- ── the right to count blind ────────────────────────────────────────────
-- restates 0821
create or replace function public.role_permission_catalog() returns text[]
language sql immutable as $fn$
  select array[
    'manageRoles','manageMembers','manageValidation','workspaceSettings',
    'issueInvoices','viewFinances','manageDocuments','manageServices',
    'approveExpenses','viewNegotiations','manageNegotiations','paymentTermsEdit',
    'manageSites','manageBilling','manageReservations','operateKiosk','exportData',
    'designDocuments','viewPersonalData','manageIntegrations','manageConfiguration',
    'deployToProd','deployToDev','accessProd','viewAnalytics',
    'useMessages','makeReservations','viewCalendar','viewDirectory',
    'viewMyMoney','viewDocuments','managePurchases','recordOutgoingPayments',
    'manageLease','managePrivacy','viewStock','manageStock','approveStockAdjustments',
    'manageBillingCustomers','countStock'];
$fn$;
revoke execute on function public.role_permission_catalog() from public, anon;

-- the workspace export carries the plans, the tasks and their lines (#2860): 0870's function restated
-- restates 0870
create or replace function public.export_workspace_records(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_tables text[] := array[
    -- configuration, readable (the XML stays the re-importable copy)
    'sites', 'fee_bands', 'packages', 'credit_products', 'vat_rates',
    'accessories', 'seat_accessories', 'closure_days', 'validation_policies',
    'workspace_roles', 'workspace_role_members', 'workspace_field_definitions',
    'workspace_field_values', 'number_sequences', 'charging_stations',
    'plan_images', 'setting_values',
    -- member accounts
    'member_credits', 'member_credit_uses', 'price_negotiations',
    'quota_extensions', 'usage_records', 'invoice_matches', 'invoice_reminders',
    'invoice_dunning_holds', 'tax_exemption_certificates',
    -- purchases, premises, assets, books
    'suppliers', 'purchase_documents', 'purchase_lines', 'purchase_obligations',
    'outgoing_payments', 'expense_schedules', 'expense_occurrences',
    'expense_repartitions', 'premises_leases', 'lease_terms',
    'lease_settlements', 'room_rentals', 'room_rental_fees', 'workspace_assets',
    'asset_valuation_batches', 'asset_valuation_rows', 'book_profiles',
    'book_accounts', 'book_mappings', 'book_periods', 'vat_declarations',
    'einvoice_inbox',
    -- people the space is accountable to
    'guest_participations', 'rights_requests',
    -- #3307 the orders to the suppliers
    'purchase_orders', 'purchase_order_lines', 'purchase_order_sends',
    'purchase_order_receipts', 'purchase_order_receipt_lines',
    -- #3308 the passes the space sells and the passes it sold
    'guest_pass_offers', 'guest_passes',
    -- #3824 the goods ledger
    'item_units', 'item_codes', 'stock_locations', 'stock_lots', 'stock_movements',
    'stock_balances',
    -- #4164 the billing identity of each customer the business invoices
    'billing_parties',
    -- #4166 the customer quotes, their revisions, the decisions the issuer recorded and
    -- the conversions into invoices
    'customer_quotes', 'customer_quote_revisions', 'customer_quote_decisions',
    'customer_quote_conversions',
    -- #4169 the variants and the supplier's article
    'item_dimensions', 'item_dimension_values', 'item_variants', 'item_variant_values',
    'supplier_item_mappings',
    -- #4171 what was put away from a delivery
    'stock_receipt_allocations',
    -- #4170 the transfers between sites and what each loaded
    'stock_transfers', 'stock_transfer_lines',
    -- #4294 the reorder points
    'stock_reorder_points',
    -- #4172 the returns, and what each line reversed
    'stock_returns', 'stock_reversals',
    -- #4172 the counts and their decisions
    'stock_counts',
    -- #4295 the plans, the tasks and their lines
    'stock_count_plans', 'stock_count_tasks', 'stock_count_task_lines',
    -- #4178 the engagements of the services ordered, their steps and the invoice
    -- lines that billed a direct commitment
    'service_fulfilments', 'service_fulfilment_transitions', 'service_fulfilment_invoice_links'];
  v_left_out text[] := public.system_column_names() || array['workspace_id', 'source_xml'];
  v_table text;
  v_columns text[];
  v_rows jsonb;
  v_out jsonb := '[]'::jsonb;
begin
  if auth.uid() is null or not public.has_permission(p_workspace_id, 'exportData') then
    raise exception 'only someone who may export this workspace''s data reads its records'
      using errcode = 'DKN01';
  end if;
  foreach v_table in array v_tables loop
    select array_agg(c.column_name::text order by c.ordinal_position) into v_columns
      from information_schema.columns c
     where c.table_schema = 'public' and c.table_name = v_table
       and c.column_name <> all (v_left_out);
    execute format(
      'select coalesce(jsonb_agg(jsonb_build_array(%s) order by created_datetime), ''[]''::jsonb)
         from public.%I where workspace_id = $1',
      (select string_agg(format('%I', c), ', ') from unnest(v_columns) c), v_table)
      into v_rows using p_workspace_id;
    v_out := v_out || jsonb_build_array(jsonb_build_object(
      'table', v_table, 'columns', to_jsonb(v_columns), 'rows', v_rows));
  end loop;
  return v_out;
end;
$fn$;
revoke execute on function public.export_workspace_records(uuid) from public, anon;
grant execute on function public.export_workspace_records(uuid) to authenticated;

select public.set_deskilo_schema_version(873);
