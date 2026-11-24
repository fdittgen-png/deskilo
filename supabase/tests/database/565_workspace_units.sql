-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4442 (0951): a business keeps its own units of measure. Every business starts with the 13 built-ins; the owner and
-- the admins create and edit units (a member and a stranger cannot); a malformed unit is refused with DKG01 and its
-- field; a retried request answers once; a built-in unit keeps its dimension and factor; a unit that is used keeps them
-- and cannot be archived; nothing is deleted; and the conversion is exact through the base unit, refusing two
-- dimensions, an unknown unit and an answer six decimals cannot hold. Rolled back.
begin;
select plan(32);

create function pg_temp.u(n int) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-8000-00004442' || lpad(n::text, 4, '0'))::uuid;
$$;
-- the answer of a statement run as a signed-in user, or ERR, its code and its detail or message
create function pg_temp.as_user(n int, p_sql text) returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(n), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  begin
    execute p_sql into v;
  exception when others then
    get stacked diagnostics d = pg_exception_detail;
    v := 'ERR ' || sqlstate || coalesce(' ' || nullif(d, ''), '');
  end;
  execute 'reset role';
  return coalesce(v, 'null');
end $f$;
-- the same as the server's own role, for what no one else may do
create function pg_temp.try(p_sql text) returns text language plpgsql as $f$
begin
  execute p_sql;
  return 'done';
exception when others then
  return 'ERR ' || sqlstate;
end $f$;
create function pg_temp.save(n int, req int, p_unit jsonb, p_ws int default 101) returns text language sql as $$
  select pg_temp.as_user(n, format($q$select public.workspace_unit_save_v1(%L, %L, %L::jsonb)::text$q$, pg_temp.u(p_ws), pg_temp.u(req), p_unit))
$$;
create function pg_temp.conv(p_qty text, p_from text, p_to text) returns text language sql as $$
  select pg_temp.as_user(1, format($q$select public.workspace_unit_convert(%L, %L, %L, %L)$q$, pg_temp.u(101), p_qty, p_from, p_to))
$$;

grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'units' || n || '@example.test', '', now(), now(), now() from generate_series(1, 3) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags) values
  (pg_temp.u(101), 'Cable and rope', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"unitsOfMeasure": true}'),
  (pg_temp.u(102), 'Rope, units off', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', '2026-01-01'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active', '2026-01-01'),
  (pg_temp.u(211), pg_temp.u(102), pg_temp.u(1), true, true, 'active', '2026-01-01');

-- ── every business starts with the built-ins ──
select is((select count(*)::int from public.workspace_units where workspace_id = pg_temp.u(101) and built_in), 13,
  'a business created now has the 13 built-in units');
select is((select string_agg(code, ',' order by sort_order) from public.workspace_units where workspace_id = pg_temp.u(101)),
  'piece,g,kg,ml,cl,l,mm,cm,m,km,m2,min,h', 'in their order');
select is((select count(*)::int from public.workspaces w where (select count(*) from public.workspace_units u where u.workspace_id = w.id and u.built_in) <> 13),
  0, 'and so does every business that existed');
select is((select factor_num::text || '/' || factor_den::text || ' ' || un_ece_code from public.workspace_units where workspace_id = pg_temp.u(101) and code = 'km'),
  '1000/1 KMT', 'a km is 1000 m, with its UN/ECE code');
select is((select factor_num::text || '/' || factor_den::text from public.workspace_units where workspace_id = pg_temp.u(101) and code = 'mm'),
  '1/1000', 'a mm is a thousandth of a m');
select is((select count(*)::int from public.workspace_units where workspace_id = pg_temp.u(101) and label is not null), 0,
  'a built-in has no label: the app names it in the member''s language');

-- ── who maintains them ──
select is(pg_temp.as_user(2, format($q$select count(*)::text from public.workspace_units where workspace_id = %L$q$, pg_temp.u(101))), '13',
  'a member of the business reads its units');
select is(pg_temp.as_user(3, format($q$select count(*)::text from public.workspace_units where workspace_id = %L$q$, pg_temp.u(101))), '0',
  'a stranger reads none');
select is(pg_temp.save(1, 901, '{"code": "drum", "label": "Cable drum", "dimension": "length", "factor_num": 50, "factor_den": 1, "un_ece_code": "C62"}')::jsonb,
  '{"code": "drum", "label": "Cable drum", "dimension": "length", "factor_num": 50, "factor_den": 1, "archived": false, "built_in": false, "sort_order": 1000, "un_ece_code": "C62"}'::jsonb,
  'the owner creates a custom unit: 1 drum = 50 m');
select is(pg_temp.save(2, 902, '{"code": "reel", "label": "Reel", "dimension": "length", "factor_num": 10, "factor_den": 1}'), 'ERR DKN01',
  'a member without the right cannot');
select is(pg_temp.save(3, 903, '{"code": "reel", "label": "Reel", "dimension": "length", "factor_num": 10, "factor_den": 1}'), 'ERR DKN01',
  'nor a stranger');

-- ── while the feature is off, nothing is maintained, and the built-ins are there ──
select is(pg_temp.save(1, 915, '{"code": "reel", "label": "Reel", "dimension": "length", "factor_num": 10}', 102), 'ERR DKN01',
  'the commands are refused while the unitsOfMeasure feature is off');
