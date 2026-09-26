-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1608/#1611: database administrators and database-scoped MCP
-- eligibility. Every caller assertion runs as `authenticated`; positive
-- controls sit beside refusals; state is read back as postgres.
begin;
select plan(20);

create function pg_temp.act_as(p_user uuid, p_aal text default 'aal2') returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)::text, true);
  execute 'set local role authenticated';
end;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_user_meta_data, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000000160a1', '00000000-0000-0000-0000-000000000000', 'authenticated',
  'authenticated', 'adm-a@deskilo.test', '', now(), '{"role":"admin"}', now(), now()),
 ('00000000-0000-4000-8000-0000000160a2', '00000000-0000-0000-0000-000000000000', 'authenticated',
  'authenticated', 'subj-b@deskilo.test', '', now(), '{"database_administrator":true}', now(), now()),
 ('00000000-0000-4000-8000-0000000160a3', '00000000-0000-0000-0000-000000000000', 'authenticated',
  'authenticated', 'adm-c@deskilo.test', '', now(), '{}', now(), now());
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
select pg_temp.act_as('00000000-0000-4000-8000-0000000160a1'); select public.finalize_identity_binding();
select pg_temp.act_as('00000000-0000-4000-8000-0000000160a2'); select public.finalize_identity_binding();
select pg_temp.act_as('00000000-0000-4000-8000-0000000160a3'); select public.finalize_identity_binding();

select pg_temp.act_as('00000000-0000-4000-8000-0000000160a2');
select is(public.request_mcp_eligibility()->>'mcp_eligibility', 'requested', 'a subject asks, with no workspace');
select throws_ok($$select public.provision_database_admin('00000000-0000-4000-8000-0000000160a2')$$,
  'P0001', 'not a database administrator here', 'metadata claiming admin confers nothing');
select throws_ok($$select public.operator_grant_database_admin('00000000-0000-4000-8000-0000000160a2')$$,
  '42501', null, 'the operator door is closed to clients');
select throws_ok($$select count(*) from public.database_administrators$$, '42501', null,
  'the trust store is not readable');
reset role;

select is(public.operator_grant_database_admin('00000000-0000-4000-8000-0000000160a1')->>'status', 'granted',
  'the operator bootstraps an administrator');
select is(public.operator_grant_database_admin('00000000-0000-4000-8000-0000000160a1')->>'status', 'unchanged',
  'bootstrap again is idempotent');
select throws_ok($$select public.operator_revoke_database_admin('00000000-0000-4000-8000-0000000160a1')$$,
  'P0001', 'the last database administrator cannot be removed; add a successor first', 'the last one stays');

select pg_temp.act_as('00000000-0000-4000-8000-0000000160a1', 'aal1');
select throws_ok($$select public.decide_mcp_eligibility('00000000-0000-4000-8000-0000000160a2',
  '00000000-0000-4000-8000-00000000d001', true)$$, 'P0001', 'a database decision needs a second factor (aal2)',
  'aal1 decides nothing');
select pg_temp.act_as('00000000-0000-4000-8000-0000000160a1');
select throws_ok($$select public.decide_mcp_eligibility('00000000-0000-4000-8000-0000000160a1',
  '00000000-0000-4000-8000-00000000d009', true)$$, 'P0001', 'nobody decides their own eligibility',
  'no self-approval');
select is(public.decide_mcp_eligibility('00000000-0000-4000-8000-0000000160a2',
  '00000000-0000-4000-8000-00000000d001', true, 1)->>'status', 'decided', 'an administrator approves');
select is(public.decide_mcp_eligibility('00000000-0000-4000-8000-0000000160a2',
  '00000000-0000-4000-8000-00000000d001', true)->>'status', 'replayed', 'the same decision replays');
select is(public.decide_mcp_eligibility('00000000-0000-4000-8000-0000000160a2',
  '00000000-0000-4000-8000-00000000d001', false)->>'status', 'conflict', 'a changed payload conflicts');
select is(public.provision_database_admin('00000000-0000-4000-8000-0000000160a3', false)->>'status', 'granted',
  'a provisioning administrator adds a reviewer');

select pg_temp.act_as('00000000-0000-4000-8000-0000000160a2');
select is(public.my_database_capabilities()->>'mcp_eligibility', 'eligible', 'one approval, the whole database');

select pg_temp.act_as('00000000-0000-4000-8000-0000000160a3');
select throws_ok($$select public.provision_database_admin('00000000-0000-4000-8000-0000000160a2')$$,
  'P0001', 'provisioning administrators is a separate authority', 'reviewing is not provisioning');
select is(public.revoke_mcp_eligibility('00000000-0000-4000-8000-0000000160a2')->>'status', 'revoked',
  'a second administrator revokes');
select is(public.decide_mcp_eligibility('00000000-0000-4000-8000-0000000160a2',
  '00000000-0000-4000-8000-00000000d001', true)->>'current', 'revoked', 'a replay after revocation revives nothing');

select pg_temp.act_as('00000000-0000-4000-8000-0000000160a2');
select is(public.my_database_capabilities()->>'mcp_eligibility', 'not_requested', 'revoked is not eligible');
reset role;
select throws_ok($$delete from public.database_authority_audit$$, 'P0001',
  'the database authority audit is append-only', 'the audit keeps everything');

update public.mcp_runtime set enabled = true;
select public.operator_revoke_database_admin('00000000-0000-4000-8000-0000000160a3');
select pg_temp.act_as('00000000-0000-4000-8000-0000000160a1');
select public.revoke_my_identity_binding();
reset role;
select is((select enabled from public.mcp_runtime), false,
  'the last administrator unlinked: the MCP runtime switches off');

select * from finish();
rollback;
