-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2137 — a permission given through a role works, in the database.
--
-- The matrix, for each door 0358 opened: a member who holds the
-- permission ONLY through one of the workspace's own roles succeeds; the
-- built-in Administrator succeeds where the matrix gives it the
-- permission; a member without it is refused; the owner still succeeds.
-- Every write runs as `authenticated`, so the policies are what decide.
-- The workspace row is the one door that also limits COLUMNS: a delegate
-- writes the columns of their permission and nothing else.
begin;
select plan(26);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_owner uuid := '00000000-0000-4000-8000-0000000005d1';
  u_admin uuid := '00000000-0000-4000-8000-0000000005d2';
  u_role  uuid := '00000000-0000-4000-8000-0000000005d3';
  u_plain uuid := '00000000-0000-4000-8000-0000000005d4';
  ws uuid;
  r uuid;
  m_role uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated',
         'authenticated', 'perm-' || n || '@deskilo.test', '', now(), now(), now()
    from (values (u_owner, 'owner'), (u_admin, 'admin'), (u_role, 'role'),
                 (u_plain, 'plain')) v(u, n);
  -- The Administrator's row of the matrix also carries the two settings
  -- permissions it does not hold by default.
  insert into public.workspaces (name, country_code, currency_code, timezone,
                                 created_by, feature_flags, role_permissions)
  values ('Permissions that work', 'FR', 'EUR', 'Europe/Paris', u_owner,
          '{"customRoles": true, "publicHolidays": true, "holidayImport": true}'::jsonb,
          jsonb_build_object('admin', jsonb_build_array(
            'manageMembers', 'manageDocuments', 'manageServices',
            'workspaceSettings', 'manageBilling', 'manageIntegrations')))
  returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_owner, true, true), (ws, u_admin, false, true),
         (ws, u_plain, false, false);
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_role, false, false) returning id into m_role;
  -- One role carrying every permission under test; held by `role` only.
  insert into public.workspace_roles (workspace_id, key, permissions, names)
  values (ws, 'office', array['manageMembers', 'manageDocuments',
          'manageServices', 'workspaceSettings'], '{"en": "Office"}'::jsonb)
  returning id into r;
  insert into public.workspace_role_members (workspace_id, role_id, member_id)
  values (ws, r, m_role);

  perform set_config('deskilo.pw.ws', ws::text, false);
  perform set_config('deskilo.pw.owner', u_owner::text, false);
  perform set_config('deskilo.pw.admin', u_admin::text, false);
  perform set_config('deskilo.pw.role', u_role::text, false);
  perform set_config('deskilo.pw.plain', u_plain::text, false);
end
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.pw.' || p_who),
                      'role', 'authenticated')::text, true);
end
$act$;

create or replace function pg_temp.ws() returns uuid language sql as $$
  select current_setting('deskilo.pw.ws')::uuid;
$$;

select pg_temp.seed();

-- ── services: manageServices ───────────────────────────────────────────
set local role authenticated;
select pg_temp.act_as('role');
select lives_ok(format($$ insert into public.services (workspace_id, name, price_cents) values (%L, 'Coffee (role)', 100) $$, pg_temp.ws()),
  'a member holding manageServices through a role adds a service');
select pg_temp.act_as('admin');
select lives_ok(format($$ insert into public.services (workspace_id, name, price_cents) values (%L, 'Coffee (admin)', 100) $$, pg_temp.ws()),
  'the Administrator adds a service');
select pg_temp.act_as('owner');
select lives_ok(format($$ insert into public.services (workspace_id, name, price_cents) values (%L, 'Coffee (owner)', 100) $$, pg_temp.ws()),
  'the owner adds a service');
select pg_temp.act_as('plain');
select throws_ok(format($$ insert into public.services (workspace_id, name, price_cents) values (%L, 'Coffee (plain)', 100) $$, pg_temp.ws()),
  '42501', null, 'a member without the permission is refused');

-- ── packages and credit products: manageServices ───────────────────────
select pg_temp.act_as('role');
select lives_ok(format($$ insert into public.packages (workspace_id, name, days, price_cents) values (%L, 'Ten days', 10, 9000) $$, pg_temp.ws()),
  'a role holder adds a package');
select lives_ok(format($$ insert into public.credit_products (workspace_id, name, half_days, price_cents) values (%L, 'Carnet', 10, 5000) $$, pg_temp.ws()),
  'and a credit product');
