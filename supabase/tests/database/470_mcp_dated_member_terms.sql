-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3937 (0816): an assistant reads and schedules a member's dated plan changes
-- and pauses, and cancels one not yet applied, through the commands #3858
-- (0766) carries. The writes show the member and the dates in the app and wait
-- for the person's confirmation; confirmed, the same request_id runs the
-- command once, under the caller's own identity. What the command would
-- refuse is refused before anyone is asked. A member without manageMembers
-- and another workspace's manager are refused; a member reads their own
-- changes, not another's, and a manager reads any.
begin;
select plan(35);

create function pg_temp.act_as(p_user uuid, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'amr', jsonb_build_array(jsonb_build_object('method', 'oauth')),
    'client_id', p_client))::text, true);
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.call(p_op text, p_args jsonb, p_request uuid default null) returns jsonb language sql as $$
  select public.mcp_execute_v1(public.installation_id(), '00000000-0000-4000-8000-0000003937c1', p_op, p_args, p_request);
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.answer(p_answer text, p_accept boolean default true) returns jsonb language sql as $$
  select public.mcp_confirm_action((current_setting(p_answer)::jsonb->'data'->>'confirmation_id')::uuid, p_accept);
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.got(p_answer text) returns text language sql as $$
  select (current_setting(p_answer)::jsonb->>'status') || ':' || coalesce(current_setting(p_answer)::jsonb->'error'->>'code', '');
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.target(p_request uuid) returns jsonb language sql as $$
  select preview->'target' from public.mcp_action_confirmations where request_id = p_request;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.asked(p_requests uuid[]) returns int language sql as $$
  select count(*)::int from public.mcp_action_confirmations where request_id = any (p_requests);
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.rows(p_sql text) returns text language plpgsql as $$
declare r text;
begin execute p_sql into r; return r; end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.mid(p_user text) returns uuid language sql as $$
  select id from public.members where workspace_id = '00000000-0000-4000-8000-0000003937c1'
     and user_id = ('00000000-0000-4000-8000-0000003937' || p_user)::uuid;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- The owner (d1), a plain member (d2) and the manager of another workspace (d3).
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select ('00000000-0000-4000-8000-0000003937' || s)::uuid, '00000000-0000-0000-0000-000000000000',
       'authenticated', 'authenticated', s || '@mcp-term-changes.test', '', now(), now(), now()
  from unnest(array['d1', 'd2', 'd3']) s;
insert into auth.identities (id, provider_id, user_id, identity_data, provider, created_at, updated_at)
select gen_random_uuid(), 'google-' || u, u, jsonb_build_object('sub', 'google-' || u), 'google', now(), now()
  from unnest(array['00000000-0000-4000-8000-0000003937d1', '00000000-0000-4000-8000-0000003937d2',
                    '00000000-0000-4000-8000-0000003937d3']::uuid[]) u;
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
insert into public.mcp_clients (client_id, name) values ('claude-test', 'Test assistant') on conflict do nothing;
update public.mcp_runtime set enabled = true;
update public.mcp_limits set calls_per_minute = 1000, mutations_per_minute = 100;

insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, environment, booking_rules,
                               feature_flags, role_permissions) values
 ('00000000-0000-4000-8000-0000003937c1', 'MCP terms', 'FR', 'EUR', 'Europe/Paris',
  '00000000-0000-4000-8000-0000003937d1', 'dev', '{"open_weekdays":[1,2,3,4,5]}',
  '{"mcpAccess": true}', '{"admin": ["manageMembers"]}'),
 ('00000000-0000-4000-8000-0000003937c2', 'MCP terms, elsewhere', 'FR', 'EUR', 'Europe/Paris',
  '00000000-0000-4000-8000-0000003937d3', 'dev', '{"open_weekdays":[1,2,3,4,5]}',
  '{"mcpAccess": true}', '{"admin": ["manageMembers"]}');
insert into public.members (workspace_id, user_id, is_owner, is_admin, status) values
 ('00000000-0000-4000-8000-0000003937c1', '00000000-0000-4000-8000-0000003937d1', true, true, 'active'),
 ('00000000-0000-4000-8000-0000003937c1', '00000000-0000-4000-8000-0000003937d2', false, false, 'active'),
 ('00000000-0000-4000-8000-0000003937c2', '00000000-0000-4000-8000-0000003937d3', false, true, 'active');

