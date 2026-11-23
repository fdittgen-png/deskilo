-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4364 (0920): the review of the bulk reads. A bulk count counts a line only when a piece of its own item, variant and lot was
-- read at its place, and the first read of a line is final; a blank or an over-long code is reported, never dropped; the replay
-- is looked up before any size check and belongs to the caller who sent it; the hard cap is five times the limit; a piece is listed
-- once as missing, whatever its tags; every refusal of the count read is proven. Rolled back.
begin;
select plan(16);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_user uuid, p_sql text, p_delegated boolean default false)
returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims',
    (jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')
     || case when p_delegated then '{"client_id": "assistant"}'::jsonb else '{}'::jsonb end)::text, true);
  set local role authenticated;
  begin
    execute p_sql into v;
    set constraints all immediate;
    set constraints all deferred;
  exception when others then
    get stacked diagnostics d = pg_exception_detail;
    v := 'ERR ' || sqlstate || coalesce(' ' || d, '');
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
create or replace function pg_temp.loc(p_code text, p_ws int default 101) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(p_ws) and code = p_code
$f$;
create or replace function pg_temp.place(p_kind text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and kind = p_kind order by created_datetime limit 1
$f$;
create or replace function pg_temp.f(p text, k text) returns text language sql immutable as $f$
  select case when p like '{%' then p::jsonb ->> k else p end
$f$;
create or replace function pg_temp.mv(p_user int, p_req int, p_lines text, p_reason text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_move_v1(%L, %L, %L::jsonb, %L)::text', pg_temp.u(101), pg_temp.u(p_req), p_lines, p_reason))
$f$;
create or replace function pg_temp.resolve(p_user int, p_codes text[], p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_resolve_codes_v1(%L, %L::text[])::text', pg_temp.u(101), p_codes), p_delegated)
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'tagread-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 4) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Reads A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
   '{"services": true, "stockManagement": true, "stockLots": true, "stockTags": true, "stockTagReads": true, "stockCounts": true, "stockCycleCounts": true, "stockItemGroups": true}',
   '{"member": ["countStock"], "admin": ["manageStock", "approveStockAdjustments"]}'),
  (pg_temp.u(102), 'Reads B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(4),
   '{"services": true, "stockManagement": true, "stockTags": true, "stockTagReads": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active'),
  (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, true, 'active'),
  (pg_temp.u(204), pg_temp.u(102), pg_temp.u(4), true, true, 'active');
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable, tag_mode) values
  (pg_temp.u(303), pg_temp.u(101), 'Baskets', 4000, true, 'piece', 'serial', true, 'per_unit');
insert into public.stock_locations (id, workspace_id, parent_id, kind, code) values
  (pg_temp.u(901), pg_temp.u(101), pg_temp.loc('MAIN'), 'zone', 'FLOOR'),
  (pg_temp.u(902), pg_temp.u(101), pg_temp.loc('MAIN'), 'zone', 'ANNEX');

-- four baskets: F1..F3 received at MAIN, F4 at FLOOR
select pg_temp.mv(3, 910, format('[{"item_id": "%s", "quantity": "3", "from": "%s", "to": "%s", "units": [{"tag": "E28068940000401561D68F01"}, {"tag": "E28068940000401561D68F02"}, {"tag": "E28068940000401561D68F03"}], "new_lot": {"total_cost_minor": 3000}}]',
  pg_temp.u(303), pg_temp.place('supplier'), pg_temp.loc('MAIN')), 'receipt');
select pg_temp.mv(3, 911, format('[{"item_id": "%s", "quantity": "1", "from": "%s", "to": "%s", "units": [{"tag": "E28068940000401561D68F04"}], "new_lot": {"total_cost_minor": 1000}}]',
  pg_temp.u(303), pg_temp.place('supplier'), pg_temp.loc('FLOOR')), 'receipt');
select set_config('t.lot', (select id::text from public.stock_lots where item_id = pg_temp.u(303) order by created_datetime limit 1), false);


insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable, tag_mode) values
  (pg_temp.u(304), pg_temp.u(101), 'Crates', 5000, true, 'piece', 'serial', true, 'per_unit');
select pg_temp.mv(3, 950, format('[{"item_id": "%s", "quantity": "2", "from": "%s", "to": "%s", "units": [{"tag": "E28068940000401561D69A01"}, {"tag": "E28068940000401561D69A02"}], "new_lot": {"total_cost_minor": 2000}}]',
  pg_temp.u(304), pg_temp.place('supplier'), pg_temp.loc('MAIN')), 'receipt');
select pg_temp.run_as(pg_temp.u(1), format('select public.stock_count_plan_save_v1(%L, %L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(930), pg_temp.u(931),
  format('{"name": "Both", "scope_kind": "items", "item_ids": ["%s", "%s"], "next_due_on": "%s"}', pg_temp.u(303), pg_temp.u(304), public.workspace_today(pg_temp.u(101)))));
