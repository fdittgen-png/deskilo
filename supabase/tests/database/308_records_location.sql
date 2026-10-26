-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2378: where the records are kept. The operator declares the hosting
-- country in the platform setting records.hosting_country; a Canadian space
-- records its CRA authorisation in the workspace setting
-- records.cra_authorisation_reference. Their registry rows, what a member
-- resolves (nothing declared, then the platform's value), who may write
-- each (a billing manager the reference, the platform owner alone the
-- country), the refusal of a value that is not text, of a reference longer
-- than its bound and of a country that is not one of the choices. A
-- reference recorded on a non-Canadian space is kept and ignored, never
-- refused: the notice is the Canadian issuer's alone. Real roles, readbacks.
begin;
select plan(10);
create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.read_as(p_user uuid, p_key text) returns text
language plpgsql as $$
declare v text;
begin
  perform pg_temp.act_as(p_user);
  v := public.setting_value(current_setting('t.a')::uuid, p_key) #>> '{}';
  reset role;
  return v;
exception when others then
  reset role;
  return 'ERROR: ' || sqlerrm;
end;
$$;
create function pg_temp.set_as(p_user uuid, p_workspace uuid, p_key text, p_value jsonb) returns text
language plpgsql as $$
declare v text;
begin
  perform pg_temp.act_as(p_user);
  v := public.set_setting(p_workspace, p_key, p_value, 'pgTAP') ->> 'status';
  reset role;
  return v;
exception when others then
  reset role;
  return 'ERROR: ' || sqlerrm;
end;
$$;
create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00002378' || lpad(n::text, 4, '0'))::uuid;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@recordsLocation.test', '', now(), now(), now()
  from generate_series(1, 2) i;
-- 1 owner of the Canadian space, 2 a member without billing rights.

-- Seeds are direct inserts as postgres: no session is needed to create
-- the workspace, and only the reads and writes below run as `authenticated`.
select set_config('t.a', '00000000-0000-4000-8000-0000237a0001', true);
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, environment, feature_flags)
values (current_setting('t.a')::uuid, 'Records CA', 'CA', 'CAD', 'America/Toronto', pg_temp.u(1), 'dev',
        '{"configurableSettings": true}');
insert into public.members (workspace_id, user_id, is_owner, is_admin, status)
values (current_setting('t.a')::uuid, pg_temp.u(1), true, true, 'active'),
       (current_setting('t.a')::uuid, pg_temp.u(2), false, false, 'active');

select is(
  (select jsonb_build_array(type, default_value, scopes, editable, choices ? '', choices ? 'CA', choices ? 'Germany')
     from public.setting_definitions where key = 'records.hosting_country'),
  '["enum", "", ["platform"], true, true, true, false]'::jsonb,
  'R1 the hosting country is a platform choice over the known countries and empty: not declared');
select is(
  (select jsonb_build_array(type, default_value, scopes, edit_permission, max_value)
     from public.setting_definitions where key = 'records.cra_authorisation_reference'),
  '["text", "", ["workspace"], "manageBilling", 64]'::jsonb,
  'R2 the CRA reference is a workspace text of at most 64 characters a billing manager writes');

-- Nothing stored for either key yet, whatever the dev data holds.
delete from public.setting_values
 where key in ('records.hosting_country', 'records.cra_authorisation_reference');

select is(pg_temp.read_as(pg_temp.u(1), 'records.hosting_country'), '',
  'R3 with nothing declared a member resolves nothing');

insert into public.setting_values (scope, workspace_id, key, value, note)
values ('platform', null, 'records.hosting_country', '"DE"'::jsonb, 'the hosting contract');
select is(pg_temp.read_as(pg_temp.u(2), 'records.hosting_country'), 'DE',
  'R4 the operator''s declaration is what every member reads');

select is(pg_temp.set_as(pg_temp.u(1), current_setting('t.a')::uuid,
                         'records.cra_authorisation_reference', '"CRA-2026-0042"'::jsonb)
          || ' ' || pg_temp.read_as(pg_temp.u(2), 'records.cra_authorisation_reference'),
  'saved CRA-2026-0042',
  'R5 the owner records the CRA authorisation and a member reads it');

select ok(pg_temp.set_as(pg_temp.u(2), current_setting('t.a')::uuid,
                         'records.cra_authorisation_reference', '"forged"'::jsonb)
          like 'ERROR: %not allowed to change this setting%',
  'R6 a member without billing rights cannot change it');

select ok(pg_temp.set_as(pg_temp.u(1), current_setting('t.a')::uuid,
                         'records.cra_authorisation_reference', '42'::jsonb)
          like 'ERROR: %text is required%',
  'R7 a value that is not text is refused');

select ok(pg_temp.set_as(pg_temp.u(1), null, 'records.hosting_country', '"CA"'::jsonb)
          like 'ERROR: %platform owners only%',
  'R8 a space''s owner cannot declare the installation''s country');

select ok(pg_temp.set_as(pg_temp.u(1), current_setting('t.a')::uuid,
                         'records.cra_authorisation_reference', to_jsonb(repeat('X', 65)))
          like 'ERROR: %longer than 64 characters%',
  'R9 a reference of 65 characters is refused by its bound');

select is(
  (select public.setting_value_problem(type, '"Germany"'::jsonb, min_value, max_value, floor_value, choices)
     from public.setting_definitions where key = 'records.hosting_country'),
  'not one of the choices',
  'R10 a country that is not a code is not one of the choices');

select * from finish();
rollback;