select is((select count(*)::int from public.workspace_units where workspace_id = pg_temp.u(102)), 13, 'but the business has its built-in units');

-- ── a malformed unit, by field ──
select is(pg_temp.save(1, 904, '{"code": "Bad Code", "label": "x", "dimension": "length", "factor_num": 1}'), 'ERR DKG11 {"field": "code", "reason": "code_malformed"}', 'a code is lower case letters, digits and underscores');
select is(pg_temp.save(1, 905, '{"code": "bad", "label": "x", "dimension": "weight", "factor_num": 1}'), 'ERR DKG11 {"field": "dimension", "reason": "dimension_invalid"}', 'a dimension is one of the six');
select is(pg_temp.save(1, 906, '{"code": "bad", "label": "x", "dimension": "length", "factor_num": 0}'), 'ERR DKG11 {"field": "factor", "reason": "factor_invalid"}', 'a factor is positive');
select is(pg_temp.save(1, 907, '{"code": "bad", "dimension": "length", "factor_num": 1}'), 'ERR DKG11 {"field": "label", "reason": "label_required"}', 'a new unit has a label');
select is(pg_temp.save(1, 908, '{"code": "bad", "label": "x", "dimension": "length", "factor_num": 1, "un_ece_code": "toolong"}'), 'ERR DKG11 {"field": "un_ece_code", "reason": "ece_invalid"}', 'a UN/ECE code is two or three capitals');

-- ── one request answers once ──
select is(pg_temp.save(1, 901, '{"code": "drum", "label": "Cable drum", "dimension": "length", "factor_num": 50, "factor_den": 1, "un_ece_code": "C62"}')::jsonb ->> 'replayed', 'true',
  'a retried request answers the stored answer');
select is(left(pg_temp.save(1, 901, '{"code": "drum", "label": "Another"}'), 9), 'ERR DKG07', 'another content under the same request id is refused');

-- ── a factor is edited while the unit is unused, and frozen when it is used ──
select is((pg_temp.save(1, 909, '{"code": "drum", "factor_num": 100, "factor_den": 2}')::jsonb ->> 'factor_num') || '/' || (pg_temp.save(1, 909, '{"code": "drum", "factor_num": 100, "factor_den": 2}')::jsonb ->> 'factor_den'),
  '50/1', 'an unused unit''s factor changes, and the fraction is reduced (100/2 is 50)');
insert into public.standalone_invoice_drafts (workspace_id, subject_member_id, lines)
values (pg_temp.u(101), pg_temp.u(202), '[{"unit": {"code": "drum", "label": "drum", "un_ece_code": "C62"}}]');
select is(public.workspace_unit_uses(pg_temp.u(101), 'drum'), 1::bigint, 'a draft line that names the unit uses it');
select is(pg_temp.save(1, 910, '{"code": "drum", "factor_num": 60}'), 'ERR DKG11 {"field": "factor", "reason": "unit_in_use"}', 'a used unit keeps its factor');
select is(pg_temp.save(1, 911, '{"code": "drum", "label": "Drum of cable"}')::jsonb ->> 'label', 'Drum of cable', 'but may be renamed');
select is(pg_temp.as_user(1, format($q$select public.workspace_unit_archive_v1(%L, %L, 'drum', true)::text$q$, pg_temp.u(101), pg_temp.u(912))), 'ERR DKG11 {"field": "archived", "reason": "unit_in_use"}',
  'and cannot be archived while it is used');

-- ── built-ins and deletion ──
select is(pg_temp.save(1, 913, '{"code": "km", "factor_num": 999}'), 'ERR DKG11 {"field": "factor", "reason": "registry_unit"}', 'a built-in unit keeps its factor');
select is(pg_temp.save(1, 914, '{"code": "km", "label": "Kilometre"}')::jsonb ->> 'label', 'Kilometre', 'but takes the business''s own word');
select is(pg_temp.try(format($q$delete from public.workspace_units where workspace_id = %L and code = 'reel'$q$, pg_temp.u(101))), 'done',
  'a delete that matches nothing is nothing');
select is(pg_temp.try(format($q$delete from public.workspace_units where workspace_id = %L and code = 'drum'$q$, pg_temp.u(101))), 'ERR DKG11', 'a unit is never deleted');

-- ── converting ──
select is(pg_temp.conv('2.5', 'km', 'm'), '2500', '2.5 km = 2500 m');
select is(pg_temp.conv('1', 'm', 'km') || ' ' || pg_temp.conv('250', 'mm', 'm') || ' ' || pg_temp.conv('1.5', 'h', 'min') || ' ' || pg_temp.conv('2', 'drum', 'km'),
  '0.001 0.25 90 0.1', 'm to km, mm to m, h to min and a custom unit all go through the base unit, exactly');
select is(pg_temp.conv('1', 'kg', 'm') || ' ' || pg_temp.conv('1', 'ghost', 'm') || ' ' || pg_temp.conv('1', 'cm', 'km'),
  'ERR DKG11 {"field": "unit", "reason": "dimension_mismatch"} ERR DKG11 {"field": "unit", "reason": "unit_unknown"} 0.00001', 'two dimensions and an unknown unit are refused; a small answer that six decimals hold is exact');

select * from finish();
rollback;
