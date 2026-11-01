-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3132 (0639, decided in #3012): an assistant proposes a change of the
-- workspace's bank account (workspaces.payment_instructions: iban, bic,
-- bank_name, account_number, bank_code, qr_iban). The person sees the account
-- as it is and as it would become in the app and confirms; confirmed, the same
-- request_id writes it once, and ONE audit event (payment_instructions_change,
-- actor = who confirmed, subject = the owner) reaches the owner without the
-- account number in it. Whatever the plan refuses is refused before anyone is
-- asked (a wrong IBAN checksum, a malformed IBAN or BIC, a QR-IBAN that is
-- not a Swiss QR-IBAN, a value on two lines, nothing to change, an argument
-- the operation does not take), a credential is refused as secret_in_app_only,
-- a plain member and another workspace's manager are refused, a proposal whose
-- account changed meanwhile is stale and a declined one never runs.
begin;
select plan(42);

create function pg_temp.act_as(p_user uuid, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'amr', jsonb_build_array(jsonb_build_object('method', 'oauth')),
    'client_id', p_client))::text, true);
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.call(p_args jsonb, p_request uuid default null) returns jsonb language sql as $$
  select public.mcp_execute_v1(public.installation_id(), '00000000-0000-4000-8000-0000003137c1',
                               'set_payment_instructions', p_args, p_request);
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.answer(p_answer text, p_accept boolean default true) returns jsonb language sql as $$
  select public.mcp_confirm_action((current_setting(p_answer)::jsonb->'data'->>'confirmation_id')::uuid, p_accept);
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
-- status:code of an envelope, held in a setting.
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
create function pg_temp.account() returns jsonb language sql as $$
  select payment_instructions from public.workspaces where id = '00000000-0000-4000-8000-0000003137c1';
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.events_seen() returns int language sql as $$
  select count(*)::int from public.events
   where workspace_id = '00000000-0000-4000-8000-0000003137c1' and type = 'payment_instructions_change';
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- The owner (d1), a delegate holding manageIntegrations (d2), the manager of
-- another workspace (d3) and a plain member (d4), all with Google identities.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select ('00000000-0000-4000-8000-0000003137' || s)::uuid, '00000000-0000-0000-0000-000000000000',
       'authenticated', 'authenticated', s || '@mcp-payment-instructions.test', '', now(), now(), now()
  from unnest(array['d1', 'd2', 'd3', 'd4']) s;
insert into auth.identities (id, provider_id, user_id, identity_data, provider, created_at, updated_at)
select gen_random_uuid(), 'google-' || u, u, jsonb_build_object('sub', 'google-' || u), 'google', now(), now()
  from unnest(array['00000000-0000-4000-8000-0000003137d1', '00000000-0000-4000-8000-0000003137d2', '00000000-0000-4000-8000-0000003137d3', '00000000-0000-4000-8000-0000003137d4']::uuid[]) u;
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
insert into public.mcp_clients (client_id, name) values ('claude-test', 'Test assistant') on conflict do nothing;
update public.mcp_runtime set enabled = true;
update public.mcp_limits set calls_per_minute = 1000, mutations_per_minute = 100;

insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, environment, booking_rules,
                               feature_flags, role_permissions) values
 ('00000000-0000-4000-8000-0000003137c1', 'MCP bank', 'FR', 'EUR', 'Europe/Paris',
  '00000000-0000-4000-8000-0000003137d1', 'dev', '{"open_weekdays":[1,2,3,4,5]}',
  '{"mcpAccess": true, "moneyTab": true}', '{"admin": ["manageIntegrations"]}'),
 ('00000000-0000-4000-8000-0000003137c2', 'MCP bank, elsewhere', 'FR', 'EUR', 'Europe/Paris',
  '00000000-0000-4000-8000-0000003137d3', 'dev', '{"open_weekdays":[1,2,3,4,5]}',
  '{"mcpAccess": true, "moneyTab": true}', '{"admin": ["manageIntegrations"]}');
