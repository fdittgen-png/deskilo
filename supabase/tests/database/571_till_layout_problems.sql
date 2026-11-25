-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4448 (0958): the rules of a till layout on the server, the same as the app's validateTillLayout. A valid layout has no
-- problem; a cell past its grid, two cells on one place, a tool below its span, an unknown kind or function, an item key
-- naming no item of this business (another business's item included), the cell cap, no name, no page and a bad grid are
-- each named with where they are; a size the server does not know is kept, not judged. Rolled back.
begin;
select plan(15);

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

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values (pg_temp.u(1), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'tlayout-1@deskilo.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Layout A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{}', '{}'),
  (pg_temp.u(102), 'Layout B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{}', '{}');
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
select is(pg_temp.check(pg_temp.lay(''), 200, ' '), 'no_name', 'a layout needs a name');
select is(pg_temp.check('{"pages": []}'::jsonb), 'no_pages', 'a layout needs a page');
select is(pg_temp.check(pg_temp.lay('', 0, 4)), 'bad_grid page 0 phone', 'a grid without columns is refused');
select is(pg_temp.check(pg_temp.lay('', 25, 4)), 'bad_grid page 0 phone', 'a grid wider than the largest side is refused');
select is(pg_temp.check('{"pages": [{"name": "p", "grids": {"phone": {"cols": 2, "rows": 2, "cells": []}, "watch": {"cols": 0, "rows": 0}}}]}'::jsonb), '',
  'a size the server does not know is kept, not judged');

select * from finish();
rollback;
