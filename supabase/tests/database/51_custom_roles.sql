-- SPDX-License-Identifier: 0BSD
--
-- #1287 — roles a workspace defines itself. ADR 0029: a custom role is an
-- ADDITIVE grant. It never removes a permission and never replaces the
-- base role, so what this file proves is one direction only — a member
-- gains what the role holds, and loses it again when the grant goes.
--
-- The two definers carry the whole authority: `set_workspace_role` is the
-- owner's, `assign_workspace_role` belongs to whoever manages the roles.
-- Neither table has a write policy, which the last test states directly:
-- a grant row can only be born inside a definer that checked something.
begin;
select plan(20);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_owner uuid := '00000000-0000-4000-8000-0000000000e1';
  u_plain uuid := '00000000-0000-4000-8000-0000000000e2';
  ws uuid;
  m_owner uuid;
  m_plain uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u_owner, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'roles-owner@deskilo.test', '', now(), now(), now()),
         (u_plain, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'roles-plain@deskilo.test', '', now(), now(), now());

  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Custom roles', 'FR', 'EUR', 'Europe/Paris', u_owner) returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_owner, true, true) returning id into m_owner;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_plain, false, false) returning id into m_plain;

  perform set_config('deskilo.roles.ws', ws::text, false);
  perform set_config('deskilo.roles.owner', u_owner::text, false);
  perform set_config('deskilo.roles.plain', u_plain::text, false);
  perform set_config('deskilo.roles.m_owner', m_owner::text, false);
  perform set_config('deskilo.roles.m_plain', m_plain::text, false);
end
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.roles.' || p_who),
                      'role', 'authenticated')::text, true);
end
$act$;

create or replace function pg_temp.ws() returns uuid language sql as $$
  select current_setting('deskilo.roles.ws')::uuid;
$$;

create or replace function pg_temp.member(p_who text) returns uuid language sql as $$
  select current_setting('deskilo.roles.m_' || p_who)::uuid;
$$;

create or replace function pg_temp.role_id() returns uuid language sql as $$
  select id from public.workspace_roles
   where workspace_id = pg_temp.ws() and key = 'treasurer';
$$;

select pg_temp.seed();
select pg_temp.act_as('owner');

select throws_matching(
  format($$ select public.set_workspace_role(%L, 'treasurer', array['issueInvoices']) $$, pg_temp.ws()),
  'custom roles are off',
  'a workspace that never switched the feature on has no way to define a '
  'role — the flag gates the definer, not only the screen');

update public.workspaces
   set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"customRoles": true}'::jsonb
 where id = pg_temp.ws();

select isnt(
  public.set_workspace_role(pg_temp.ws(), 'treasurer', array['issueInvoices'],
    '{"en": "Treasurer", "fr": "Trésorier", "de": "Kassenwart",
      "es": "Tesorero", "it": "Tesoriere"}'::jsonb, 5, true),
  null,
  'an owner defines a role by key, and the key is what the workspace keeps');

select is(
  (select names->>'fr' || ' / ' || array_to_string(permissions, ',') || ' / ' || sort_order
     from public.workspace_roles where id = pg_temp.role_id()),
  'Trésorier / issueInvoices / 5',
  'the name is stored once per language, beside the permissions it grants, '
  'so a member reads the role in their own language and not the owner''s');

select throws_matching(
  format($$ select public.set_workspace_role(%L, 'auditor', array['notAPermission']) $$, pg_temp.ws()),
  'unknown permission notAPermission',
  'a custom role can never hold a permission the product does not have: '
  'every entry is checked against role_permission_catalog()');

select throws_matching(
  format($$ select public.set_workspace_role(%L, 'admin', array['issueInvoices']) $$, pg_temp.ws()),
  'built-in roles are not redefined here',
  'the four built-in roles keep their meaning — a workspace adds roles, it '
  'does not rewrite the ones every workspace shares');

select throws_matching(
  format($$ select public.set_workspace_role(%L, 'Trésorier!', array[]::text[]) $$, pg_temp.ws()),
  'lower-case letters, digits and underscores',
  'the key is an identifier, never a label; the label is the names map');

