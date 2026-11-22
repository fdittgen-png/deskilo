-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4361 (0881-0883): who may and what is read. Whoever manages the stock edits groups; VAT, price rounding and
-- margin also need the finances; whoever sees the stock reads the groups and an item's effective settings; an
-- assistant reads group names and is refused every write; another business sees nothing and reaches nothing; a
-- group in use is not deleted, and one nothing uses is; an edit of the item itself keeps what it changes against
-- a later change of its group; a per-unit tag mode on an item not tracked by piece, a proposal as an override and
-- an unknown unit are refused in words; the feature off refuses. Rolled back.
begin;
select plan(45);

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

select pg_temp.sv(1, 910, 501, 0, format('{"name": "Dairy", "parameters": {"tracking": "none", "shelf_life_days": 7, "vat_rate_id": "%s"}}', pg_temp.u(401)));
select pg_temp.asg(1, 920, 301, pg_temp.rev(301), 501);
select pg_temp.asg(1, 921, 302, pg_temp.rev(302), 501);

-- ── who may ──
select is(pg_temp.sv(2, 930, 502, 0, '{"name": "Bread"}'), 'ERR DKN01', 'a member who only sees the stock cannot create a group');
select is(pg_temp.f(pg_temp.sv(3, 931, 502, 0, '{"name": "Bread", "parameters": {"shelf_life_days": 3}}'), 'revision'), '1',
  'a clerk who manages the stock can');
select is(pg_temp.sv(3, 932, 501, 1, format('{"parameters": {"vat_rate_id": "%s"}}', pg_temp.u(402))), 'ERR DKN01',
  'but not set the VAT rate: that also needs the finances');
select is(pg_temp.sv(3, 933, 501, 1, '{"parameters": {"price_rounding": "0.05"}}'), 'ERR DKN01', 'nor the price rounding');
select is(pg_temp.f(pg_temp.sv(1, 934, 501, 1, format('{"parameters": {"vat_rate_id": "%s", "price_rounding": "0.05", "target_margin_bps": 3500}}', pg_temp.u(402))), 'revision'),
  '2', 'the owner can');
select is(pg_temp.sv(1, 935, 501, 2, format('{"parameters": {"vat_rate_id": "%s"}}', pg_temp.u(403))), 'ERR DKG11', 'a VAT rate of another business is refused');
select is(pg_temp.sv(1, 936, 501, 2, '{"parameters": {"inventory_unit": "furlong"}}'), 'ERR DKG11', 'an unknown unit is refused');
select is(pg_temp.sv(1, 937, 501, 2, '{"parameters": {"shelf_life_days": 0}}'), 'ERR DKG11', 'a shelf life out of range is refused');

-- ── assistants and other businesses ──
select is(pg_temp.sv(1, 940, 504, 0, '{"name": "X"}', true, 101, true), 'ERR DKN01', 'an assistant session cannot write a group');
select is(pg_temp.asg(1, 941, 301, pg_temp.rev(301), null, true, 102), 'ERR DKN01', 'nor reach another business''s item');
select is(pg_temp.run_as(pg_temp.u(1), format('select jsonb_array_length(public.item_groups_v1(%L))::text', pg_temp.u(101)), true), '2',
  'an assistant reads the groups');
select is(pg_temp.run_as(pg_temp.u(1), format('select (public.item_groups_v1(%L) -> 0 ? ''tracking'')::text', pg_temp.u(101)), true), 'false',
  'by name only');
select is(pg_temp.run_as(pg_temp.u(1), format('select (public.item_groups_v1(%L) -> 0 ? ''tracking'')::text', pg_temp.u(101))), 'true',
  'a person sees the parameters');
select is(pg_temp.run_as(pg_temp.u(4), format('select jsonb_array_length(public.item_groups_v1(%L))::text', pg_temp.u(102))), '0',
  'another business has no groups');
select is(pg_temp.run_as(pg_temp.u(4), format('select jsonb_array_length(public.item_groups_v1(%L))::text', pg_temp.u(101))), 'ERR DKN01',
  'and cannot read this one');