select pg_temp.act_as('00000000-0000-4000-8000-0000003937d1');
select public.finalize_identity_binding();
select pg_temp.act_as('00000000-0000-4000-8000-0000003937d2');
select public.finalize_identity_binding();
select pg_temp.act_as('00000000-0000-4000-8000-0000003937d3');
select public.finalize_identity_binding();
insert into public.mcp_eligibility_grants (installation_id, binding_id, local_user_id, decision_id, decision, status, decided_by, expires_at)
select public.installation_id(), id, local_user_id, gen_random_uuid(), 'approved', 'active', local_user_id, now() + interval '30 days'
  from public.identity_bindings
 where local_user_id in ('00000000-0000-4000-8000-0000003937d1', '00000000-0000-4000-8000-0000003937d2',
                         '00000000-0000-4000-8000-0000003937d3') and status = 'active';
insert into public.workspace_mcp_policies (workspace_id, installation_id, revision, enabled, operations, target_ceiling)
values ('00000000-0000-4000-8000-0000003937c1', public.installation_id(), 1, true,
        array['list_member_term_changes', 'schedule_member_share_change', 'schedule_member_pause',
              'cancel_member_term_change'], 'workspace');
insert into public.mcp_connections (installation_id, local_user_id, binding_id, client_id)
select public.installation_id(), local_user_id, id, 'claude-test' from public.identity_bindings
 where local_user_id in ('00000000-0000-4000-8000-0000003937d1', '00000000-0000-4000-8000-0000003937d2',
                         '00000000-0000-4000-8000-0000003937d3') and status = 'active';
insert into public.mcp_connection_scopes (connection_id, workspace_id, operations, target_ceiling)
select id, '00000000-0000-4000-8000-0000003937c1',
       array['list_member_term_changes', 'schedule_member_share_change', 'schedule_member_pause',
             'cancel_member_term_change'], 'workspace'
  from public.mcp_connections
 where local_user_id in ('00000000-0000-4000-8000-0000003937d1', '00000000-0000-4000-8000-0000003937d2',
                         '00000000-0000-4000-8000-0000003937d3');

-- The business's days: the first of next month, of the month after, and after that.
select set_config('t.m1', (date_trunc('month', public.workspace_today('00000000-0000-4000-8000-0000003937c1')) + interval '1 month')::date::text, true);
select set_config('t.m2', (date_trunc('month', public.workspace_today('00000000-0000-4000-8000-0000003937c1')) + interval '2 month')::date::text, true);
select set_config('t.m3', (date_trunc('month', public.workspace_today('00000000-0000-4000-8000-0000003937c1')) + interval '3 month')::date::text, true);
select set_config('t.member', pg_temp.mid('d2')::text, true);
select set_config('t.owner', pg_temp.mid('d1')::text, true);

-- ── the owner, through the assistant: a share from a date ───────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000003937d1', 'claude-test');
select set_config('t.s1', pg_temp.call('schedule_member_share_change', jsonb_build_object(
  'member_id', current_setting('t.member'), 'pct', 50, 'effective_on', current_setting('t.m1')),
  '00000000-0000-4000-8000-0000003937e1')::text, true);
-- what the command would refuse is refused before anyone is asked
select set_config('t.s2', pg_temp.call('schedule_member_share_change', jsonb_build_object(
  'member_id', current_setting('t.member'), 'pct', 50, 'effective_on', (current_setting('t.m1')::date + 14)::text),
  '00000000-0000-4000-8000-0000003937e2')::text, true);
select set_config('t.s3', pg_temp.call('schedule_member_share_change', jsonb_build_object(
  'member_id', current_setting('t.member'), 'pct', 50, 'effective_on', '2020-01-01'),
  '00000000-0000-4000-8000-0000003937e3')::text, true);
select set_config('t.s4', pg_temp.call('schedule_member_share_change', jsonb_build_object(
  'member_id', current_setting('t.member'), 'pct', 50, 'effective_on', '2026-02-30'),
  '00000000-0000-4000-8000-0000003937e4')::text, true);
select set_config('t.s5', pg_temp.call('schedule_member_share_change', jsonb_build_object(
  'member_id', current_setting('t.member'), 'pct', 150, 'effective_on', current_setting('t.m1')),
  '00000000-0000-4000-8000-0000003937e5')::text, true);
