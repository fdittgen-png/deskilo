-- SPDX-License-Identifier: AGPL-3.0-or-later
-- A workspace host enforces the status its personal home asserts: a suspension bans the bound
-- account for the assertion's lifetime and an erasure for good, an active status lifts only the ban
-- the enforcement set, a status for a subject not bound yet is kept and enforced at the binding, a
-- suspension lapses with its deadline, and only the ban fields of the accounts are touched. The home
-- re-asserts a status that is not active once per refresh period and goes on to the installations
-- that have not acknowledged an erasure.
begin;
select plan(39);

create function pg_temp.u(p_n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000002562b' || p_n)::uuid $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.iss() returns text language sql as $$ select 'https://p.test/auth/v1' $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.w() returns uuid language sql as $$
  select '00000000-0000-4000-8000-00000025620a'::uuid $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.p() returns uuid language sql as $$
  select '00000000-0000-4000-8000-00000025620f'::uuid $$;
grant execute on all functions in schema pg_temp to authenticated, anon;

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



-- ── P: a status that is not active is re-asserted ─────────────────────
alter table public.identity_status_outbox disable trigger protect_federation_history;
update auth.users set banned_until = now() + interval '1 day' where id = pg_temp.u(1);
select is((select count(*)::int from public.identity_status_outbox where subject = pg_temp.u(1)::text), 1,
  'a suspension is issued once');
select is(public.identity_status_reissue(), 0, 'a run with nothing due issues nothing');
update public.identity_status_outbox set issued_at = now() - interval '10 minutes', valid_until = now() - interval '1 minute'
 where subject = pg_temp.u(1)::text;
select is(public.identity_status_reissue(), 1, 'a suspension older than the refresh period is issued again');
select is((select string_agg(revision::text, '<' order by revision) is not null and count(*) = 2 and max(revision) > min(revision)
             from public.identity_status_outbox where subject = pg_temp.u(1)::text), true, 'with a higher revision');
select is(public.identity_status_reissue(), 0, 'and a second run is quiet');
update auth.users set banned_until = null where id = pg_temp.u(1);
update public.identity_status_outbox set issued_at = now() - interval '10 minutes' where subject = pg_temp.u(1)::text;
select is(public.identity_status_reissue(), 0, 'a lifted suspension is asserted active, and not re-asserted');
update auth.users set deleted_at = now() where id = pg_temp.u(1);
update public.identity_status_outbox set issued_at = now() - interval '10 minutes', valid_until = now() - interval '1 minute' where subject = pg_temp.u(1)::text;
select is(public.identity_status_reissue(), 1, 'an erasure that no installation acknowledged goes on');
update public.identity_status_outbox set issued_at = now() - interval '10 minutes' where subject = pg_temp.u(1)::text;
select is(public.identity_status_reissue(), 0, 'an issue that still waits is not repeated');
update public.identity_status_outbox set state = 'refused', outcome = 'unlinked_subject' where subject = pg_temp.u(1)::text and status = 'erased' and state = 'pending';
select is(public.identity_status_reissue(), 0, 'nor one the installation refused for good');
update public.identity_status_outbox set state = 'delivered', delivered_at = now() where subject = pg_temp.u(1)::text and status = 'erased';
update public.identity_status_outbox set issued_at = now() - interval '10 minutes' where subject = pg_temp.u(1)::text;
select is(public.identity_status_reissue(), 0, 'one that was acknowledged does not');
select is((select count(*)::int from cron.job where jobname = 'deskilo-identity-status-reissue'), 1, 'the job runs every minute') ;

alter table public.identity_status_outbox enable trigger protect_federation_history;

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
  p_issuer text default pg_temp.iss(), p_src uuid default pg_temp.p()) returns jsonb language sql as $$
  select jsonb_build_object('protocol', 1, 'kind', 'identity_status',
    'event_id', ('00000000-0000-4000-8000-000000256' || lpad(p_event::text, 3, '0'))::uuid, 'source_installation_id', p_src,
    'target_installation_id', public.installation_id(), 'issuer', p_issuer, 'subject', p_subject,
    'revision', p_rev, 'status', p_status, 'issued_at', p_issued, 'valid_until', p_until) $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
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
grant execute on all functions in schema pg_temp to authenticated, anon;