select is((select count(*)::int from public.item_groups where workspace_id = pg_temp.u(101)), 2, 'fixture: two groups in the business');
select is(pg_temp.run_as(pg_temp.u(2), format('select (public.item_effective_settings_v1(%L, %L) #>> ''{parameters,tracking,value}'')', pg_temp.u(101), pg_temp.u(301))),
  'none', 'whoever sees the stock reads an item''s effective settings');
select is(pg_temp.run_as(pg_temp.u(2), format('select (public.item_effective_settings_v1(%L, %L))::text', pg_temp.u(101), pg_temp.u(306))), 'ERR DKG04',
  'but not another business''s item');

-- ── moving what an item sells for needs the finances, whichever way it is written ──
select is(pg_temp.asg(3, 990, 303, pg_temp.rev(303), 501), 'ERR DKN01', 'a clerk cannot move an item under a group whose VAT it would take');
select is(pg_temp.f(pg_temp.sv(3, 991, 503, 0, format('{"name": "Soft", "parent_id": "%s"}', pg_temp.u(502))), 'created'), 'true', 'she can make a sub-group under a group with no finance values');
select is(pg_temp.f(pg_temp.asg(3, 992, 303, pg_temp.rev(303), 503), 'item_id') is not null, true, 'and move an item into it');
select is(pg_temp.sv(3, 993, 503, 1, format('{"parent_id": "%s"}', pg_temp.u(501))), 'ERR DKN01',
  'but not move a group in use under one whose VAT its items would inherit');

-- ── an item's own edit stays ──
select is(pg_temp.run_as(pg_temp.u(1), format('select (public.save_stock_item_v1(%L, %L, %s, %L, %L::jsonb) ->> ''replayed'')',
  pg_temp.u(101), pg_temp.u(301), pg_temp.rev(301), pg_temp.u(950), '{"shelf_life_days": 30}')), 'false', 'the item''s own edit saves');
select is((select group_overrides from public.services where id = pg_temp.u(301)), array['shelf_life_days']::text[], 'and is marked as the item''s own');
select pg_temp.sv(1, 951, 501, 2, '{"parameters": {"shelf_life_days": 9}}');
select is((select shelf_life_days from public.services where id = pg_temp.u(301)) || '|' || (select shelf_life_days from public.services where id = pg_temp.u(302)),
  '30|9', 'a later change of the group leaves it');

-- ── an item's own value, written by the service editor, survives a change of the group ──
insert into public.vat_rates (id, workspace_id, label, percent) values (pg_temp.u(404), pg_temp.u(101), 'Intermediate', 10);
update public.services set vat_rate_id = pg_temp.u(401) where id = pg_temp.u(302);
select is((select group_overrides from public.services where id = pg_temp.u(302)), array['vat_rate_id']::text[], 'an item''s own VAT, written directly, is marked as its own');
select pg_temp.sv(1, 994, 501, 3, format('{"parameters": {"vat_rate_id": "%s"}}', pg_temp.u(404)));
select is((select (vat_rate_id = pg_temp.u(404))::text || '|' || (select (vat_rate_id = pg_temp.u(401))::text from public.services where id = pg_temp.u(302)) from public.services where id = pg_temp.u(301)),
  'true|true', 'a change of the group''s VAT reaches the inheriting item and leaves the one with its own');

-- ── the finance values an item is proposed a price with ──
select pg_temp.sv(1, 995, 506, 0, '{"name": "Margin", "parameters": {"target_margin_bps": 4000}}');
select is(pg_temp.asg(3, 996, 304, pg_temp.rev(304), 506), 'ERR DKN01', 'a clerk cannot move an item to where a margin would be proposed for it');
select is(pg_temp.ovr(1, 997, 301, pg_temp.rev(301), 'shelf_life_days', null, '5'), 'ERR DKG11', 'a request with no mode is refused');
select is(pg_temp.run_as(pg_temp.u(3), format('select (public.item_groups_v1(%L) -> 0 ? ''price_rounding'')::text', pg_temp.u(101))), 'false',
  'the rounding is not read without the finances');
