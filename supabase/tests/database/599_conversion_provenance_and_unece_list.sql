-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4479 (0990): a conversion a person wrote is told apart from one the units generate, and editing an unused custom unit no longer
-- deletes it: the generated rows of the unit are written again, the authored row stays, marked to be looked at, and saving it
-- again clears the mark. The UN/ECE code of a unit is one of the maintained list: a code outside it is refused when given or
-- changed, one the unit already holds stays until changed. Rolled back.
begin;
select plan(14);

create function pg_temp.u(n int) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-8000-00004479' || lpad(n::text, 4, '0'))::uuid;
$$;
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
create function pg_temp.save(req int, p_unit jsonb) returns text language sql as $$
  select pg_temp.as_user(1, format($q$select public.workspace_unit_save_v1(%L, %L, %L::jsonb)::text$q$, pg_temp.u(101), pg_temp.u(req), p_unit))
$$;
create function pg_temp.conv(req int, p_from text, p_to text, p_num int) returns text language sql as $$
  select pg_temp.as_user(1, format($q$select public.unit_conversion_save_v1(%L, %L, %L::jsonb)::text$q$, pg_temp.u(101), pg_temp.u(req),
    jsonb_build_object('from_unit', p_from, 'to_unit', p_to, 'factor_num', p_num, 'factor_den', 1)))
$$;
create function pg_temp.row_of(p_from text, p_to text) returns text language sql as $$
  select factor_num || '/' || factor_den || ' ' || authored || ' ' || needs_review
    from public.unit_conversions where workspace_id = pg_temp.u(101) and from_unit = p_from and to_unit = p_to
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values (pg_temp.u(1), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'prov-1@example.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags) values
  (pg_temp.u(101), 'Cable and rope', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"unitsOfMeasure": true}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', '2026-01-01');

-- a drum of 50 m: its conversions to the lengths are generated
select pg_temp.save(901, '{"code": "drum", "label": "Cable drum", "dimension": "length", "factor_num": 50, "factor_den": 1}');
select is(pg_temp.row_of('drum', 'm'), '50/1 false false', 'a unit''s conversions are generated, not authored');
select is((select count(*)::int from public.unit_conversions where workspace_id = pg_temp.u(101) and authored), 0, 'a business starts with none authored');

-- the owner writes drum to m as 48
select pg_temp.conv(902, 'drum', 'm', 48);
select is(pg_temp.row_of('drum', 'm'), '48/1 true false', 'a conversion a person writes is authored');

-- the drum becomes 40 m
select pg_temp.save(903, '{"code": "drum", "dimension": "length", "factor_num": 40, "factor_den": 1}');
select is(pg_temp.row_of('drum', 'm'), '48/1 true true', 'editing the factor keeps the authored row, marked to be looked at');
select is(pg_temp.row_of('drum', 'cm'), '4000/1 false false', 'and the generated rows of the unit are written again for the new factor');
select is((select count(*)::int from public.unit_conversions where workspace_id = pg_temp.u(101) and (from_unit = 'drum' or to_unit = 'drum')),
  (select count(*)::int from public.workspace_units where workspace_id = pg_temp.u(101) and dimension = 'length' and code <> 'drum'),
  'one row per length unit: the authored one holds its pair''s place');

-- writing it again is the review
select pg_temp.conv(904, 'drum', 'm', 40);
select is(pg_temp.row_of('drum', 'm'), '40/1 true false', 'saving the conversion again clears the mark');

-- the drum changes dimension
select pg_temp.save(905, '{"code": "drum", "dimension": "mass", "factor_num": 25, "factor_den": 1}');
select is(pg_temp.row_of('drum', 'm'), '40/1 true true', 'a change of dimension keeps the authored row too, and asks to look at it');
select is(pg_temp.row_of('drum', 'cm'), null, 'the generated rows of the old dimension are gone');

-- UN/ECE
select alike(pg_temp.save(906, '{"code": "bale", "label": "Bale", "dimension": "count", "factor_num": 1, "factor_den": 1, "un_ece_code": "QQQ"}'),
  'ERR DKG11%ece_invalid%', 'a code of the right shape that is not on the list is refused');
select is((pg_temp.save(907, '{"code": "bale", "label": "Bale", "dimension": "count", "factor_num": 1, "factor_den": 1, "un_ece_code": "BG"}')::jsonb) ->> 'un_ece_code',
  'BG', 'a code on the list is taken');
-- a code stored before the list stays until it is changed
update public.workspace_units set un_ece_code = 'QZQ' where workspace_id = pg_temp.u(101) and code = 'bale';
select is((pg_temp.save(908, '{"code": "bale", "label": "Bale of rope"}')::jsonb) ->> 'un_ece_code', 'QZQ',
  'a code stored before the list is kept when the unit is saved without changing it');
select alike(pg_temp.save(909, '{"code": "bale", "un_ece_code": "ZQZ"}'), 'ERR DKG11%ece_invalid%', 'and refused once it is changed to another that is not on the list');
select ok(not has_function_privilege('authenticated', 'public.unece_unit_known(text)', 'execute'), 'the list is the server''s: a client does not call it');

select * from finish();
rollback;
