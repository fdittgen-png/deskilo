-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4172 (0868-0870): stock counts, approved before they move the stock. Whoever manages the stock records a
-- count (nothing moves); whoever may approve adjustments applies it, as one adjustment of exactly the
-- difference, and only if no movement has touched the scope since (a stale count is refused even when the
-- same person approves, and a fresh one is reviewed); reject and cancel move nothing; a decision is final and
-- the same decision sent again answers the same result; a count has a stable identity apart from the request;
-- the generic move cannot make an adjustment without the right to approve; the rights, the business, an
-- assistant and the feature off are refused; a variant and a lot are part of the scope. Rolled back.
begin;
select plan(39);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_user uuid, p_sql text, p_delegated boolean default false)
returns text language plpgsql as $f$
declare v text; d text;
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
create or replace function pg_temp.mv(p_user int, p_req int, p_item int, p_qty text, p_from uuid, p_to uuid, p_reason text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_move_v1(%L, %L, %L::jsonb, %L)::text', pg_temp.u(101), pg_temp.u(p_req),
    format('[{"item_id": "%s", "quantity": "%s", "from": "%s", "to": "%s"}]', pg_temp.u(p_item), p_qty, p_from, p_to), p_reason))
$f$;
create or replace function pg_temp.scope(p_item int, p_loc uuid, p_lot text default null, p_var text default null) returns text language sql as $f$
  select jsonb_strip_nulls(jsonb_build_object('item_id', pg_temp.u(p_item), 'location_id', p_loc, 'lot_id', p_lot, 'variant_id', p_var))::text
$f$;
-- record: user, request, count, scope, observed
create or replace function pg_temp.rec(p_user int, p_req int, p_count int, p_scope text, p_obs text, p_ws int default 101, p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_count_record_v1(%L, %L, %L, %L::jsonb, %L, %L)::text', pg_temp.u(p_ws), pg_temp.u(p_req),
    pg_temp.u(p_count), p_scope, p_obs, 'shelf count'), p_delegated)
$f$;
create or replace function pg_temp.dec(p_user int, p_req int, p_count int, p_decision text, p_ws int default 101, p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_count_decide_v1(%L, %L, %L, %L, %L)::text', pg_temp.u(p_ws), pg_temp.u(p_req),
    pg_temp.u(p_count), p_decision, 'ok'), p_delegated)
$f$;
create or replace function pg_temp.f(p text, k text) returns text language sql immutable as $f$
  select case when p like '{%' then p::jsonb ->> k else p end
$f$;
create or replace function pg_temp.onhand(p_item int, p_loc uuid) returns numeric language sql stable as $f$
  select coalesce(sum(quantity), 0) from public.stock_balances where item_id = pg_temp.u(p_item) and location_id = p_loc
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cnt-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 5) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Counts A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
   '{"services": true, "stockManagement": true, "stockLots": true, "stockCounts": true}',
   '{"member": ["viewStock"], "admin": ["manageStock"]}'),
  (pg_temp.u(102), 'Counts B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(4),
   '{"services": true, "stockManagement": true, "stockCounts": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active'),
  (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, true, 'active'),
  (pg_temp.u(204), pg_temp.u(102), pg_temp.u(4), true, true, 'active');
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Mugs', 300, true, 'piece', 'none', true),
  (pg_temp.u(302), pg_temp.u(101), 'Beans', 900, true, 'kg', 'lot', true),
  (pg_temp.u(303), pg_temp.u(101), 'Shirts', 900, true, 'piece', 'none', true),
  (pg_temp.u(304), pg_temp.u(102), 'Foreign', 100, true, 'piece', 'none', true);
insert into public.item_variants (id, workspace_id, item_id, canonical) values
  (pg_temp.u(311), pg_temp.u(101), pg_temp.u(303), 'colour:red'), (pg_temp.u(312), pg_temp.u(101), pg_temp.u(303), 'colour:blue');

select pg_temp.mv(1, 900, 301, '10', pg_temp.place('supplier'), pg_temp.loc('MAIN'), 'receipt');
select is(pg_temp.onhand(301, pg_temp.loc('MAIN')), 10::numeric, 'fixture: 10 mugs on hand');
select is(pg_temp.mv(3, 901, 301, '1', pg_temp.place('loss'), pg_temp.loc('MAIN'), 'adjustment'), 'ERR DKN01',
  'a clerk who manages the stock cannot make an adjustment through the generic move');
