-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2085 — an invitation can carry roles.
--
-- What this file proves, where it is enforced:
--   * only the person who created an unused member invitation sets its
--     roles, and only roles they may give (the rules of
--     assign_workspace_role: a delegate gives what they hold, never a role
--     carrying manageRoles); an Administrator invitation carries none;
--   * the roles arrive when the person becomes an ACTIVE member through
--     that invitation — not while the membership waits for approval —
--     each recorded as an applied role_change marked `invitation`;
--   * they arrive once: leaving and coming back gives nothing twice;
--   * the inviter's authority is asked again on the day: an inviter who
--     lost the right to give a role gives nothing.
begin;
select plan(13);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_owner uuid := '00000000-0000-4000-8000-0000000004c1';
  u_dele  uuid := '00000000-0000-4000-8000-0000000004c2';
  u_n1    uuid := '00000000-0000-4000-8000-0000000004c3';
  u_n2    uuid := '00000000-0000-4000-8000-0000000004c4';
  ws uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated',
         'authenticated', 'invroles-' || n || '@deskilo.test', '', now(), now(), now()
    from (values (u_owner, 'owner'), (u_dele, 'dele'), (u_n1, 'n1'), (u_n2, 'n2')) v(u, n);
  insert into public.workspaces (name, country_code, currency_code, timezone,
                                 created_by, feature_flags)
  values ('Invitation roles', 'FR', 'EUR', 'Europe/Paris', u_owner,
          '{"customRoles": true}'::jsonb)
  returning id into ws;
  -- The delegate is an Administrator (who may invite) given the board
  -- role (who may give roles); an Administrator does not issue invoices.
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_owner, true, true), (ws, u_dele, false, true);

  perform set_config('deskilo.inv.ws', ws::text, false);
  perform set_config('deskilo.inv.owner', u_owner::text, false);
  perform set_config('deskilo.inv.dele', u_dele::text, false);
  perform set_config('deskilo.inv.n1', u_n1::text, false);
  perform set_config('deskilo.inv.n2', u_n2::text, false);
end
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.inv.' || p_who),
                      'role', 'authenticated')::text, true);
end
$act$;

create or replace function pg_temp.ws() returns uuid language sql as $$
  select current_setting('deskilo.inv.ws')::uuid;
$$;

create or replace function pg_temp.member(p_who text) returns uuid language sql as $$
  select id from public.members
   where workspace_id = pg_temp.ws()
     and user_id = current_setting('deskilo.inv.' || p_who)::uuid;
$$;

create or replace function pg_temp.roles_of(p_who text) returns text language sql as $$
  select coalesce(string_agg(r.key, ',' order by r.key), '-')
    from public.workspace_role_members rm
    join public.workspace_roles r on r.id = rm.role_id and not r.builtin
   where rm.member_id = pg_temp.member(p_who);
$$;

-- Redeeming, the way join_workspace does: the code is marked used by the
-- person, and their membership arrives with the status it is given.
create or replace function pg_temp.redeem(p_code text, p_who text, p_status text)
returns void language plpgsql as $$
begin
  update public.invitations
     set redeemed_by = current_setting('deskilo.inv.' || p_who)::uuid,
         redeemed_at = now()
   where code = p_code;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status)
  values (pg_temp.ws(), current_setting('deskilo.inv.' || p_who)::uuid,
          false, false, p_status);
end
$$;

select pg_temp.seed();
select pg_temp.act_as('owner');
select public.set_workspace_role(pg_temp.ws(), 'bureau',
  array['manageRoles', 'viewFinances'], '{"en": "Board"}'::jsonb, 1, true);
select public.set_workspace_role(pg_temp.ws(), 'lecteur',
  array['viewFinances'], '{"en": "Reader"}'::jsonb, 2, true);
select public.set_workspace_role(pg_temp.ws(), 'tresorier',
  array['viewFinances', 'issueInvoices'], '{"en": "Treasurer"}'::jsonb, 3, true);