select throws_matching(
  format($$ select public.set_workspace_role(%L, 'auditor', array[]::text[], '{"pt": "Tesoureiro"}'::jsonb) $$, pg_temp.ws()),
  'unsupported locale pt',
  'a name is offered in a language the app actually speaks');

select throws_matching(
  format($$ select public.set_workspace_role(%L, 'auditor', array[]::text[], '{"en": "  "}'::jsonb) $$, pg_temp.ws()),
  'the name for en is empty',
  'a blank name would show as a nameless role in one language only');

select pg_temp.act_as('plain');
select throws_matching(
  format($$ select public.set_workspace_role(%L, 'sneaky', array['issueInvoices']) $$, pg_temp.ws()),
  'only an owner defines the roles',
  'defining a role is granting authority, so it stays with the owner even '
  'though assigning one does not');

select is(public.has_permission(pg_temp.ws(), 'issueInvoices'), false,
  'the member holds nothing before the grant — the reading that the next '
  'test changes');

select pg_temp.act_as('owner');
select lives_ok(
  format($$ select public.assign_workspace_role(%L, %L, true) $$, pg_temp.member('plain'), pg_temp.role_id()),
  'whoever manages the roles assigns one');

select is(public.member_has_permission(pg_temp.member('plain'), 'issueInvoices'), true,
  'the answer about somebody else''s membership follows the same union, so '
  'a screen that lists what a member may do agrees with what they may do');

select pg_temp.act_as('plain');
select is(public.has_permission(pg_temp.ws(), 'issueInvoices'), true,
  'the member now issues invoices, and holds it from the custom role alone');

select pg_temp.act_as('owner');
select throws_matching(
  format($$ select public.assign_workspace_role(%L, %L, true) $$, pg_temp.member('owner'), pg_temp.role_id()),
  'never assigned to yourself',
  'nobody grants themselves a permission, the rule every authority-granting '
  'call in this database already follows');

select lives_ok(
  format($$ select public.assign_workspace_role(%L, %L, false) $$, pg_temp.member('plain'), pg_temp.role_id()),
  'the grant is withdrawn');
select pg_temp.act_as('plain');
select is(public.has_permission(pg_temp.ws(), 'issueInvoices'), false,
  'and the permission leaves with it — additive means it was only ever the '
  'grant holding it up');

select pg_temp.act_as('owner');
select public.assign_workspace_role(pg_temp.member('plain'), pg_temp.role_id(), true);
select public.set_workspace_role(pg_temp.ws(), 'treasurer', array['issueInvoices'],
  '{"en": "Treasurer"}'::jsonb, 5, false);
select pg_temp.act_as('plain');
select is(public.has_permission(pg_temp.ws(), 'issueInvoices'), false,
  'a role put aside grants nothing while it waits, and the assignments '
  'survive so switching it back on restores exactly who had it');

select pg_temp.act_as('owner');
select public.set_workspace_role(pg_temp.ws(), 'treasurer', array['issueInvoices'],
  '{"en": "Treasurer"}'::jsonb, 5, true);
update public.workspaces
   set feature_flags = feature_flags || '{"customRoles": false}'::jsonb
 where id = pg_temp.ws();

select pg_temp.act_as('plain');
select is(public.has_permission(pg_temp.ws(), 'issueInvoices'), false,
  'switching the feature off withdraws every custom grant, the way the '
  'adminInvoicing branch beside it has behaved since #1333 — a flag that '
  'only hid the screen would leave the authority standing');

update public.workspaces
   set feature_flags = feature_flags || '{"customRoles": true}'::jsonb
 where id = pg_temp.ws();
select is(public.has_permission(pg_temp.ws(), 'issueInvoices'), true,
  'and the assignments outlived the pause, so switching the feature back '
  'on restores exactly who had what');

select ok(
  not has_table_privilege('authenticated', 'public.workspace_role_members', 'INSERT')
  and not has_table_privilege('authenticated', 'public.workspace_roles', 'INSERT'),
  'neither table takes a write from a signed-in client: a grant row exists '
  'only because a definer checked who was asking');

select * from finish();
rollback;
