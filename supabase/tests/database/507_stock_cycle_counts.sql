-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4295 (0872-0874): scheduled cycle counts. A plan names a scope (places with their sub-places, items, or high
-- value) and a schedule; the due job makes ONE task per plan and due day, in the business's own day, lists the
-- scope's lines and moves the plan on; the counter reads a task with no quantities; counting a line records a
-- count of #4172 (so the approval and the adjustment are that leaf's) and a movement between the count and the
-- approval makes it stale; skipping needs a reason; a task is complete when every line is counted or skipped; an
-- overdue open task raises one notice, ended when the task is complete; the history says when and how exactly;
-- the rights, another business, an assistant and the feature off are refused. Rolled back.
begin;
select plan(33);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_user uuid, p_sql text, p_delegated boolean default false)
returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims',
    case when p_user is null then '' else
    (jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')
     || case when p_delegated then '{"client_id": "assistant"}'::jsonb else '{}'::jsonb end)::text end, true);
  set local role authenticated;
  begin
    execute p_sql into v;
  exception when others then
    v := 'ERR ' || sqlstate;
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
create or replace function pg_temp.place(p_kind text, p_ws int default 101) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(p_ws) and kind = p_kind order by created_datetime limit 1
$f$;
create or replace function pg_temp.loc(p_code text, p_ws int default 101) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(p_ws) and code = p_code
$f$;
create or replace function pg_temp.mv(p_req int, p_item int, p_qty text, p_from uuid, p_to uuid, p_reason text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.stock_move_v1(%L, %L, %L::jsonb, %L)::text', pg_temp.u(101), pg_temp.u(p_req),
    format('[{"item_id": "%s", "quantity": "%s", "from": "%s", "to": "%s"}]', pg_temp.u(p_item), p_qty, p_from, p_to), p_reason))
