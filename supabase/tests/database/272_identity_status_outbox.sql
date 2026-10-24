-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2562 C2b: a personal home commits a signed identity status for each
-- enrolled installation a person consented to, with the account change
-- itself, and a workspace installation applies only an authentic, fresh,
-- first-seen statement about a subject bound to it. Both sides live in this
-- one database: the far installations are foreign ids, the P scenes run with
-- a native authority and the W scenes with an oidc one. pg_net only queues
-- inside the rolled-back transaction, so nothing leaves; the answers of a
-- real W are the cross-project proof (C3), not this file.
begin;
select plan(44);

create function pg_temp.u(p_n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000002562b' || p_n)::uuid $$;
create function pg_temp.iss() returns text language sql as $$ select 'https://p.test/auth/v1' $$;
create function pg_temp.w() returns uuid language sql as $$
  select '00000000-0000-4000-8000-00000025620a'::uuid $$;
create function pg_temp.p() returns uuid language sql as $$
  select '00000000-0000-4000-8000-00000025620f'::uuid $$;

-- ── P: fixtures ───────────────────────────────────────────────────────
select public.operator_set_installation_roles(array['personal_home', 'workspace_host']);
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', pg_temp.iss());
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || n || '-2562@deskilo.test', '', now(), now(), now()
  from generate_series(1, 4) n;
insert into auth.oauth_clients (id, client_name, registration_type, redirect_uris, grant_types,
                                token_endpoint_auth_method)
values ('00000000-0000-4000-8000-0000002562c1', 'W-A identity', 'manual',
        'https://w-a.test/auth/v1/callback', 'authorization_code', 'client_secret_basic');
insert into public.identity_federation_clients (client_id, target_installation_id, target_auth_url, enabled)
values ('00000000-0000-4000-8000-0000002562c1', pg_temp.w(), 'https://w-a.test/auth/v1', true);
do $c$ begin
  execute 'insert into auth.oauth_consents (id, user_id, client_id, scopes) values ($1, $2, $3, $4)'
    using gen_random_uuid(), pg_temp.u(1), '00000000-0000-4000-8000-0000002562c1'::uuid, 'openid';
end $c$;
select public.operator_enrol_installation(pg_temp.w(), 'https://w-a.test',
  'sb_publishable_wa_key_123', array['workspace_host'], array['workspace@1']);
select public.operator_set_federation_key(pg_temp.w(), 'outbound', 'identity_status', 'k1', repeat('p', 40));

-- ── the doors ─────────────────────────────────────────────────────────
select is((select count(*)::int from pg_policy
            where polrelid in ('public.federation_keys'::regclass, 'public.identity_status_outbox'::regclass,
                               'public.federation_inbox_receipts'::regclass,
                               'public.identity_status_assertions'::regclass)
              and not polpermissive and polname in ('mcp_delegated_deny', 'personal_native_session')),
  8, 'both restrictive policies on all four tables');
select is_empty($$select t || r from unnest(array['federation_keys', 'identity_status_outbox',
    'federation_inbox_receipts', 'identity_status_assertions']) t
  cross join unnest(array['anon', 'authenticated', 'service_role', 'deskilo_identity']) r
  where has_table_privilege(r, 'public.' || t, 'SELECT, INSERT, UPDATE, DELETE')$$,
  'no API role holds any privilege on them');
select is_empty($$select p.proname || ' ' || r from pg_proc p
  cross join unnest(array['anon', 'authenticated', 'service_role', 'deskilo_identity']) r
  where p.pronamespace = 'public'::regnamespace
    and p.proname in ('operator_set_federation_key', 'operator_retire_federation_key',
      'federation_signing_input', 'federation_envelope_headers', 'federation_verify',
      'identity_status_linked_targets', 'identity_status_issue', 'identity_status_on_account_change',
      'identity_status_drain', 'identity_status_apply', 'protect_federation_history')
    and has_function_privilege(r, p.oid, 'EXECUTE')$$,
  'no API role executes the internal functions');
select is((select string_agg(r, ',' order by r) from unnest(array['anon', 'authenticated',
    'service_role', 'deskilo_identity']) r
  where has_function_privilege(r, 'public.federation_inbox_accept(text, text, jsonb, text)', 'EXECUTE')),
  'service_role', 'only the service role reaches the inbox');

-- ── P: a status change commits its assertions ─────────────────────────
update auth.users set banned_until = now() + interval '1 day' where id in (pg_temp.u(1), pg_temp.u(2));
select is((select string_agg(status || '>' || target_installation_id, ',') from public.identity_status_outbox
            where subject = pg_temp.u(1)::text),
  'suspended>' || pg_temp.w(), 'a ban commits a suspension for the linked target');
select is((select extract(epoch from valid_until - issued_at)::int || ' ' || (body->>'revision' = revision::text)
             || ' ' || (body->>'issuer') from public.identity_status_outbox where subject = pg_temp.u(1)::text),
  '900 true https://p.test/auth/v1', 'valid for the lifetime, from the issuer');
select is((select count(*)::int from public.identity_status_outbox where subject = pg_temp.u(2)::text),
  0, 'an unlinked person is not enumerated');
update auth.users set banned_until = now() + interval '2 days' where id = pg_temp.u(1);
select is((select count(*)::int from public.identity_status_outbox where subject = pg_temp.u(1)::text),
  1, 'a ban extended is no new status');
update auth.users set banned_until = null where id = pg_temp.u(1);
select is((select string_agg(status, '<' order by revision) from public.identity_status_outbox
            where subject = pg_temp.u(1)::text),
  'suspended<active', 'a lifted ban asserts active, higher revision');

-- ── P: delivery ───────────────────────────────────────────────────────
select is(public.identity_status_drain()->>'sent', '2', 'the drain sends both');
select is((select count(*)::int from public.identity_status_outbox
            where subject = pg_temp.u(1)::text and state = 'sent' and attempts = 1 and net_request_id is not null),
  2, 'and records the attempts');
select is((select count(*)::int from net.http_request_queue q join public.identity_status_outbox o
             on o.net_request_id = q.id
           where q.url = 'https://w-a.test/functions/v1/federation-inbox'
             and q.headers->>'x-deskilo-digest' = encode(extensions.digest(q.body, 'sha256'), 'hex')
             and q.headers->>'x-deskilo-signature' = encode(extensions.hmac(convert_to(
                   public.federation_signing_input('POST', '/federation-inbox', 'identity_status',
                     public.installation_id(), pg_temp.w(), o.event_id,
                     (q.headers->>'x-deskilo-timestamp')::bigint, q.headers->>'x-deskilo-digest', 'k1'),
                   'UTF8'), convert_to(repeat('p', 40), 'UTF8'), 'sha256'), 'hex')),
  2, 'the queued bytes are what the key signed, to the inbox');
select public.operator_revoke_installation(pg_temp.w());
update auth.users set deleted_at = now() where id = pg_temp.u(1);
select is((select count(*)::int from public.identity_status_outbox where status = 'erased'),
  0, 'a revoked enrolment links nobody');

-- ── W: fixtures ───────────────────────────────────────────────────────
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer, oidc_provider)
values ('oidc', pg_temp.iss(), 'custom:deskilo');
insert into public.identity_bindings (installation_id, local_user_id, issuer, subject, verified_via, status, revoked_at)
values (public.installation_id(), pg_temp.u(3), pg_temp.iss(), 'sa', 'oidc_identity', 'active', null),
       (public.installation_id(), pg_temp.u(4), pg_temp.iss(), 'sr', 'oidc_identity', 'revoked', now());