insert into public.members (workspace_id, user_id, is_owner, is_admin, status) values
 ('00000000-0000-4000-8000-0000003137c1', '00000000-0000-4000-8000-0000003137d1', true, true, 'active'),
 ('00000000-0000-4000-8000-0000003137c1', '00000000-0000-4000-8000-0000003137d2', false, true, 'active'),
 ('00000000-0000-4000-8000-0000003137c1', '00000000-0000-4000-8000-0000003137d4', false, false, 'active'),
 ('00000000-0000-4000-8000-0000003137c2', '00000000-0000-4000-8000-0000003137d3', false, true, 'active');
update public.workspaces
   set payment_instructions = '{"iban": "FR76 3000 6000 0112 3456 7890 189", "bic": "AGRIFRPP", "bank_name": "Bank A", "paypal_me": "somebody"}'
 where id = '00000000-0000-4000-8000-0000003137c1';

select pg_temp.act_as('00000000-0000-4000-8000-0000003137d1');
select public.finalize_identity_binding();
select pg_temp.act_as('00000000-0000-4000-8000-0000003137d2');
select public.finalize_identity_binding();
select pg_temp.act_as('00000000-0000-4000-8000-0000003137d3');
select public.finalize_identity_binding();
select pg_temp.act_as('00000000-0000-4000-8000-0000003137d4');
select public.finalize_identity_binding();
insert into public.mcp_eligibility_grants (installation_id, binding_id, local_user_id, decision_id, decision, status, decided_by, expires_at)
select public.installation_id(), id, local_user_id, gen_random_uuid(), 'approved', 'active', local_user_id, now() + interval '30 days'
  from public.identity_bindings
 where local_user_id in ('00000000-0000-4000-8000-0000003137d1', '00000000-0000-4000-8000-0000003137d2', '00000000-0000-4000-8000-0000003137d3', '00000000-0000-4000-8000-0000003137d4') and status = 'active';
insert into public.workspace_mcp_policies (workspace_id, installation_id, revision, enabled, operations, target_ceiling)
values ('00000000-0000-4000-8000-0000003137c1', public.installation_id(), 1, true,
        array['set_payment_instructions'], 'workspace');
insert into public.mcp_connections (installation_id, local_user_id, binding_id, client_id)
select public.installation_id(), local_user_id, id, 'claude-test' from public.identity_bindings
 where local_user_id in ('00000000-0000-4000-8000-0000003137d1', '00000000-0000-4000-8000-0000003137d2', '00000000-0000-4000-8000-0000003137d3', '00000000-0000-4000-8000-0000003137d4') and status = 'active';
-- Every connection is consented to this workspace, so each refusal below
-- comes from the right or the membership and not from a missing consent.
insert into public.mcp_connection_scopes (connection_id, workspace_id, operations, target_ceiling)
select id, '00000000-0000-4000-8000-0000003137c1', array['set_payment_instructions'], 'workspace'
  from public.mcp_connections
 where local_user_id in ('00000000-0000-4000-8000-0000003137d1', '00000000-0000-4000-8000-0000003137d2', '00000000-0000-4000-8000-0000003137d3', '00000000-0000-4000-8000-0000003137d4');

-- ── the delegate, through the assistant ────────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000003137d2', 'claude-test');
select set_config('t.r1', pg_temp.call('{"iban": "DE89 3704 0044 0532 0130 00", "bic": "cobadeff"}', '00000000-0000-4000-8000-0000003137e1')::text, true);
select set_config('t.before', pg_temp.account()::text, true);
select set_config('t.r2', pg_temp.call('{"iban": "DE89 3704 0044 0532 0130 01"}', '00000000-0000-4000-8000-0000003137e2')::text, true);
select set_config('t.r3', pg_temp.call('{"iban": "not an iban"}', '00000000-0000-4000-8000-0000003137e3')::text, true);
select set_config('t.r4', pg_temp.call('{"bic": "COBADE"}', '00000000-0000-4000-8000-0000003137e4')::text, true);
select set_config('t.r5', pg_temp.call('{"qr_iban": "DE89 3704 0044 0532 0130 00"}', '00000000-0000-4000-8000-0000003137e5')::text, true);
select set_config('t.r6', pg_temp.call('{"qr_iban": "CH93 0076 2011 6238 5295 7"}', '00000000-0000-4000-8000-0000003137e6')::text, true);
select set_config('t.r7', pg_temp.call('{"bic": "AGRIFRPP"}', '00000000-0000-4000-8000-0000003137e7')::text, true);
select set_config('t.r8', pg_temp.call('{}', '00000000-0000-4000-8000-0000003137e8')::text, true);
select set_config('t.r9', pg_temp.call('{"iban": "DE89 3704 0044 0532 0130 00", "paypal_me": "someone"}', '00000000-0000-4000-8000-0000003137e9')::text, true);
select set_config('t.r10', pg_temp.call('{"iban": "DE89 3704 0044 0532 0130 00", "api_key": "sk_live_x"}', '00000000-0000-4000-8000-0000003137ea')::text, true);
select set_config('t.r11', pg_temp.call('{"bank_name": "Bank\nB"}', '00000000-0000-4000-8000-0000003137eb')::text, true);

