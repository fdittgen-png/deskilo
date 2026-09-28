-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1648: real native role resolves protected consent before Auth auto-approval;
-- unknown/expired/wrong-account requests fail closed, and purposes cannot overlap.
begin;
select plan(14);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at)
select ('00000000-0000-4000-8000-0000000295' || suffix)::uuid,
  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  suffix || '@consent.deskilo.test', '', now(), now(), now()
from unnest(array['a1','a2']) suffix;
insert into auth.oauth_clients (id, registration_type, redirect_uris, grant_types, token_endpoint_auth_method)
select ('00000000-0000-4000-8000-0000000295' || suffix)::uuid,
  'manual', 'https://target.example/auth/v1/callback', 'authorization_code', 'client_secret_basic'
from unnest(array['c1','c2','c3']) suffix;
select public.operator_register_identity_federation_client(
  '00000000-0000-4000-8000-0000000295c1',
  '00000000-0000-4000-8000-0000000295b1', 'https://target.example/auth/v1');
select public.operator_set_identity_federation_client(
  '00000000-0000-4000-8000-0000000295c1', true);
select public.operator_approve_mcp_client('00000000-0000-4000-8000-0000000295c2','Assistant');
insert into auth.oauth_authorizations (id, authorization_id, client_id,
  redirect_uri, scope, code_challenge, code_challenge_method)
select gen_random_uuid(), repeat(letter,32),
  ('00000000-0000-4000-8000-0000000295' || suffix)::uuid,
  'https://target.example/auth/v1/callback', 'openid profile', repeat('a',43), 's256'
from (values ('a','c1'),('b','c2'),('c','c3')) clients(letter,suffix);
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000295a1","role":"authenticated"}', true);
set local role authenticated;
select is(public.oauth_authorization_context(repeat('a',32))->>'purpose',
  'identity_federation', 'native identity consent requires no workspace or MCP eligibility');
select is(public.oauth_authorization_context(repeat('b',32))->>'purpose',
  'mcp', 'approved assistant uses its existing consent consumer');
select ok(not (public.oauth_authorization_context(repeat('a',32)) ?|
  array['state','nonce','authorization_code','code_challenge']),
  'context discloses no OAuth credentials');
select throws_ok($$select public.oauth_authorization_context(repeat('c',32))$$,
  'P0001','oauth client purpose unavailable','unknown client does not become MCP');
select throws_ok($$select public.oauth_authorization_context('invalid')$$,
  'P0001','oauth authorization unavailable','malformed authorization fails closed');
reset role;
update auth.oauth_authorizations set user_id='00000000-0000-4000-8000-0000000295a2'
  where authorization_id=repeat('a',32);
set local role authenticated;
select throws_ok($$select public.oauth_authorization_context(repeat('a',32))$$,
  'P0001','oauth authorization unavailable','another account cannot claim the request');
reset role;
update auth.oauth_authorizations set user_id=null, scope='openid email'
  where authorization_id=repeat('a',32);
set local role authenticated;
select throws_ok($$select public.oauth_authorization_context(repeat('a',32))$$,
  'P0001','identity authorization refused','identity scope override is refused before consent');
reset role;
update auth.oauth_authorizations set scope='openid profile', redirect_uri='https://other.example/callback'
  where authorization_id=repeat('a',32);
set local role authenticated;
select throws_ok($$select public.oauth_authorization_context(repeat('a',32))$$,
  'P0001','identity authorization refused','redirect is the exact registered target');
reset role;
update auth.oauth_authorizations set redirect_uri='https://target.example/auth/v1/callback',
  created_at=now()-interval '2 minutes',expires_at=now()-interval '1 minute'
  where authorization_id=repeat('a',32);
set local role authenticated;
select throws_ok($$select public.oauth_authorization_context(repeat('a',32))$$,
  'P0001','oauth authorization unavailable','expired requests cannot resume');
reset role;
update auth.oauth_authorizations set expires_at=now()+interval '1 minute'
  where authorization_id=repeat('a',32);
select public.operator_set_identity_federation_client(
  '00000000-0000-4000-8000-0000000295c1',false);
set local role authenticated;
select throws_ok($$select public.oauth_authorization_context(repeat('a',32))$$,
  'P0001','identity authorization refused','disabled identity client cannot request consent');
reset role;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000295a1","role":"authenticated","client_id":"00000000-0000-4000-8000-0000000295c2"}',true);
set local role authenticated;
select throws_ok($$select public.oauth_authorization_context(repeat('b',32))$$,
  'P0001','connections are managed in the Deskilo app','delegated sessions cannot manage consent');
reset role;
select throws_ok($$select public.operator_approve_mcp_client(
  '00000000-0000-4000-8000-0000000295c1','Wrong purpose')$$,
  'P0001','oauth client purpose is already reserved','identity clients cannot become business clients');
select throws_ok($$select public.operator_register_identity_federation_client(
  '00000000-0000-4000-8000-0000000295c2',
  '00000000-0000-4000-8000-0000000295b1','https://target.example/auth/v1')$$,
  'P0001','oauth client purpose is already reserved','business clients cannot become identity clients');
set local role anon;
select throws_ok($$select public.oauth_authorization_context(repeat('b',32))$$,
  '42501',null,'anonymous callers cannot inspect consent');
reset role;
select * from finish();
rollback;
