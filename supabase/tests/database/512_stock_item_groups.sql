-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4361 (0881-0883): item groups. An item's value is its own, else its sub-group's, else its group's, else the
-- business's; a group change reaches the inheriting items at once and never an item that keeps its own value;
-- an item the change cannot reach (stock movements fix its tracking) is skipped and listed while the group still
-- saves; the preview writes nothing and says how many items each parameter reaches; a sub-group cannot have
-- sub-groups; a per-unit tag mode needs tracking by piece; every change is in the history; a repeat of a
-- request answers once and other content under its id is refused; an old revision is refused. Rolled back.
begin;
select plan(35);

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
-- save a group: user, request, group, expected revision, body, apply
create or replace function pg_temp.sv(p_user int, p_req int, p_group int, p_exp int, p_body text, p_apply boolean default true, p_ws int default 101, p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.item_group_save_v1(%L, %L, %L, %s, %L::jsonb, %L)::text',
    pg_temp.u(p_ws), pg_temp.u(p_req), pg_temp.u(p_group), p_exp, p_body, p_apply), p_delegated)
$f$;
create or replace function pg_temp.asg(p_user int, p_req int, p_item int, p_exp int, p_group int, p_apply boolean default true, p_ws int default 101) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.item_group_assign_v1(%L, %L, %L, %s, %L, %L)::text',
    pg_temp.u(p_ws), pg_temp.u(p_req), pg_temp.u(p_item), p_exp, case when p_group is null then null else pg_temp.u(p_group)::text end, p_apply))
$f$;
create or replace function pg_temp.ovr(p_user int, p_req int, p_item int, p_exp int, p_param text, p_mode text, p_value text default null, p_ws int default 101) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.item_override_save_v1(%L, %L, %L, %s, %L, %L, %L::jsonb)::text',
    pg_temp.u(p_ws), pg_temp.u(p_req), pg_temp.u(p_item), p_exp, p_param, p_mode, p_value))
$f$;
create or replace function pg_temp.f(p text, k text) returns text language sql immutable as $f$
  select case when p like '{%' then p::jsonb ->> k else p end
$f$;
create or replace function pg_temp.rev(p_item int) returns int language sql stable as $f$
  select stock_revision from public.services where id = pg_temp.u(p_item)
$f$;
-- an effective parameter of an item: value|source
create or replace function pg_temp.eff(p_item int, p_param text) returns text language sql stable as $f$
  select (e -> 'parameters' -> p_param ->> 'value') || '|' || (e -> 'parameters' -> p_param ->> 'source')
    from (select public.item_effective_core(pg_temp.u(p_item)) e) x
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'grp-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 5) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Groups A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
   '{"services": true, "stockManagement": true, "stockItemGroups": true}',
   '{"member": ["viewStock"], "admin": ["manageStock"]}'),
  (pg_temp.u(102), 'Groups B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(4),
   '{"services": true, "stockManagement": true, "stockItemGroups": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active'),
  (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, true, 'active'),
  (pg_temp.u(204), pg_temp.u(102), pg_temp.u(4), true, true, 'active');
insert into public.vat_rates (id, workspace_id, label, percent, is_default) values
  (pg_temp.u(401), pg_temp.u(101), 'Standard', 20, true), (pg_temp.u(402), pg_temp.u(101), 'Reduced', 5.5, false),
  (pg_temp.u(403), pg_temp.u(102), 'Foreign', 20, true);
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Milk', 150, true, 'piece', 'none', true),
  (pg_temp.u(302), pg_temp.u(101), 'Yogurt', 120, true, 'piece', 'none', true),
  (pg_temp.u(303), pg_temp.u(101), 'Cheddar', 900, true, 'piece', 'none', true),
  (pg_temp.u(304), pg_temp.u(101), 'Gouda', 950, true, 'piece', 'none', true),
  (pg_temp.u(305), pg_temp.u(101), 'Cream', 200, true, 'piece', 'none', true),
  (pg_temp.u(306), pg_temp.u(102), 'Foreign', 100, true, 'piece', 'none', true);

