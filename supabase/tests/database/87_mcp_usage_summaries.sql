-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1630 (checkpoint 2): what mcp_usage counted, read back as counts. A
-- person sees their own assistants' counts and nobody else's; the owner
-- sees the workspace's per day and operation, a member does not; refusals,
-- applied mutations and pending validations are counted apart; another
-- workspace and rows older than 30 days are left out. The cleanup is
-- service_role's, bounded, and never reaches under 30 days.
begin;
select plan(15);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end;
$$;
-- Usage rows seeded directly, as postgres.
create function pg_temp.seed(p_user uuid, p_client text, p_op text, p_mutation boolean, p_outcome text,
                             p_rows integer, p_age interval default '0'::interval, p_ws uuid default null)
returns void language sql as $$
  insert into public.mcp_usage (installation_id, workspace_id, local_user_id, client_id, operation, mutation, outcome, created_at)
  select public.installation_id(), coalesce(p_ws, current_setting('t.a')::uuid), p_user, p_client,
         p_op, p_mutation, p_outcome, now() - p_age
    from generate_series(1, p_rows);
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select ('00000000-0000-4000-8000-0000001630' || s)::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated',
       'authenticated', s || '@u1630.deskilo.test', '', now(), now(), now()
  from unnest(array['a1', 'b2']) s;