select public.operator_set_federation_key(pg_temp.p(), 'inbound', 'identity_status', 'k1', repeat('s', 40));

create function pg_temp.b(p_event int, p_subject text, p_rev int, p_status text,
  p_issued timestamptz default now(), p_until timestamptz default now() + interval '900 seconds',
  p_issuer text default pg_temp.iss()) returns jsonb language sql as $$
  select jsonb_build_object('protocol', 1, 'kind', 'identity_status',
    'event_id', ('00000000-0000-4000-8000-000000256' || lpad(p_event::text, 3, '0'))::uuid, 'source_installation_id', pg_temp.p(),
    'target_installation_id', public.installation_id(), 'issuer', p_issuer, 'subject', p_subject,
    'revision', p_rev, 'status', p_status, 'issued_at', p_issued, 'valid_until', p_until) $$;
-- Signs `p_signed` as P would and posts `p_sent` (the same unless tampering).
create function pg_temp.tx(p_signed jsonb, p_sent jsonb default null, p_secret text default repeat('s', 40),
  p_key text default 'k1', p_source uuid default pg_temp.p(), p_target uuid default public.installation_id(),
  p_ts bigint default extract(epoch from now())::bigint) returns text language plpgsql as $$
declare
  v_event uuid := (p_signed->>'event_id')::uuid;
  v_digest text := encode(extensions.digest(convert_to(p_signed::text, 'UTF8'), 'sha256'), 'hex');