select pg_temp.run_as(pg_temp.u(1), format('select public.stock_move_v1(%L, %L, %L::jsonb, %L)::text', pg_temp.u(101), pg_temp.u(900),
  format('[{"item_id": "%s", "quantity": "5", "from": "%s", "to": "%s"}]', pg_temp.u(305),
    (select id from public.stock_locations where workspace_id = pg_temp.u(101) and kind = 'supplier' limit 1),
    (select id from public.stock_locations where workspace_id = pg_temp.u(101) and code = 'MAIN')), 'receipt'));

-- ── groups and sub-groups ──
select is(pg_temp.f(pg_temp.sv(1, 910, 501, 0,
  format('{"name": "Dairy", "parameters": {"tracking": "expiry", "shelf_life_days": 7, "vat_rate_id": "%s", "count_every_days": 14}}', pg_temp.u(401))), 'revision'),
  '1', 'a group is created with its parameters');
select is(pg_temp.f(pg_temp.sv(1, 911, 502, 0,
  format('{"name": "Cheese", "parent_id": "%s", "parameters": {"sold_by_weight": true, "weight_basis": "kg"}}', pg_temp.u(501))), 'created'),
  'true', 'a sub-group is created under it');
select is(pg_temp.sv(1, 912, 503, 0, format('{"name": "Hard", "parent_id": "%s"}', pg_temp.u(502))), 'ERR DKG11',
  'a sub-group cannot have sub-groups');
select is(pg_temp.sv(1, 913, 504, 0, '{"name": "Dairy"}'), 'ERR DKG11', 'two groups of one level do not share a name');
select is(pg_temp.sv(1, 914, 501, 5, '{"name": "Dairy"}'), 'ERR DKG10', 'an old revision is refused');
select is(pg_temp.sv(1, 915, 501, 1, '{"parameters": {"colour": "red"}}'), 'ERR DKG11', 'an unknown parameter is refused');
select is(pg_temp.sv(1, 916, 501, 1, '{"parameters": {"tag_mode": "per_unit"}}'), 'ERR DKG11', 'a per-unit tag mode needs tracking by piece');
select is(pg_temp.f(pg_temp.sv(1, 917, 505, 0, '{"name": "Gift baskets", "parameters": {"tracking": "serial", "tag_mode": "per_unit"}}'), 'revision'),
  '1', 'and is accepted where the group tracks by piece');

-- ── an item moves in: the preview writes nothing, the move applies ──
select is(pg_temp.f(pg_temp.asg(1, 920, 301, pg_temp.rev(301), 501, false), 'applied'), 'false', 'the preview of a move says it is a preview');
select is((select tracking || '|' || coalesce(shelf_life_days::text, '-') from public.services where id = pg_temp.u(301)), 'none|-',
  'and wrote nothing');
select is(pg_temp.f(pg_temp.asg(1, 921, 301, pg_temp.rev(301), 501), 'affected'), '4', 'the move reaches tracking, shelf life, VAT and the count cadence');
select is((select tracking || '|' || shelf_life_days::text || '|' || (vat_rate_id = pg_temp.u(401))::text from public.services where id = pg_temp.u(301)),
  'expiry|7|true', 'the item now holds its group''s values');
select pg_temp.asg(1, 922, 302, pg_temp.rev(302), 501);
select pg_temp.asg(1, 923, 303, pg_temp.rev(303), 502);
select pg_temp.asg(1, 924, 304, pg_temp.rev(304), 502);
select is(pg_temp.f(pg_temp.asg(1, 925, 305, pg_temp.rev(305), 501), 'skipped')::jsonb -> 0 ->> 'reason', 'has_movements',
  'an item with stock movements keeps its tracking and is listed');