$f$;
create or replace function pg_temp.plan(p_user int, p_req int, p_plan int, p_body text, p_ws int default 101, p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_count_plan_save_v1(%L, %L, %L, %L::jsonb)::text', pg_temp.u(p_ws), pg_temp.u(p_req), pg_temp.u(p_plan), p_body), p_delegated)
$f$;
create or replace function pg_temp.due() returns text language sql as $f$ select public.stock_cycle_counts_due()::text $f$;
create or replace function pg_temp.tasks(p_user int, p_ws int default 101, p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_count_tasks_v1(%L)::text', pg_temp.u(p_ws)), p_delegated)
$f$;
create or replace function pg_temp.task(p_user int, p_plan int) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_count_task_v1(%L, %L)::text', pg_temp.u(101), (select id from public.stock_count_tasks where plan_id = pg_temp.u(p_plan) order by due_on limit 1)))
$f$;
create or replace function pg_temp.line_of(p_plan int, p_item int) returns uuid language sql stable as $f$
  select x.id from public.stock_count_task_lines x join public.stock_count_tasks t on t.id = x.task_id where t.plan_id = pg_temp.u(p_plan) and x.item_id = pg_temp.u(p_item) order by x.id limit 1
$f$;
create or replace function pg_temp.cnt(p_user int, p_req int, p_line uuid, p_obs text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_cycle_count_line_v1(%L, %L, %L, %L)::text', pg_temp.u(101), pg_temp.u(p_req), p_line, p_obs))
$f$;
create or replace function pg_temp.skip(p_user int, p_req int, p_line uuid, p_reason text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_cycle_skip_line_v1(%L, %L, %L, %L)::text', pg_temp.u(101), pg_temp.u(p_req), p_line, p_reason))
$f$;
create or replace function pg_temp.f(p text, k text) returns text language sql immutable as $f$
  select case when p like '{%' then p::jsonb ->> k else p end
$f$;
create or replace function pg_temp.onhand(p_item int, p_loc uuid) returns numeric language sql stable as $f$
  select coalesce(sum(quantity), 0) from public.stock_balances where item_id = pg_temp.u(p_item) and location_id = p_loc
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cyc-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 4) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Cycle A', 'FR', 'EUR', 'Pacific/Kiritimati', pg_temp.u(1),
   '{"services": true, "stockManagement": true, "stockLots": true, "stockCounts": true, "stockCycleCounts": true}',
   '{"member": ["viewStock"]}'),
  (pg_temp.u(102), 'Cycle B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(4),
   '{"services": true, "stockManagement": true, "stockCounts": true, "stockCycleCounts": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active'),
  (pg_temp.u(204), pg_temp.u(102), pg_temp.u(4), true, true, 'active');
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Mugs', 300, true, 'piece', 'none', true),
  (pg_temp.u(302), pg_temp.u(101), 'Beans', 900, true, 'kg', 'lot', true),
  (pg_temp.u(303), pg_temp.u(101), 'Plates', 200, true, 'piece', 'none', true),
  (pg_temp.u(304), pg_temp.u(102), 'Foreign', 100, true, 'piece', 'none', true);
insert into public.stock_locations (workspace_id, kind, code, name, parent_id) values (pg_temp.u(101), 'shelf', 'SHELF-A', 'Shelf A', pg_temp.loc('MAIN'));
insert into public.stock_locations (workspace_id, kind, code, name, parent_id) values (pg_temp.u(101), 'warehouse', 'ANNEX', 'Annex', null);
select pg_temp.mv(900, 301, '10', pg_temp.place('supplier'), pg_temp.loc('MAIN'), 'receipt');
select pg_temp.mv(901, 303, '6', pg_temp.place('supplier'), pg_temp.loc('SHELF-A'), 'receipt');
select pg_temp.mv(902, 303, '4', pg_temp.place('supplier'), pg_temp.loc('ANNEX'), 'receipt');
select pg_temp.run_as(pg_temp.u(1), format($q$select public.stock_move_v1(%L, %L, %L::jsonb, 'receipt')::text$q$, pg_temp.u(101), pg_temp.u(903),
  format('[{"item_id": "%s", "quantity": "10", "from": "%s", "to": "%s", "new_lot": {"code": "B1", "total_cost_minor": 100000}}]', pg_temp.u(302), pg_temp.place('supplier'), pg_temp.loc('MAIN'))));

-- the Kiritimati business's own day is ahead of the server's: a plan due on its today is due now
select set_config('cy.today', public.workspace_today(pg_temp.u(101))::text, false);

-- ── plans ──
select is(pg_temp.f(pg_temp.plan(1, 910, 801, format('{"name": "Main aisle", "scope_kind": "places", "location_ids": ["%s"], "interval_days": 7, "next_due_on": "%s"}',
  pg_temp.loc('MAIN'), current_setting('cy.today'))), 'active'), 'true', 'a plan of the main store, every 7 days, is saved');
select is(pg_temp.plan(1, 911, 801, format('{"name": "Main aisle", "scope_kind": "places", "location_ids": ["%s"], "interval_days": 7, "next_due_on": "%s"}',
  pg_temp.loc('MAIN'), current_setting('cy.today'))), pg_temp.plan(1, 910, 801, format('{"name": "Main aisle", "scope_kind": "places", "location_ids": ["%s"], "interval_days": 7, "next_due_on": "%s"}',
  pg_temp.loc('MAIN'), current_setting('cy.today'))), 'the same plan sent again answers the same');
select is(pg_temp.plan(1, 912, 802, '{"name": "x", "scope_kind": "places", "location_ids": [], "next_due_on": "2030-01-01"}'), 'ERR DKG07', 'a plan of places names some');
select is(pg_temp.plan(1, 913, 802, format('{"name": "x", "scope_kind": "places", "location_ids": ["%s"], "next_due_on": "2030-01-01"}', pg_temp.u(999))), 'ERR DKG04', 'a place that is not of this business is refused');
select is(pg_temp.plan(2, 914, 803, format('{"name": "x", "scope_kind": "items", "item_ids": ["%s"], "next_due_on": "2030-01-01"}', pg_temp.u(301))), 'ERR DKN01', 'a member who only views the stock cannot plan');
select is(pg_temp.plan(1, 915, 803, format('{"name": "x", "scope_kind": "items", "item_ids": ["%s"], "next_due_on": "2030-01-01"}', pg_temp.u(301)), 101, true), 'ERR DKN01', 'an assistant cannot');
select pg_temp.plan(1, 916, 804, format('{"name": "Plates", "scope_kind": "items", "item_ids": ["%s"], "next_due_on": "%s"}', pg_temp.u(303), current_setting('cy.today')));
select pg_temp.plan(1, 917, 805, format('{"name": "Valuable", "scope_kind": "high_value", "next_due_on": "%s"}', current_setting('cy.today')));
select pg_temp.plan(1, 918, 806, '{"name": "Later", "scope_kind": "items", "item_ids": ["' || pg_temp.u(301)::text || '"], "next_due_on": "2099-01-01"}');

-- ── the due job ──
select is(pg_temp.due(), '3', 'the job makes one task for each of the three plans that are due, and not the one due in 2099');
select is(pg_temp.due(), '0', 'a second run makes nothing');
select is((select count(*)::int from public.stock_count_tasks), 3, 'three tasks');
select is((select next_due_on::text from public.stock_count_plans where id = pg_temp.u(801)), (current_setting('cy.today')::date + 7)::text, 'the weekly plan moved a week on, in the business''s own day');
select is((select active from public.stock_count_plans where id = pg_temp.u(804)), false, 'a plan with no interval runs once');
select is((select count(*)::int from public.stock_count_task_lines x join public.stock_count_tasks t on t.id = x.task_id where t.plan_id = pg_temp.u(801)), 3,
  'the main store plan lists the lines of the places inside it: mugs and beans at the main store, plates on the shelf (a sub-place)');
select is((select count(*)::int from public.stock_count_task_lines x join public.stock_count_tasks t on t.id = x.task_id where t.plan_id = pg_temp.u(804)), 2,
  'the items plan lists plates at both places they are held');
select is((select count(*)::int from public.stock_count_task_lines x join public.stock_count_tasks t on t.id = x.task_id where t.plan_id = pg_temp.u(805)), 1,
  'the high-value plan lists only the beans (10 kg at 1000.00): above the threshold of 500.00');

-- ── the blind task ──
select is(pg_temp.task(1, 801) ~ '(quantity|baseline|observed|on_hand|expected)', false, 'the counter''s task shows no quantity');
select is(jsonb_array_length(pg_temp.task(1, 801)::jsonb -> 'lines'), 3, 'only what to count and where');
select is(pg_temp.tasks(2), 'ERR DKN01', 'a member who only views the stock cannot read the tasks');

-- ── counting ──
select is(pg_temp.f(pg_temp.cnt(1, 920, pg_temp.line_of(801, 301), '8'), 'difference'), '-2.000000', 'counting the mugs records a count of 8 against 10');
select is(pg_temp.onhand(301, pg_temp.loc('MAIN')), 10::numeric, 'counting moves nothing');
select is(pg_temp.cnt(1, 921, pg_temp.line_of(801, 301), '8'), pg_temp.cnt(1, 920, pg_temp.line_of(801, 301), '8'), 'the same line counted again answers the same');
select is((select state from public.stock_counts where count_id = pg_temp.line_of(801, 301)), 'recorded', 'it is a count of #4172, waiting for its approval');
select pg_temp.mv(931, 301, '1', pg_temp.place('supplier'), pg_temp.loc('MAIN'), 'receipt');
select is(pg_temp.run_as(pg_temp.u(1), format($q$select public.stock_count_decide_v1(%L, %L, %L, 'apply')::text$q$, pg_temp.u(101), pg_temp.u(932), pg_temp.line_of(801, 301))), 'ERR DKG20',
  'a movement between the count and the approval makes it stale: refused, the balance is not overwritten');
select is(pg_temp.onhand(301, pg_temp.loc('MAIN')), 11::numeric, 'the balance is what it is');

-- ── skipping and completing ──
select is(pg_temp.skip(1, 940, pg_temp.line_of(801, 302), ''), 'ERR DKG07', 'skipping needs a reason');
select is(pg_temp.f(pg_temp.skip(1, 941, pg_temp.line_of(801, 302), 'aisle closed'), 'task_state'), 'open', 'a skipped line leaves the task open while one is pending');
select is(pg_temp.f(pg_temp.cnt(1, 942, pg_temp.line_of(801, 303), '6'), 'task_state'), 'complete', 'the task is complete when every line is counted or skipped');
select is(pg_temp.cnt(1, 943, pg_temp.line_of(801, 303), '5'), 'ERR DKG19', 'a complete task takes no more counts');

-- ── overdue ──
update public.stock_count_tasks set due_on = (current_setting('cy.today')::date - 30) where plan_id = pg_temp.u(804);
select pg_temp.due();
select is((select count(*)::int from public.events where type = 'stock_count_overdue'), 1, 'an open task past its due day by the setting raises one notice');
select pg_temp.due();
select is((select count(*)::int from public.events where type = 'stock_count_overdue' and not (payload ? 'ended')), 1, 'and only once');
select pg_temp.run_as(pg_temp.u(1), format($q$select public.stock_cycle_skip_line_v1(%L, %L, %L, 'gone')::text$q$, pg_temp.u(101), pg_temp.u(950), pg_temp.line_of(804, 303)));
select pg_temp.run_as(pg_temp.u(1), format($q$select public.stock_cycle_skip_line_v1(%L, %L, %L, 'gone')::text$q$, pg_temp.u(101), pg_temp.u(951), (select x.id from public.stock_count_task_lines x join public.stock_count_tasks t on t.id = x.task_id where t.plan_id = pg_temp.u(804) and x.state = 'pending' limit 1)));
select is((select payload ->> 'ended' from public.events where type = 'stock_count_overdue'), 'complete', 'the notice ends when the task is complete');

-- ── history, business, feature ──
select is(pg_temp.run_as(pg_temp.u(1), format($q$select (public.stock_count_history_v1(%L, %L) -> 0 ->> 'counts')$q$, pg_temp.u(101), pg_temp.u(301))), '1', 'the history says the mugs were counted once');
select is(pg_temp.run_as(pg_temp.u(4), format($q$select public.stock_count_tasks_v1(%L)::text$q$, pg_temp.u(101))), 'ERR DKN01', 'another business sees nothing');
update public.workspaces set feature_flags = feature_flags || '{"stockCycleCounts": false}' where id = pg_temp.u(101);
select is(pg_temp.tasks(1), 'ERR DKG01', 'with the feature off nothing is read');

select * from finish();
rollback;

