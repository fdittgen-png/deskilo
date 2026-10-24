-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2561 L3: an installation names the personal home of its people
-- explicitly. Unset by default (today's behaviour); `self` only on a
-- personal home; `endpoint` only on a workspace host that is not one, with
-- an HTTPS origin and a publishable key; anything else is refused and
-- changes nothing; every change is audited; anonymous clients read the
-- declaration through column grants. Then the platform-settings reader at a
-- workspace-free personal home: `my_settings(null)` and
-- `setting_value(null, key)` answer platform values over the registry
-- defaults for a person who belongs to no workspace, with no workspace row
-- written. Seeds and operator calls run as postgres first; callers are
-- impersonated last (set local role), and `reset role` returns to postgres.
begin;
select plan(41);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000002561c1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'platform-2561l3@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000002561c2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'person-2561l3@deskilo.test', '', now(), now(), now());
delete from public.platform_admins;
insert into public.platform_admins (user_id) values ('00000000-0000-4000-8000-0000002561c1');

-- ── the declaration: unset, public, guarded by the table ───────────
select is((select personal_home_kind from public.installation_identity), 'unset',
  'an installation declares no personal home by default');
select ok((select personal_home_url is null and personal_home_key is null from public.installation_identity),
  'and carries no endpoint');
select ok(has_column_privilege('anon', 'public.installation_identity', 'personal_home_kind', 'SELECT')
      and has_column_privilege('anon', 'public.installation_identity', 'personal_home_url', 'SELECT')
      and has_column_privilege('anon', 'public.installation_identity', 'personal_home_key', 'SELECT'),
  'anonymous clients may read the declaration, as they read the roles (0559)');
select ok(not has_function_privilege('authenticated', 'public.operator_set_personal_home(text, text, text, uuid)', 'EXECUTE')
      and not has_function_privilege('anon', 'public.operator_set_personal_home(text, text, text, uuid)', 'EXECUTE'),
  'the operator function is out of the API''s reach');
select throws_ok($$update public.installation_identity set personal_home_kind = 'elsewhere'$$, '23514', null,
  'the table refuses a kind it does not know');
select throws_ok($$update public.installation_identity set personal_home_kind = 'endpoint'$$, '23514', null,
  'the table refuses an endpoint without a URL');
select throws_ok($$update public.installation_identity set personal_home_kind = 'endpoint',
  personal_home_url = 'https://home.example', personal_home_key = 'sb_secret_abcdefghijklmnopqrstuvwxyz'$$, '23514', null,
  'the table refuses a secret key, whoever writes it');
select throws_ok($$update public.installation_identity set personal_home_kind = 'endpoint',
  personal_home_url = 'http://home.example', personal_home_key = 'sb_publishable_abcdefghijklmnop'$$, '23514', null,
  'the table refuses a URL that is not HTTPS');

-- ── a combined installation: self, never another home ──────────────
select throws_ok($$select public.operator_set_personal_home('self', null, null, '00000000-0000-4000-8000-0000002561ff')$$,
  '55000', null, 'another installation''s id is a mismatched target, refused');
select throws_ok($$select public.operator_set_personal_home('elsewhere')$$, '22023', null,
  'a kind the contract does not know is refused');
select throws_ok($$select public.operator_set_personal_home('endpoint', 'https://home.example', 'sb_publishable_abcdefghijklmnop')$$,
  'DKR03', null, 'a personal home (combined) names no other personal home');
select is((select personal_home_kind from public.installation_identity), 'unset', 'and nothing moved');
select is(public.operator_set_personal_home('self')->>'unchanged', 'false',
  'a combined installation may declare itself the personal home');
select is((select personal_home_kind from public.installation_identity), 'self', 'the declaration is stored');
select is(public.operator_set_personal_home('self')->>'unchanged', 'true', 'the same declaration again is unchanged');
select throws_ok($$select public.operator_set_personal_home('self', 'https://home.example', null)$$, '22023', null,
  'only an endpoint carries a URL');
select is(public.operator_set_personal_home('unset')->>'unchanged', 'false', 'and back to unset');
select is((select count(*) from public.database_authority_audit where action = 'personal_home_set'), 2::bigint,
  'every change is audited, an unchanged call is not');

-- ── a workspace host names its personal home ───────────────────────
select is(public.operator_set_installation_roles('{workspace_host}')->>'unchanged', 'false',
  'precondition: the installation becomes a workspace host only');
select throws_ok($$select public.operator_set_personal_home('self')$$, 'DKR03', null,
  'a workspace host that is not a personal home cannot name itself');
select throws_ok($$select public.operator_set_personal_home('endpoint', 'http://home.example', 'sb_publishable_abcdefghijklmnop')$$,
  '22023', null, 'a plain-HTTP personal home is refused');
select throws_ok($$select public.operator_set_personal_home('endpoint', 'https://home.example/rest/v1', 'sb_publishable_abcdefghijklmnop')$$,
  '22023', null, 'a URL with a path is refused: the home is an origin');
select throws_ok($$select public.operator_set_personal_home('endpoint', 'https://home.example', 'sb_secret_abcdefghijklmnopqrstuvwxyz')$$,
  '22023', null, 'a secret key is refused before it could be published');
-- {"alg":"HS256","typ":"JWT"} . {"role":"service_role"} . signature
select throws_ok($$select public.operator_set_personal_home('endpoint', 'https://home.example',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.c2lnbmF0dXJl')$$,
  '22023', null, 'a service-role JWT is refused');
select throws_ok($$select public.operator_set_personal_home('endpoint', 'https://home.example', 'sb_publishable_x')$$,
  '22023', null, 'a key too short to be one is refused');
select is((select personal_home_kind from public.installation_identity), 'unset', 'no refused call changed anything');
select is(public.operator_set_personal_home('endpoint', ' HTTPS://Home.Example/ ', 'sb_publishable_abcdefghijklmnop')->>'url',
  'https://home.example', 'an HTTPS origin and a publishable key are accepted, canonical');
select is((select personal_home_url || ' ' || personal_home_key from public.installation_identity),
  'https://home.example sb_publishable_abcdefghijklmnop', 'and stored');
-- {"alg":"HS256","typ":"JWT"} . {"role":"anon","iss":"supabase"} . signature
select is(public.operator_set_personal_home('endpoint', 'https://home.example:8443',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIn0.c2lnbmF0dXJl')->>'unchanged',
  'false', 'a legacy anon JWT is a publishable key too');
select is((select count(*) from public.database_authority_audit where action = 'personal_home_set'), 4::bigint,
  'both endpoint declarations are audited');
select is(public.operator_set_personal_home('unset')->>'kind', 'unset', 'the declaration can be withdrawn');

-- ── the platform-settings reader at a workspace-free personal home ─
select is((select count(*) from public.workspaces), 0::bigint,
  'precondition: the replayed database hosts no workspace');
select is(public.operator_set_installation_roles('{personal_home}')->>'unchanged', 'false',
  'it becomes a personal home only');
select is(public.operator_set_personal_home('self')->>'kind', 'self', 'that names itself');

select pg_temp.act_as('00000000-0000-4000-8000-0000002561c1');
select is(public.set_setting(null, 'dunning.first_after_days', '21', 'platform value at P')->>'status', 'saved',
  'the platform owner stores a platform value on the personal home');

select pg_temp.act_as('00000000-0000-4000-8000-0000002561c2');
select is((select e->'value' from jsonb_array_elements(public.my_settings(null)) e
            where e->>'key' = 'dunning.first_after_days'), '21'::jsonb,
  'a person in no workspace reads the platform value through my_settings(null)');
select is((select e->>'origin' from jsonb_array_elements(public.my_settings(null)) e
            where e->>'key' = 'dunning.first_after_days'), 'platform',
  'named as the platform''s');
select is((select e->'value' from jsonb_array_elements(public.my_settings(null)) e
            where e->>'key' = 'assets.valuation_max_rows'), '2000'::jsonb,
  'a workspace-only key answers its registry default, not an error');
select is(public.setting_value(null, 'dunning.first_after_days'), '21'::jsonb,
  'setting_value(null, key) resolves the platform scope without a workspace');

reset role;
select is((select count(*) from public.workspaces), 0::bigint,
  'reading the platform settings wrote no workspace (no dummy workspace at P)');
select set_config('request.jwt.claims', '{"role": "anon"}', true);
set local role anon;
select is((select personal_home_kind from public.installation_identity), 'self',
  'an anonymous client reads the declaration through the column grant');
reset role;

select * from finish();
rollback;
