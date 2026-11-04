-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3278 (0666) -- direct access, and the privacy incident.
--   * with privacy.member_self_service on (the default) a member exports their
--     own data; with it off the SERVER refuses the export and the erasure
--     (42501, privacy_self_service_off) while an owner, an admin through
--     viewPersonalData and a Personal Data Admin are never blocked, and filing a
--     rights request stays open;
--   * record_privacy_incident: an owner or a managePrivacy holder only; an
--     unknown kind and an over-long note are refused; one applied event per
--     holder of managePrivacy (owner, co-owner, the role's member) and none to an
--     admin or a plain member; the type is read by managePrivacy only.
begin;
select plan(26);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.u(p text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000003279' || p)::uuid
$$;
create function pg_temp.ws() returns uuid language sql as $$
  select current_setting('deskilo.ps.ws')::uuid
$$;
-- The export as a user: its error text, or '' when it answered.
create function pg_temp.export_as(p_user text) returns text language plpgsql as $$
declare v text := '';
begin
  perform pg_temp.act_as(pg_temp.u(p_user));
  begin
    perform public.export_my_data(pg_temp.ws());
  exception when others then
    v := sqlstate || ' ' || sqlerrm;
  end;
  reset role;
  return v;
end $$;
create function pg_temp.erase_as(p_user text) returns text language plpgsql as $$
declare v text := '';
begin
  perform pg_temp.act_as(pg_temp.u(p_user));
  begin
    perform public.erase_my_membership(pg_temp.ws());
  exception when others then
    v := sqlstate || ' ' || sqlerrm;
  end;
  reset role;
  return v;
end $$;
create function pg_temp.incident_as(p_user text, p_kind text, p_note text default '') returns text language plpgsql as $$
declare v text;
begin
  perform pg_temp.act_as(pg_temp.u(p_user));
  begin
    v := public.record_privacy_incident(pg_temp.ws(), p_kind, p_note)::text;
  exception when others then
    v := sqlstate;
  end;
  reset role;
  return v;
end $$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
select pg_temp.u(s), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       s || '@privacy-self.test', '', now(), now(), now()
  from unnest(array['c1', 'c2', 'c3', 'c4', 'c5', 'c6']) s;
-- c1 owner, c2 member, c3 co-owner, c4 admin, c5 role holder, c6 member to erase.

select pg_temp.act_as(pg_temp.u('c1'));
select set_config('deskilo.ps.ws', public.create_workspace(
  'Privacy self-service', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces set feature_flags = feature_flags || '{"customRoles":true,"configurableSettings":true}'
 where id = pg_temp.ws();
insert into public.members (workspace_id, user_id, status, is_admin, co_owner) values
  (pg_temp.ws(), pg_temp.u('c2'), 'active', false, 'none'),
  (pg_temp.ws(), pg_temp.u('c3'), 'active', false, 'active'),
  (pg_temp.ws(), pg_temp.u('c4'), 'active', true, 'none'),
  (pg_temp.ws(), pg_temp.u('c5'), 'active', false, 'none'),
  (pg_temp.ws(), pg_temp.u('c6'), 'active', false, 'none');
insert into public.workspace_role_members (workspace_id, role_id, member_id)
select pg_temp.ws(), r.id, m.id
  from public.workspace_roles r, public.members m
 where r.workspace_id = pg_temp.ws() and r.key = 'personal_data_admin'
   and m.workspace_id = pg_temp.ws() and m.user_id = pg_temp.u('c5');
-- END FIXTURE

-- On by default: a member exports directly.
select is(pg_temp.export_as('c2'), '', 'default: a member exports their own data');

-- Off: the server refuses the member, not the controllers.
select pg_temp.act_as(pg_temp.u('c1'));
select public.set_setting(pg_temp.ws(), 'privacy.member_self_service', 'false'::jsonb, 'test');
reset role;
select ok(pg_temp.export_as('c2') like '42501 privacy_self_service_off:%',
  'off: a member''s export is refused by the server');
select ok(pg_temp.erase_as('c2') like '42501 privacy_self_service_off:%',
  'off: a member''s erasure is refused by the server');
select is(pg_temp.export_as('c1'), '', 'off: the owner still exports');
select is(pg_temp.export_as('c4'), '', 'off: an admin (viewPersonalData) still exports');
select is(pg_temp.export_as('c5'), '', 'off: a Personal Data Admin still exports');

select pg_temp.act_as(pg_temp.u('c2'));
select is((public.submit_rights_request(pg_temp.ws(), 'access', 'my data', gen_random_uuid()) ->> 'status'),
  'received', 'off: filing a rights request stays open');
reset role;

-- On again: nothing is refused.
select pg_temp.act_as(pg_temp.u('c1'));
select public.set_setting(pg_temp.ws(), 'privacy.member_self_service', 'true'::jsonb, 'test');
reset role;
select is(pg_temp.export_as('c2'), '', 'on again: the member exports');
select is(pg_temp.erase_as('c6'), '', 'on: a member erases their own membership');

-- The incident.
select is(pg_temp.incident_as('c2', 'data_breach'), '42501', 'a plain member cannot record an incident');
select is(pg_temp.incident_as('c4', 'data_breach'), '42501', 'an admin without managePrivacy cannot');
select is(pg_temp.incident_as('c5', 'invented'), '22023', 'an unknown kind is refused');
select is(pg_temp.incident_as('c5', 'other', repeat('x', 1001)), '22023', 'a note over 1000 characters is refused');
select is(pg_temp.incident_as('c5', 'data_breach', 'a laptop was lost'), '3',
  'the Personal Data Admin records it: three holders are told (owner, co-owner, role holder)');
select is((select array_agg(u.user_id order by u.user_id)
             from public.events e join public.members u on u.id = e.subject_member_id
            where e.workspace_id = pg_temp.ws() and e.type = 'privacy_incident' and e.status = 'applied'),
  array[pg_temp.u('c1'), pg_temp.u('c3'), pg_temp.u('c5')],
  'one applied event each, for the owner, the co-owner and the role holder; none for the admin or a member');
select is(pg_temp.incident_as('c1', 'wrong_invoice'), '3', 'the owner records one too');
select is(public.event_type_view_permissions('privacy_incident'), array['managePrivacy'],
  'the event type is read by managePrivacy');
select is((select count(*)::int from public.events
            where workspace_id = pg_temp.ws() and type = 'privacy_incident'
              and payload ->> 'note' = 'a laptop was lost'), 3, 'the note travels in the payload');

-- Who can READ it: events_select also admits the actor or subject and any member
-- under a wildcard validation policy; the restrictive policy narrows the type to
-- the holders of the right now.
-- A wildcard validation policy open to every member: the member may validate
-- ANY event type (0144 lets such a member read those events), and still reads
-- no incident.
insert into public.validation_policies (workspace_id, event_type, validator_scope)
values (pg_temp.ws(), null, 'members');
select pg_temp.act_as(pg_temp.u('c2'));
select ok(public.may_validate_event_type(pg_temp.ws(), 'privacy_incident'),
  'the plain member satisfies may_validate_event_type for the incident under the wildcard members policy');
select is((select count(*)::int from public.events where type = 'privacy_incident'), 0,
  'and still reads no incident event: the restrictive policy beats the validator rule');
reset role;
select pg_temp.act_as(pg_temp.u('c4'));
select is((select count(*)::int from public.events where type = 'privacy_incident'), 0,
  'an admin without managePrivacy reads none');
reset role;
select pg_temp.act_as(pg_temp.u('c5'));
select ok((select count(*)::int from public.events where type = 'privacy_incident') > 0,
  'the Personal Data Admin reads them');
reset role;
-- The role is taken away: the same person is still the subject of two events,
-- and reads none.
delete from public.workspace_role_members rm using public.members m
 where rm.member_id = m.id and m.workspace_id = pg_temp.ws() and m.user_id = pg_temp.u('c5');
select pg_temp.act_as(pg_temp.u('c5'));
select is((select count(*)::int from public.events where type = 'privacy_incident'), 0,
  'a former holder, still the subject of the events, reads none');
reset role;

-- A co-owner whose workspace has an EXPLICIT list without managePrivacy does not
-- hold the right: they cannot record an incident, are not told, and read none.
update public.workspaces
   set role_permissions = '{"co_owner": ["viewPersonalData"]}'::jsonb
 where id = pg_temp.ws();
select pg_temp.act_as(pg_temp.u('c3'));
select is((select count(*)::int from public.events where type = 'privacy_incident'), 0,
  'such a co-owner reads no incident event');
reset role;
select is(pg_temp.incident_as('c3', 'other', 'tried'), '42501',
  'cannot record one');
select is(pg_temp.incident_as('c1', 'other', 'owner again'), '1',
  'the owner records one, and only the owner is told: the role holder lost the role and the co-owner has no right');

select * from finish();
rollback;