select is((select tracking || '|' || shelf_life_days::text from public.services where id = pg_temp.u(305)), 'none|7',
  'while the rest of its group still applies');

-- ── the order of inheritance ──
select is(pg_temp.eff(301, 'tracking'), 'expiry|group', 'a group value is the group''s');
select is(pg_temp.eff(304, 'count_every_days'), '14|group', 'a sub-group item inherits what only the group says');
select is(pg_temp.eff(304, 'sold_by_weight'), 'true|subgroup', 'and what its sub-group says');
select is(pg_temp.eff(301, 'tag_mode'), 'none|business', 'what no group says is the business''s default');
select is(pg_temp.eff(305, 'tracking'), 'none|item', 'an item the group could not reach shows its own');

-- ── an override, the preview, the change ──
select is(pg_temp.f(pg_temp.ovr(1, 930, 304, pg_temp.rev(304), 'shelf_life_days', 'set', '21'), 'revision') is not null, true,
  'an item keeps its own shelf life');
select is(pg_temp.eff(304, 'shelf_life_days'), '21|item', 'and says so');
select is(pg_temp.f(pg_temp.sv(1, 931, 501, 1, '{"parameters": {"shelf_life_days": 10}}', false), 'parameters')::jsonb -> 'shelf_life_days',
  '{"skipped": 0, "kept_own": 1, "affected": 4}'::jsonb, 'the preview says it reaches 4 items and 1 keeps its own');
select is((select shelf_life_days from public.services where id = pg_temp.u(301)), 7, 'and wrote nothing');
select is(pg_temp.f(pg_temp.sv(1, 932, 501, 1, '{"parameters": {"shelf_life_days": 10}}'), 'revision'), '2', 'the change saves');
select is((select string_agg(shelf_life_days::text, ',' order by name) from public.services where workspace_id = pg_temp.u(101) and group_id is not null),
  '10,10,21,10,10', 'it reached the inheriting items and not the one with its own value');
select is(pg_temp.f(pg_temp.sv(1, 932, 501, 1, '{"parameters": {"shelf_life_days": 10}}'), 'revision'), '2',
  'the same request again answers the same result');
select is(pg_temp.sv(1, 932, 501, 1, '{"parameters": {"shelf_life_days": 11}}'), 'ERR P0001', 'other content under its request id is refused');
select is((select count(*)::int from public.item_group_history where group_id = pg_temp.u(501) and parameter = 'shelf_life_days'), 2,
  'and wrote its history once');
select is(pg_temp.f(pg_temp.ovr(1, 933, 304, pg_temp.rev(304), 'shelf_life_days', 'inherit'), 'revision') is not null, true,
  'an item gives its own value back to its group');
select is(pg_temp.eff(304, 'shelf_life_days'), '10|group', 'and shows the group''s again');

-- ── a sub-group's value is nearer than its group's ──
select is(pg_temp.f(pg_temp.sv(1, 934, 502, 1, '{"parameters": {"shelf_life_days": 30}}'), 'revision'), '2', 'a sub-group says its own shelf life');
select is(pg_temp.eff(303, 'shelf_life_days') || ' ' || pg_temp.eff(301, 'shelf_life_days'), '30|subgroup 10|group', 'its items take it, the others do not');
select is((pg_temp.f(pg_temp.sv(1, 935, 501, 2, '{"parameters": {"shelf_life_days": 14}}', false), 'parameters')::jsonb -> 'shelf_life_days' ->> 'affected'), '3',
  'a change of the group does not reach what the sub-group speaks for');
select is(pg_temp.f(pg_temp.sv(1, 936, 501, 2, '{"parameters": {"vat_rate_id": null}}'), 'revision'), '3',
  'clearing a parameter at a level is a change too');
select is((select vat_rate_id = pg_temp.u(401) from public.services where id = pg_temp.u(301)), true,
  'it leaves the items as they are written');

select * from finish();
rollback;
