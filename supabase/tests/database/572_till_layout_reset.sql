-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4448 (0962): a till back to its generated keys. The owner's reset removes the draft and the published layout; the
-- same request answers again; a seller without the right is refused; another business's till is refused; a business
-- without till layouts resets nothing. Rolled back.
begin;
select plan(6);

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

select set_config('t.lay', pg_temp.lay('{"kind": "basket", "col": 0, "row": 0, "col_span": 2, "row_span": 2}')::text, false);
select pg_temp.save(1, 101, 901, 401, 0, current_setting('t.lay')::jsonb);
select pg_temp.publish(1, 902, 1);
create or replace function pg_temp.reset(p_user int, p_ws int, p_req int, p_till int) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.till_layout_reset_v1(%L, %L, %L)::text',
    pg_temp.u(p_ws), pg_temp.u(p_req), pg_temp.u(p_till)))
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;
select is(left(pg_temp.reset(4, 101, 910, 401), 9), 'ERR DKN01', 'a seller without the right does not reset a till');
select is(pg_temp.reset(1, 101, 911, 402), 'ERR DKL02 {"reason": "till"}', 'another business''s till is not this business''s');
select is(left(pg_temp.reset(1, 102, 912, 402), 9), 'ERR DKG01', 'a business without till layouts resets nothing');
select is(pg_temp.f(pg_temp.reset(1, 101, 913, 401), 'removed'), '2', 'the owner''s reset removes the draft and the published layout');
select is((select count(*)::int from public.till_layouts where till_id = pg_temp.u(401)), 0, 'and the till keeps no layout');
select is(pg_temp.f(pg_temp.reset(1, 101, 913, 401), 'replayed'), 'true', 'the same request answers again');

select * from finish();
rollback;
