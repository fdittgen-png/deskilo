-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1630: the MCP facade records every call it answers in mcp_usage and
-- refuses a call over a limit before any work. A read writes one row; the
-- eleventh mutation of a minute is rate_limited and changes nothing; reads
-- stay under their own limit; a replay is answered from idempotency even
-- at the limit and writes no row; a workspace's day refuses at its limit;
-- the table holds no argument, token or result.
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
select plan(12);

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
-- Usage rows seeded directly, as postgres, in the caller's current minute.
create function pg_temp.seed(p_user uuid, p_client text, p_mutation boolean, p_rows integer) returns void language sql as $$
  insert into public.mcp_usage (installation_id, workspace_id, local_user_id, client_id, operation, mutation, outcome)
  select public.installation_id(), current_setting('t.a')::uuid, p_user, p_client,
         case when p_mutation then 'request_subscription_change' else 'get_capabilities' end, p_mutation, 'completed'
    from generate_series(1, greatest(p_rows, 0));
$$;
create function pg_temp.usage(p_request uuid) returns integer language sql as $$
  select count(*)::integer from public.mcp_usage where request_id = p_request;
$$;

select set_config('t.i', public.installation_id()::text, true);
select set_config('t.ops', 'get_capabilities,request_subscription_change', true);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select ('00000000-0000-4000-8000-0000001630' || s)::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated',
       'authenticated', s || '@m1630.deskilo.test', '', now(), now(), now()
  from unnest(array['a1', 'b2', 'd4']) s;
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
insert into public.mcp_clients (client_id, name) values ('claude-test', 'Test assistant') on conflict do nothing;
update public.mcp_runtime set enabled = true;
select pg_temp.act_as('00000000-0000-4000-8000-0000001630a1');
select public.finalize_identity_binding();
select set_config('t.a', public.create_workspace('MCP W 1630', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"mcpAccess": true}'
 where id = current_setting('t.a')::uuid;
insert into public.members (workspace_id, user_id, status, is_admin, subscription_pct)
values (current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000001630b2', 'active', false, 100),
       (current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000001630d4', 'active', false, 100);
select set_config('t.' || right(user_id::text, 2), id::text, true)
  from public.members where workspace_id = current_setting('t.a')::uuid;
insert into public.workspace_mcp_policies (workspace_id, installation_id, revision, enabled, operations, target_ceiling)
values (current_setting('t.a')::uuid, public.installation_id(), 1, true, string_to_array(current_setting('t.ops'), ','), 'workspace');
select pg_temp.connect('00000000-0000-4000-8000-0000001630a1', string_to_array(current_setting('t.ops'), ','));

-- 1. A read writes one usage row: its operation, its outcome, no mutation.
select set_config('t.r1', pg_temp.call('00000000-0000-4000-8000-0000001630a1', 'get_capabilities', '{}',
  '00000000-0000-4000-8000-0000001630e1')::text, true);
reset role;
select is((select string_agg(operation || '/' || outcome || '/' || mutation, ',') from public.mcp_usage
            where request_id = '00000000-0000-4000-8000-0000001630e1'),
  'get_capabilities/completed/false', 'a read writes one usage row with its operation and outcome');

-- 2. A mutation runs (confirmed natively) and is recorded in its own transaction.
select set_config('t.m1', pg_temp.confirm_and_run('00000000-0000-4000-8000-0000001630a1', 'request_subscription_change',
  jsonb_build_object('member_id', current_setting('t.d4'), 'pct', 50), '00000000-0000-4000-8000-0000001630e2')::text, true);
reset role;
select is((select subscription_pct from public.members where id = current_setting('t.d4')::uuid)::text
          || '/' || pg_temp.usage('00000000-0000-4000-8000-0000001630e2'),
  '50/2', 'a mutation applies, and its two answers (confirmation, completion) are recorded');

-- 3. Ten mutations this minute: the eleventh is refused and runs nothing.
select pg_temp.seed('00000000-0000-4000-8000-0000001630a1', 'claude-test', true,
  10 - (select count(*)::integer from public.mcp_usage
         where local_user_id = '00000000-0000-4000-8000-0000001630a1' and mutation));
select set_config('t.ev0', (select count(*) from public.events where workspace_id = current_setting('t.a')::uuid)::text, true);
select set_config('t.m2', pg_temp.call('00000000-0000-4000-8000-0000001630a1', 'request_subscription_change',
  jsonb_build_object('member_id', current_setting('t.d4'), 'pct', 60), '00000000-0000-4000-8000-0000001630e3')::text, true);
reset role;
select is(current_setting('t.m2')::jsonb->>'status' || '/' || (current_setting('t.m2')::jsonb->'error'->>'code'),
  'rate_limited/rate_limited', 'the eleventh mutation of the minute is rate_limited');
select ok((current_setting('t.m2')::jsonb->'data'->>'retry_after')::integer between 1 and 60,
  'with retry_after: the seconds until the minute resets');
select is((select subscription_pct from public.members where id = current_setting('t.d4')::uuid)
          + (select count(*)::integer from public.events where workspace_id = current_setting('t.a')::uuid)
          - current_setting('t.ev0')::integer
          + (select count(*)::integer from public.mcp_action_confirmations
              where request_id = '00000000-0000-4000-8000-0000001630e3')
          + (select count(*)::integer from public.mcp_idempotency
              where request_id = '00000000-0000-4000-8000-0000001630e3'),
  50, 'nothing ran: no change, no event, no confirmation, no stored answer');
select is((select string_agg(outcome || '/' || mutation, ',') from public.mcp_usage
            where request_id = '00000000-0000-4000-8000-0000001630e3'),
  'rate_limited/true', 'the refusal itself is recorded');

-- 4. Reads have their own, larger limit.
select set_config('t.r2', pg_temp.call('00000000-0000-4000-8000-0000001630a1', 'get_capabilities', '{}',
  '00000000-0000-4000-8000-0000001630e4')::text, true);
reset role;
select is(current_setting('t.r2')::jsonb->>'status', 'completed', 'a read is still answered at the mutation limit');

-- 5. A replay at the limit is answered from idempotency and writes no row.
select set_config('t.u0', (select count(*) from public.mcp_usage)::text, true);
select set_config('t.m3', pg_temp.call('00000000-0000-4000-8000-0000001630a1', 'request_subscription_change',
  jsonb_build_object('member_id', current_setting('t.d4'), 'pct', 50), '00000000-0000-4000-8000-0000001630e2')::text, true);
reset role;
select is(current_setting('t.m3')::jsonb->>'status', current_setting('t.m1')::jsonb->>'status',
  'a replay at the limit gets the stored answer, not rate_limited');
select is((select count(*) from public.mcp_usage)::text, current_setting('t.u0'),
  'and adds no usage row');

-- 6. The workspace's day: another member's calls fill it; the next read is refused.
select pg_temp.seed('00000000-0000-4000-8000-0000001630b2', 'other-client', false,
  10000 - (select count(*)::integer from public.mcp_usage where workspace_id = current_setting('t.a')::uuid
             and outcome not in ('denied', 'rate_limited', 'validation_error')));
select set_config('t.r3', pg_temp.call('00000000-0000-4000-8000-0000001630a1', 'get_capabilities', '{}',
  '00000000-0000-4000-8000-0000001630e5')::text, true);
reset role;
select is(current_setting('t.r3')::jsonb->>'status' || '/'
          || ((current_setting('t.r3')::jsonb->'data'->>'retry_after')::integer > 0),
  'rate_limited/true', 'the workspace''s daily limit refuses, with a retry_after');

-- 7. Only these columns: no argument, token or result body.
select is((select string_agg(column_name::text, ',' order by column_name) from information_schema.columns
            where table_schema = 'public' and table_name = 'mcp_usage'),
  'client_id,company_id,created_at,created_by_user,created_datetime,event_id,id,installation_id,'
  'local_user_id,modified_by_user,modified_datetime,mutation,operation,outcome,request_id,site_id,workspace_id',
  'mcp_usage has exactly the allowed columns');
select is(has_table_privilege('authenticated', 'public.mcp_usage', 'select')
          or has_table_privilege('authenticated', 'public.mcp_limits', 'select'), false,
  'neither table is readable by a signed-in client');

select * from finish();
rollback;