-- ── W: enforcement ────────────────────────────────────────────────────
select public.operator_set_personal_home('unset');
select public.operator_set_installation_roles(array['workspace_host']);
select public.operator_set_personal_home('endpoint', 'https://p.test', 'sb_publishable_p_key_123');
select public.operator_set_federation_key(pg_temp.p(), 'outbound', 'membership_fact', 'k1', repeat('m', 40));
select public.operator_set_federation_key(pg_temp.u(8), 'inbound', 'identity_status', 'k1', repeat('z', 40));
insert into public.identity_bindings (installation_id, local_user_id, issuer, subject, verified_via, status, revoked_at)
values (public.installation_id(), pg_temp.u(2), pg_temp.iss(), 'sm', 'oidc_identity', 'active', null);
create temp table _o as select count(*)::int n from public.identity_status_outbox;
create temp table _before as select md5((to_jsonb(u) - 'banned_until' - 'updated_at')::text) h from auth.users u where u.id = pg_temp.u(3);
select is(pg_temp.tx(pg_temp.b(21, 'sa', 30, 'suspended')), 'applied', 'a suspension is applied');
select is((select (banned_until > now() + interval '800 seconds' and banned_until <= now() + interval '960 seconds')::text
             from auth.users where id = pg_temp.u(3)), 'true', 'and bans the account for the lifetime plus the skew');
select is((select count(*)::int from public.database_authority_audit where action = 'identity_status_enforced' and target_user_id = pg_temp.u(3)),
  1, 'the ban is audited');
select is((select h from _before), (select md5((to_jsonb(u) - 'banned_until' - 'updated_at')::text) from auth.users u where u.id = pg_temp.u(3)),
  'and nothing else of the account changes');
select is((select count(*)::int from public.identity_status_outbox), (select n from _o), 'nothing is asserted back to anyone');
select is(pg_temp.tx(pg_temp.b(22, 'sa', 31, 'active')), 'applied', 'an active status is applied');
select is((select (banned_until is null)::text from auth.users where id = pg_temp.u(3)), 'true', 'and lifts the ban the enforcement set');
select is((select count(*)::int from public.database_authority_audit where action = 'identity_status_lifted' and target_user_id = pg_temp.u(3)),
  1, 'which is audited');
-- a ban set another way is not the enforcement's to lift, or to shorten
update auth.users set banned_until = now() + interval '30 days' where id = pg_temp.u(2);
select is(pg_temp.tx(pg_temp.b(23, 'sm', 1, 'suspended')) || ' ' || pg_temp.tx(pg_temp.b(24, 'sm', 2, 'active')), 'applied applied',
  'a suspension and its lifting for an account banned another way');
select is((select (banned_until > now() + interval '29 days')::text from auth.users where id = pg_temp.u(2)), 'true',
  'leave that ban as it was');
-- an erasure is final
select is(pg_temp.tx(pg_temp.b(25, 'sa', 32, 'erased')), 'applied', 'an erasure is applied');
select is((select (banned_until > now() + interval '50 years')::text from auth.users where id = pg_temp.u(3)), 'true', 'and bans for good');
select is(pg_temp.tx(pg_temp.b(26, 'sa', 33, 'active')), 'superseded', 'nothing lifts it');

-- a status for a subject not bound yet
select is(pg_temp.tx(pg_temp.b(27, 'later', 1, 'suspended')) || ' ' || pg_temp.tx(pg_temp.b(28, 'never', 1, 'active')),
  'held unlinked_subject', 'a suspension for a subject not bound yet is kept; an active one is refused');
