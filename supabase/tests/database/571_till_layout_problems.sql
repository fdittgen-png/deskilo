-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4448 (0958, 0959): the rules of a till layout on the server, the same as the app's validateTillLayout. A valid layout has no
-- problem; a cell past its grid, two cells on one place, a tool below its span, an unknown kind or function, an item key
-- naming no item of this business (another business's item included), the cell cap, no name, no page and a bad grid are
-- each named with where they are; a size the server does not know is kept, not judged. The save and publish commands:
-- the owner and an admin (configureTill is an admin default) save, a member does not; the same request replays; a stale
-- version is refused; an invalid layout is refused with its first problem; another business's till and a business
-- without the flag are refused; a seller reads the published layout and never the draft. Rolled back.
begin;
select plan(29);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
-- one page, one phone grid of [cols] x [rows] holding [cells]
create or replace function pg_temp.lay(p_cells text, p_cols int default 4, p_rows int default 4) returns jsonb language sql immutable as $f$
  select format('{"pages": [{"name": "Sale", "grids": {"phone": {"cols": %s, "rows": %s, "cells": [%s]}}}]}', p_cols, p_rows, p_cells)::jsonb
$f$;
create or replace function pg_temp.item(p_id uuid, p_col int, p_row int) returns text language sql immutable as $f$
  select format('{"kind": "item_key", "col": %s, "row": %s, "col_span": 1, "row_span": 1, "params": {"item_id": "%s"}}', p_col, p_row, p_id)
$f$;
create or replace function pg_temp.check(p_layout jsonb, p_cap int default 200, p_name text default 'Front') returns text language sql as $f$
  select array_to_string(public.till_layout_problems(pg_temp.u(101), p_name, p_layout, p_cap), ', ')
$f$;

create or replace function pg_temp.run_as(p_user uuid, p_sql text) returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  set local role authenticated;
  begin
    execute p_sql into v;
  exception when others then
    get stacked diagnostics d = pg_exception_detail;
    v := 'ERR ' || sqlstate || coalesce(' ' || d, '');
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
create or replace function pg_temp.save(p_user int, p_ws int, p_req int, p_till int, p_version int, p_layout jsonb) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.till_layout_save_v1(%L, %L, %L, %L, %L, %L::jsonb)::text',
    pg_temp.u(p_ws), pg_temp.u(p_req), pg_temp.u(p_till), 'Front', p_version, p_layout))
$f$;
create or replace function pg_temp.publish(p_user int, p_req int, p_version int) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.till_layout_publish_v1(%L, %L, %L, %L)::text',
    pg_temp.u(101), pg_temp.u(p_req), pg_temp.u(401), p_version))