begin
  return public.federation_inbox_accept('POST', '/federation-inbox', jsonb_build_object(
    'x-deskilo-protocol', '1', 'x-deskilo-purpose', 'identity_status', 'x-deskilo-source', p_source,
    'x-deskilo-target', p_target, 'x-deskilo-event', v_event, 'x-deskilo-timestamp', p_ts::text,
    'x-deskilo-digest', v_digest, 'x-deskilo-key', p_key,
    'x-deskilo-signature', encode(extensions.hmac(convert_to(public.federation_signing_input('POST',
      '/federation-inbox', 'identity_status', p_source, p_target, v_event, p_ts, v_digest, p_key), 'UTF8'),
      convert_to(p_secret, 'UTF8'), 'sha256'), 'hex')),
    encode(convert_to(coalesce(p_sent, p_signed)::text, 'UTF8'), 'base64'))->>'outcome';
end $$;

-- ── W: authentic, fresh, first seen ───────────────────────────────────
select is(pg_temp.tx(pg_temp.b(1, 'sa', 10, 'active')), 'applied', 'a signed active status applies');
select is((select status || ' ' || revision from public.identity_status_assertions where subject = 'sa'),
  'active 10', 'and is held for the subject');
select is(pg_temp.tx(pg_temp.b(1, 'sa', 10, 'active')), 'duplicate', 'the same event is a retry');
select is(pg_temp.tx(pg_temp.b(1, 'sa', 11, 'active')), 'event_conflict',
  'same event, other body: tampering');
select is(pg_temp.tx(pg_temp.b(2, 'sa', 11, 'active'), p_secret => repeat('x', 40)), 'bad_signature',
  'a wrong key signs nothing');
select is(pg_temp.tx(pg_temp.b(2, 'sa', 11, 'active'), p_source => pg_temp.u(9)), 'unknown_installation',
  'no inbound key: unknown');
select is(pg_temp.tx(pg_temp.b(2, 'sa', 11, 'active'), p_target => pg_temp.w()), 'wrong_target',
  'another target is refused');
select is(pg_temp.tx(pg_temp.b(2, 'sa', 11, 'active'), pg_temp.b(2, 'sa', 99, 'active')),
  'bad_digest', 'an unsigned body is refused');
select is(pg_temp.tx(pg_temp.b(2, 'sa', 11, 'active'), p_ts => extract(epoch from now())::bigint + 120),
  'future_request', 'a request beyond the skew is refused');
select is(pg_temp.tx(pg_temp.b(3, 'sa', 11, 'active', now() - interval '1000 seconds',
    now() - interval '100 seconds')), 'expired_assertion', 'an expired assertion is refused');
