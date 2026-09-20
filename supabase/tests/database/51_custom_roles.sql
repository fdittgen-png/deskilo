-- SPDX-License-Identifier: AGPL-3.0-or-later
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
--
-- The last section is #1505: the DEFINITIONS travel with a template and a
-- deployment, the grants never do. What makes that safe is not a review
-- step — it is that a role arriving in another space holds nobody, and
-- grants nothing until somebody there gives it to somebody.
begin;
select plan(34);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_owner uuid := '00000000-0000-4000-8000-0000000000e1';
  u_plain uuid := '00000000-0000-4000-8000-0000000000e2';
  u_far   uuid := '00000000-0000-4000-8000-0000000000e3';
  ws uuid;
  far uuid;
  m_owner uuid;
  m_plain uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u_owner, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'roles-owner@deskilo.test', '', now(), now(), now()),
         (u_plain, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'roles-plain@deskilo.test', '', now(), now(), now()),
         (u_far, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'roles-far@deskilo.test', '', now(), now(), now());

  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Custom roles', 'FR', 'EUR', 'Europe/Paris', u_owner) returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_owner, true, true) returning id into m_owner;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_plain, false, false) returning id into m_plain;

  -- The space a template lands in: another owner, nobody in common.
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Far away', 'FR', 'EUR', 'Europe/Paris', u_far) returning id into far;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (far, u_far, true, true);

  perform set_config('deskilo.roles.ws', ws::text, false);
  perform set_config('deskilo.roles.far', far::text, false);
  perform set_config('deskilo.roles.farowner', u_far::text, false);
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

-- ── #1505: the definitions travel, the holders stay ──────────────────

create or replace function pg_temp.far() returns uuid language sql as $$
  select current_setting('deskilo.roles.far')::uuid;
$$;

-- The export is taken ONCE, while the source's owner is still the
-- caller: only an owner exports a configuration, and the space it lands
-- in has a different one. Reading it again from inside the import would
-- ask the wrong person.
create or replace function pg_temp.config() returns jsonb language sql as $$
  select current_setting('deskilo.roles.config')::jsonb;
$$;

select pg_temp.act_as('owner');
select public.set_workspace_role(pg_temp.ws(), 'treasurer', array['issueInvoices'],
  '{"en": "Treasurer", "fr": "Trésorier"}'::jsonb, 3, true);
select set_config('deskilo.roles.config',
  public.export_workspace_configuration(pg_temp.ws())::text, false);

select is(
  (select e.value - 'sort_order' - 'active'
     from jsonb_array_elements(pg_temp.config() #> '{tables,workspace_roles}') e
    where e.value->>'key' = 'treasurer'),
  '{"key": "treasurer", "names": {"en": "Treasurer", "fr": "Trésorier"},
    "permissions": ["issueInvoices"]}'::jsonb,
  'the configuration export carries the role a space invented: its key, its '
  'name in every language the space wrote, and what it grants');

select ok(
  pg_temp.config()::text not like '%workspace_role_members%'
  and pg_temp.config()::text not like ('%' || pg_temp.member('plain')::text || '%'),
  'and carries no holder — neither the junction table nor the id of the '
  'member who holds the role appears anywhere in the export');

select pg_temp.act_as('farowner');
select lives_ok(
  format($$ select public.import_workspace_configuration(%L, %L::jsonb, 'merge') $$,
         pg_temp.far(), pg_temp.config()),
  'another space imports the configuration');

select is(
  (select r.names->>'fr' || ' ' || array_to_string(r.permissions, ',')
     from public.workspace_roles r
    where r.workspace_id = pg_temp.far() and r.key = 'treasurer'),
  'Trésorier issueInvoices',
  'the role arrives whole, in the language the space wrote it');

select is(
  (select count(*)::int from public.workspace_role_members rm
     join public.workspace_roles r on r.id = rm.role_id
    where r.workspace_id = pg_temp.far()),
  0,
  'and NOBODY holds it there. That is the answer #1505 asked for: a role '
  'that arrives grants nothing until an owner gives it to somebody, and '
  'assign_workspace_role needs manageRoles and refuses the caller');

select throws_matching(
  format($$ select public.workspace_roles_import(%L,
    '[{"key": "admin", "names": {"en": "Admin"}}]'::jsonb, 'merge') $$, pg_temp.far()),
  'built-in roles are not redefined',
  'a template cannot redefine a built-in role by arriving with its key — '
  'the import refuses exactly what set_workspace_role refuses');