-- The money functionality off: nobody is asked.
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"moneyTab": false}'::jsonb
 where id = '00000000-0000-4000-8000-0000003137c1';
select set_config('t.r12', pg_temp.call('{"iban": "DE89 3704 0044 0532 0130 00"}', '00000000-0000-4000-8000-0000003137ec')::text, true);
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"moneyTab": true}'::jsonb
 where id = '00000000-0000-4000-8000-0000003137c1';

-- A valid QR-IBAN, and a field cleared: proposed, shown, not confirmed.
select set_config('t.rq', pg_temp.call('{"qr_iban": "ch4431999123000889012"}', '00000000-0000-4000-8000-0000003137ed')::text, true);
select set_config('t.rf', pg_temp.call('{"bank_name": ""}', '00000000-0000-4000-8000-0000003137ee')::text, true);

-- ── a plain member, and another workspace's manager ────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000003137d4', 'claude-test');
select set_config('t.ra', pg_temp.call('{"iban": "DE89 3704 0044 0532 0130 00"}', '00000000-0000-4000-8000-0000003137ef')::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000003137d3', 'claude-test');
select set_config('t.rb', pg_temp.call('{"iban": "DE89 3704 0044 0532 0130 00"}', '00000000-0000-4000-8000-0000003137f0')::text, true);
select set_config('request.jwt.claims', '', true);

-- ── the delegate confirms in the app, the assistant repeats the call ───
select pg_temp.act_as('00000000-0000-4000-8000-0000003137d2');
select set_config('t.c1', pg_temp.answer('t.r1')::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000003137d2', 'claude-test');
select set_config('t.r13', pg_temp.call('{"iban": "DE89 3704 0044 0532 0130 00", "bic": "cobadeff"}', '00000000-0000-4000-8000-0000003137e1')::text, true);
select set_config('t.after', pg_temp.account()::text, true);
select set_config('t.r14', pg_temp.call('{"iban": "DE89 3704 0044 0532 0130 00", "bic": "cobadeff"}', '00000000-0000-4000-8000-0000003137e1')::text, true);
select set_config('t.stored', pg_temp.account()::text, true);

-- A proposal whose account changed meanwhile is stale.
select set_config('t.rd', pg_temp.call('{"bic": "SOGEFRPP"}', '00000000-0000-4000-8000-0000003137f1')::text, true);
update public.workspaces set payment_instructions = payment_instructions || '{"bank_name": "Bank B"}'::jsonb
 where id = '00000000-0000-4000-8000-0000003137c1';
select pg_temp.act_as('00000000-0000-4000-8000-0000003137d2');
select set_config('t.cd', pg_temp.answer('t.rd')::text, true);

-- A declined proposal never runs.
select pg_temp.act_as('00000000-0000-4000-8000-0000003137d2', 'claude-test');
select set_config('t.re', pg_temp.call('{"bank_code": "20041"}', '00000000-0000-4000-8000-0000003137f2')::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000003137d2');
select set_config('t.ce', pg_temp.answer('t.re', false)::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000003137d2', 'claude-test');
select set_config('t.re2', pg_temp.call('{"bank_code": "20041"}', '00000000-0000-4000-8000-0000003137f2')::text, true);
select set_config('request.jwt.claims', '', true);

-- ── who reads the owner's notice, under row level security ─────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000003137d1');
set local role authenticated;
select set_config('t.owner_sees', pg_temp.events_seen()::text, true);
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-0000003137d4');
set local role authenticated;
select set_config('t.member_sees', pg_temp.events_seen()::text, true);
reset role;
select set_config('request.jwt.claims', '', true);

select is(jsonb_build_object('permission', c->'permission', 'features', c->'features', 'mutation', c->>'mutation',
                             'confirmation', c->>'confirmation'),
  '{"permission": "manageIntegrations", "features": ["mcpAccess", "moneyTab"], "mutation": "write", "confirmation": "native"}'::jsonb,
  'the catalogue asks manageIntegrations, as the Payment methods screen does, and the money functionality, writes, and confirms in the app')
  from (select public.mcp_operation_catalogue()->'operations'->'set_payment_instructions' c) q;
select is(pg_temp.got('t.r1'), 'requires_confirmation:', 'the change waits for the person');
select is(current_setting('t.before')::jsonb,
  '{"iban": "FR76 3000 6000 0112 3456 7890 189", "bic": "AGRIFRPP", "bank_name": "Bank A", "paypal_me": "somebody"}'::jsonb,
  'and nothing is written before it');
select is(pg_temp.target('00000000-0000-4000-8000-0000003137e1'),
  '{"kind": "payment_instructions", "changes": [{"field": "iban", "from": "FR76 3000 6000 0112 3456 7890 189", "to": "DE89 3704 0044 0532 0130 00"}, {"field": "bic", "from": "AGRIFRPP", "to": "COBADEFF"}]}'::jsonb,
  'the app is shown the account as it is and as it would become, each field from and to');
select is(pg_temp.got('t.r2'), 'validation_error:invalid_arguments', 'an IBAN with a wrong checksum is refused');
select is(pg_temp.got('t.r3'), 'validation_error:invalid_arguments', 'an IBAN that is not one is refused');
select is(pg_temp.got('t.r4'), 'validation_error:invalid_arguments', 'a BIC of six letters is refused');
select is(pg_temp.got('t.r5'), 'validation_error:invalid_arguments', 'a QR-IBAN that is not a Swiss one is refused');
select is(pg_temp.got('t.r6'), 'validation_error:invalid_arguments', 'a Swiss IBAN outside the QR-IBAN range is refused');
select is(pg_temp.got('t.r7'), 'validation_error:invalid_arguments', 'a value equal to the stored one changes nothing and is refused');
select is(pg_temp.got('t.r8'), 'validation_error:invalid_arguments', 'no field at all is refused');
select is(pg_temp.got('t.r9'), 'validation_error:invalid_arguments', 'another way to pay is not offered here and is refused');
select is(pg_temp.got('t.r10'), 'denied:secret_in_app_only', 'a credential is refused');
select is(pg_temp.got('t.r11'), 'validation_error:invalid_arguments', 'a value on two lines is refused');
select is(pg_temp.asked(array['00000000-0000-4000-8000-0000003137e2', '00000000-0000-4000-8000-0000003137e3', '00000000-0000-4000-8000-0000003137e4', '00000000-0000-4000-8000-0000003137e5', '00000000-0000-4000-8000-0000003137e6', '00000000-0000-4000-8000-0000003137e7',
  '00000000-0000-4000-8000-0000003137e8', '00000000-0000-4000-8000-0000003137e9', '00000000-0000-4000-8000-0000003137ea', '00000000-0000-4000-8000-0000003137eb']::uuid[]), 0,
  'and no one is asked to confirm what the plan would refuse');
select is(pg_temp.got('t.r12'), 'denied:not_exposed', 'a space with the money functionality off is refused');
select is(pg_temp.got('t.ra'), 'denied:forbidden', 'a member without manageIntegrations is refused');
select is(pg_temp.got('t.rb'), 'denied:not_a_member', 'another workspace''s manager is refused');
select is(pg_temp.asked(array['00000000-0000-4000-8000-0000003137ec', '00000000-0000-4000-8000-0000003137ef', '00000000-0000-4000-8000-0000003137f0']::uuid[]), 0, 'and none of them is asked to confirm');
select throws_ok($$select public.mcp_execute_v1(public.installation_id(), '00000000-0000-4000-8000-0000003137c1',
  'set_payment_instructions', '{"iban": "DE89 3704 0044 0532 0130 00"}', '00000000-0000-4000-8000-0000003137f3')$$,
  'P0001', null, 'nobody signed in is refused');
select is(current_setting('t.c1')::jsonb->>'status', 'acknowledged', 'the delegate confirms it in the app');
select is(pg_temp.got('t.r13'), 'completed:', 'the same request_id then runs it');
select is(current_setting('t.r13')::jsonb->'data', '{"changed": true}'::jsonb,
  'the answer says the account changed and nothing else');
select is(current_setting('t.after')::jsonb,
  '{"iban": "DE89 3704 0044 0532 0130 00", "bic": "COBADEFF", "bank_name": "Bank A", "paypal_me": "somebody"}'::jsonb,
  'the two fields changed, normalised as the app shows them, and the other ways to pay stayed');
select is(pg_temp.got('t.r14'), 'completed:', 'a repeated call answers the same outcome');
select is(current_setting('t.stored')::jsonb, current_setting('t.after')::jsonb, 'and never writes twice');
select is(pg_temp.events_seen(), 1, 'one audit event is recorded, not one per call');
select is((select count(*)::int from public.events e
            join public.members a on a.id = e.actor_member_id
            join public.members s on s.id = e.subject_member_id
           where e.type = 'payment_instructions_change' and e.status = 'applied'
             and a.user_id = '00000000-0000-4000-8000-0000003137d2' and s.user_id = '00000000-0000-4000-8000-0000003137d1'), 1,
  'by the delegate who confirmed, about the owner');
select is((select payload from public.events where type = 'payment_instructions_change' and workspace_id = '00000000-0000-4000-8000-0000003137c1'),
  '{"fields": ["iban", "bic"], "iban_before": "0189", "iban_after": "3000"}'::jsonb,
  'naming the fields and the last four characters of the IBAN before and after');
select ok((select position('DE89' in payload::text) = 0 and position('FR76' in payload::text) = 0
             and position('COBADEFF' in payload::text) = 0
             from public.events where type = 'payment_instructions_change' and workspace_id = '00000000-0000-4000-8000-0000003137c1'),
  'and never the account itself');
select is(current_setting('t.owner_sees')::int, 1, 'the owner reads the notice');
select is(current_setting('t.member_sees')::int, 0, 'a plain member does not');
select is(pg_temp.got('t.rq'), 'requires_confirmation:', 'a valid QR-IBAN is proposed');
select is(pg_temp.target('00000000-0000-4000-8000-0000003137ed'),
  '{"kind": "payment_instructions", "changes": [{"field": "qr_iban", "from": "", "to": "CH44 3199 9123 0008 8901 2"}]}'::jsonb,
  'in upper case, in groups of four');
select is(pg_temp.got('t.rd'), 'requires_confirmation:', 'another change is proposed');
select is(current_setting('t.cd')::jsonb->>'status', 'target_changed', 'and is stale once the account changed meanwhile');
select is(pg_temp.got('t.re'), 'requires_confirmation:', 'a further change is proposed');
select is(current_setting('t.ce')::jsonb->>'status', 'declined', 'the person declines it in the app');
select is(pg_temp.got('t.re2'), 'denied:confirmation_declined', 'and the repeated call is refused as declined');
select is(pg_temp.account(),
  '{"iban": "DE89 3704 0044 0532 0130 00", "bic": "COBADEFF", "bank_name": "Bank B", "paypal_me": "somebody"}'::jsonb,
  'neither the stale nor the declined change was written');
select is(pg_temp.target('00000000-0000-4000-8000-0000003137ee'),
  '{"kind": "payment_instructions", "changes": [{"field": "bank_name", "from": "Bank A", "to": ""}]}'::jsonb,
  'an empty value is a field cleared, shown as such');
select ok(not has_function_privilege('authenticated', 'public.mcp_op_set_payment_instructions(public.mcp_call_context,jsonb)', 'execute')
          and not has_function_privilege('authenticated', 'public.mcp_target_set_payment_instructions(uuid,jsonb)', 'execute')
          and not has_function_privilege('authenticated', 'public.payment_instructions_plan(uuid,jsonb)', 'execute'),
  'the handler, the target and the plan are reachable only through the dispatcher');

select * from finish();
rollback;