select is(pg_temp.tx(pg_temp.b(4, 'sa', 11, 'active', now() - interval '880 seconds',
    now() - interval '20 seconds')), 'applied', 'expired within the skew still applies');
select is(pg_temp.tx(pg_temp.b(5, 'sa', 12, 'active', now() + interval '120 seconds',
    now() + interval '600 seconds'), p_ts => extract(epoch from now())::bigint + 25), 'future_assertion',
  'issued beyond the skew is refused');
select is(pg_temp.tx(pg_temp.b(6, 'sa', 12, 'active', now(), now() + interval '5000 seconds')),
  'applied', 'a longer validity is accepted');
select is((select extract(epoch from valid_until - asserted_at)::int from public.identity_status_assertions
            where subject = 'sa'), 900, 'but held for the lifetime here only');
select is(pg_temp.tx(pg_temp.b(7, 'sa', 9, 'suspended')), 'superseded', 'a lower revision changes nothing');
select is(pg_temp.tx(pg_temp.b(8, 'sa', 13, 'suspended')), 'applied', 'a suspension applies');
select is(pg_temp.tx(pg_temp.b(9, 'sa', 12, 'active')), 'superseded', 'a late active cannot undo it');
select is(pg_temp.tx(pg_temp.b(10, 'sa', 14, 'erased')), 'applied', 'an erasure applies');
select is(pg_temp.tx(pg_temp.b(11, 'sa', 15, 'active')), 'superseded', 'and is final');
select is(pg_temp.tx(pg_temp.b(12, 'nobody', 1, 'suspended')), 'unlinked_subject',
  'an unbound subject is refused');
select is(pg_temp.tx(pg_temp.b(13, 'sr', 1, 'active')) || ' ' ||
          pg_temp.tx(pg_temp.b(14, 'sr', 2, 'suspended')), 'unlinked_subject applied',
  'a revoked binding: no active, but a suspension');
select is(pg_temp.tx(pg_temp.b(15, 'sa', 16, 'active', p_issuer => 'https://other.test/auth/v1')),
  'wrong_issuer', 'only the trusted issuer asserts');

-- ── W: rotation, retirement and the API roles ─────────────────────────
select public.operator_set_federation_key(pg_temp.p(), 'inbound', 'identity_status', 'k2', repeat('t', 40));
select is(pg_temp.tx(pg_temp.b(16, 'sr', 3, 'suspended')), 'unknown_key', 'a rotated-out key verifies nothing');
select is(pg_temp.tx(pg_temp.b(16, 'sr', 3, 'suspended'), p_secret => repeat('t', 40), p_key => 'k2'),
  'applied', 'the new key does');
select public.operator_retire_federation_key(pg_temp.p(), 'inbound', 'identity_status', 'k2');
select is(pg_temp.tx(pg_temp.b(17, 'sr', 4, 'suspended'), p_secret => repeat('t', 40), p_key => 'k2'),
  'unknown_installation', 'all keys retired: unknown');
select is((select count(*)::int from public.federation_keys k
            where exists (select 1 from vault.secrets s where s.id = k.vault_secret_id) and retired_at is not null),
  0, 'a retired key has no secret left');
select throws_ok($$delete from public.identity_status_assertions$$, '55000', null,
  'an assertion is never deleted');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000002562b3","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select count(*) from public.identity_status_assertions$$, '42501', null,
  'a signed-in person reads no status');
select throws_ok($$select public.federation_inbox_accept('POST', '/federation-inbox', '{}', '')$$, '42501', null,
  'nor posts to the inbox');
reset role;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok($$select public.federation_inbox_accept('POST', '/federation-inbox', '{}', '')$$, '42501', null,
  'an anonymous caller neither');
reset role;
select is(public.federation_inbox_accept('POST', '/federation-inbox', '{}', 'eyJ9')->>'outcome', 'malformed',
  'no envelope: malformed');

select * from finish();
rollback;
