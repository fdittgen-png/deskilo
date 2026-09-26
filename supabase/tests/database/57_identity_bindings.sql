-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1647: one canonical identity bound to local users. Every caller
-- assertion runs as `authenticated`; positive bindings sit beside every
-- refusal, and refused writes are read back as postgres.
begin;
select plan(18);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  execute 'set local role authenticated';
end;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, raw_user_meta_data, is_anonymous, created_at, updated_at)
values
 ('00000000-0000-4000-8000-0000000016a1', '00000000-0000-0000-0000-000000000000', 'authenticated',
  'authenticated', 'ident-a@deskilo.test', '', now(), '{"sub":"spoofed","iss":"https://evil.test"}', false, now(), now()),
 ('00000000-0000-4000-8000-0000000016a2', '00000000-0000-0000-0000-000000000000', 'authenticated',
  'authenticated', 'ident-b@deskilo.test', '', now(), '{}', false, now(), now()),
 ('00000000-0000-4000-8000-0000000016a3', '00000000-0000-0000-0000-000000000000', 'authenticated',
  'authenticated', 'ident-c@deskilo.test', '', null, '{}', false, now(), now()),
 ('00000000-0000-4000-8000-0000000016a4', '00000000-0000-0000-0000-000000000000', 'authenticated',
  'authenticated', null, '', null, '{}', true, now(), now());

select is((select count(*)::int from public.installation_identity), 1, 'one installation id');

delete from public.identity_authority;
select pg_temp.act_as('00000000-0000-4000-8000-0000000016a1');
select is(public.finalize_identity_binding()->>'status', 'unavailable',
  'no configured authority: nothing is bound');
reset role;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');

select pg_temp.act_as('00000000-0000-4000-8000-0000000016a1');
select is(public.my_identity_status()->>'status', 'unlinked', 'configured, not yet bound');
select is(public.finalize_identity_binding()->>'status', 'verified', 'a confirmed account binds');
select is(public.finalize_identity_binding()->>'status', 'verified', 'binding again is idempotent');
select throws_ok('select count(*) from public.identity_bindings', '42501', null,
  'a client cannot read the bindings table');
select throws_ok($$insert into public.identity_bindings (installation_id, local_user_id, issuer, subject, verified_via)
  values (gen_random_uuid(), '00000000-0000-4000-8000-0000000016a2', 'https://x.test', 'forged', 'native_authority')$$,
  '42501', null, 'a client cannot write a binding');
select pg_temp.act_as('00000000-0000-4000-8000-0000000016a2');
select is(public.finalize_identity_binding()->>'status', 'verified', 'a second person binds separately');
select pg_temp.act_as('00000000-0000-4000-8000-0000000016a3');
select is(public.finalize_identity_binding()->>'reason', 'unverified', 'an unconfirmed account is ineligible');
select pg_temp.act_as('00000000-0000-4000-8000-0000000016a4');
select is(public.finalize_identity_binding()->>'reason', 'account', 'an anonymous account is ineligible');
reset role;
select is((select subject from public.identity_bindings
            where local_user_id = '00000000-0000-4000-8000-0000000016a1' and status = 'active'),
  '00000000-0000-4000-8000-0000000016a1', 'native subject is the local id, never metadata');
select is((select count(*)::int from public.identity_bindings
            where local_user_id in ('00000000-0000-4000-8000-0000000016a3', '00000000-0000-4000-8000-0000000016a4')),
  0, 'refusals left no row behind');

select pg_temp.act_as('00000000-0000-4000-8000-0000000016a1');
select is((public.revoke_my_identity_binding()->>'revoked')::boolean, true, 'the caller unlinks itself');
reset role;
select throws_ok($$update public.identity_bindings set subject = 'rewritten'
  where local_user_id = '00000000-0000-4000-8000-0000000016a1'$$,
  'P0001', 'an identity binding is revoked, never rewritten', 'history is immutable');

-- OIDC: the subject comes from auth.identities for the configured provider.
delete from public.identity_bindings;
update public.identity_authority
   set kind = 'oidc', issuer = 'https://id.deskilo.test/realms/d', oidc_provider = 'keycloak';
insert into auth.identities (id, provider_id, user_id, identity_data, provider, created_at, updated_at) values
 (gen_random_uuid(), 'kc-1', '00000000-0000-4000-8000-0000000016a1',
  '{"sub":"kc-1","iss":"https://id.deskilo.test/realms/d"}', 'keycloak', now(), now()),
 (gen_random_uuid(), 'kc-1b', '00000000-0000-4000-8000-0000000016a2',
  '{"sub":"kc-1","iss":"https://id.deskilo.test/realms/d"}', 'keycloak', now(), now()),
 (gen_random_uuid(), 'kc-3', '00000000-0000-4000-8000-0000000016a3',
  '{"sub":"kc-3","iss":"https://evil.test"}', 'keycloak', now(), now());
select pg_temp.act_as('00000000-0000-4000-8000-0000000016a1');
select is(public.finalize_identity_binding()->>'status', 'verified', 'the provider identity binds');
select pg_temp.act_as('00000000-0000-4000-8000-0000000016a2');
select is(public.finalize_identity_binding()->>'reason', 'subject_bound_to_another_user',
  'one canonical subject, one local user per installation');
select pg_temp.act_as('00000000-0000-4000-8000-0000000016a3');
select is(public.finalize_identity_binding()->>'reason', 'issuer_mismatch',
  'an identity from another issuer is refused');
reset role;
select is((select subject from public.identity_bindings where status = 'active'), 'kc-1',
  'the bound subject is the provider''s, not the user metadata''s');

select * from finish();
rollback;
