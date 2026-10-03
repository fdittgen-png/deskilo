-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2085 — the Administrator is a role.
--
-- What this file proves, in the database that enforces it:
--   * every workspace carries exactly one built-in Administrator row,
--     born with the workspace;
--   * who holds it is `members.is_admin` — neither owner nor active
--     co-owner — and the holder rows follow every change of the flag;
--   * it grants nothing as a role row (the custom branch skips it), so
--     what an Administrator may do is still the matrix: manageMembers by
--     default, and manageIntegrations only when an owner grants it
--     (#1826), while the owner keeps it always;
--   * it never travels in an export, an import never puts it aside, and
--     no door redefines it; only an owner renames it;
--   * giving it through `assign_workspace_role` asks the validation
--     quorum, exactly as the member page always did.
begin;
select plan(22);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_owner uuid := '00000000-0000-4000-8000-0000000003b1';
  u_ana   uuid := '00000000-0000-4000-8000-0000000003b2';
  u_bob   uuid := '00000000-0000-4000-8000-0000000003b3';
  ws uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated',
         'authenticated', 'administrator-' || n || '@deskilo.test', '', now(), now(), now()
    from (values (u_owner, 'owner'), (u_ana, 'ana'), (u_bob, 'bob')) v(u, n);

  insert into public.workspaces (name, country_code, currency_code, timezone,
                                 created_by, feature_flags)
  values ('The Administrator', 'FR', 'EUR', 'Europe/Paris', u_owner,
          '{"customRoles": true}'::jsonb)
  returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_owner, true, true), (ws, u_ana, false, true),
         (ws, u_bob, false, false);

  perform set_config('deskilo.adm.ws', ws::text, false);
  perform set_config('deskilo.adm.owner', u_owner::text, false);
  perform set_config('deskilo.adm.ana', u_ana::text, false);
  perform set_config('deskilo.adm.bob', u_bob::text, false);
end
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.adm.' || p_who),
                      'role', 'authenticated')::text, true);
end
$act$;

create or replace function pg_temp.ws() returns uuid language sql as $$
  select current_setting('deskilo.adm.ws')::uuid;
$$;

create or replace function pg_temp.member(p_who text) returns uuid language sql as $$
  select id from public.members
   where workspace_id = pg_temp.ws()
     and user_id = current_setting('deskilo.adm.' || p_who)::uuid;
$$;

create or replace function pg_temp.admin_role() returns uuid language sql as $$
  select id from public.workspace_roles
   where workspace_id = pg_temp.ws() and builtin;
$$;

create or replace function pg_temp.holds(p_who text) returns boolean language sql as $$
  select exists (select 1 from public.workspace_role_members
                  where role_id = pg_temp.admin_role()
                    and member_id = pg_temp.member(p_who));
$$;

select pg_temp.seed();

select is(
  (select count(*)::int || ' ' || min(key) from public.workspace_roles
    where workspace_id = pg_temp.ws() and builtin),
  '1 admin',
  'a workspace is born with exactly one built-in Administrator');

select ok(pg_temp.holds('ana'), 'an admin holds it from the moment they join');
select ok(not pg_temp.holds('owner') and not pg_temp.holds('bob'),
  'the owner, who holds everything already, and a plain member do not');

update public.members set is_admin = true where id = pg_temp.member('bob');
select ok(pg_temp.holds('bob'),
  'giving the admin flag — whatever path writes it — makes a holder');
update public.members set is_admin = false where id = pg_temp.member('bob');
select ok(not pg_temp.holds('bob'), 'and taking it away ends the holding');

update public.members set co_owner = 'active' where id = pg_temp.member('ana');
select ok(not pg_temp.holds('ana'),
  'an active co-owner holds owner permissions, not the Administrator');
update public.members set co_owner = 'none' where id = pg_temp.member('ana');
select ok(pg_temp.holds('ana'), 'and holds it again when the co-ownership ends');

select is(public.member_custom_permissions(pg_temp.member('ana')), '{}'::text[],
  'the row grants nothing on its own: the custom branch skips it');

select pg_temp.act_as('ana');
select ok(public.has_permission(pg_temp.ws(), 'manageMembers'),
  'what an Administrator may do is still the matrix: manageMembers by default');
select ok(not public.has_permission(pg_temp.ws(), 'manageIntegrations'),
  'and manageIntegrations only when an owner grants it (#1826)');
select ok(public.has_permission(pg_temp.ws(), 'viewAnalytics'),
  'and viewAnalytics, which Administrators hold by default (0340)');
select ok(public.is_admin_of(pg_temp.ws()),
  'is_admin_of keeps its meaning for every caller that reads it');

select pg_temp.act_as('owner');
select ok(public.has_permission(pg_temp.ws(), 'manageIntegrations'),
  'the owner keeps every permission, manageIntegrations included');

select ok(
  public.workspace_roles_export(pg_temp.ws())::text not like '%"admin"%',
  'the configuration export never carries the built-in row');

select public.set_workspace_role(pg_temp.ws(), 'lecteur', array['viewFinances'],
  '{"en": "Reader"}'::jsonb, 1, true);
select public.workspace_roles_import(pg_temp.ws(), '[]'::jsonb, 'mirror');
select is(
  (select string_agg(key || '=' || active, ',' order by key)
     from public.workspace_roles where workspace_id = pg_temp.ws()),
  'admin=true,lecteur=false',
  'an import in mirror mode puts aside the roles it does not carry, never '
  'the Administrator');

select throws_matching(
  format($$ select public.set_workspace_role(%L, 'admin', array['exportData']) $$, pg_temp.ws()),
  'built-in roles are not redefined',
  'no door redefines it');

select lives_ok(
  format($$ select public.rename_administrator_role(%L, '{"en": "Board member", "fr": "Bureau"}'::jsonb) $$,
         pg_temp.ws()),
  'the owner renames it');
select is((select names->>'fr' from public.workspace_roles where id = pg_temp.admin_role()),
  'Bureau', 'and the name is kept per language');
select throws_matching(
  format($$ select public.rename_administrator_role(%L, '{"pt": "Diretor"}'::jsonb) $$, pg_temp.ws()),
  'unsupported locale pt',
  'in a language the app speaks');

select pg_temp.act_as('ana');
select throws_matching(
  format($$ select public.rename_administrator_role(%L, '{"en": "Boss"}'::jsonb) $$, pg_temp.ws()),
  'only an owner defines the roles',
  'renaming is the owner''s, as defining a role is');

select pg_temp.act_as('owner');
select public.assign_workspace_role(pg_temp.member('bob'), pg_temp.admin_role(), true);
select is(
  (select status || ' ' || (payload->>'make_admin') from public.events
    where workspace_id = pg_temp.ws() and type = 'role_change'
      and subject_member_id = pg_temp.member('bob')),
  'pending true',
  'giving the Administrator through the one RPC asks the validation quorum, '
  'as the member page always did');
select ok(not pg_temp.holds('bob'),
  'and nothing is granted until the validators confirm it');

select * from finish();
rollback;