select public.assign_workspace_role(pg_temp.member('dele'),
  (select id from public.workspace_roles where workspace_id = pg_temp.ws() and key = 'bureau'), true);

select set_config('deskilo.inv.c1', public.create_invitation(pg_temp.ws(), false), false);
select set_config('deskilo.inv.ca', public.create_invitation(pg_temp.ws(), true), false);

select lives_ok(
  format($$ select public.set_invitation_roles(%L, %L, array['tresorier', 'lecteur']) $$,
         pg_temp.ws(), current_setting('deskilo.inv.c1')),
  'the owner gives an invitation two roles');
select is(
  (select array_to_string(role_keys, ',') from public.invitations
    where code = current_setting('deskilo.inv.c1')),
  'lecteur,tresorier', 'and they are kept on the invitation');
select throws_matching(
  format($$ select public.set_invitation_roles(%L, %L, array['lecteur']) $$,
         pg_temp.ws(), current_setting('deskilo.inv.ca')),
  'carries no roles',
  'an Administrator invitation is the Administrator, and carries nothing else');
select throws_matching(
  format($$ select public.set_invitation_roles(%L, %L, array['nope']) $$,
         pg_temp.ws(), current_setting('deskilo.inv.c1')),
  'unknown role nope', 'a role the workspace does not have is refused');

select pg_temp.act_as('dele');
select set_config('deskilo.inv.c2', public.create_invitation(pg_temp.ws(), false), false);
select throws_matching(
  format($$ select public.set_invitation_roles(%L, %L, array['tresorier']) $$,
         pg_temp.ws(), current_setting('deskilo.inv.c2')),
  'not yours to give',
  'a delegate cannot send a role holding more than they hold');
select throws_matching(
  format($$ select public.set_invitation_roles(%L, %L, array['bureau']) $$,
         pg_temp.ws(), current_setting('deskilo.inv.c2')),
  'not yours to give',
  'nor the power to give roles');
select lives_ok(
  format($$ select public.set_invitation_roles(%L, %L, array['lecteur']) $$,
         pg_temp.ws(), current_setting('deskilo.inv.c2')),
  'but sends a role whose permissions they hold');
select throws_matching(
  format($$ select public.set_invitation_roles(%L, %L, array['lecteur']) $$,
         pg_temp.ws(), current_setting('deskilo.inv.c1')),
  'only the person who created',
  'and touches nobody else''s invitation');

select pg_temp.redeem(current_setting('deskilo.inv.c1'), 'n1', 'pending');
select is(pg_temp.roles_of('n1'), '-',
  'a membership waiting for approval holds no role yet');
update public.members set status = 'active' where id = pg_temp.member('n1');
select is(pg_temp.roles_of('n1'), 'lecteur,tresorier',
  'the roles arrive with the approval');
select is(
  (select count(*)::int from public.events
    where workspace_id = pg_temp.ws() and type = 'role_change'
      and subject_member_id = pg_temp.member('n1')
      and payload->>'invitation' = 'true' and status = 'applied'),
  2, 'each recorded as given through the invitation');

update public.members set status = 'paused' where id = pg_temp.member('n1');
update public.members set status = 'active' where id = pg_temp.member('n1');
select is(
  (select count(*)::int from public.events
    where workspace_id = pg_temp.ws() and type = 'role_change'
      and subject_member_id = pg_temp.member('n1')),
  2, 'and only once: coming back from a pause gives nothing twice');

-- The delegate loses the board role before the second person arrives.
select pg_temp.act_as('owner');
select public.assign_workspace_role(pg_temp.member('dele'),
  (select id from public.workspace_roles where workspace_id = pg_temp.ws() and key = 'bureau'), false);
select pg_temp.redeem(current_setting('deskilo.inv.c2'), 'n2', 'active');
select is(pg_temp.roles_of('n2'), '-',
  'an inviter who lost the right to give a role gives nothing on the day '
  'the invitation is used');

select * from finish();
rollback;
