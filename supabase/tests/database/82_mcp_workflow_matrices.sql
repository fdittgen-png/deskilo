-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1622 #1623 #1624: the MCP workflow matrices. An expired confirmation
-- runs nothing; a sequential policy counts an out-of-turn decision; a
-- quorum holds a void until the second person decides in the app; the
-- owner cannot be paused through MCP; a custom role without the permission
-- is refused before anyone is asked.
begin;

-- 0340 — assistants act only for Google accounts: every test user this
-- file creates gets a Google identity (a trigger inside this transaction,
-- rolled back with it).
create function public.test_google_identity() returns trigger language plpgsql as $g$
begin
  insert into auth.identities (id, provider_id, user_id, identity_data, provider, created_at, updated_at)
  values (gen_random_uuid(), 'google-' || new.id, new.id,
          jsonb_build_object('sub', 'google-' || new.id), 'google', now(), now());
  return new;
end
$g$;
create trigger zz_test_google_identity after insert on auth.users
  for each row execute function public.test_google_identity();
select plan(13);

create function pg_temp.act_as(p_user uuid, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'amr', jsonb_build_array(jsonb_build_object('method', 'oauth')), 'client_id', p_client))::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.call(p_user uuid, p_op text, p_args jsonb, p_request uuid) returns jsonb language plpgsql as $$
begin
  perform pg_temp.act_as(p_user, 'claude-test');
  return public.mcp_execute_v1(current_setting('t.i')::uuid, current_setting('t.a')::uuid, p_op, p_args, p_request);
end;
$$;
create function pg_temp.confirm_and_run(p_user uuid, p_op text, p_args jsonb, p_request uuid) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  v := pg_temp.call(p_user, p_op, p_args, p_request);
  if v->>'status' <> 'requires_confirmation' then return v; end if;
  perform pg_temp.act_as(p_user);
  perform public.mcp_confirm_action((v->'data'->>'confirmation_id')::uuid, true);
  return pg_temp.call(p_user, p_op, p_args, p_request);
end;
$$;
-- Seeded as postgres: eligibility, a connection and its consent.
create function pg_temp.connect(p_user uuid, p_ops text[]) returns void language plpgsql as $$
begin
  insert into public.mcp_eligibility_grants (installation_id, binding_id, local_user_id, decision_id, decision, status, decided_by, expires_at)
  select public.installation_id(), id, local_user_id, gen_random_uuid(), 'approved', 'active', local_user_id, now() + interval '30 days'
    from public.identity_bindings where local_user_id = p_user and status = 'active';
  insert into public.mcp_connections (installation_id, local_user_id, binding_id, client_id)
  select public.installation_id(), local_user_id, id, 'claude-test' from public.identity_bindings
   where local_user_id = p_user and status = 'active';
  insert into public.mcp_connection_scopes (connection_id, workspace_id, operations, target_ceiling)
  select id, current_setting('t.a')::uuid, p_ops, 'workspace' from public.mcp_connections where local_user_id = p_user;
end;
$$;

