-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- 0340 — assistants use the profile's Google sign-in and nothing else.
-- A Google identity opened with OAuth is ready; the same account signed
-- in by password must sign in with Google before consenting; an account
-- without a Google identity can neither ask for approval nor consent.
begin;
select plan(7);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  g uuid := '00000000-0000-4000-8000-000000000339';
  e uuid := '00000000-0000-4000-8000-000000000339';
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (g, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'google-mcp@deskilo.test', '', now(), now(), now()),
         (e, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'email-mcp@deskilo.test', '', now(), now(), now());
  insert into auth.identities (id, provider_id, user_id, identity_data, provider,
                               created_at, updated_at)
  values (gen_random_uuid(), 'google-sub-340', g,
          jsonb_build_object('sub', 'google-sub-340', 'email', 'google-mcp@deskilo.test'),
          'google', now(), now()),
         (gen_random_uuid(), e::text, e,
          jsonb_build_object('sub', e::text, 'email', 'email-mcp@deskilo.test'),
          'email', now(), now());
  perform set_config('deskilo.g', g::text, false);
  perform set_config('deskilo.e', e::text, false);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.as(p_user text, p_method text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object(
    'sub', current_setting('deskilo.' || p_user), 'role', 'authenticated',
    'amr', json_build_array(json_build_object('method', p_method)))::text, false);
$$;

select pg_temp.as('g', 'oauth');
select is(public.mcp_google_status(),
  '{"google_linked": true, "google_session": true}'::jsonb,
  'a Google identity signed in with Google is ready');

select pg_temp.as('g', 'password');
select is(public.mcp_google_status(),
  '{"google_linked": true, "google_session": false}'::jsonb,
  'the same account signed in by password is not');
select throws_like(
  $$ select public.mcp_prepare_connection('client', 'auth-1', '[]'::jsonb) $$,
  '%sign in with Google%',
  'consenting to an assistant needs a Google sign-in');
select throws_like(
  $$ select public.mcp_finalize_connection('auth-1') $$,
  '%sign in with Google%',
  'and so does finishing the connection');

select pg_temp.as('e', 'password');
select is(public.mcp_google_status(),
  '{"google_linked": false, "google_session": false}'::jsonb,
  'an account without Google is not linked');
select ok(not public.mcp_has_google_identity(),
  'the facade refuses it every call (no_google_identity)');

select ok(
  (select position('mcp_has_google_identity' in pg_get_functiondef('public.request_mcp_eligibility()'::regprocedure)) > 0),
  'asking for database approval checks the Google identity');

select * from finish();
rollback;
