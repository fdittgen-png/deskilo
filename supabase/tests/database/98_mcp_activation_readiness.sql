-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1633 / 0312: MCP is switched on only for the installation, epoch and
-- current evidence the operator inspected, and only with nothing blocking;
-- a caller's claim of readiness is not an input. The read-only inspection
-- names each database-side blocker and carries no user, administrator or
-- e-mail. A disable keeps the guard, the denial policies and the audit.
-- After an authority reset the old evidence and the old epoch are refused,
-- and administrators must be provisioned again by the operator. Seeds and
-- operator calls run as postgres (the operator's own authority); the
-- grants are checked for anon and authenticated.
begin;
select plan(32);

-- ── a disabled installation with nothing provisioned ─────────────────
update public.mcp_runtime set enabled = false;
delete from public.identity_authority;
update public.mcp_clients set status = 'revoked' where status = 'active';
update public.database_administrators set status = 'revoked', revoked_at = now() where status = 'active';
select set_config('t.i', public.installation_id()::text, true);
select set_config('t.r0', public.operator_mcp_readiness()::text, true);

select ok((current_setting('t.r0')::jsonb->'blockers') ? 'no_identity_authority',
  'no canonical identity authority is a named blocker');
select ok((current_setting('t.r0')::jsonb->'blockers') ? 'no_database_administrator',
  'no database administrator is a named blocker');
select ok((current_setting('t.r0')::jsonb->'blockers') ? 'no_active_mcp_client',
  'no approved assistant client is a named blocker');
select ok(not (current_setting('t.r0')::jsonb->'blockers') ? 'facade_guard_incomplete',
  'the installed guard is not reported missing (positive control)');
select is(current_setting('t.r0')::jsonb->>'installation_id', current_setting('t.i'),
  'the inspection is bound to this installation');
select is((current_setting('t.r0')::jsonb->>'enabled')::boolean, false, 'MCP is off while inspected');
select throws_like(
  format('select public.operator_activate_mcp_runtime(%L, %s, %L)', current_setting('t.i'),
         current_setting('t.r0')::jsonb->>'epoch', current_setting('t.r0')::jsonb->>'fingerprint'),
  'MCP stays off: not ready%', 'current evidence with blockers does not switch MCP on');

-- ── provision through the ordinary operator path (fictional people) ──
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000001633a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin-1633@deskilo.test', '', now(), now(), now());
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
select set_config('request.jwt.claims', jsonb_build_object('sub', '00000000-0000-4000-8000-0000001633a1',
  'role', 'authenticated', 'aal', 'aal2')::text, true);
select public.finalize_identity_binding();
select set_config('request.jwt.claims', '', true);
select public.operator_grant_database_admin('00000000-0000-4000-8000-0000001633a1', true);
select public.operator_approve_mcp_client('pilot-1633', 'Pilot assistant', true);
select set_config('t.r1', public.operator_mcp_readiness()::text, true);

select is(current_setting('t.r1')::jsonb->'blockers', '[]'::jsonb, 'provisioned: nothing blocks');
select ok(current_setting('t.r1')::jsonb->>'fingerprint' <> current_setting('t.r0')::jsonb->>'fingerprint',
  'provisioning moves the fingerprint');
select ok(position('0000001633a1' in current_setting('t.r1')) = 0
      and position('admin-1633' in current_setting('t.r1')) = 0,
  'the inspection carries no administrator id or e-mail');
select is((current_setting('t.r1')::jsonb#>>'{areas,database_eligibility,administrators}')::int, 1,
  'the administrator is counted');

-- ── wrong target, wrong epoch, stale or forged evidence ──────────────
select throws_like(
  format('select public.operator_activate_mcp_runtime(%L, %s, %L)', gen_random_uuid(),
         current_setting('t.r1')::jsonb->>'epoch', current_setting('t.r1')::jsonb->>'fingerprint'),
  'MCP stays off: this database is installation%', 'another installation id is refused');
select throws_like(
  format('select public.operator_activate_mcp_runtime(%L, %s, %L)', current_setting('t.i'),
         (current_setting('t.r1')::jsonb->>'epoch')::int + 1, current_setting('t.r1')::jsonb->>'fingerprint'),
  'MCP stays off: the inspected epoch%', 'another epoch is refused');
select throws_like(
  format('select public.operator_activate_mcp_runtime(%L, %s, %L)', current_setting('t.i'),
         current_setting('t.r0')::jsonb->>'epoch', current_setting('t.r0')::jsonb->>'fingerprint'),
  'MCP stays off: the readiness evidence is stale%', 'evidence from before provisioning is stale');
select throws_like(
  format('select public.operator_activate_mcp_runtime(%L, %s, %L)', current_setting('t.i'),
         current_setting('t.r1')::jsonb->>'epoch', '{"checksPassed":true}'),
  'MCP stays off: the readiness evidence is stale%', 'a claimed verdict is not evidence');
select is((select enabled from public.mcp_runtime), false, 'every refusal left MCP off');

-- ── the controlled activation, and it is idempotent ──────────────────
select is((public.operator_activate_mcp_runtime(current_setting('t.i')::uuid,
            (current_setting('t.r1')::jsonb->>'epoch')::int,
            current_setting('t.r1')::jsonb->>'fingerprint')->>'enabled')::boolean,
  true, 'the exact installation, epoch and current evidence switch MCP on');
select is((select enabled from public.mcp_runtime), true, 'MCP is on');
select is((public.operator_activate_mcp_runtime(current_setting('t.i')::uuid,
            (current_setting('t.r1')::jsonb->>'epoch')::int,
            current_setting('t.r1')::jsonb->>'fingerprint')->>'unchanged')::boolean,
  true, 'a second identical activation changes nothing');
select is((select count(*)::int from public.database_authority_audit
            where action = 'runtime_activation_checked'
              and detail->>'fingerprint' = current_setting('t.r1')::jsonb->>'fingerprint'), 1,
  'the activation is audited once, with the evidence it used');

-- ── a failed pilot disables; containment stays ───────────────────────
select set_config('t.denials', (select count(*)::text from pg_policy where polname = 'mcp_delegated_deny'), true);
select throws_like(
  format('select public.operator_disable_mcp_runtime(%L, %L)', current_setting('t.i'), 'because'),
  'a disable names its reason%', 'a disable without a known reason is refused');
select throws_like(
  format('select public.operator_disable_mcp_runtime(%L, %L)', gen_random_uuid(), 'pilot_failed'),
  'this database is installation%', 'a disable aimed at another installation is refused');
select is((public.operator_disable_mcp_runtime(current_setting('t.i')::uuid, 'pilot_failed')->>'enabled')::boolean,
  false, 'a failed pilot switches MCP off');
select is((public.mcp_facade_guard_status()->>'pre_request_installed')::boolean, true,
  'the pre-request guard is still installed');
select is((select count(*)::text from pg_policy where polname = 'mcp_delegated_deny'),
  current_setting('t.denials'), 'every delegated-token denial policy is still there');
select is((select detail->>'reason' from public.database_authority_audit
            where action = 'runtime_disable_reason' order by id desc limit 1), 'pilot_failed',
  'the reason is audited');

-- ── recovery: reset moves the epoch; old evidence is refused ─────────
select public.operator_reset_mcp_authority(current_setting('t.i')::uuid, 'synthetic restore drill #1633');
select set_config('t.r2', public.operator_mcp_readiness()::text, true);
select is((current_setting('t.r2')::jsonb->>'epoch')::int, (current_setting('t.r1')::jsonb->>'epoch')::int + 1,
  'the reset moved the epoch');
select ok((current_setting('t.r2')::jsonb->'blockers') ? 'no_database_administrator',
  'administrator trust did not survive the reset');
select throws_like(
  format('select public.operator_activate_mcp_runtime(%L, %s, %L)', current_setting('t.i'),
         current_setting('t.r1')::jsonb->>'epoch', current_setting('t.r1')::jsonb->>'fingerprint'),
  'MCP stays off: the inspected epoch%', 'pre-reset evidence cannot switch MCP back on');

-- ── operator functions are not the application's ─────────────────────
select ok(not has_function_privilege('authenticated', 'public.operator_mcp_readiness()', 'execute')
      and not has_function_privilege('anon', 'public.operator_mcp_readiness()', 'execute'),
  'a signed-in or anonymous caller cannot inspect');
select ok(not has_function_privilege('authenticated', 'public.operator_activate_mcp_runtime(uuid, integer, text)', 'execute')
      and not has_function_privilege('anon', 'public.operator_activate_mcp_runtime(uuid, integer, text)', 'execute'),
  'a signed-in or anonymous caller cannot activate');
select ok(not has_function_privilege('authenticated', 'public.operator_disable_mcp_runtime(uuid, text)', 'execute')
      and not has_function_privilege('anon', 'public.operator_disable_mcp_runtime(uuid, text)', 'execute'),
  'a signed-in or anonymous caller cannot disable');

select * from finish();
rollback;