select set_config('t.i', public.installation_id()::text, true);
select set_config('t.ops', 'request_subscription_change,request_member_status_change,request_invoice_void,respond_to_validation', true);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select ('00000000-0000-4000-8000-0000000298' || s)::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated',
       'authenticated', s || '@m298.deskilo.test', '', now(), now(), now()
  from unnest(array['a1', 'b2', 'c3', 'd4', 'e5']) s;
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
insert into public.mcp_clients (client_id, name) values ('claude-test', 'Test assistant') on conflict do nothing;
update public.mcp_runtime set enabled = true;
select pg_temp.act_as('00000000-0000-4000-8000-0000000298a1');
select public.finalize_identity_binding();
select set_config('t.a', public.create_workspace('MCP W 298', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000000298e5');
select public.finalize_identity_binding();
reset role;
update public.workspaces set street = '1 Fixture Street', city = 'Fixtureville', feature_flags = coalesce(feature_flags, '{}'::jsonb)
  || '{"mcpAccess": true, "invoicing": true, "moneyTab": true, "adminInvoicing": true, "customRoles": true}'
 where id = current_setting('t.a')::uuid;
insert into public.members (workspace_id, user_id, status, is_admin, subscription_pct)
values (current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000000298b2', 'active', true, 100),
       (current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000000298c3', 'active', true, 100),
       (current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000000298d4', 'active', false, 100),
       (current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000000298e5', 'active', false, 100);
select set_config('t.' || right(user_id::text, 2), id::text, true)
  from public.members where workspace_id = current_setting('t.a')::uuid;
insert into public.workspace_mcp_policies (workspace_id, installation_id, revision, enabled, operations, target_ceiling)
values (current_setting('t.a')::uuid, public.installation_id(), 1, true, string_to_array(current_setting('t.ops'), ','), 'workspace');
select pg_temp.connect('00000000-0000-4000-8000-0000000298a1', string_to_array(current_setting('t.ops'), ','));
select pg_temp.connect('00000000-0000-4000-8000-0000000298e5', string_to_array(current_setting('t.ops'), ','));
-- b2 comes first, the owner second: the only order a policy can state.
insert into public.validation_policies (workspace_id, event_type, required_count, validator_scope, eligible_admin_ids, sequential)
values (current_setting('t.a')::uuid, 'subscription_change', 2, 'listed',
        array[current_setting('t.b2')::uuid, current_setting('t.a1')::uuid], true);
insert into public.validation_policies (workspace_id, event_type, required_count, admins_may_validate, validator_scope)
values (current_setting('t.a')::uuid, 'invoice_void', 2, true, 'admins');
insert into public.workspace_roles (workspace_id, key, permissions)
values (current_setting('t.a')::uuid, 'reception', array['viewFinances']);
insert into public.workspace_role_members (workspace_id, role_id, member_id)
select current_setting('t.a')::uuid, id, current_setting('t.e5')::uuid
  from public.workspace_roles where workspace_id = current_setting('t.a')::uuid and key = 'reception';

-- 1. #1624: a confirmation past its expiry cannot be given, and the retry runs nothing.
select set_config('t.x1', pg_temp.call('00000000-0000-4000-8000-0000000298a1', 'request_subscription_change',
  jsonb_build_object('member_id', current_setting('t.d4'), 'pct', 50), '00000000-0000-4000-8000-0000000298f1')::text, true);
reset role;
update public.mcp_action_confirmations set expires_at = now() - interval '1 second'
 where id = (current_setting('t.x1')::jsonb->'data'->>'confirmation_id')::uuid;
select pg_temp.act_as('00000000-0000-4000-8000-0000000298a1');
select set_config('t.x2', public.mcp_confirm_action((current_setting('t.x1')::jsonb->'data'->>'confirmation_id')::uuid, true)::text, true);
select set_config('t.x3', pg_temp.call('00000000-0000-4000-8000-0000000298a1', 'request_subscription_change',
  jsonb_build_object('member_id', current_setting('t.d4'), 'pct', 50), '00000000-0000-4000-8000-0000000298f1')::text, true);
reset role;
select is(current_setting('t.x2')::jsonb->>'status', 'expired', 'an expired confirmation cannot be given');
select is(current_setting('t.x3')::jsonb->>'status' || '/' || (current_setting('t.x3')::jsonb->'error'->>'code'),
  'denied/confirmation_expired', 'and the retry is denied as expired');
select is((select subscription_pct from public.members where id = current_setting('t.d4')::uuid)
          + (select count(*)::int from public.events where workspace_id = current_setting('t.a')::uuid
               and type = 'subscription_change'), 100, 'nothing ran: no change, no event');

-- 2. #1624: respond_to_event does not enforce a turn order under sequential;
-- it stamps payload.validation_stage and still needs required_count accepts.
-- So the owner (second in the list) deciding first is recorded, not refused.
select pg_temp.act_as('00000000-0000-4000-8000-0000000298c3');
select set_config('t.ev', public.request_subscription_change(current_setting('t.d4')::uuid, 75)->>'event_id', true);
select set_config('t.s1', pg_temp.confirm_and_run('00000000-0000-4000-8000-0000000298a1', 'respond_to_validation',
  jsonb_build_object('event_id', current_setting('t.ev'), 'accept', true), '00000000-0000-4000-8000-0000000298f2')::text, true);
reset role;
select is(current_setting('t.s1')::jsonb->>'status' || '/' || (current_setting('t.s1')::jsonb->'data'->>'decision_recorded'),
  'pending_validation/true', 'an out-of-turn decision is recorded and the event stays pending');
select is((select payload->>'validation_stage' from public.events where id = current_setting('t.ev')::uuid), '2',
  'sequential stamps the next stage');
select pg_temp.act_as('00000000-0000-4000-8000-0000000298b2');
select public.respond_to_event(current_setting('t.ev')::uuid, true);
reset role;
select is((select subscription_pct from public.members where id = current_setting('t.d4')::uuid), 75,
  'the first-listed validator completes it afterwards');

-- 3. #1622: a void through MCP under a quorum of two waits for the second person.
select pg_temp.act_as('00000000-0000-4000-8000-0000000298a1');
select set_config('t.inv', public.request_invoice_issue(current_setting('t.a')::uuid, current_setting('t.d4')::uuid,
  to_char(now(), 'YYYY-MM'), 'full', false, true)->>'invoice_id', true);
select set_config('t.v1', pg_temp.confirm_and_run('00000000-0000-4000-8000-0000000298a1', 'request_invoice_void',
  jsonb_build_object('invoice_id', current_setting('t.inv'), 'reason', 'duplicate'), '00000000-0000-4000-8000-0000000298f3')::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000000298b2');
select public.respond_to_event((current_setting('t.v1')::jsonb->'data'->>'event_id')::uuid, true);
reset role;
select is(current_setting('t.v1')::jsonb->>'status', 'pending_validation', 'a void under a quorum is pending');
select is((select voided_at is null from public.invoices where id = current_setting('t.inv')::uuid), true,
  'one of two approvals leaves the invoice as it was');
select pg_temp.act_as('00000000-0000-4000-8000-0000000298c3');
select public.respond_to_event((current_setting('t.v1')::jsonb->'data'->>'event_id')::uuid, true);
reset role;
select is((select voided_at is not null from public.invoices where id = current_setting('t.inv')::uuid), true,
  'the second person in the app voids it');

-- 4. #1623: the owner cannot be paused through MCP; a custom role without
-- manageMembers is refused, and the same call with it is put to its human.
select set_config('t.o1', pg_temp.confirm_and_run('00000000-0000-4000-8000-0000000298a1', 'request_member_status_change',
  jsonb_build_object('member_id', current_setting('t.a1'), 'status', 'paused'), '00000000-0000-4000-8000-0000000298f4')::text, true);
select set_config('t.r1', pg_temp.call('00000000-0000-4000-8000-0000000298e5', 'request_member_status_change',
  jsonb_build_object('member_id', current_setting('t.d4'), 'status', 'paused'), '00000000-0000-4000-8000-0000000298f5')::text, true);
reset role;
update public.workspace_roles set permissions = permissions || 'manageMembers'::text
 where workspace_id = current_setting('t.a')::uuid and key = 'reception';
select set_config('t.r2', pg_temp.call('00000000-0000-4000-8000-0000000298e5', 'request_member_status_change',
  jsonb_build_object('member_id', current_setting('t.d4'), 'status', 'paused'), '00000000-0000-4000-8000-0000000298f6')::text, true);
reset role;
select is(current_setting('t.o1')::jsonb->>'status' || '/' || (current_setting('t.o1')::jsonb->'data'->>'reason'),
  'conflict/an owner hands the workspace over first', 'the owner cannot be paused through MCP');
select is((select status from public.members where id = current_setting('t.a1')::uuid), 'active', 'and stays active');
select is(current_setting('t.r1')::jsonb->>'status' || '/' || (current_setting('t.r1')::jsonb->'error'->>'code'),
  'denied/forbidden', 'a custom role without manageMembers is refused');
select is(current_setting('t.r2')::jsonb->>'status', 'requires_confirmation', 'with it, the request is put to its human');

select * from finish();
rollback;