select set_config('t.before', coalesce(pg_temp.rows('select count(*)::text from public.member_term_changes
  where member_id = ''' || current_setting('t.member') || ''' and source = ''scheduled'''), '?'), true);

-- ── a member and another workspace's manager ────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000003937d2', 'claude-test');
select set_config('t.f1', pg_temp.call('schedule_member_share_change', jsonb_build_object(
  'member_id', current_setting('t.member'), 'pct', 100, 'effective_on', current_setting('t.m1')),
  '00000000-0000-4000-8000-0000003937f1')::text, true);
select set_config('t.f2', pg_temp.call('cancel_member_term_change', jsonb_build_object(
  'change_id', gen_random_uuid()), '00000000-0000-4000-8000-0000003937f2')::text, true);
select set_config('t.f3', pg_temp.call('schedule_member_pause', jsonb_build_object(
  'member_id', current_setting('t.member'), 'from', current_setting('t.m2')),
  '00000000-0000-4000-8000-0000003937f3')::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000003937d3', 'claude-test');
select set_config('t.f4', pg_temp.call('schedule_member_share_change', jsonb_build_object(
  'member_id', current_setting('t.member'), 'pct', 100, 'effective_on', current_setting('t.m1')),
  '00000000-0000-4000-8000-0000003937f4')::text, true);
select set_config('request.jwt.claims', '', true);

-- ── the owner confirms in the app, the assistant repeats the call ───────
select pg_temp.act_as('00000000-0000-4000-8000-0000003937d1');
select set_config('t.c1', pg_temp.answer('t.s1')::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000003937d1', 'claude-test');
select set_config('t.s6', pg_temp.call('schedule_member_share_change', jsonb_build_object(
  'member_id', current_setting('t.member'), 'pct', 50, 'effective_on', current_setting('t.m1')),
  '00000000-0000-4000-8000-0000003937e1')::text, true);
select set_config('t.n1', pg_temp.rows('select count(*)::text from public.member_term_changes
  where member_id = ''' || current_setting('t.member') || ''' and source = ''scheduled'' and kind = ''share'''), true);
select set_config('t.s7', pg_temp.call('schedule_member_share_change', jsonb_build_object(
  'member_id', current_setting('t.member'), 'pct', 50, 'effective_on', current_setting('t.m1')),
  '00000000-0000-4000-8000-0000003937e1')::text, true);
select set_config('t.n2', pg_temp.rows('select count(*)::text from public.member_term_changes
  where member_id = ''' || current_setting('t.member') || ''' and source = ''scheduled'' and kind = ''share'''), true);
-- the same request id with other values is refused
select set_config('t.s8', pg_temp.call('schedule_member_share_change', jsonb_build_object(
  'member_id', current_setting('t.member'), 'pct', 70, 'effective_on', current_setting('t.m1')),
  '00000000-0000-4000-8000-0000003937e1')::text, true);

-- ── the reads: what the app shows, for the same rights ─────────────────
select set_config('t.r1', pg_temp.call('list_member_term_changes', jsonb_build_object(
  'member_id', current_setting('t.member')))::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000003937d2', 'claude-test');
select set_config('t.r2', pg_temp.call('list_member_term_changes', '{}'::jsonb)::text, true);
select set_config('t.r3', pg_temp.call('list_member_term_changes', jsonb_build_object(
  'member_id', current_setting('t.owner')))::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000003937d3', 'claude-test');
select set_config('t.r4', pg_temp.call('list_member_term_changes', jsonb_build_object(
  'member_id', current_setting('t.member')))::text, true);

-- ── a pause, confirmed and run once ─────────────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000003937d1', 'claude-test');
select set_config('t.p1', pg_temp.call('schedule_member_pause', jsonb_build_object(
  'member_id', current_setting('t.member'), 'from', current_setting('t.m2'), 'to', current_setting('t.m3')),
  '00000000-0000-4000-8000-0000003937a1')::text, true);
select set_config('t.p2', pg_temp.call('schedule_member_pause', jsonb_build_object(
  'member_id', current_setting('t.member'), 'from', current_setting('t.m3'), 'to', current_setting('t.m2')),
  '00000000-0000-4000-8000-0000003937a2')::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000003937d1');
select set_config('t.c2', pg_temp.answer('t.p1')::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000003937d1', 'claude-test');
select set_config('t.p3', pg_temp.call('schedule_member_pause', jsonb_build_object(
  'member_id', current_setting('t.member'), 'from', current_setting('t.m2'), 'to', current_setting('t.m3')),
  '00000000-0000-4000-8000-0000003937a1')::text, true);
select set_config('t.pn', pg_temp.rows('select count(*)::text from public.member_term_changes
  where member_id = ''' || current_setting('t.member') || ''' and kind = ''status'' and source = ''scheduled'''), true);
select set_config('t.pid', pg_temp.rows('select id::text from public.member_term_changes
  where member_id = ''' || current_setting('t.member') || ''' and kind = ''status'' and to_status = ''paused'''), true);

-- ── a cancellation, confirmed and run once; a second finds nothing to cancel
select set_config('t.x1', pg_temp.call('cancel_member_term_change', jsonb_build_object(
  'change_id', current_setting('t.pid')), '00000000-0000-4000-8000-0000003937b1')::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000003937d1');
select set_config('t.c3', pg_temp.answer('t.x1')::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000003937d1', 'claude-test');
select set_config('t.x2', pg_temp.call('cancel_member_term_change', jsonb_build_object(
  'change_id', current_setting('t.pid')), '00000000-0000-4000-8000-0000003937b1')::text, true);
select set_config('t.xs', pg_temp.rows('select string_agg(state, '','' order by due_on) from public.member_term_changes
  where member_id = ''' || current_setting('t.member') || ''' and kind = ''status'' and source = ''scheduled'''), true);
select set_config('t.x3', pg_temp.call('cancel_member_term_change', jsonb_build_object(
  'change_id', current_setting('t.pid')), '00000000-0000-4000-8000-0000003937b2')::text, true);
-- ── a change an issued invoice already carries is refused before anyone is asked
select set_config('request.jwt.claims', '', true);
insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents,
                             currency, member_name, workspace_name, issuer_name, signature, issued_at, period, kind)
