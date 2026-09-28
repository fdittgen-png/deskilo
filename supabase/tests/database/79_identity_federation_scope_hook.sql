-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1648: only the operator registers identity clients; the Auth hook rejects
-- caller-overridden email scopes and preserves native/other-client claims.
begin;
select plan(17);

create function pg_temp.identity_event(p_scope text, p_client text default
  '00000000-0000-4000-8000-000000016481') returns jsonb language sql as $$
  select jsonb_build_object('claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', '00000000-0000-4000-8000-000000016482', 'role', 'authenticated',
    'client_id', p_client, 'scope', p_scope,
    'user_metadata', jsonb_build_object('scope', 'openid', 'enabled', true))));
$$;

select public.operator_register_identity_federation_client(
  '00000000-0000-4000-8000-000000016481',
  '00000000-0000-4000-8000-000000016483', 'https://target.example/auth/v1');
select ok(has_function_privilege('supabase_auth_admin',
  'public.identity_federation_token_hook(jsonb)', 'execute'),
  'the Auth service can invoke the hook; member execution is tested below');
select is((select enabled from public.identity_federation_clients where
  client_id = '00000000-0000-4000-8000-000000016481'), false,
  'registration starts disabled, independently of workspace/admin presence');

select throws_ok($$select public.identity_federation_token_hook(
  pg_temp.identity_event('openid profile'))$$, '28000', 'identity_client_disabled',
  'a staged identity client cannot mint tokens');
reset role;
select public.operator_set_identity_federation_client(
  '00000000-0000-4000-8000-000000016481', true);

select is(public.identity_federation_token_hook(pg_temp.identity_event('openid profile')),
  pg_temp.identity_event('openid profile'), 'allowed claims survive unchanged');
select is(public.identity_federation_token_hook(pg_temp.identity_event('profile openid')),
  pg_temp.identity_event('profile openid'), 'scope ordering is immaterial');
select throws_ok($$select public.identity_federation_token_hook(
  pg_temp.identity_event('openid email'))$$, '28000', 'identity_client_scope_refused',
  'requesting email cannot bypass provider defaults or user metadata');
select throws_ok($$select public.identity_federation_token_hook(
  pg_temp.identity_event('openid phone'))$$, '28000', 'identity_client_scope_refused',
  'only the pinned identity scopes are issued');
select throws_ok($$select public.identity_federation_token_hook(
  pg_temp.identity_event('profile'))$$, '28000', 'identity_client_scope_refused',
  'openid is required, preventing a userinfo-only fallback');
select throws_ok($$select public.identity_federation_token_hook(
  pg_temp.identity_event(null))$$, '28000', 'identity_client_scope_refused',
  'missing scope fails closed');
select is(public.identity_federation_token_hook(pg_temp.identity_event(null, null)),
  pg_temp.identity_event(null, null), 'ordinary native sessions are unchanged');
select is(public.identity_federation_token_hook(pg_temp.identity_event('openid email',
  '00000000-0000-4000-8000-000000016484')),
  pg_temp.identity_event('openid email', '00000000-0000-4000-8000-000000016484'),
  'other OAuth clients keep their existing policy and client_id guard');
reset role;

set local role authenticated;
select throws_ok($$select public.identity_federation_token_hook('{}')$$,
  '42501', null, 'a member cannot invoke the Auth hook');
select throws_ok($$select public.operator_set_identity_federation_client(
  '00000000-0000-4000-8000-000000016481', true)$$,
  '42501', null, 'a member cannot enable identity clients');
select throws_ok($$select * from public.identity_federation_clients$$,
  '42501', null, 'protected client configuration is not a public catalogue');
reset role;

select throws_ok($$update public.identity_federation_clients
  set target_auth_url = 'https://another.example/auth/v1'
  where client_id = '00000000-0000-4000-8000-000000016481'$$,
  'P0001', 'identity client target is immutable', 'an existing client cannot be repointed');
select throws_ok($$delete from public.identity_federation_clients
  where client_id = '00000000-0000-4000-8000-000000016481'$$,
  'P0001', 'identity clients are disabled, never forgotten',
  'removal cannot make a previously restricted client unrestricted');
select is(public.mcp_facade_guard_status()->'tables_without_denial', '[]'::jsonb,
  'new protected configuration retains the existing containment invariant');

select * from finish();
rollback;
