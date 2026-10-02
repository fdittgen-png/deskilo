-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2085 — who may give a workspace's own role, and the record of it.
--
-- The owner's decision, proved where it is enforced: someone who is not
-- the owner gives (or takes back) only a role whose permissions they hold,
-- and never a role carrying manageRoles; the owner is not limited; nobody
-- gives a role to themselves; a kiosk or a role put aside is not given.
-- Every change leaves an applied `role_change` event naming the role and
-- the direction, and a repeat that changes nothing leaves none.
--
-- Each refusal is paired with the case beside it that passes, so a
-- refusal cannot be the side effect of a broken seed.
begin;
select plan(17);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_owner uuid := '00000000-0000-4000-8000-0000000002a1';
  u_dele  uuid := '00000000-0000-4000-8000-0000000002a2';
  u_lea   uuid := '00000000-0000-4000-8000-0000000002a3';
  u_kiosk uuid := '00000000-0000-4000-8000-0000000002a4';
  u_admin uuid := '00000000-0000-4000-8000-0000000002a5';
  ws uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated',
         'authenticated', 'giving-' || n || '@deskilo.test', '', now(), now(), now()
    from (values (u_owner, 'owner'), (u_dele, 'delegate'), (u_lea, 'lea'),
                 (u_kiosk, 'kiosk'), (u_admin, 'admin')) v(u, n);

  insert into public.workspaces (name, country_code, currency_code, timezone,
                                 created_by, feature_flags)
  values ('Giving roles', 'FR', 'EUR', 'Europe/Paris', u_owner,
          '{"customRoles": true}'::jsonb)
  returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_owner, true, true), (ws, u_dele, false, false),
         (ws, u_lea, false, false), (ws, u_admin, false, true);
  insert into public.members (workspace_id, user_id, is_owner, is_admin, is_kiosk)
  values (ws, u_kiosk, false, false, true);

  perform set_config('deskilo.give.ws', ws::text, false);
  perform set_config('deskilo.give.owner', u_owner::text, false);
  perform set_config('deskilo.give.delegate', u_dele::text, false);
  perform set_config('deskilo.give.lea', u_lea::text, false);
  perform set_config('deskilo.give.kiosk', u_kiosk::text, false);
  perform set_config('deskilo.give.admin', u_admin::text, false);
end
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.give.' || p_who),
                      'role', 'authenticated')::text, true);
end
$act$;

create or replace function pg_temp.ws() returns uuid language sql as $$
  select current_setting('deskilo.give.ws')::uuid;
$$;

create or replace function pg_temp.member(p_who text) returns uuid language sql as $$
  select id from public.members
   where workspace_id = pg_temp.ws()
     and user_id = current_setting('deskilo.give.' || p_who)::uuid;
$$;

create or replace function pg_temp.role(p_key text) returns uuid language sql as $$
  select id from public.workspace_roles
   where workspace_id = pg_temp.ws() and key = p_key;
$$;

create or replace function pg_temp.give(p_who text, p_key text, p_assign boolean)
returns text language sql as $$
  select format('select public.assign_workspace_role(%L, %L, %L)',
                pg_temp.member(p_who), pg_temp.role(p_key), p_assign);
$$;

create or replace function pg_temp.events(p_who text) returns int language sql as $$
  select count(*)::int from public.events
   where workspace_id = pg_temp.ws() and type = 'role_change'
     and subject_member_id = pg_temp.member(p_who);
$$;

select pg_temp.seed();
select pg_temp.act_as('owner');

-- Four roles: the board gives roles, the reader reads the finances, the
-- treasurer reads AND issues, and an old role was put aside.
select public.set_workspace_role(pg_temp.ws(), 'bureau',
  array['manageRoles', 'viewFinances'], '{"en": "Board"}'::jsonb, 1, true);
select public.set_workspace_role(pg_temp.ws(), 'lecteur',
  array['viewFinances'], '{"en": "Reader"}'::jsonb, 2, true);
select public.set_workspace_role(pg_temp.ws(), 'tresorier',
  array['viewFinances', 'issueInvoices'], '{"en": "Treasurer"}'::jsonb, 3, true);
select public.set_workspace_role(pg_temp.ws(), 'ancien',
  array['viewFinances'], '{"en": "Old"}'::jsonb, 4, false);

select lives_ok(pg_temp.give('delegate', 'bureau', true),
  'the owner gives a role that manages roles');
select is(pg_temp.events('delegate'), 1,
  'and the grant is on the record');
select is(
  (select payload->>'role_key' || ' ' || (payload->>'assign') || ' ' || status
     from public.events
    where workspace_id = pg_temp.ws() and type = 'role_change'
      and subject_member_id = pg_temp.member('delegate')),
  'bureau true applied',
  'naming the role and the direction, as an applied act, with no make_admin '
  '— which is how the app tells it from the Administrator quorum request');

select pg_temp.act_as('delegate');
select lives_ok(pg_temp.give('lea', 'lecteur', true),
  'a delegate who manages roles gives a role whose permissions they hold');
select throws_matching(pg_temp.give('lea', 'tresorier', true),
  'holds what it gives',
  'but not one holding a permission they do not hold: the delegate reads '
  'the finances and does not issue invoices');
select throws_matching(pg_temp.give('lea', 'bureau', true),
  'owner gives a role that manages roles',
  'and never the power to give roles, even one they hold themselves');
select throws_matching(pg_temp.give('delegate', 'lecteur', true),
  'never assigned to yourself',
  'nobody gives a role to themselves');
select throws_matching(pg_temp.give('kiosk', 'lecteur', true),
  'cannot hold a role',
  'a kiosk is a device, not a person, and holds no role');

select pg_temp.act_as('owner');
select lives_ok(pg_temp.give('lea', 'tresorier', true),
  'the owner gives the treasurer role the delegate could not');

select pg_temp.act_as('delegate');
select throws_matching(pg_temp.give('lea', 'tresorier', false),
  'holds what it gives',
  'and the delegate cannot take it back either: who may give a role is who '
  'may take it back');
select lives_ok(pg_temp.give('lea', 'lecteur', false),
  'while the role the delegate gave, the delegate takes back');
select is(pg_temp.events('lea'), 3,
  'three changes, three records: given, given by the owner, taken back');

select lives_ok(pg_temp.give('lea', 'lecteur', false),
  'taking back a role nobody holds is not an error');
select is(pg_temp.events('lea'), 3,
  'but it changed nothing, so it records nothing');

select pg_temp.act_as('owner');
select throws_matching(pg_temp.give('lea', 'ancien', true),
  'put aside',
  'a role that was put aside is not given, by the owner either');

select pg_temp.act_as('admin');
select throws_matching(pg_temp.give('lea', 'lecteur', true),
  'only someone who manages the roles',
  'an Administrator does not manage roles unless the matrix says so');

select pg_temp.act_as('lea');
select is(public.has_permission(pg_temp.ws(), 'issueInvoices'), true,
  'and what the owner gave still holds: the member issues invoices');

select * from finish();
rollback;