values (gen_random_uuid(), '00000000-0000-4000-8000-0000003937c1', current_setting('t.member')::uuid,
        current_setting('t.owner')::uuid, 'T-3937', 'T', '[]'::jsonb, 4800, 'EUR', 'A', 'B', 'O', 'sig',
        now() + interval '1 minute', to_char(current_setting('t.m1')::date, 'YYYY-MM'), 'subscription');
select pg_temp.act_as('00000000-0000-4000-8000-0000003937d1', 'claude-test');
select set_config('t.k1', pg_temp.call('cancel_member_term_change', jsonb_build_object(
  'change_id', current_setting('t.s6')::jsonb->'data'->>'change_id'), '00000000-0000-4000-8000-0000003937b3')::text, true);
select set_config('request.jwt.claims', '', true);

select is(jsonb_build_object('permission', c->'permission', 'features', c->'features', 'mutation', c->>'mutation',
                             'confirmation', c->>'confirmation')
          ,'{"permission": "manageMembers", "features": ["mcpAccess"], "mutation": "request", "confirmation": "native"}'::jsonb,
  'a schedule asks manageMembers, is a request and confirms in the app')
  from (select public.mcp_operation_catalogue()->'operations'->'schedule_member_share_change' c) q;
select is(public.mcp_operation_catalogue()->'operations'->'list_member_term_changes'->>'mutation', 'read',
  'the list is a read');
select is(pg_temp.got('t.s1'), 'requires_confirmation:', 'a share from a date waits for the person');
select is(pg_temp.target('00000000-0000-4000-8000-0000003937e1') - 'id' - 'name' - 'status' - 'subscription_pct',
  jsonb_build_object('kind', 'member', 'to_pct', 50, 'effective_on', current_setting('t.m1')),
  'the app is shown the member, the share and the day');
select is(current_setting('t.before'), '0', 'and nothing is written before it');
select is(pg_temp.got('t.s2') || ' ' || (current_setting('t.s2')::jsonb->'data'->>'reason' like '%first day of a period%')::text,
  'conflict:refused true', 'a day that is not a period''s first day is refused, with the reason');
select is(pg_temp.got('t.s3') || ' ' || (current_setting('t.s3')::jsonb->'data'->>'reason' like '%the earliest is%')::text,
  'conflict:refused true', 'so is a day long past, and the answer names the earliest day allowed');
select is(pg_temp.got('t.s4'), 'validation_error:invalid_arguments', 'a day that does not exist');
select is(pg_temp.got('t.s5'), 'validation_error:invalid_arguments', 'and a share above 100');
select is(pg_temp.asked(array['00000000-0000-4000-8000-0000003937e2', '00000000-0000-4000-8000-0000003937e3',
  '00000000-0000-4000-8000-0000003937e4', '00000000-0000-4000-8000-0000003937e5']::uuid[]), 0,
  'and no one is asked to confirm what the command would refuse');