select throws_matching(
  format($$ select public.workspace_roles_import(%L,
    '[{"key": "ghost", "permissions": ["notAPermission"]}]'::jsonb, 'merge') $$,
    pg_temp.far()),
  'unknown permission',
  'nor can it carry a permission the product does not have: every one is '
  'checked against role_permission_catalog()');

select is(
  (select e.value->>'merge_policy' || ' ' || (e.value->>'group') || ' ' ||
          (public.template_publication_rules() #>> '{workspace_roles,allowed}')
     from jsonb_array_elements(public.deployable_entities()) e
    where e.value->>'key' = 'workspace_roles'),
  'keyed_update roles_access true',
  'and the entity is registered the way the matrix says: keyed on the '
  'role''s own key, in the roles group, publishable in a template');


-- ── #1560: the import is a door to the same rows, and it locks ───────
--
-- Everything above asks the owner. This asks somebody else, because the
-- configuration import had its own guard and that guard had been
-- rewritten four times since it said `owner` — 0177 owner, 0186
-- `manageConfiguration OR deploying`, 0197 `manageConfiguration`, 0206
-- `+ deployToProd/deployToDev`. Each step was right about hours and
-- tariffs and none was about roles, because roles did not travel until
-- 0251.
--
-- The test that existed called `workspace_roles_import` DIRECTLY, which
-- is exactly why it proved nothing: the helper is revoked from every
-- client, and the way in is the wrapper. These call the wrapper.

-- `plain` becomes an admin: `deployToDev` is an admin default, so the
-- import's own guard lets them in. No custom role, no delegation — the
-- ordinary second-in-command of a development workspace.
update public.members set is_admin = true where id = pg_temp.member('plain');

-- The WHOLE row, the way `workspace_roles_export` writes it. A payload
-- that names only the permissions is a payload that also blanks the
-- names, and the guard reads it as the change it is — so the no-op case
-- below has to be a real no-op, not a partial one.
create or replace function pg_temp.config_with(p_key text, p_permissions jsonb)
returns jsonb language sql as $$
  select jsonb_build_object('tables', jsonb_build_object('workspace_roles',
    jsonb_build_array(jsonb_build_object(
      'key', p_key, 'permissions', p_permissions,
      'names', '{"en": "Treasurer", "fr": "Trésorier"}'::jsonb,
      'sort_order', 3, 'active', true))));
$$;

select pg_temp.act_as('plain');

select throws_matching(
  format($$ select public.import_workspace_configuration(%L, %L::jsonb, 'merge') $$,
         pg_temp.ws(), pg_temp.config_with('treasurer', '["issueInvoices","manageRoles"]'::jsonb)),
  'only an owner defines the roles',
  'an admin cannot widen a role through the configuration import: the '
  'import reaches the same rows the editor guards, so it asks the same '
  'question and refuses in the same words');

select is(
  (select array_to_string(r.permissions, ',') from public.workspace_roles r
    where r.workspace_id = pg_temp.ws() and r.key = 'treasurer'),
  'issueInvoices',
  'and the refusal is atomic: the role still grants what it granted. This '
  'is the escalation that was open — the caller HOLDS treasurer, so '
  'rewriting its permissions rewrites their own authority');

select lives_ok(
  format($$ select public.import_workspace_configuration(%L, %L::jsonb, 'merge') $$,
         pg_temp.ws(), pg_temp.config_with('treasurer', '["issueInvoices"]'::jsonb)),
  'but a configuration that carries the roles a space already has still '
  'imports. Refusing that would teach people to strip the section by '
  'hand, which is how a guard gets worked around rather than obeyed');

select throws_matching(
  format($$ select public.import_workspace_configuration(%L,
    jsonb_build_object('workspace', jsonb_build_object('role_permissions',
      jsonb_build_object('admin', jsonb_build_array('exportData', 'manageRoles')))),
    'merge') $$, pg_temp.ws()),
  'changes what a role may do',
  'the BUILT-IN matrix is the same door and was never filed: '
  '`set_role_permissions` asks for manageRoles, and the import wrote the '
  'column with no question at all');

select is(public.has_permission(pg_temp.ws(), 'manageRoles'), false,
  'and the caller still cannot manage the roles — which is the only form '
  'of "the matrix did not move" that matters, because the matrix exists '
  'to answer exactly this question');

select pg_temp.act_as('owner');
select lives_ok(
  format($$ select public.import_workspace_configuration(%L, %L::jsonb, 'merge') $$,
         pg_temp.ws(), pg_temp.config_with('treasurer', '["issueInvoices","manageRoles"]'::jsonb)),
  'the owner, meeting the same door, walks through it');

select * from finish();
rollback;
