-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4435 (0931): how an item is traced is a choice every item offers: not traced, by batch (with an expiry date where set) or by piece.
-- The item save accepts the piece choice when the tags feature is on (and says why when it is not), pins the per-piece tag mode, and still
-- refuses a change once the item has movements. Rolled back.
begin;
select plan(8);

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
create or replace function pg_temp.loc(p_code text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and code = p_code
$f$;
create or replace function pg_temp.place(p_kind text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and kind = p_kind order by created_datetime limit 1
$f$;
create or replace function pg_temp.today() returns date language sql stable as $f$
  select public.workspace_today(pg_temp.u(101))
$f$;
create or replace function pg_temp.day(p_offset int) returns text language sql stable as $f$
  select to_char(pg_temp.today() + p_offset, 'YYYY-MM-DD')
$f$;
create or replace function pg_temp.mv(p_user int, p_req int, p_lines text, p_reason text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_move_v1(%L, %L, %L::jsonb, %L)::text', pg_temp.u(101), pg_temp.u(p_req), p_lines, p_reason))
$f$;
-- the report as a member reads it: scope, horizon, place, group, limit, cursor


create or replace function pg_temp.save(p_user int, p_item int, p_tracking text, p_ws int default 101) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.save_stock_item_v1(%L, %L, %s, %L, %L::jsonb)::text', pg_temp.u(p_ws), pg_temp.u(p_item),
    (select stock_revision from public.services where id = pg_temp.u(p_item)), gen_random_uuid(), jsonb_build_object('tracking', p_tracking)::text))
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ht-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 4) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Choice A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"services": true, "stockManagement": true, "stockLots": true, "stockTags": true}', '{"admin": ["manageStock"]}'),
  (pg_temp.u(102), 'Choice B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(4), '{"services": true, "stockManagement": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, true, 'active'),
  (pg_temp.u(204), pg_temp.u(102), pg_temp.u(4), true, true, 'active');
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable) values
  (pg_temp.u(303), pg_temp.u(101), 'Plain', 100, true, 'piece', 'none', true),
  (pg_temp.u(304), pg_temp.u(101), 'Used', 100, true, 'piece', 'lot', true),
  (pg_temp.u(305), pg_temp.u(102), 'Other', 100, true, 'piece', 'none', true);
select pg_temp.mv(3, 910, format('[{"item_id": "%s", "quantity": "5", "from": "%s", "to": "%s", "new_lot": {"total_cost_minor": 500, "code": "L1"}}]',
  pg_temp.u(304), pg_temp.place('supplier'), pg_temp.loc('MAIN')), 'receipt');

select is(left(pg_temp.save(3, 303, 'lot'), 3) <> 'ERR', true, 'an item can be traced by batch');
select is(left(pg_temp.save(3, 303, 'expiry'), 3) <> 'ERR', true, 'or by batch with an expiry date');
select is(left(pg_temp.save(3, 303, 'serial'), 3) <> 'ERR', true, 'or by piece: the editor can now make a piece-tracked item');
select is((select tracking || ' ' || coalesce(tag_mode, '-') from public.services where id = pg_temp.u(303)), 'serial per_unit', 'and a piece-tracked item carries the per-piece tag mode');
select is(left(pg_temp.save(3, 303, 'none'), 3) <> 'ERR', true, 'and back to not traced while nothing moved');
select is(left(pg_temp.save(3, 304, 'serial'), 9), 'ERR DKG08', 'an item that has movements keeps how it is traced');
select is(left(pg_temp.save(3, 303, 'weird'), 9), 'ERR DKG11', 'a choice that is none of the four is refused');
select is(pg_temp.save(4, 305, 'serial', 102), 'ERR DKG11 {"field": "tracking", "reason": "tags_off"}', 'by piece needs the tags feature: the reason is told');

select * from finish();
rollback;
