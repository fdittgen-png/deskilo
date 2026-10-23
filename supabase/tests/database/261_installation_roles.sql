-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2561 L1 (9999): an installation declares what it is. Combined by
-- default; the operator function refuses to make a personal home of an
-- installation that holds a workspace or a member and changes nothing;
-- a personal home refuses a workspace row at the table, so every creation
-- path refuses with one SQLSTATE and no row; the descriptor advertises the
-- roles and their capability versions live. A workspace's network id is
-- its birth record: installation id : local id, stamped by the server,
-- unique, immutable. Seeds are direct inserts as postgres; callers are
-- impersonated through request.jwt.claims (the entry points are definer
-- functions and triggers, not row policies).
begin;
select plan(37);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000002561a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner-2561@deskilo.test', '', now(), now(), now());

-- ── the replay starts empty, and combined ──────────────────────────
select is((select count(*) from public.workspaces), 0::bigint,
  'precondition: the replayed database hosts no workspace before this file');
select is((select roles from public.installation_identity),
  array['personal_home', 'workspace_host']::text[], 'an installation is combined by default');
select throws_ok($$update public.installation_identity set roles = '{owner}'$$, '23514', null,
  'the table refuses a role it does not know');
select throws_ok($$update public.installation_identity set roles = '{}'$$, '23514', null,
  'the table refuses an empty role set');
select throws_ok($$update public.installation_identity set roles = '{personal_home,personal_home}'$$, '23514', null,
  'the table refuses a duplicate');
select ok(has_column_privilege('anon', 'public.installation_identity', 'roles', 'SELECT'),
  'anonymous discovery may read the roles column, as it reads installation_id (0299)');
select is(public.public_network_descriptor()->'roles', '["personal_home","workspace_host"]'::jsonb,
  'the descriptor advertises both roles of a combined installation');
select is(public.public_network_descriptor()->'role_capabilities', '["personal@1","workspace@1"]'::jsonb,
  'and the capability version each role carries');

-- ── the operator function on an empty installation ─────────────────
select throws_ok($$select public.operator_set_installation_roles('{personal_home}', '00000000-0000-4000-8000-0000002561ff')$$,
  '55000', null, 'another installation''s id is a mismatched target, refused');
select throws_ok($$select public.operator_set_installation_roles('{owner}')$$, '22023', null,
  'a role the contract does not know is refused');
select is(public.operator_set_installation_roles('{personal_home}')->>'unchanged', 'false',
  'an installation that holds no workspace and no member becomes a personal home');
select is((select roles from public.installation_identity), array['personal_home']::text[],
  'the role is stored');
select is((select count(*) from public.database_authority_audit where action = 'installation_roles_set'), 1::bigint,
  'the change is audited');
select is(public.public_network_descriptor()->'roles', '["personal_home"]'::jsonb,
  'the descriptor now advertises the personal home alone');
select is(public.public_network_descriptor()->'role_capabilities', '["personal@1"]'::jsonb,
  'with the personal capability only');

-- ── a personal home refuses a workspace, and writes nothing ────────
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000002561a1","role":"authenticated"}', true);
select throws_ok($$select public.create_workspace('Refused 2561', 'FR', 'EUR', 'Europe/Paris', 'dev', false)$$,
  'DKR01', 'this installation is a personal home and hosts no workspace',
  'create_workspace refuses on a personal home with the named SQLSTATE');
select is((select count(*) from public.workspaces), 0::bigint, 'no workspace row was written');
select is((select count(*) from public.members), 0::bigint, 'and no member row');
select throws_ok($$insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by)
  values ('00000000-0000-4000-8000-0000002561b1', 'Direct 2561', 'FR', 'EUR', 'Europe/Paris', '00000000-0000-4000-8000-0000002561a1')$$,
  'DKR01', null, 'the guard is the table''s: a direct insert refuses the same way');

-- ── combined again: creation works and carries the birth record ────
select is(public.operator_set_installation_roles('{personal_home,workspace_host}')->>'unchanged', 'false',
  'the operator adds workspace_host back');
select is((select count(*) from public.database_authority_audit where action = 'installation_roles_set'), 2::bigint,
  'audited again');
select lives_ok($$select set_config('t.ws', public.create_workspace('Roles 2561', 'FR', 'EUR', 'Europe/Paris', 'dev', false)::text, true)$$,
  'a combined installation creates a workspace');
select is((select network_id from public.workspaces where id = current_setting('t.ws')::uuid),
  (select installation_id::text from public.installation_identity) || ':' || current_setting('t.ws'),
  'network_id is installation id : local id, stamped by the server');
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, network_id)
values ('00000000-0000-4000-8000-0000002561b2', 'Forged 2561', 'FR', 'EUR', 'Europe/Paris',
        '00000000-0000-4000-8000-0000002561a1', 'elsewhere:forged');
select is((select network_id from public.workspaces where id = '00000000-0000-4000-8000-0000002561b2'),
  (select installation_id::text from public.installation_identity) || ':00000000-0000-4000-8000-0000002561b2',
  'a network id a client sends is replaced by the birth record');
select throws_ok($$update public.workspaces set network_id = 'moved:elsewhere' where id = '00000000-0000-4000-8000-0000002561b2'$$,
  'P0001', 'a workspace''s network id is its birth record and never changes', 'network_id is immutable');
select is((select network_id from public.workspaces where id = '00000000-0000-4000-8000-0000002561b2'),
  (select installation_id::text from public.installation_identity) || ':00000000-0000-4000-8000-0000002561b2',
  'the refused update changed nothing');
select col_is_unique('public', 'workspaces', 'network_id', 'network_id is unique');
select col_not_null('public', 'workspaces', 'network_id', 'network_id is never null');

-- ── with rows, a personal home is refused; a workspace host is not ─
select throws_ok($$select public.operator_set_installation_roles('{personal_home}')$$, 'DKR02', null,
  'personal_home alone is refused while workspaces and members exist');
select is((select roles from public.installation_identity), array['personal_home', 'workspace_host']::text[],
  'the roles did not move');
select is((select count(*) from public.workspaces), 2::bigint, 'and nothing was deleted');
select is(public.operator_set_installation_roles('{workspace_host,personal_home}')->>'unchanged', 'true',
  'the same set in another order is unchanged');
select is(public.operator_set_installation_roles('{workspace_host}')->>'unchanged', 'false',
  'workspace_host alone is accepted with rows: a host that is nobody''s home');
select is((select roles from public.installation_identity), array['workspace_host']::text[], 'and stored');
select is(public.public_network_descriptor()->'roles', '["workspace_host"]'::jsonb,
  'the descriptor advertises the workspace host alone');
select is(public.public_network_descriptor()->'role_capabilities', '["workspace@1"]'::jsonb,
  'with the workspace capability only');
select is((select count(*) from public.database_authority_audit where action = 'installation_roles_set'), 3::bigint,
  'every change is audited');

select * from finish();
rollback;