select is(pg_temp.mv(3, 904, 301, '1', pg_temp.place('opening'), pg_temp.loc('MAIN'), 'opening'), 'ERR DKN01',
  'nor can she make stock from an opening count through it');
select is(pg_temp.mv(1, 902, 301, '1', pg_temp.loc('MAIN'), pg_temp.place('loss'), 'adjustment') like 'ERR%', false,
  'whoever may approve adjustments can');
select pg_temp.mv(1, 903, 301, '1', pg_temp.place('loss'), pg_temp.loc('MAIN'), 'adjustment');

-- ── recording moves nothing ──
select is(pg_temp.f(pg_temp.rec(3, 910, 701, pg_temp.scope(301, pg_temp.loc('MAIN')), '8'), 'difference'), '-2.000000', 'a clerk records a count of 8 where the ledger holds 10: the difference is -2');
select is(pg_temp.onhand(301, pg_temp.loc('MAIN')), 10::numeric, 'recording moves nothing');
select is(pg_temp.rec(3, 911, 701, pg_temp.scope(301, pg_temp.loc('MAIN')), '8'), pg_temp.rec(3, 910, 701, pg_temp.scope(301, pg_temp.loc('MAIN')), '8'),
  'the same count under a new request id answers the recorded result');
select is((select count(*)::int from public.stock_counts where count_id = pg_temp.u(701)), 1, 'one count');
select is(pg_temp.rec(3, 912, 701, pg_temp.scope(301, pg_temp.loc('MAIN')), '9'), 'ERR DKG16', 'other content under the same count id is refused');

-- ── deciding ──
select is(pg_temp.dec(3, 920, 701, 'apply'), 'ERR DKN01', 'a clerk without the right to approve adjustments cannot apply');
select is(pg_temp.f(pg_temp.dec(1, 921, 701, 'apply'), 'state'), 'applied', 'the owner applies it');
select is(pg_temp.onhand(301, pg_temp.loc('MAIN')), 8::numeric, 'exactly the difference moved: 10 - 2 = 8');
select is((select reason || '/' || quantity::text from public.stock_movements where id = (select applied_movement_id from public.stock_counts where count_id = pg_temp.u(701))), 'adjustment/2.000000',
  'as one adjustment movement');
select is(pg_temp.dec(1, 922, 701, 'apply'), pg_temp.dec(1, 921, 701, 'apply'), 'the same decision under a new request id answers the same result');
select is((select count(*)::int from public.stock_movements where reason = 'adjustment' and item_id = pg_temp.u(301) and quantity = 2), 1, 'and posts no second movement');
select is(pg_temp.dec(1, 923, 701, 'reject'), 'ERR DKG19', 'a decided count is final');
select is((select author_member_id = pg_temp.u(203) and decided_by_member_id = pg_temp.u(201) from public.stock_counts where count_id = pg_temp.u(701)), true,
  'the author and the approver are both kept');

-- ── a stale count, even for the same person ──
select pg_temp.rec(1, 930, 702, pg_temp.scope(301, pg_temp.loc('MAIN')), '5');
select pg_temp.mv(1, 932, 301, '1', pg_temp.place('supplier'), pg_temp.loc('MAIN'), 'receipt');
select is(pg_temp.dec(1, 933, 702, 'apply'), 'ERR DKG20', 'the stock moved after the count: the owner, who recorded it, cannot apply it either');
select is((select state from public.stock_counts where count_id = pg_temp.u(702)), 'recorded', 'and it stays recorded, nothing overwritten');
select is(pg_temp.onhand(301, pg_temp.loc('MAIN')), 9::numeric, 'the stock is what it was');
select is(pg_temp.run_as(pg_temp.u(1), format($q$select (public.stock_counts_v1(%L, 'recorded') -> 0 ->> 'stale')$q$, pg_temp.u(101))), 'true', 'the list says it is stale');
select is(pg_temp.f(pg_temp.rec(1, 934, 703, pg_temp.scope(301, pg_temp.loc('MAIN')), '5'), 'difference'), '-4.000000', 'a fresh count of 5 against 9 is reviewed');
select is(pg_temp.f(pg_temp.dec(1, 935, 703, 'apply'), 'state'), 'applied', 'and applies');
select is(pg_temp.onhand(301, pg_temp.loc('MAIN')), 5::numeric, 'exactly the difference of the fresh count moved: 9 - 4 = 5');

