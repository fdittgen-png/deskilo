-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4364 (0915-0917): a UHF reader's bulk read. The batched resolution is scoped to the business, de-duplicated and bounded; a move of
-- pieces from two places is one request with its pieces taken from where they are, and a piece moved by someone else is refused with
-- its new place named; a bulk read fills the counted lines of a cycle count task for per-unit items and adjusts nothing by itself;
-- a blind counter is not told what was expected. Rolled back.
begin;
select plan(23);

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

-- ── the batched resolution ──
select set_config('t.r', pg_temp.resolve(3, array['e28068940000401561d68f01', 'E28068940000401561D68F01', 'E28068940000401561D68F02', 'E28068940000401561D68FEE', 'nothing', '  ', 'E28068940000401561D68F04']), false);
select is((pg_temp.f(current_setting('t.r'), 'received') || '/' || pg_temp.f(current_setting('t.r'), 'distinct') || '/' || pg_temp.f(current_setting('t.r'), 'truncated')), '7/5/false',
  'a read of seven codes (one tag twice, one blank) answers five distinct ones, in order, untruncated');
select is((current_setting('t.r')::jsonb #>> '{results,0,piece,place,code}') || ' ' || (current_setting('t.r')::jsonb #>> '{results,0,piece,state}'), 'MAIN in_stock', 'a piece answers its place and its state');
select is((current_setting('t.r')::jsonb #>> '{results,4,piece,place,code}'), 'FLOOR', 'each from where it is');
select is((current_setting('t.r')::jsonb #>> '{results,2,kind}') || ' ' || (current_setting('t.r')::jsonb #>> '{results,3,kind}'), 'unknown unknown', 'a tag and a code nobody knows answer unknown, never an error');
select is(left(pg_temp.resolve(4, array['E28068940000401561D68F01']), 9), 'ERR DKN01', 'a member of another business reads nothing of this one');
select set_config('t.other', (select pg_temp.run_as(pg_temp.u(4), format('select public.stock_resolve_codes_v1(%L, %L::text[])::text', pg_temp.u(102), array['E28068940000401561D68F01']))), false);
select is(current_setting('t.other')::jsonb #>> '{results,0,kind}', 'unknown', 'and a tag of this business is unknown to the other');
select is(left(pg_temp.resolve(3, array['E28068940000401561D68F01'], true), 9), 'ERR DKN01', 'an assistant session does not bulk read');
select is(left(pg_temp.resolve(2, array['E28068940000401561D68F01']), 9), 'ERR DKN01', 'and a counter who holds only the count right resolves through the count command, not the stock reader');
insert into public.setting_values (scope, workspace_id, key, value) values ('workspace', pg_temp.u(101), 'stock.tag_read_max_tags', '2'::jsonb);
select is(pg_temp.f(pg_temp.resolve(3, array['E28068940000401561D68F01', 'E28068940000401561D68F02', 'E28068940000401561D68F03']), 'truncated') || '/' || pg_temp.f(pg_temp.resolve(3, array['E28068940000401561D68F01', 'E28068940000401561D68F02', 'E28068940000401561D68F03']), 'distinct'), 'true/2',
  'a read keeps at most the setting''s tags and says it stopped');
select is(left(pg_temp.resolve(3, (select array_agg('E28068940000401561D68F0' || (i % 9)) from generate_series(1, 41) i)), 9), 'ERR DKG07', 'a request far beyond the bound is refused before any work');
delete from public.setting_values where key = 'stock.tag_read_max_tags';

-- ── a move of pieces from two places: one request, each piece taken from where it is ──
select set_config('t.move', pg_temp.run_as(pg_temp.u(3), format('select public.stock_transfer_v1(%L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(920),
  format('[{"item_id": "%s", "lot_id": "%s", "quantity": "1", "from": "%s", "to": "%s", "units": [{"tag": "E28068940000401561D68F01"}]},
          {"item_id": "%s", "lot_id": "%s", "quantity": "1", "from": "%s", "to": "%s", "units": [{"tag": "E28068940000401561D68F04"}]}]',
    pg_temp.u(303), current_setting('t.lot'), pg_temp.loc('MAIN'), pg_temp.loc('ANNEX'), pg_temp.u(303), (select u.lot_id from public.stock_tagged_units u join public.stock_tags t on t.piece_id = u.id where t.code = 'E28068940000401561D68F04'), pg_temp.loc('FLOOR'), pg_temp.loc('ANNEX')))), false);
select is(left(current_setting('t.move'), 2), '{"', 'the pieces of two places are moved by one request');
select is((select count(*)::int from public.stock_movements where request_id = pg_temp.u(920)), 2, 'which is one request id with a line for each source');
select is((select string_agg(distinct z.code, ',') from public.stock_tagged_units u join public.stock_tags t on t.piece_id = u.id join public.stock_locations z on z.id = u.location_id where t.code in ('E28068940000401561D68F01', 'E28068940000401561D68F04')), 'ANNEX', 'and both pieces are in the destination');
select is(left(pg_temp.run_as(pg_temp.u(3), format('select public.stock_transfer_v1(%L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(921),
  format('[{"item_id": "%s", "lot_id": "%s", "quantity": "1", "from": "%s", "to": "%s", "units": [{"tag": "E28068940000401561D68F01"}]}]', pg_temp.u(303), current_setting('t.lot'), pg_temp.loc('MAIN'), pg_temp.loc('FLOOR')))), 10), 'ERR DKG26 ', 'a piece moved by someone else while the read was open is refused at the confirm');
select is(pg_temp.run_as(pg_temp.u(3), format('select public.stock_transfer_v1(%L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(921),
  format('[{"item_id": "%s", "lot_id": "%s", "quantity": "1", "from": "%s", "to": "%s", "units": [{"tag": "E28068940000401561D68F01"}]}]', pg_temp.u(303), current_setting('t.lot'), pg_temp.loc('MAIN'), pg_temp.loc('FLOOR'))))::text like '%"place": "ANNEX"%', true,
  'naming its new place');

-- ── a cycle count filled by a bulk read: F2 and F3 at MAIN, F1 and F4 at ANNEX, nothing at FLOOR ──
select pg_temp.run_as(pg_temp.u(1), format('select public.stock_count_plan_save_v1(%L, %L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(930), pg_temp.u(931),
  format('{"name": "Baskets", "scope_kind": "items", "item_ids": ["%s"], "next_due_on": "%s"}', pg_temp.u(303), public.workspace_today(pg_temp.u(101)))));
select public.stock_cycle_counts_due();
select set_config('t.task', (select id::text from public.stock_count_tasks order by created_datetime limit 1), false);
select is((select count(*)::int from public.stock_count_task_lines where task_id = current_setting('t.task')::uuid), 3, 'the task has a line for each lot of baskets at each place that holds some');
select set_config('t.count', pg_temp.run_as(pg_temp.u(2), format('select public.stock_count_tag_read_v1(%L, %L, %L, %L::text[])::text', pg_temp.u(101), pg_temp.u(940), current_setting('t.task')::uuid,
  array['E28068940000401561D68F02', 'E28068940000401561D68F02', 'E28068940000401561D68F01', 'E28068940000401561D68F04', 'E28068940000401561D68FEE'])), false);
select is((select string_agg(l.state || ':' || z.code, ',' order by z.code) from public.stock_count_task_lines l join public.stock_locations z on z.id = l.location_id where l.task_id = current_setting('t.task')::uuid), 'counted:ANNEX,counted:ANNEX,counted:MAIN',
  'a counter reads the baskets of two places and all three lines are counted');
select is((select string_agg(c.observed_quantity::text, ',' order by z.code) from public.stock_counts c join public.stock_count_task_lines l on l.count_id = c.count_id join public.stock_locations z on z.id = l.location_id where l.task_id = current_setting('t.task')::uuid), '1.000000,1.000000,1.000000',
  'with the pieces read at each place: one at the annex for each lot, one at the main store (the other is not read)');
select is((select sum(quantity)::int from public.stock_balances where item_id = pg_temp.u(303) and location_id = pg_temp.loc('MAIN')), 2, 'and the balance of the main store is untouched: a read never adjusts it');
select is(current_setting('t.count')::jsonb ? 'missing', false, 'a blind counter is told what it counted, never what was expected');
select is(pg_temp.f(pg_temp.run_as(pg_temp.u(2), format('select public.stock_count_tag_read_v1(%L, %L, %L, %L::text[])::text', pg_temp.u(101), pg_temp.u(940), current_setting('t.task')::uuid,
  array['E28068940000401561D68F02', 'E28068940000401561D68F02', 'E28068940000401561D68F01', 'E28068940000401561D68F04', 'E28068940000401561D68FEE'])), 'replayed'), 'true', 'a lost answer recovers the same read: nothing is counted twice');

-- a manager reads two crates of three and is told the one that was not read, and the tag that is no piece
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable, tag_mode) values
  (pg_temp.u(304), pg_temp.u(101), 'Crates', 5000, true, 'piece', 'serial', true, 'per_unit');
select pg_temp.mv(3, 950, format('[{"item_id": "%s", "quantity": "2", "from": "%s", "to": "%s", "units": [{"tag": "E28068940000401561D69A01"}, {"tag": "E28068940000401561D69A02"}], "new_lot": {"total_cost_minor": 2000}}]',
  pg_temp.u(304), pg_temp.place('supplier'), pg_temp.loc('MAIN')), 'receipt');
select pg_temp.run_as(pg_temp.u(1), format('select public.stock_count_plan_save_v1(%L, %L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(951), pg_temp.u(952),
  format('{"name": "Crates", "scope_kind": "items", "item_ids": ["%s"], "next_due_on": "%s"}', pg_temp.u(304), public.workspace_today(pg_temp.u(101)))));
select public.stock_cycle_counts_due();
select set_config('t.task2', (select t.id::text from public.stock_count_tasks t join public.stock_count_task_lines l on l.task_id = t.id where l.item_id = pg_temp.u(304) limit 1), false);
select set_config('t.count2', pg_temp.run_as(pg_temp.u(3), format('select public.stock_count_tag_read_v1(%L, %L, %L, %L::text[])::text', pg_temp.u(101), pg_temp.u(953), current_setting('t.task2')::uuid,
  array['E28068940000401561D69A01', 'E28068940000401561D68F02', 'E28068940000401561D69AEE'])), false);
select is(current_setting('t.count2')::jsonb #>> '{missing,0,code}', 'E28068940000401561D69A02', 'a manager is told which crate was expected and not read');
select is((select string_agg(x ->> 'reason', ',' order by x ->> 'code') from jsonb_array_elements(current_setting('t.count2')::jsonb -> 'left_out') x), 'other_place,not_a_piece', 'and which tags were left out: a piece of another task, a tag that is no piece');

select * from finish();
rollback;
