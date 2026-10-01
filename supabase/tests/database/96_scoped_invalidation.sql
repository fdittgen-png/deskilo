-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1631 / 0310: every revocation ends exactly its own scope. One human
-- (H) in workspaces A and B, a second person (P) in A, two assistants.
-- A pause or a policy switched off RESTRICTS and lifts; withdrawing one
-- workspace, leaving it, a revoked eligibility, a revoked assistant, an
-- unlinked identity and an authority reset REVOKE, and nothing revives
-- them except the legitimate path (approval, fresh consent). A replayed
-- request id is re-authorised and, once allowed again, answers its stored
-- outcome and never acts twice. Ownership moves without taking the
-- workspace policy or anybody's eligibility with it; administrators leave
-- one at a time; a configuration export carries no authority. Callers run
-- as `authenticated`; seeds and read-backs run as postgres.
begin;
select plan(71);

create function pg_temp.act_as(p_user uuid, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2', 'client_id', p_client))::text, true);
  execute 'set local role authenticated';
end;
$$;
-- The dispatcher's answer for one read, as the delegated token of p_user.
create function pg_temp.cap(p_user uuid, p_client text, p_ws text) returns text language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.act_as(p_user, p_client);
  r := public.mcp_execute_v1(current_setting('t.i')::uuid, current_setting('t.' || p_ws)::uuid,
                             'get_capabilities', '{}'::jsonb, null);
  execute 'reset role';
  return coalesce(r->'error'->>'code', r->>'status');
end;
$$;
-- One reservation, by request id, as H through the first assistant.
create function pg_temp.book(p_req uuid) returns jsonb language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.act_as('00000000-0000-4000-8000-0000001631a3', 'claude-1631');
  r := public.mcp_execute_v1(current_setting('t.i')::uuid, current_setting('t.a')::uuid, 'create_reservation',
         jsonb_build_object('seat_id', current_setting('t.seat'),
                            'starts_at', current_setting('t.am_s'), 'ends_at', current_setting('t.am_e')), p_req);
  execute 'reset role';
  return r;
end;
$$;
-- The native consent flow: prepare, then finalise.
create function pg_temp.consent(p_user uuid, p_client text, p_authz text, p_scopes jsonb) returns text language plpgsql as $$
declare
  v text;
begin
  perform pg_temp.act_as(p_user);
  perform public.mcp_prepare_connection(p_client, p_authz, p_scopes);
  v := public.mcp_finalize_connection(p_authz)->>'status';
  execute 'reset role';
  return v;
end;
$$;
create function pg_temp.bookings() returns int language sql as $$
  select count(*)::int from public.reservations r join public.members m on m.id = r.member_id
   where r.workspace_id = current_setting('t.a')::uuid and m.user_id = '00000000-0000-4000-8000-0000001631a3';
$$;

-- ── seed ─────────────────────────────────────────────────────────────
select set_config('t.i', public.installation_id()::text, true);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000001631a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner1-1631@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000001631a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner2-1631@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000001631a3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'human-1631@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000001631a4', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'other-1631@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000001631a5', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin1-1631@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000001631a6', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin2-1631@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000001631a7', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'again-1631@deskilo.test', '', now(), now(), now());
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
insert into public.mcp_clients (client_id, name) values ('claude-1631', 'First assistant'), ('other-1631', 'Second assistant')
  on conflict (client_id) do update set status = 'active';
update public.mcp_runtime set enabled = true;
update public.mcp_limits set calls_per_minute = 1000, mutations_per_minute = 100;