-- ── reject, cancel and a zero difference move nothing ──
select pg_temp.rec(3, 940, 704, pg_temp.scope(301, pg_temp.loc('MAIN')), '1');
select is(pg_temp.f(pg_temp.dec(1, 941, 704, 'reject'), 'state'), 'rejected', 'a count is rejected');
select pg_temp.rec(3, 942, 705, pg_temp.scope(301, pg_temp.loc('MAIN')), '1');
select is(pg_temp.dec(2, 943, 705, 'cancel'), 'ERR DKN01', 'a member without rights cannot cancel it');
select is(pg_temp.f(pg_temp.dec(3, 944, 705, 'cancel'), 'state'), 'cancelled', 'its author cancels it');
select is(pg_temp.onhand(301, pg_temp.loc('MAIN')), 5::numeric, 'rejecting and cancelling moved nothing');
select pg_temp.rec(1, 945, 706, pg_temp.scope(301, pg_temp.loc('MAIN')), '5');
select is((pg_temp.f(pg_temp.dec(1, 946, 706, 'apply'), 'movement_id')) is null, true, 'a count that matches the ledger applies with no movement');

-- ── the scope: a variant, a lot, a place ──
select is(pg_temp.rec(1, 950, 707, pg_temp.scope(303, pg_temp.loc('MAIN')), '3'), 'ERR DKG12', 'an item with variants is counted per variant');
select pg_temp.run_as(pg_temp.u(1), format($q$select public.stock_move_v1(%L, %L, %L::jsonb, 'receipt')::text$q$, pg_temp.u(101), pg_temp.u(951),
  format('[{"item_id": "%s", "variant_id": "%s", "quantity": "4", "from": "%s", "to": "%s"}]', pg_temp.u(303), pg_temp.u(311), pg_temp.place('supplier'), pg_temp.loc('MAIN'))));
select is(pg_temp.f(pg_temp.rec(1, 954, 713, pg_temp.scope(303, pg_temp.loc('MAIN'), null, pg_temp.u(311)::text), '3'), 'difference'), '-1.000000', 'the red shirts are counted against the 4 red ones');
select is(pg_temp.f(pg_temp.rec(1, 955, 714, pg_temp.scope(303, pg_temp.loc('MAIN'), null, pg_temp.u(312)::text), '0'), 'baseline'), '0.000000', 'the blue ones at the same place have their own baseline');
select is(pg_temp.rec(1, 952, 708, pg_temp.scope(302, pg_temp.loc('MAIN')), '3'), 'ERR DKG06', 'a lot-tracked item is counted per lot');
select is(pg_temp.rec(1, 953, 709, pg_temp.scope(301, pg_temp.place('loss')), '3'), 'ERR DKG05', 'a count is taken at a real place');

-- ── the rights, the business, the feature ──
select is(pg_temp.rec(2, 960, 710, pg_temp.scope(301, pg_temp.loc('MAIN')), '5'), 'ERR DKN01', 'a member who only views the stock cannot record');
select is(pg_temp.rec(1, 961, 711, pg_temp.scope(301, pg_temp.loc('MAIN')), '5', 101, true), 'ERR DKN01', 'an assistant''s session cannot');
select is(pg_temp.dec(4, 962, 701, 'apply', 102), 'ERR DKG04', 'another business''s count is not a count of this one');
select throws_ok(format($q$update public.stock_counts set observed_quantity = 99 where count_id = %L$q$, pg_temp.u(704)), 'DKG19', null, 'a decided count is not edited');
update public.workspaces set feature_flags = feature_flags || '{"stockCounts": false}' where id = pg_temp.u(101);
select is(pg_temp.rec(1, 970, 712, pg_temp.scope(301, pg_temp.loc('MAIN')), '5'), 'ERR DKG01', 'with the feature off no count is recorded');

select * from finish();
rollback;