$f$;
create or replace function pg_temp.f(p text, k text) returns text language sql immutable as $f$
  select case when p like '{%' then p::jsonb ->> k else p end
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'tlayout-' || n || '@deskilo.test', '', now(), now(), now()
from generate_series(1, 4) n;
-- 1 owns both businesses; 2 is an admin of A; 3 belongs to no business; 4 a member of A who sells (issueInvoices)
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Layout A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "counterTillSessions": true, "counterTillLayout": true}',
   '{"member": ["issueInvoices"]}'),
  (pg_temp.u(102), 'Layout B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "counterTillSessions": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, true, 'active'),
  (pg_temp.u(203), pg_temp.u(101), pg_temp.u(4), false, false, 'active'),
  (pg_temp.u(204), pg_temp.u(102), pg_temp.u(1), true, true, 'active');
insert into public.counter_tills (id, workspace_id, name) values
  (pg_temp.u(401), pg_temp.u(101), 'Till 1'), (pg_temp.u(402), pg_temp.u(102), 'Till B');
insert into public.services (id, workspace_id, name, price_cents, active, stock, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Croissant', 120, true, null, 'piece', 'none', true),
  (pg_temp.u(302), pg_temp.u(102), 'Other shop', 500, true, null, 'piece', 'none', true);

select is(pg_temp.check(pg_temp.lay(pg_temp.item(pg_temp.u(301), 0, 0)
  || ', {"kind": "keypad", "col": 2, "row": 0, "col_span": 2, "row_span": 3}'
  || ', {"kind": "function_key", "col": 0, "row": 3, "params": {"function": "pay_cash"}}')), '',
  'a layout inside its grid, with known kinds and an item of the business, has no problem');
select is(pg_temp.check(pg_temp.lay('{"kind": "basket", "col": 3, "row": 0, "col_span": 2, "row_span": 2}')),
  'outside_grid page 0 phone cell 0', 'a cell past the edge is outside its grid, with where');
select is(pg_temp.check(pg_temp.lay('{"kind": "basket", "col": 0, "row": 0, "col_span": 0, "row_span": 2}')),
  'outside_grid page 0 phone cell 0', 'a cell without a span is outside its grid');
select is(pg_temp.check(pg_temp.lay(pg_temp.item(pg_temp.u(301), 0, 0) || ', ' || pg_temp.item(pg_temp.u(301), 0, 0))),
  'overlap page 0 phone cell 1', 'two cells on one place overlap, the later one named');
select is(pg_temp.check(pg_temp.lay('{"kind": "keypad", "col": 0, "row": 0, "col_span": 2, "row_span": 2}')),
  'too_small page 0 phone cell 0', 'a keypad below its span is too small');
select is(pg_temp.check(pg_temp.lay('{"kind": "hologram", "col": 0, "row": 0}')),
  'unknown_kind page 0 phone cell 0', 'a kind the server does not know is refused');
select is(pg_temp.check(pg_temp.lay('{"kind": "function_key", "col": 0, "row": 0, "params": {"function": "teleport"}}')),
  'unknown_function page 0 phone cell 0', 'a function the till does not have is refused');
select is(pg_temp.check(pg_temp.lay(pg_temp.item(pg_temp.u(302), 0, 0))),
  'unknown_item page 0 phone cell 0', 'an item of another business is not an item of this one');
select is(pg_temp.check(pg_temp.lay('{"kind": "item_key", "col": 0, "row": 0, "params": {"item_id": "not-a-uuid"}}')),
  'unknown_item page 0 phone cell 0', 'an item key naming no item is refused, never cast');
select is(pg_temp.check(pg_temp.lay(pg_temp.item(pg_temp.u(301), 0, 0) || ', ' || pg_temp.item(pg_temp.u(301), 1, 0)), 1),
  'too_large', 'the cell cap counts every cell');
select is(pg_temp.check(pg_temp.lay(pg_temp.item(pg_temp.u(301), 0, 0) || ', ' || pg_temp.item(pg_temp.u(301), 0, 0)), 1),
  'too_large', 'past the cap nothing else is judged: the overlap is not even looked at');
select is(pg_temp.check(jsonb_build_object('pages', jsonb_build_array(jsonb_build_object('name', repeat('x', 300000), 'grids', '{}'::jsonb)))),
  'too_large', 'a layout past the byte cap is refused before it is walked');
select is(pg_temp.check(pg_temp.lay(''), 200, ' '), 'no_name', 'a layout needs a name');
select is(pg_temp.check('{"pages": []}'::jsonb), 'no_pages', 'a layout needs a page');
select is(pg_temp.check(pg_temp.lay('', 0, 4)), 'bad_grid page 0 phone', 'a grid without columns is refused');
select is(pg_temp.check(pg_temp.lay('', 25, 4)), 'bad_grid page 0 phone', 'a grid wider than the largest side is refused');
select is(pg_temp.check('{"pages": [{"name": "p", "grids": {"phone": {"cols": 2, "rows": 2, "cells": []}, "watch": {"cols": 0, "rows": 0}}}]}'::jsonb), '',
  'a size the server does not know is kept, not judged');

-- ── the save and publish commands ──
select set_config('t.lay', pg_temp.lay('{"kind": "basket", "col": 0, "row": 0, "col_span": 2, "row_span": 2}')::text, false);
select is(pg_temp.f(pg_temp.save(1, 101, 901, 401, 0, current_setting('t.lay')::jsonb), 'version'), '1', 'the owner saves a first draft at version 1');
select is(pg_temp.f(pg_temp.save(1, 101, 901, 401, 0, current_setting('t.lay')::jsonb), 'replayed'), 'true', 'the same request answers the same draft');
select is(pg_temp.f(pg_temp.save(2, 101, 902, 401, 1, current_setting('t.lay')::jsonb), 'version'), '2', 'an admin lays out the tills by default');
select is(left(pg_temp.save(1, 101, 903, 401, 1, current_setting('t.lay')::jsonb), 9), 'ERR DKL10', 'a save at a version another editor moved is refused');
select is(left(pg_temp.save(4, 101, 904, 401, 2, current_setting('t.lay')::jsonb), 9), 'ERR DKN01', 'a seller without the right does not lay out a till');
select is(pg_temp.save(1, 101, 905, 401, 2, pg_temp.lay('{"kind": "basket", "col": 3, "row": 0, "col_span": 2, "row_span": 2}')),
  'ERR DKL02 {"reason": "outside_grid page 0 phone cell 0"}', 'an invalid layout is refused with its first problem');
select is(pg_temp.save(1, 101, 906, 402, 0, current_setting('t.lay')::jsonb), 'ERR DKL02 {"reason": "till"}', 'another business''s till is not this business''s');
select is(left(pg_temp.save(1, 102, 907, 402, 0, current_setting('t.lay')::jsonb), 9), 'ERR DKG01', 'a business without till layouts saves none');
select is(pg_temp.f(pg_temp.publish(2, 911, 2), 'version'), '1', 'the draft at the version read is published');
select is(left(pg_temp.publish(1, 912, 1), 9), 'ERR DKL10', 'publishing a version that moved is refused');
select is(pg_temp.run_as(pg_temp.u(4), $q$select string_agg(status, ',' order by status) from public.till_layouts$q$), 'published',
  'a seller reads the published layout and never the draft');
select is(pg_temp.run_as(pg_temp.u(3), $q$select count(*)::text from public.till_layouts$q$), '0', 'someone of no business reads none');

select * from finish();
rollback;