select pg_temp.act_as('plain');
select throws_ok(format($$ insert into public.packages (workspace_id, name, days, price_cents) values (%L, 'Sneaky', 10, 1) $$, pg_temp.ws()),
  '42501', null, 'a plain member adds no package');

-- ── closure days: workspaceSettings ────────────────────────────────────
select pg_temp.act_as('role');
select lives_ok(format($$ insert into public.closure_days (workspace_id, day, reason) values (%L, '2031-01-02', 'role') $$, pg_temp.ws()),
  'a role holder closes a day');
select lives_ok(format($$ select public.generate_closure_days(%L, 'FR', 2031, false) $$, pg_temp.ws()),
  'and previews the public holidays');
select lives_ok(format($$ select public.import_closure_days(%L, '[{"day": "2031-05-08", "name": "x"}]'::jsonb, true) $$, pg_temp.ws()),
  'and imports a holiday');
select pg_temp.act_as('admin');
select lives_ok(format($$ insert into public.closure_days (workspace_id, day, reason) values (%L, '2031-01-03', 'admin') $$, pg_temp.ws()),
  'the Administrator whose matrix row holds it closes a day');
select pg_temp.act_as('plain');
select throws_ok(format($$ insert into public.closure_days (workspace_id, day, reason) values (%L, '2031-01-04', 'plain') $$, pg_temp.ws()),
  '42501', null, 'a plain member closes nothing');
select throws_ok(format($$ select public.generate_closure_days(%L, 'FR', 2031, false) $$, pg_temp.ws()),
  '42501', null, 'nor generates holidays');
select pg_temp.act_as('owner');
select lives_ok(format($$ select public.generate_closure_days(%L, 'FR', 2031, false) $$, pg_temp.ws()),
  'the owner still does');

-- ── documents: manageDocuments ─────────────────────────────────────────
select pg_temp.act_as('role');
select lives_ok(format($$ insert into public.workspace_documents (workspace_id, title, url, min_role) values (%L, 'Board minutes', 'https://example.org/m', 'admin') $$, pg_temp.ws()),
  'a role holder files a document reserved to administrators');
select is((select count(*)::int from public.workspace_documents where workspace_id = pg_temp.ws() and min_role = 'admin'), 1,
  'and reads it back');
select pg_temp.act_as('plain');
select is((select count(*)::int from public.workspace_documents where workspace_id = pg_temp.ws() and min_role = 'admin'), 0,
  'a plain member does not read a document reserved to administrators');
select throws_ok(format($$ insert into public.workspace_documents (workspace_id, title, url) values (%L, 'x', 'https://example.org/x') $$, pg_temp.ws()),
  '42501', null, 'nor files one');

-- ── inviting a member: manageMembers ───────────────────────────────────
select pg_temp.act_as('role');
select isnt(public.create_invitation(pg_temp.ws(), false), null,
  'a role holder invites a member');
select throws_matching(format($$ select public.create_invitation(%L, true) $$, pg_temp.ws()),
  'only owners may invite admins', 'but not an Administrator');
select pg_temp.act_as('plain');
select throws_matching(format($$ select public.create_invitation(%L, false) $$, pg_temp.ws()),
  'only admins may invite members', 'a plain member invites nobody');

-- ── the workspace row: its columns, by permission ──────────────────────
select pg_temp.act_as('role');
select lives_ok(format($$ update public.workspaces set address = 'Rue du Bureau 1' where id = %L $$, pg_temp.ws()),
  'a workspaceSettings holder changes the address');
select throws_ok(format($$ update public.workspaces set feature_flags = '{}'::jsonb where id = %L $$, pg_temp.ws()),
  '42501', null, 'but not the features');
select throws_ok(format($$ update public.workspaces set role_permissions = '{}'::jsonb where id = %L $$, pg_temp.ws()),
  '42501', null, 'nor the matrix that gave them the permission');
select pg_temp.act_as('admin');
select lives_ok(format($$ update public.workspaces set payment_instructions = '{"iban": "FR76"}'::jsonb where id = %L $$, pg_temp.ws()),
  'the Administrator holding manageIntegrations changes the payment instructions');
reset role;
select is((select address from public.workspaces where id = pg_temp.ws()), 'Rue du Bureau 1',
  'and the address the delegate wrote is the one stored');

select * from finish();
rollback;