select public.stock_cycle_counts_due();
select set_config('t.task', (select id::text from public.stock_count_tasks order by created_datetime limit 1), false);
create or replace function pg_temp.cnt(p_user int, p_req int, p_task uuid, p_codes text[], p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_count_tag_read_v1(%L, %L, %L, %L::text[])::text', pg_temp.u(101), pg_temp.u(p_req), p_task, p_codes), p_delegated)
$f$;
create or replace function pg_temp.line_state(p_item int, p_place text) returns text language sql stable as $f$
  select l.state from public.stock_count_task_lines l where l.task_id = current_setting('t.task')::uuid and l.item_id = pg_temp.u(p_item) and l.location_id = pg_temp.loc(p_place) limit 1
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- ── a line is counted by a piece of its own: one basket read leaves the crates of the same shelf pending ──
select pg_temp.cnt(2, 940, current_setting('t.task')::uuid, array['E28068940000401561D68F01']);
select is(pg_temp.line_state(303, 'MAIN'), 'counted', 'the baskets of the main store are counted by a basket read');
select is(pg_temp.line_state(304, 'MAIN'), 'pending', 'and the crates of the same place are not recorded as none: they stay pending');

-- ── the first read of a line is final; a code that cannot be read is told ──
select set_config('t.second', pg_temp.cnt(2, 941, current_setting('t.task')::uuid, array['E28068940000401561D68F02', '   ', repeat('A', 201)]), false);
select is((select string_agg(x ->> 'reason', ',' order by x ->> 'reason') from jsonb_array_elements(current_setting('t.second')::jsonb -> 'left_out') x), 'already_counted,invalid,invalid',
  'a second read of a counted line says already_counted, to a blind counter too, and the blank and the over-long code are returned, not dropped');
select is((pg_temp.f(pg_temp.resolve(3, array['E28068940000401561D68F01', '', repeat('B', 201)]), 'invalid'))::jsonb -> 0 ->> 'reason', 'invalid', 'the resolution reports an unreadable code as well');

-- ── the replay belongs to its caller, and a lowered limit does not refuse the retry of a lost answer ──
select is(left(pg_temp.cnt(3, 940, current_setting('t.task')::uuid, array['E28068940000401561D68F01']), 9), 'ERR P0001', 'another member sending the same request id is not handed the answer');
insert into public.setting_values (scope, workspace_id, key, value) values ('workspace', pg_temp.u(101), 'stock.tag_read_max_tags', '1'::jsonb);
select is(pg_temp.f(pg_temp.cnt(2, 940, current_setting('t.task')::uuid, array['E28068940000401561D68F01']), 'replayed'), 'true', 'the retry of a lost answer is a replay even when the limit was lowered since');

-- ── more than the limit, and far more than the limit ──
select is(left(pg_temp.cnt(3, 942, current_setting('t.task')::uuid, array['E28068940000401561D68F04', 'E28068940000401561D69A01']), 9), 'ERR DKG07', 'more different tags than the limit is refused (DKG07)');
select is(left(pg_temp.cnt(3, 943, current_setting('t.task')::uuid, array['E28068940000401561D68F04', 'E28068940000401561D68F04', 'E28068940000401561D68F04', 'E28068940000401561D68F04', 'E28068940000401561D68F04', 'E28068940000401561D68F04']), 9), 'ERR DKG07',
  'and six codes of a limit of one are refused before any work: the hard cap is five times the limit');
select is(left(pg_temp.resolve(3, array['a', 'a', 'a', 'a', 'a', 'a']), 9), 'ERR DKG07', 'as the resolution is');
delete from public.setting_values where key = 'stock.tag_read_max_tags';

-- ── the refusals of the count read ──
select is(left(pg_temp.cnt(3, 944, pg_temp.u(999), array['E28068940000401561D68F04']), 9), 'ERR DKG04', 'a task that is not this business''s is refused (DKG04)');
select is(left(pg_temp.cnt(3, 945, current_setting('t.task')::uuid, array['E28068940000401561D68F04'], true), 9), 'ERR DKN01', 'an assistant session does not count by bulk read');
select is(left(pg_temp.cnt(2, 941, current_setting('t.task')::uuid, array['E28068940000401561D68F03']), 9), 'ERR P0001', 'the same request id with another set of codes is refused, not answered with the first');
select is(left(pg_temp.resolve(2, array['E28068940000401561D68F01']), 9), 'ERR DKN01', 'a counter with only the counting right is refused by the resolution first, with its own right named');

-- ── a piece is missing once, whatever its tags; a task whose lines are all counted is closed ──
insert into public.stock_tags (workspace_id, code, tag_kind, owner_kind, item_id, piece_id)
select pg_temp.u(101), 'E28068940000401561D69AEE', 'epc', 'piece', u.item_id, u.id
  from public.stock_tagged_units u join public.stock_tags t on t.piece_id = u.id where t.code = 'E28068940000401561D69A02';
select set_config('t.third', pg_temp.cnt(3, 946, current_setting('t.task')::uuid, array['E28068940000401561D69A01', 'E28068940000401561D68F04']), false);
select is(jsonb_array_length(current_setting('t.third')::jsonb -> 'missing'), 1, 'a crate with two tags is listed once among what was not read');
select is(left(pg_temp.cnt(3, 947, current_setting('t.task')::uuid, array['E28068940000401561D68F04']), 9), 'ERR DKG19', 'a closed task takes no more reads (DKG19)');

-- ── the feature off: the refusal names it ──
update public.workspaces set feature_flags = feature_flags || '{"stockTagReads": false}'::jsonb where id = pg_temp.u(101);
select is(left(pg_temp.cnt(3, 948, current_setting('t.task')::uuid, array['E28068940000401561D68F04']), 9) || ' ' || left(pg_temp.resolve(3, array['E28068940000401561D68F04']), 9), 'ERR DKG01 ERR DKG01', 'with bulk reading off, both functions refuse (DKG01)');

select * from finish();
rollback;