select is(pg_temp.tx(pg_temp.b(30, 'other', 1, 'suspended', p_src => pg_temp.u(8)), p_source => pg_temp.u(8), p_secret => repeat('z', 40)), 'unlinked_subject',
  'one for a subject not bound yet from an installation that is not the home is refused');
select is(pg_temp.tx(pg_temp.b(29, 'gone', 1, 'erased')), 'held', 'so is an erasure');
insert into public.identity_bindings (installation_id, local_user_id, issuer, subject, verified_via, status, revoked_at)
values (public.installation_id(), pg_temp.u(4), pg_temp.iss(), 'later', 'oidc_identity', 'active', null);
select is((select (banned_until is not null and banned_until > now())::text from auth.users where id = pg_temp.u(4)), 'true',
  'the binding enforces what was kept');
-- a ban in force is not taken over, whatever its length
update auth.users set banned_until = now() + interval '10 minutes' where id = pg_temp.u(2);
select is(pg_temp.tx(pg_temp.b(31, 'sm', 3, 'suspended')) || ' ' || pg_temp.tx(pg_temp.b(32, 'sm', 4, 'active')), 'applied applied',
  'a suspension and its lifting for an account banned another way, for a short time');
select is((select (banned_until > now() + interval '9 minutes' and banned_until < now() + interval '11 minutes')::text from auth.users where id = pg_temp.u(2)),
  'true', 'neither extend nor lift that ban');
-- the enforcement writes on a change of state, not on each re-assertion
update auth.users set banned_until = null where id = pg_temp.u(2);
select is(pg_temp.tx(pg_temp.b(33, 'sm', 5, 'suspended')), 'applied', 'a suspension for an account with no ban');
create temp table _ban as select banned_until b, (select count(*)::int from public.database_authority_audit
  where action = 'identity_status_enforced' and target_user_id = pg_temp.u(2)) n from auth.users where id = pg_temp.u(2);
select is(pg_temp.tx(pg_temp.b(34, 'sm', 6, 'suspended')), 'applied', 'asserted again');
select is((select (u.banned_until = _ban.b and (select count(*)::int from public.database_authority_audit
              where action = 'identity_status_enforced' and target_user_id = pg_temp.u(2)) = _ban.n)::text
             from auth.users u, _ban where u.id = pg_temp.u(2)), 'true', 'changes neither the ban nor the audit');
-- revoking the binding does not lift it while the suspension holds
update public.identity_bindings set status = 'revoked', revoked_at = now() where subject = 'sm' and status = 'active';
select is((select (banned_until > now())::text from auth.users where id = pg_temp.u(2)), 'true',
  'unlinking does not lift a ban the status still holds the account out with');
-- a suspension lapses with its deadline
alter table public.identity_status_assertions disable trigger protect_federation_history;
update public.identity_status_assertions set valid_until = now() - interval '1 hour', asserted_at = now() - interval '2 hours' where subject = 'later';
alter table public.identity_status_assertions enable trigger protect_federation_history;
select is(public.identity_status_enforce(pg_temp.iss(), 'later'), 1, 'a suspension past its deadline is looked at again');
select is((select (banned_until is null)::text from auth.users where id = pg_temp.u(4)), 'true', 'and stops being enforced');
-- an erasure holds an account out whoever set the ban in force
update auth.users set banned_until = now() + interval '1 day' where id = pg_temp.u(4);
select is(pg_temp.tx(pg_temp.b(35, 'later', 5, 'erased')), 'applied', 'an erasure for an account banned another way');
select is((select (banned_until > now() + interval '900 years')::text from auth.users where id = pg_temp.u(4)), 'true', 'bans it for good');
select is((select count(*)::int from unnest(array['anon', 'authenticated', 'service_role']) r
            where has_function_privilege(r, 'public.identity_status_enforce(text, text)', 'EXECUTE')
               or has_function_privilege(r, 'public.identity_status_reissue()', 'EXECUTE')), 0, 'no API role reaches the functions');

select * from finish();
rollback;