select is(pg_temp.got('t.f1'), 'denied:forbidden', 'a member without manageMembers cannot schedule');
select is(pg_temp.got('t.f2') || ' ' || pg_temp.got('t.f3'), 'denied:forbidden denied:forbidden', 'nor cancel, nor pause');
select is(pg_temp.got('t.f4'), 'denied:not_a_member', 'another workspace''s manager is refused');
select is(current_setting('t.c1')::jsonb->>'status', 'acknowledged', 'the person confirms it in the app');
select is(pg_temp.got('t.s6') || ' ' || (current_setting('t.s6')::jsonb->'data'->>'state'), 'completed: scheduled',
  'the same request_id then schedules it');
select is(current_setting('t.n1') || current_setting('t.n2'), '11', 'once, and a repeated call does not schedule it again');
select is(pg_temp.got('t.s8'), 'conflict:request_id_reused', 'the same request id with other values is refused');
select is((current_setting('t.r1')::jsonb->'data'->'items'->0)
          - 'change_id' - 'group_id' - 'applied_on' - 'reason' - 'to_status',
  jsonb_build_object('kind', 'share', 'state', 'scheduled', 'effective_on', current_setting('t.m1'), 'to_pct', 50),
  'a manager reads the change with its day and state');
select is(pg_temp.got('t.r2') || ' ' || jsonb_array_length(current_setting('t.r2')::jsonb->'data'->'items'), 'completed: 1',
  'a member reads their own');
select is(pg_temp.got('t.r3'), 'denied:forbidden', 'and not another member''s');
select is(pg_temp.got('t.r4'), 'denied:not_a_member', 'another workspace''s manager reads nothing');
select is(pg_temp.got('t.p1'), 'requires_confirmation:', 'a pause waits for the person');
select is(pg_temp.got('t.p2') || ' ' || (current_setting('t.p2')::jsonb->'data'->>'reason' like '%ends after it starts%')::text,
  'conflict:refused true', 'a pause ending before it starts is refused, with the reason');
select is(current_setting('t.c2')::jsonb->>'status', 'acknowledged', 'the person confirms the pause in the app');
select is(pg_temp.got('t.p3') || ' ' || (current_setting('t.p3')::jsonb->'data' ? 'first_free'), 'completed: true',
  'the same request_id pauses, and the answer names the first month it frees');
select is(current_setting('t.pn'), '2', 'the pause is its two ends, once');
select is(pg_temp.got('t.x1'), 'requires_confirmation:', 'a cancellation waits for the person');
select is(current_setting('t.c3')::jsonb->>'status', 'acknowledged', 'the person confirms it');
select is(pg_temp.got('t.x2') || ' ' || (current_setting('t.x2')::jsonb->'data'->>'cancelled'), 'completed: 2',
  'cancelling a pause cancels both its ends and says how many');
select is(current_setting('t.xs'), 'cancelled,cancelled', 'and both read as cancelled');
select is(pg_temp.got('t.x3') || ' ' || (current_setting('t.x3')::jsonb->'data'->>'reason' like '%not yet applied%')::text,
  'conflict:refused true', 'a change no longer waiting is not put to the person, and says why');
select is(pg_temp.got('t.k1') || ' ' || (current_setting('t.k1')::jsonb->'data'->>'reason' like '%already on an invoice%')::text,
  'conflict:refused true', 'a change an invoice carries is refused with the command''s own reason');
select is(pg_temp.asked(array['00000000-0000-4000-8000-0000003937b3', '00000000-0000-4000-8000-0000003937b2']::uuid[]), 0,
  'and nobody is asked to confirm either cancellation');
select is((select state from public.member_term_changes where id = (current_setting('t.s6')::jsonb->'data'->>'change_id')::uuid),
  'scheduled', 'the change stays scheduled: the probe wrote nothing');
select ok(not has_function_privilege('authenticated', 'public.mcp_op_schedule_member_pause(public.mcp_call_context,jsonb)', 'execute')
          and not has_function_privilege('authenticated', 'public.mcp_target_schedule_member_share_change(uuid,jsonb)', 'execute')
          and not has_function_privilege('authenticated', 'public.mcp_op_list_member_term_changes(public.mcp_call_context,jsonb)', 'execute'),
  'the handlers and the targets are reachable only through the dispatcher');

select * from finish();
rollback;