select pg_temp.act_as('00000000-0000-4000-8000-0000001631a1');
select public.finalize_identity_binding();
select set_config('t.a', public.create_workspace('Scope A', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select public.apply_workspace_template(current_setting('t.a')::uuid, (select id from public.workspace_templates where key = 'tiny'));
select set_config('t.b', public.create_workspace('Scope B', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a2'); select public.finalize_identity_binding();
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a3'); select public.finalize_identity_binding();
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a4'); select public.finalize_identity_binding();
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a5'); select public.finalize_identity_binding();
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a6'); select public.finalize_identity_binding();
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a7'); select public.finalize_identity_binding();
reset role;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"mcpAccess": true}',
  booking_rules = booking_rules || '{"open_weekdays":[1,2,3,4,5,6,7],"granularity":"half_day","work_start_minutes":480,"half_boundary_minutes":720,"work_end_minutes":1080}'
 where id in (current_setting('t.a')::uuid, current_setting('t.b')::uuid);
insert into public.members (workspace_id, user_id, status) values
 (current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000001631a2', 'active'),
 (current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000001631a3', 'active'),
 (current_setting('t.b')::uuid, '00000000-0000-4000-8000-0000001631a3', 'active'),
 (current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000001631a4', 'active');
select public.operator_grant_database_admin('00000000-0000-4000-8000-0000001631a5', true);
select public.operator_grant_database_admin('00000000-0000-4000-8000-0000001631a6', false);
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a5');
select public.decide_mcp_eligibility('00000000-0000-4000-8000-0000001631a3', '00000000-0000-4000-8000-000000163101', true);
select public.decide_mcp_eligibility('00000000-0000-4000-8000-0000001631a4', '00000000-0000-4000-8000-000000163102', true);
select public.decide_mcp_eligibility('00000000-0000-4000-8000-0000001631a7', '00000000-0000-4000-8000-000000163103', true);
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a1');
select public.save_mcp_policy(current_setting('t.a')::uuid, 0, '00000000-0000-4000-8000-000000163111', true,
  array['create_reservation', 'get_capabilities'], 'own');
select public.save_mcp_policy(current_setting('t.b')::uuid, 0, '00000000-0000-4000-8000-000000163112', true,
  array['get_capabilities'], 'own');
reset role;
select pg_temp.consent('00000000-0000-4000-8000-0000001631a3', 'claude-1631', 'authz-1631-h1', jsonb_build_array(
  jsonb_build_object('workspace_id', current_setting('t.a'), 'operations', '["get_capabilities","create_reservation"]'::jsonb),
  jsonb_build_object('workspace_id', current_setting('t.b'), 'operations', '["get_capabilities"]'::jsonb)));
select pg_temp.consent('00000000-0000-4000-8000-0000001631a3', 'other-1631', 'authz-1631-h2', jsonb_build_array(
  jsonb_build_object('workspace_id', current_setting('t.a'), 'operations', '["get_capabilities"]'::jsonb)));
select pg_temp.consent('00000000-0000-4000-8000-0000001631a4', 'claude-1631', 'authz-1631-p1', jsonb_build_array(
  jsonb_build_object('workspace_id', current_setting('t.a'), 'operations', '["get_capabilities"]'::jsonb)));
select set_config('t.seat', (select id::text from public.seats where workspace_id = current_setting('t.a')::uuid order by name limit 1), true);
select set_config('t.day', ((now() at time zone 'Europe/Paris')::date + 2)::text, true);
select set_config('t.am_s', to_jsonb((current_setting('t.day') || ' 08:00')::timestamp at time zone 'Europe/Paris')->>0, true);
select set_config('t.am_e', to_jsonb((current_setting('t.day') || ' 12:00')::timestamp at time zone 'Europe/Paris')->>0, true);

-- ── 1. positive controls ────────────────────────────────────────────
select is(pg_temp.cap('00000000-0000-4000-8000-0000001631a3', 'claude-1631', 'a'), 'completed', 'H reaches A');
select is(pg_temp.cap('00000000-0000-4000-8000-0000001631a3', 'claude-1631', 'b'), 'completed', 'H reaches B');
select is(pg_temp.cap('00000000-0000-4000-8000-0000001631a4', 'claude-1631', 'a'), 'completed', 'P reaches A');
select set_config('t.r1', pg_temp.book('00000000-0000-4000-8000-0000001631e1')::text, true);
select is(current_setting('t.r1')::jsonb->>'status', 'completed', 'H books through the assistant');
select is(pg_temp.bookings(), 1, 'one real reservation');

-- ── 2. restriction lifts; it is not revocation ───────────────────────
update public.members set status = 'paused'
 where workspace_id = current_setting('t.a')::uuid and user_id = '00000000-0000-4000-8000-0000001631a3';
select is(pg_temp.cap('00000000-0000-4000-8000-0000001631a3', 'claude-1631', 'a'), 'not_a_member', 'a paused membership refuses A');
select is(pg_temp.cap('00000000-0000-4000-8000-0000001631a3', 'claude-1631', 'b'), 'completed', 'and leaves B alone');
select ok((select s.revoked_at is null from public.mcp_connection_scopes s join public.mcp_connections c on c.id = s.connection_id
            where c.local_user_id = '00000000-0000-4000-8000-0000001631a3' and c.client_id = 'claude-1631'
              and s.workspace_id = current_setting('t.a')::uuid), 'a pause keeps the consent record');
update public.members set status = 'active'
 where workspace_id = current_setting('t.a')::uuid and user_id = '00000000-0000-4000-8000-0000001631a3';
select is(pg_temp.cap('00000000-0000-4000-8000-0000001631a3', 'claude-1631', 'a'), 'completed', 'the pause lifted, A answers again');
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a1');
select public.save_mcp_policy(current_setting('t.b')::uuid, 1, '00000000-0000-4000-8000-000000163113', false,
  array['get_capabilities'], 'own');
select is(pg_temp.cap('00000000-0000-4000-8000-0000001631a3', 'claude-1631', 'b'), 'not_exposed', 'B switched off refuses B');
select is(pg_temp.cap('00000000-0000-4000-8000-0000001631a3', 'claude-1631', 'a'), 'completed', 'and only B');
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a1');
select public.save_mcp_policy(current_setting('t.b')::uuid, 2, '00000000-0000-4000-8000-000000163114', true,
  array['get_capabilities'], 'own');
select is(pg_temp.cap('00000000-0000-4000-8000-0000001631a3', 'claude-1631', 'b'), 'completed', 'B back on: the consent was never revoked');

-- ── 3. withdrawing one workspace, and the replay ─────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a3');
select set_config('t.w', public.revoke_mcp_workspace_scope('claude-1631', current_setting('t.a')::uuid)::text, true);
reset role;
select is(current_setting('t.w')::jsonb - 'client_id', jsonb_build_object('installation_id', current_setting('t.i'),
  'scope', 'workspace', 'workspaces', jsonb_build_array(current_setting('t.a')), 'connections', 0, 'status', 'revoked'),
  'the answer names the installation and exactly the workspace it ended');
select is(pg_temp.cap('00000000-0000-4000-8000-0000001631a3', 'claude-1631', 'a'), 'no_consent', 'A is gone for that assistant');
select is(pg_temp.cap('00000000-0000-4000-8000-0000001631a3', 'claude-1631', 'b'), 'completed', 'B stays');
select is(pg_temp.cap('00000000-0000-4000-8000-0000001631a3', 'other-1631', 'a'), 'completed', 'the other assistant keeps A');
select is(pg_temp.cap('00000000-0000-4000-8000-0000001631a4', 'claude-1631', 'a'), 'completed', 'P keeps A');
select is(pg_temp.book('00000000-0000-4000-8000-0000001631e1')->'error'->>'code', 'no_consent',
  'a replay is re-authorised: the stored answer is not handed out');
select is(pg_temp.consent('00000000-0000-4000-8000-0000001631a3', 'claude-1631', 'authz-1631-h3', jsonb_build_array(
  jsonb_build_object('workspace_id', current_setting('t.a'), 'operations', '["get_capabilities","create_reservation"]'::jsonb))),
  'finalized', 'H consents to A again');
select is(pg_temp.book('00000000-0000-4000-8000-0000001631e1')->'data'->>'reservation_id',
  current_setting('t.r1')::jsonb->'data'->>'reservation_id', 'the replay answers the stored outcome');
select is(pg_temp.bookings(), 1, 'and books nothing twice');

-- ── 4. leaving a workspace (native) ends that consent ────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a4');
select public.leave_workspace(current_setting('t.a')::uuid);
reset role;
select ok((select s.revoked_at is not null from public.mcp_connection_scopes s join public.mcp_connections c on c.id = s.connection_id
            where c.local_user_id = '00000000-0000-4000-8000-0000001631a4' and s.workspace_id = current_setting('t.a')::uuid),
  'leaving A revokes P''s consent to A');
select is(pg_temp.cap('00000000-0000-4000-8000-0000001631a3', 'claude-1631', 'a'), 'completed', 'H is untouched');
update public.members set status = 'active'
 where workspace_id = current_setting('t.a')::uuid and user_id = '00000000-0000-4000-8000-0000001631a4';
select is(pg_temp.cap('00000000-0000-4000-8000-0000001631a4', 'claude-1631', 'a'), 'no_consent',
  'rejoining does not revive the old consent');
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a4');
select is(public.my_database_capabilities()->>'mcp_eligibility', 'eligible', 'nor asks for another database approval');
reset role;
select pg_temp.consent('00000000-0000-4000-8000-0000001631a4', 'claude-1631', 'authz-1631-p2', jsonb_build_array(
  jsonb_build_object('workspace_id', current_setting('t.a'), 'operations', '["get_capabilities"]'::jsonb)));
select is(pg_temp.cap('00000000-0000-4000-8000-0000001631a4', 'claude-1631', 'a'), 'completed', 'fresh consent is enough');

-- ── 5. the database administrator revokes eligibility ────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a6');
select public.revoke_mcp_eligibility('00000000-0000-4000-8000-0000001631a3', 'test');
reset role;
select is(pg_temp.cap('00000000-0000-4000-8000-0000001631a3', 'claude-1631', 'a'), 'not_eligible', 'H is refused in A');
select is(pg_temp.cap('00000000-0000-4000-8000-0000001631a3', 'claude-1631', 'b'), 'not_eligible', 'and in B');
select is(pg_temp.cap('00000000-0000-4000-8000-0000001631a4', 'claude-1631', 'a'), 'completed', 'P is not');
select is((select count(*)::int from public.mcp_connections
            where local_user_id = '00000000-0000-4000-8000-0000001631a3' and status = 'active'), 0,
  'every connection of H on this database ended');
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a3');
select is((select count(*)::int from public.members where workspace_id = current_setting('t.a')::uuid
            and user_id = '00000000-0000-4000-8000-0000001631a3'), 1, 'the native session still reads its membership');
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a5');
select public.decide_mcp_eligibility('00000000-0000-4000-8000-0000001631a3', '00000000-0000-4000-8000-000000163104', true);
reset role;
select is(pg_temp.cap('00000000-0000-4000-8000-0000001631a3', 'claude-1631', 'a'), 'no_connection',
  'a new approval revives no old connection');
select pg_temp.consent('00000000-0000-4000-8000-0000001631a3', 'claude-1631', 'authz-1631-h4', jsonb_build_array(
  jsonb_build_object('workspace_id', current_setting('t.a'), 'operations', '["get_capabilities","create_reservation"]'::jsonb)));
select pg_temp.consent('00000000-0000-4000-8000-0000001631a3', 'other-1631', 'authz-1631-h6', jsonb_build_array(
  jsonb_build_object('workspace_id', current_setting('t.a'), 'operations', '["get_capabilities"]'::jsonb)));
select is(pg_temp.cap('00000000-0000-4000-8000-0000001631a3', 'claude-1631', 'a'), 'completed', 'approval plus fresh consent');
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a5');
select public.decide_mcp_eligibility('00000000-0000-4000-8000-0000001631a3', '00000000-0000-4000-8000-000000163105', true);
reset role;
select is(pg_temp.cap('00000000-0000-4000-8000-0000001631a3', 'claude-1631', 'a'), 'completed',
  'renewing a current approval ends no consent');

-- ── 6. ownership moves; the policy stays the workspace's ─────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a1');
select public.set_co_owner((select id from public.members where workspace_id = current_setting('t.a')::uuid
                              and user_id = '00000000-0000-4000-8000-0000001631a2'), 'passive');
select public.activate_co_owner((select id from public.members where workspace_id = current_setting('t.a')::uuid
                                   and user_id = '00000000-0000-4000-8000-0000001631a2'));
select public.leave_workspace(current_setting('t.a')::uuid);
select throws_ok(format($$select public.save_mcp_policy(%L, 1, '00000000-0000-4000-8000-000000163115', false, array['get_capabilities'], 'own')$$,
  current_setting('t.a')), 'only those who manage integrations configure MCP exposure', 'the departed owner edits nothing');
reset role;
select is((select enabled and operations = array['create_reservation', 'get_capabilities'] from public.workspace_mcp_policies
            where workspace_id = current_setting('t.a')::uuid), true, 'the policy outlives its author');
select is(pg_temp.cap('00000000-0000-4000-8000-0000001631a4', 'claude-1631', 'a'), 'completed', 'and nobody''s access moved');
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a2');
select is(public.save_mcp_policy(current_setting('t.a')::uuid, 0, '00000000-0000-4000-8000-000000163116', true,
  array['get_capabilities'], 'own')->>'reason', 'stale_revision', 'a stale edit fails under the new owner too');
select is(public.save_mcp_policy(current_setting('t.a')::uuid, 1, '00000000-0000-4000-8000-000000163117', true,
  array['get_capabilities'], 'own')->>'status', 'saved', 'the new owner narrows the policy');
reset role;
select is(pg_temp.book('00000000-0000-4000-8000-0000001631e2')->'error'->>'code', 'not_exposed', 'the narrowing takes effect');
select is(pg_temp.cap('00000000-0000-4000-8000-0000001631a3', 'claude-1631', 'a'), 'completed', 'within what is still exposed');
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a2');
select public.save_mcp_policy(current_setting('t.a')::uuid, 2, '00000000-0000-4000-8000-000000163118', true,
  array['create_reservation', 'get_capabilities'], 'own');

-- ── 7. a configuration export carries no authority ───────────────────
select set_config('t.cfg', public.export_workspace_configuration(current_setting('t.a')::uuid)::text, true);
select set_config('t.c', public.create_workspace('Scope C', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select public.import_workspace_configuration(current_setting('t.c')::uuid, current_setting('t.cfg')::jsonb, 'merge');
reset role;
select ok(position('claude-1631' in current_setting('t.cfg')) = 0
          and position('00000000-0000-4000-8000-0000001631e1' in current_setting('t.cfg')) = 0
          and position('00000000-0000-4000-8000-000000163101' in current_setting('t.cfg')) = 0
          and position('mcp_polic' in current_setting('t.cfg')) = 0,
  'the export names no assistant, request id, decision or policy');
select ok(public.feature_effective(current_setting('t.c')::uuid, 'mcpAccess')
          and not exists (select 1 from public.workspace_mcp_policies where workspace_id = current_setting('t.c')::uuid),
  'the imported flag comes without a policy');
insert into public.members (workspace_id, user_id, status)
values (current_setting('t.c')::uuid, '00000000-0000-4000-8000-0000001631a4', 'active');
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a4');
select ok(not (public.mcp_consent_options()->'workspaces' @> jsonb_build_array(jsonb_build_object('workspace_id', current_setting('t.c')))),
  'so the copy offers nothing to consent to');
reset role;

-- ── 8. the operator revokes an assistant for the instance ────────────
select public.operator_approve_mcp_client('claude-1631', 'First assistant', false);
select is(pg_temp.cap('00000000-0000-4000-8000-0000001631a3', 'claude-1631', 'a'), 'no_connection', 'H loses it');
select is(pg_temp.cap('00000000-0000-4000-8000-0000001631a4', 'claude-1631', 'a'), 'no_connection', 'P loses it');
select is(pg_temp.cap('00000000-0000-4000-8000-0000001631a3', 'other-1631', 'a'), 'completed', 'the other assistant does not');
select public.operator_approve_mcp_client('claude-1631', 'First assistant', true);
select is(pg_temp.cap('00000000-0000-4000-8000-0000001631a3', 'claude-1631', 'a'), 'no_connection',
  'approving it again revives no connection');

-- ── 9. identity: relink and a recreated address ──────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a3');
select public.revoke_my_identity_binding();
reset role;
select is(pg_temp.cap('00000000-0000-4000-8000-0000001631a3', 'other-1631', 'a'), 'no_identity', 'unlinked: nothing');
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a3');
select public.finalize_identity_binding();
select is(public.my_database_capabilities()->>'mcp_eligibility', 'not_requested', 'a relink inherits no eligibility');
reset role;
select is((select count(*)::int from public.mcp_connections
            where local_user_id = '00000000-0000-4000-8000-0000001631a3' and status = 'active'), 0, 'nor any connection');
delete from auth.users where id = '00000000-0000-4000-8000-0000001631a7';
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000001631a8', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'again-1631@deskilo.test', '', now(), now(), now());
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a8');
select is(public.finalize_identity_binding()->>'status', 'verified', 'the same address registers again');
select is(public.my_database_capabilities()->>'mcp_eligibility', 'not_requested', 'as somebody new: no eligibility');
reset role;
select is((select count(*)::int from public.mcp_eligibility_grants where status = 'active'
            and local_user_id in ('00000000-0000-4000-8000-0000001631a7', '00000000-0000-4000-8000-0000001631a8')), 0,
  'the old approval went with the old account');
insert into public.members (workspace_id, user_id, status)
values (current_setting('t.b')::uuid, '00000000-0000-4000-8000-0000001631a4', 'active');
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a4');
select ok(public.mcp_consent_options()->'workspaces' @> jsonb_build_array(jsonb_build_object('workspace_id', current_setting('t.b')))
          and public.mcp_consent_options()->>'eligibility' = 'eligible',
  'a new workspace needs only consent: the database approval carries over');

-- ── 10. administrators leave one at a time ───────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a6');
select public.revoke_my_identity_binding();
reset role;
select is((select enabled from public.mcp_runtime), true, 'one administrator gone, the other still governs');
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a5');
select is(public.revoke_mcp_eligibility('00000000-0000-4000-8000-0000001631a4', 'still governed')->>'status', 'revoked',
  'the remaining administrator decides');
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a2');
select throws_ok($$select public.provision_database_admin('00000000-0000-4000-8000-0000001631a2')$$,
  'not a database administrator here', 'a workspace owner cannot appoint one');
reset role;
select throws_ok($$select public.operator_revoke_database_admin('00000000-0000-4000-8000-0000001631a5')$$,
  'the last database administrator cannot be removed; add a successor first', 'the last one is not removed');
delete from public.database_administrators where local_user_id = '00000000-0000-4000-8000-0000001631a5';
select is((select enabled from public.mcp_runtime), false, 'the last one''s account gone: MCP stops');
select throws_ok($$select public.operator_set_mcp_runtime(true)$$,
  'MCP stays off: no database administrator governs it; provision one first', 'and stays off without one');

-- ── 11. controlled restore: the authority reset and the epoch ────────
select public.operator_grant_database_admin('00000000-0000-4000-8000-0000001631a5', true);
update public.mcp_runtime set enabled = true;
select set_config('t.e0', (select epoch::text from public.mcp_runtime), true);
select throws_ok(format($$select public.operator_reset_mcp_authority(%L, 'drill')$$, current_setting('t.i')),
  'switch the MCP runtime off before resetting its authority', 'a reset needs the runtime off first');
update public.mcp_runtime set enabled = false;
select throws_ok($$select public.operator_reset_mcp_authority('00000000-0000-4000-8000-000000000000', 'drill')$$,
  format('this database is installation %s, not 00000000-0000-4000-8000-000000000000', current_setting('t.i')),
  'a copy of another installation is refused');
select is((public.operator_reset_mcp_authority(current_setting('t.i')::uuid, 'restore drill')->>'epoch')::int,
  current_setting('t.e0')::int + 1, 'the reset moves the epoch');
select is((select count(*)::int from public.mcp_connections where installation_id = current_setting('t.i')::uuid and status = 'active')
        + (select count(*)::int from public.mcp_eligibility_grants where installation_id = current_setting('t.i')::uuid and status = 'active')
        + (select count(*)::int from public.database_administrators where installation_id = current_setting('t.i')::uuid and status = 'active'),
  0, 'no copied connection, eligibility or administrator survives');
select ok(exists (select 1 from public.mcp_idempotency where request_id = '00000000-0000-4000-8000-0000001631e1')
          and exists (select 1 from public.identity_bindings where local_user_id = '00000000-0000-4000-8000-0000001631a3' and status = 'active')
          and exists (select 1 from public.workspace_mcp_policies where workspace_id = current_setting('t.a')::uuid and enabled),
  'identities, workspace policies and replay tombstones stay');
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a3', 'claude-1631');
select set_config('request.method', 'POST', true);
select set_config('request.path', '/rpc/mcp_execute_v1', true);
select set_config('request.headers', jsonb_build_object('x-deskilo-mcp-epoch', current_setting('t.e0'))::text, true);
select throws_ok($$select public.mcp_pre_request()$$, 'PGRST', null, 'an endpoint deployed for the old epoch is refused');
select set_config('request.headers', jsonb_build_object('x-deskilo-mcp-epoch', (current_setting('t.e0')::int + 1)::text)::text, true);
select lives_ok($$select public.mcp_pre_request()$$, 'the current epoch passes');
reset role;
select public.operator_grant_database_admin('00000000-0000-4000-8000-0000001631a5', true);
select public.operator_set_mcp_runtime(true);
select pg_temp.act_as('00000000-0000-4000-8000-0000001631a5');
select public.decide_mcp_eligibility('00000000-0000-4000-8000-0000001631a3', '00000000-0000-4000-8000-000000163106', true);
reset role;
select pg_temp.consent('00000000-0000-4000-8000-0000001631a3', 'claude-1631', 'authz-1631-h5', jsonb_build_array(
  jsonb_build_object('workspace_id', current_setting('t.a'), 'operations', '["get_capabilities","create_reservation"]'::jsonb)));
select is(pg_temp.book('00000000-0000-4000-8000-0000001631e1')->'data'->>'reservation_id',
  current_setting('t.r1')::jsonb->'data'->>'reservation_id', 're-enrolled: the old request id answers what it did');
select is(pg_temp.bookings(), 1, 'the reset never made an old mutation new');
select ok(exists (select 1 from public.database_authority_audit where action = 'authority_reset')
          and exists (select 1 from public.database_authority_audit where action = 'mcp_consent_invalidated'
                        and detail->>'reason' = 'membership_ended'),
  'every revocation left its audit row');

select * from finish();
rollback;