select is(pg_temp.run_as(pg_temp.u(1), format('select (public.item_groups_v1(%L) -> 0 ? ''price_rounding'')::text', pg_temp.u(101))), 'true', 'and is with them');
select is(pg_temp.run_as(pg_temp.u(3), format('select public.item_effective_settings_v1(%L, %L) #>> ''{parameters,target_margin_bps,source}''', pg_temp.u(101), pg_temp.u(301))), 'hidden',
  'nor an item''s margin');
select is(pg_temp.run_as(pg_temp.u(1), 'select count(*)::text from (select target_margin_bps from public.item_groups limit 1) x'), 'ERR 42501',
  'the columns are closed to a direct read');

-- ── the history keeps the finance values to those who read the finances ──
select is(pg_temp.run_as(pg_temp.u(3), format('select (public.item_group_history_v1(%L, %L) -> 0 ->> ''parameter'') || ''|'' || coalesce((select string_agg(e ->> ''new'', '','') from jsonb_array_elements(public.item_group_history_v1(%L, %L)) e where e ->> ''parameter'' = ''vat_rate_id''), ''-'')',
  pg_temp.u(101), pg_temp.u(501), pg_temp.u(101), pg_temp.u(501))) like '%|%', true, 'a clerk reads the history');
select is(pg_temp.run_as(pg_temp.u(3), format('select count(*)::text from jsonb_array_elements(public.item_group_history_v1(%L, %L)) e where e ->> ''parameter'' in (''vat_rate_id'', ''price_rounding'', ''target_margin_bps'') and e -> ''new'' <> ''null''::jsonb', pg_temp.u(101), pg_temp.u(501))), '0',
  'but not the VAT, the rounding or the margin it changed');
select is(pg_temp.run_as(pg_temp.u(1), format('select (count(*) filter (where e -> ''new'' <> ''null''::jsonb))::text from jsonb_array_elements(public.item_group_history_v1(%L, %L)) e where e ->> ''parameter'' in (''vat_rate_id'', ''price_rounding'')', pg_temp.u(101), pg_temp.u(501))) <> '0', true,
  'whoever reads the finances reads them');
select is(pg_temp.run_as(pg_temp.u(1), 'select count(*)::text from public.item_group_history'), 'ERR 42501', 'and the table is closed to a direct read');

-- ── refusals in words ──
select is(pg_temp.ovr(1, 960, 301, pg_temp.rev(301), 'tag_mode', 'set', '"per_unit"'), 'ERR DKG11', 'a per-unit tag mode on an item not tracked by piece is refused');
select is(pg_temp.ovr(1, 961, 301, pg_temp.rev(301), 'price_rounding', 'set', '"0.05"'), 'ERR DKG11', 'a proposal is not an override');
select is(pg_temp.f(pg_temp.ovr(1, 962, 301, pg_temp.rev(301), 'till_category', 'set', '"Dairy"'), 'revision') is not null, true,
  'an own till category is kept');
select is(pg_temp.eff(301, 'till_category'), 'Dairy|item', 'and shown as its own');

-- ── deleting ──
select is(pg_temp.run_as(pg_temp.u(1), format('select public.item_group_delete_v1(%L, %L, %L, 4)::text', pg_temp.u(101), pg_temp.u(970), pg_temp.u(501))), 'ERR DKG11',
  'a group used by items is not deleted');
select pg_temp.sv(1, 972, 504, 0, '{"name": "Spare"}');
select is(pg_temp.run_as(pg_temp.u(1), format('select public.item_group_delete_v1(%L, %L, %L, 1)::jsonb ->> ''deleted''', pg_temp.u(101), pg_temp.u(971), pg_temp.u(504))), 'true',
  'one nothing uses is');

-- ── the feature off ──
update public.workspaces set feature_flags = feature_flags || '{"stockItemGroups": false}' where id = pg_temp.u(101);
select is(pg_temp.sv(1, 980, 509, 0, '{"name": "Late"}'), 'ERR DKG01', 'with the feature off nothing is written');
select is(pg_temp.run_as(pg_temp.u(2), format('select public.item_groups_v1(%L)::text', pg_temp.u(101))), '[]', 'and the groups read as none');

select * from finish();
rollback;