insert into public.mcp_clients (client_id, name) values ('claude-test', 'Test assistant') on conflict do nothing;
select pg_temp.act_as('00000000-0000-4000-8000-0000001630a1');
select set_config('t.a', public.create_workspace('MCP U 1630', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
insert into public.members (workspace_id, user_id, status, is_admin, subscription_pct)
values (current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000001630b2', 'active', false, 100);

-- The owner (a1) through claude-test, today: 3 reads, 2 applied mutations,
-- 1 pending validation, 3 refusals; one read two days ago; one read 40
-- days ago; one read in another workspace. The member (b2): 2 reads today.
select pg_temp.seed('00000000-0000-4000-8000-0000001630a1', 'claude-test', 'get_capabilities', false, 'completed', 3);
select pg_temp.seed('00000000-0000-4000-8000-0000001630a1', 'claude-test', 'request_subscription_change', true, 'completed', 2);
select pg_temp.seed('00000000-0000-4000-8000-0000001630a1', 'claude-test', 'request_subscription_change', true, 'pending_validation', 1);
select pg_temp.seed('00000000-0000-4000-8000-0000001630a1', 'claude-test', 'get_capabilities', false, o, 1)
  from unnest(array['denied', 'validation_error', 'rate_limited']) o;
select pg_temp.seed('00000000-0000-4000-8000-0000001630a1', 'claude-test', 'get_capabilities', false, 'completed', 1, '2 days');
select pg_temp.seed('00000000-0000-4000-8000-0000001630a1', 'claude-test', 'get_capabilities', false, 'completed', 1, '40 days');
select pg_temp.seed('00000000-0000-4000-8000-0000001630a1', 'claude-test', 'get_capabilities', false, 'completed', 1, '0',
                    gen_random_uuid());
select pg_temp.seed('00000000-0000-4000-8000-0000001630b2', 'other-client', 'get_capabilities', false, 'completed', 2);

-- 1. A person's own summary: their assistant, today's counts apart.
select pg_temp.act_as('00000000-0000-4000-8000-0000001630a1');
select set_config('t.mine', public.mcp_usage_summary_mine()::text, true);
select is((select string_agg(c->>'client_id' || '/' || (c->>'client_name') || '/' || (c->>'requests_today') || '/'
                             || (c->>'refusals') || '/' || (c->>'applied') || '/' || (c->>'pending_validation'), ',')
             from jsonb_array_elements(current_setting('t.mine')::jsonb->'clients') c),
  'claude-test/Test assistant/10/3/2/1',
  'the owner''s own counts: 10 today (another workspace''s too), 3 refused, 2 applied, 1 pending');
select ok((current_setting('t.mine')::jsonb->'clients'->0->>'last_used_at')::timestamptz >= now() - interval '1 minute',
  'with when the assistant was last used');

-- 2. The member sees only their own rows.
select pg_temp.act_as('00000000-0000-4000-8000-0000001630b2');
select is((select string_agg(c->>'client_id' || '/' || (c->>'requests_today') || '/' || (c->>'refusals'), ',')
             from jsonb_array_elements(public.mcp_usage_summary_mine()->'clients') c),
  'other-client/2/0', 'a member sees only their own counts');
select is(jsonb_array_length(public.mcp_usage_summary_mine(gen_random_uuid())->'clients'), 0,
  'another installation''s summary is empty');

-- 3. The workspace: owner only, per day and operation, 30 days.
select throws_ok($$select public.mcp_usage_summary_workspace(current_setting('t.a')::uuid)$$, '42501', null,
  'a member who is not the owner is refused the workspace summary');
select pg_temp.act_as('00000000-0000-4000-8000-0000001630a1');
select set_config('t.ws', public.mcp_usage_summary_workspace(current_setting('t.a')::uuid)::text, true);
select is(current_setting('t.ws')::jsonb->>'workspace_id', current_setting('t.a'), 'the answer names its workspace');
select is((select string_agg(w->>'operation' || '/' || (w->>'requests') || '/' || (w->>'refusals') || '/'
                             || (w->>'applied') || '/' || (w->>'pending_validation') || '/' || (w->>'people'),
                             ',' order by w->>'operation')
             from jsonb_array_elements(current_setting('t.ws')::jsonb->'rows') w
            where (w->>'day')::date = (now() at time zone 'UTC')::date),
  'get_capabilities/8/3/0/0/2,request_subscription_change/3/0/2/1/1',
  'today, per operation: requests, refusals, applied, pending and people counted apart');
select is((select sum((w->>'requests')::integer)::integer from jsonb_array_elements(current_setting('t.ws')::jsonb->'rows') w),
  12, 'thirty days: two days ago counts; 40 days ago and another workspace do not');
select is((select count(*)::integer from jsonb_array_elements(current_setting('t.ws')::jsonb->'rows') w
            where w ?| array['local_user_id', 'client_id', 'email', 'event_id']),
  0, 'no identity beyond counts');
select throws_ok($$select public.mcp_usage_summary_workspace(gen_random_uuid())$$, '42501', null,
  'the owner of one workspace is refused another''s');

-- 4. Cleanup: service_role only, bounded to rows older than max(keep, 30) days.
select throws_ok($$select public.mcp_usage_cleanup(90)$$, '42501', null, 'a signed-in client cannot run the cleanup');
reset role;
select pg_temp.seed('00000000-0000-4000-8000-0000001630b2', 'other-client', 'get_capabilities', false, 'completed', 2, '100 days');
select pg_temp.seed('00000000-0000-4000-8000-0000001630b2', 'other-client', 'get_capabilities', false, 'completed', 1, '20 days');
select set_config('t.old90', (select count(*) from public.mcp_usage where created_at < now() - interval '90 days')::text, true);
set local role service_role;
select is(public.mcp_usage_cleanup(90)::text, current_setting('t.old90'), 'keep 90 days: deletes exactly the older rows');
reset role;
select set_config('t.old30', (select count(*) from public.mcp_usage where created_at < now() - interval '30 days')::text, true);
set local role service_role;
select is(public.mcp_usage_cleanup(1)::text, current_setting('t.old30'),
  'asked for 1 day, it still stops at 30 days');
reset role;
select is((select count(*)::integer from public.mcp_usage
            where local_user_id = '00000000-0000-4000-8000-0000001630a1' and created_at < now() - interval '30 days'),
  0, 'the 40-day row is gone');
select is((select count(*)::integer from public.mcp_usage
            where local_user_id = '00000000-0000-4000-8000-0000001630b2' and created_at < now() - interval '19 days'),
  1, 'the 20-day row stays');

select * from finish();
rollback;
