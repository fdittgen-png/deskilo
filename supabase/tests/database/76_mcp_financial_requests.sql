-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1622 / 0289: the financial request tools refuse bad arguments before a
-- human is asked, stay in their workspace, and read the invoice back.
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
select plan(8);

create function pg_temp.act_as(p_user uuid, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'amr', jsonb_build_array(jsonb_build_object('method', 'oauth')), 'client_id', p_client))::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.call(p_op text, p_args jsonb, p_request uuid) returns jsonb language sql as $$
  select public.mcp_execute_v1(current_setting('t.i')::uuid, current_setting('t.a')::uuid, p_op, p_args, p_request);
$$;

select set_config('t.i', public.installation_id()::text, true);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000000289a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'o1622@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000000289a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1622@deskilo.test', '', now(), now(), now());
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
insert into public.mcp_clients (client_id, name) values ('claude-test', 'Test assistant') on conflict do nothing;
update public.mcp_runtime set enabled = true;
select pg_temp.act_as('00000000-0000-4000-8000-0000000289a1');
select public.finalize_identity_binding();
select set_config('t.a', public.create_workspace('MCP F', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"mcpAccess": true, "invoicing": true, "moneyTab": true}'
 where id = current_setting('t.a')::uuid;
insert into public.members (workspace_id, user_id, status, subscription_pct)
values (current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000000289a2', 'active', 100);
select set_config('t.m', (select id::text from public.members where workspace_id = current_setting('t.a')::uuid
  and user_id = '00000000-0000-4000-8000-0000000289a2'), true);
insert into public.mcp_eligibility_grants (installation_id, binding_id, local_user_id, decision_id, decision, status, decided_by, expires_at)
select public.installation_id(), id, local_user_id, gen_random_uuid(), 'approved', 'active', local_user_id, now() + interval '30 days'
  from public.identity_bindings where local_user_id = '00000000-0000-4000-8000-0000000289a1' and status = 'active';
insert into public.workspace_mcp_policies (workspace_id, installation_id, revision, enabled, operations, target_ceiling)
values (current_setting('t.a')::uuid, public.installation_id(), 1, true, array['request_invoice_issue','request_invoice_void','request_refund'], 'workspace');
insert into public.mcp_connections (installation_id, local_user_id, binding_id, client_id)
select public.installation_id(), local_user_id, id, 'claude-test' from public.identity_bindings
 where local_user_id = '00000000-0000-4000-8000-0000000289a1' and status = 'active';
insert into public.mcp_connection_scopes (connection_id, workspace_id, operations, target_ceiling)
select id, current_setting('t.a')::uuid, array['request_invoice_issue','request_invoice_void','request_refund'], 'workspace'
  from public.mcp_connections where local_user_id = '00000000-0000-4000-8000-0000000289a1';

select pg_temp.act_as('00000000-0000-4000-8000-0000000289a1', 'claude-test');
select set_config('t.p', to_char(now(), 'YYYY-MM'), true);
select set_config('t.r1', pg_temp.call('request_invoice_issue', jsonb_build_object('member_id', current_setting('t.m'),
  'period', current_setting('t.p')), '00000000-0000-4000-8000-00000000f101')::text, true);
select set_config('t.bad', pg_temp.call('request_invoice_void', jsonb_build_object('invoice_id', gen_random_uuid(),
  'reason', 'x'), gen_random_uuid())::text, true);
select set_config('t.per', pg_temp.call('request_invoice_issue', jsonb_build_object('member_id', current_setting('t.m'),
  'period', '2026-13'), gen_random_uuid())::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000000289a1');
select public.mcp_confirm_action((current_setting('t.r1')::jsonb->'data'->>'confirmation_id')::uuid, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000000289a1', 'claude-test');
select set_config('t.r2', pg_temp.call('request_invoice_issue', jsonb_build_object('member_id', current_setting('t.m'),
  'period', current_setting('t.p')), '00000000-0000-4000-8000-00000000f101')::text, true);
select set_config('t.r3', pg_temp.call('request_invoice_issue', jsonb_build_object('member_id', current_setting('t.m'),
  'period', current_setting('t.p')), '00000000-0000-4000-8000-00000000f101')::text, true);
reset role;

select is(current_setting('t.r1')::jsonb->>'status', 'requires_confirmation', 'an invoice issue asks its human first');
select is(current_setting('t.per')::jsonb->>'status', 'validation_error', 'month 13 is refused before anyone is asked');
select is((select count(*)::int from public.mcp_action_confirmations
            where request_id = (current_setting('t.per')::jsonb->>'request_id')::uuid), 0, 'and no confirmation exists for it');
select is(current_setting('t.bad')::jsonb->>'status', 'not_found', 'an invoice outside the workspace is not found');
select is(current_setting('t.r2')::jsonb->>'status', 'completed', 'the confirmed request runs');
select is(current_setting('t.r2')::jsonb->'data'->>'invoice_number',
  (select number from public.invoices where id = (current_setting('t.r2')::jsonb->'data'->>'invoice_id')::uuid),
  'and reads the issued invoice back');
select is(current_setting('t.r3')::jsonb->'data'->>'invoice_id', current_setting('t.r2')::jsonb->'data'->>'invoice_id',
  'a retry answers the same invoice');
select is((select count(*)::int from public.invoices where workspace_id = current_setting('t.a')::uuid), 1,
  'one invoice, however often it is sent');

select * from finish();
rollback;
