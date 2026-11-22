-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Federation hardening: the operator functions are the operator's alone; a request that cannot be
-- authenticated gets one refusal whichever way it fails, and a request too old is refused as a
-- request too new is; an identity from an OpenID provider binds only when it names the configured
-- issuer; the personal home lists the people and the business of another installation only while
-- that business keeps its members directory on, and a business asserts whether it does.
begin;
select plan(25);

create function pg_temp.id(p_tail text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-' || p_tail)::uuid $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.u(p_n int) returns uuid language sql as $$
  select pg_temp.id('00002563e' || lpad(p_n::text, 3, '0')) $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.iss() returns text language sql as $$ select 'https://p.test/auth/v1' $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
-- W-A, W-B, P and a stranger, by letter.
create function pg_temp.inst(p_c text) returns uuid language sql as $$
  select pg_temp.id('000002563a0' || p_c) $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.ws() returns uuid language sql as $$ select pg_temp.id('000002563f01') $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.ref(p_c text) returns text language sql as $$ select pg_temp.inst(p_c) || ':' || pg_temp.ws() $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
-- plpgsql, not an inlinable SQL function: its own statement takes a fresh
-- snapshot, so it sees what an earlier go() in the same statement wrote.
create function pg_temp.sees(p_field text, p_viewer int) returns text language plpgsql as $$
begin return public.account_field_visible_to(pg_temp.u(1), p_field, pg_temp.u(p_viewer))::text; end $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.mine(p_c text) returns text language plpgsql as $$
declare v jsonb;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.u(1), 'role', 'authenticated')::text, true);
  select e into v from jsonb_array_elements(public.my_personal_workspace_refs_v1()->'refs') e
   where e->>'network_id' = pg_temp.ref(p_c);
  perform set_config('request.jwt.claims', '', true);
  return coalesce((v->>'freshness') || ' ' || coalesce(v->>'status', '-'), 'none');
end $$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- ── P: fixtures ───────────────────────────────────────────────────────
select public.operator_set_installation_roles(array['personal_home', 'workspace_host']);
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', pg_temp.iss());
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || n || '-2563@deskilo.test', '', now(), now(), now()
  from generate_series(1, 4) n;
insert into auth.oauth_clients (id, client_name, registration_type, redirect_uris, grant_types,
                                token_endpoint_auth_method)
select pg_temp.id('000002563c0' || c), 'W-' || c, 'manual',
       'https://w-' || c || '.test/auth/v1/callback', 'authorization_code', 'client_secret_basic'
  from unnest(array['a', 'b']) c;
insert into public.identity_federation_clients (client_id, target_installation_id, target_auth_url, enabled)
select pg_temp.id('000002563c0' || c), pg_temp.inst(c), 'https://w-' || c || '.test/auth/v1', true
  from unnest(array['a', 'b']) c;
-- u1, u2 consented to W-A; u2, u3 to W-B; u4 to nobody.
do $c$ declare r record; begin
  for r in select * from (values (1, 'a'), (2, 'a'), (2, 'b'), (3, 'b')) v(n, c) loop
    execute 'insert into auth.oauth_consents (id, user_id, client_id, scopes) values ($1, $2, $3, $4)'
      using gen_random_uuid(), pg_temp.u(r.n), pg_temp.id('000002563c0' || r.c), 'openid';
  end loop;
end $c$;
do $c$ declare c text; begin
  foreach c in array array['a', 'b'] loop
    perform public.operator_enrol_installation(pg_temp.inst(c), 'https://w-' || c || '.test',
      'sb_publishable_w' || c || '_key_123', array['workspace_host'], array['workspace@1']);
    perform public.operator_set_federation_key(pg_temp.inst(c), 'inbound', 'membership_fact', 'k1', repeat(c, 40));
  end loop;
end $c$;
-- u1 shows identity to my spaces, about to the chosen space W-A:ws only.
insert into public.account_field_audience (user_id, field, audience)
values (pg_temp.u(1), 'identity', 'my_spaces'), (pg_temp.u(1), 'about', 'chosen_spaces');
insert into public.account_field_audience_spaces (user_id, field, workspace_network_id)
values (pg_temp.u(1), 'about', pg_temp.ref('a'));

-- A fact as the source signs it; now() is the transaction's, so a rebuilt
-- fact is byte-identical.
create function pg_temp.f(p_e int, p_s text, p_u int, p_r int, p_st text,
  p_at timestamptz default now(), p_issuer text default pg_temp.iss(), p_ws text default null,
  p_extra jsonb default '{}')
returns jsonb language sql as $$
  select jsonb_build_object('protocol', 1, 'kind', 'membership_fact',
    'event_id', pg_temp.id('0000025631' || lpad(p_e::text, 2, '0')),
    'source_installation_id', pg_temp.inst(p_s), 'target_installation_id', public.installation_id(),
    'issuer', p_issuer, 'subject', pg_temp.u(p_u), 'network_id', pg_temp.ref(coalesce(p_ws, p_s)),
    'revision', p_r, 'status', p_st, 'asserted_at', p_at,
    'valid_until', p_at + interval '900 seconds') || p_extra $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
-- Signs the fact as its source would and posts it to the inbox.
create function pg_temp.go(p_e int, p_s text, p_u int, p_r int, p_st text,
  p_at timestamptz default now(), p_issuer text default pg_temp.iss(), p_ws text default null,
  p_extra jsonb default '{}')
returns text language plpgsql as $$
declare
  v_body jsonb := pg_temp.f(p_e, p_s, p_u, p_r, p_st, p_at, p_issuer, p_ws, p_extra);
  v_src uuid := pg_temp.inst(p_s);
  v_to uuid := public.installation_id();
  v_ts bigint := extract(epoch from now())::bigint;
  v_digest text := encode(extensions.digest(convert_to(v_body::text, 'UTF8'), 'sha256'), 'hex');
  v_h jsonb := jsonb_build_object('protocol', '1', 'purpose', 'membership_fact', 'source', v_src,
    'target', v_to, 'event', v_body->>'event_id', 'timestamp', v_ts::text, 'digest', v_digest, 'key', 'k1');
begin
  v_h := v_h || jsonb_build_object('signature', encode(extensions.hmac(convert_to(
    public.federation_signing_input('POST', '/federation-inbox', 'membership_fact', v_src, v_to,
      (v_body->>'event_id')::uuid, v_ts, v_digest, 'k1'), 'UTF8'),
    convert_to(repeat(p_s, 40), 'UTF8'), 'sha256'), 'hex'));
  return public.federation_inbox_accept('POST', '/federation-inbox',
    (select jsonb_object_agg('x-deskilo-' || key, value) from jsonb_each(v_h)),
    encode(convert_to(v_body::text, 'UTF8'), 'base64'))->>'outcome';
end $$;
grant execute on all functions in schema pg_temp to authenticated, anon;


-- ── the operator functions ────────────────────────────────────────────
select is((select count(*)::int from unnest(array['anon', 'authenticated', 'service_role']) r
            where has_function_privilege(r, 'public.operator_set_personal_home(text, text, text, uuid)', 'EXECUTE')
               or has_function_privilege(r, 'public.operator_set_installation_roles(text[], uuid)', 'EXECUTE')), 0,
  'no API role executes the operator functions');

-- ── P: whether the business keeps its directory on ───────────────────
select is(pg_temp.go(1, 'a', 1, 10, 'active') || ' ' || pg_temp.go(2, 'a', 2, 11, 'active'), 'applied applied',
  'facts from W-A that do not say: applied');
select is((select string_agg(members_directory::text, ',' order by user_id) from public.membership_facts where network_id = pg_temp.ref('a')),
  'false,false', 'a fact that does not say keeps the directory off');
select is((select count(*)::int from public.personal_directory_relationships(pg_temp.u(1)) r where r.network_id = pg_temp.ref('a')), 0,
  'the business is not listed while its directory is off');
select is(pg_temp.go(3, 'a', 1, 10, 'active', now() + interval '10 seconds', p_extra => '{"members_directory": true}'), 'renewed',
  'the same fact renewed with the directory on');
select is((select members_directory::text from public.membership_facts where user_id = pg_temp.u(1) and network_id = pg_temp.ref('a')),
  'true', 'the renewal carries the value');
select is((select count(*)::int from public.personal_directory_relationships(pg_temp.u(1)) r where r.network_id = pg_temp.ref('a')), 1,
  'the business is listed once its directory is on');
select is(pg_temp.go(4, 'a', 2, 12, 'active', p_extra => '{"members_directory": "yes"}'), 'malformed',
  'a value that is not a boolean is not a fact');
select is(pg_temp.go(5, 'a', 1, 13, 'tombstone', p_extra => '{"members_directory": true}'), 'applied', 'a tombstone is applied');
select is((select members_directory::text from public.membership_facts where user_id = pg_temp.u(1) and network_id = pg_temp.ref('a')),
  'false', 'and keeps no directory');
select is(pg_temp.go(6, 'a', 1, 14, 'active', p_extra => '{"members_directory": true}'), 'applied', 'and a rejoin says it again');

-- ── W: fixtures ───────────────────────────────────────────────────────
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer, oidc_provider)
values ('oidc', pg_temp.iss(), 'custom:deskilo');
select public.operator_set_personal_home('unset');
select public.operator_set_installation_roles(array['workspace_host']);
select public.operator_set_personal_home('endpoint', 'https://p.test', 'sb_publishable_p_key_123');
select public.operator_set_federation_key(pg_temp.inst('f'), 'outbound', 'membership_fact', 'k1', repeat('m', 40));
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, environment, booking_rules, feature_flags)
values (pg_temp.ws(), 'Facts', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(4), 'dev', '{}', '{}');
insert into public.identity_bindings (installation_id, local_user_id, issuer, subject, verified_via, status, revoked_at)
values (public.installation_id(), pg_temp.u(4), pg_temp.iss(), pg_temp.u(1)::text, 'oidc_identity', 'active', null);
create function pg_temp.out() returns text language sql as $$
  select string_agg(status, '<' order by revision, asserted_at) from public.membership_fact_outbox
   where subject = pg_temp.u(1)::text $$;
grant execute on all functions in schema pg_temp to authenticated, anon;


-- the business keeps its directory off: the fact says so
update public.workspaces set feature_flags = '{"membersDirectory": false}'::jsonb where id = pg_temp.ws();
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status)
values (pg_temp.id('000004328d01'), pg_temp.ws(), pg_temp.u(4), false, false, 'active');
select is((select body->>'members_directory' from public.membership_fact_outbox where subject = pg_temp.u(1)::text),
  'false', 'a fact asserts that the directory is off');
update public.workspaces set feature_flags = feature_flags || '{"membersDirectory": true}'::jsonb where id = pg_temp.ws();
select is((select last_asserted_at is null from public.membership_fact_state where subject = pg_temp.u(1)::text), true,
  'changing the setting marks the business''s facts for re-assertion');
select is(public.membership_fact_reconcile()::text, '{"changed": 0, "renewed": 1}', 'the reconcile re-asserts it');
select is((select count(*) filter (where body->>'members_directory' = 'false')::text || ' ' ||
                  count(*) filter (where body->>'members_directory' = 'true')::text
             from public.membership_fact_outbox where subject = pg_temp.u(1)::text),
  '1 1', 'with the value now in force: the first said off, the renewal says on');

-- ── W: a request that cannot be authenticated ─────────────────────────
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer, oidc_provider) values ('oidc', pg_temp.iss(), 'custom:deskilo');
select public.operator_set_federation_key(pg_temp.inst('a'), 'inbound', 'identity_status', 'k1', repeat('s', 40));
create function pg_temp.b(p_event int, p_subject text, p_rev int, p_status text) returns jsonb language sql as $$
  select jsonb_build_object('protocol', 1, 'kind', 'identity_status',
    'event_id', ('00000000-0000-4000-8000-0000004328' || lpad(p_event::text, 2, '0'))::uuid, 'source_installation_id', pg_temp.inst('a'),
    'target_installation_id', public.installation_id(), 'issuer', pg_temp.iss(), 'subject', p_subject,
    'revision', p_rev, 'status', p_status, 'issued_at', now(), 'valid_until', now() + interval '900 seconds') $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.tx(p_signed jsonb, p_secret text default repeat('s', 40), p_key text default 'k1',
  p_source uuid default pg_temp.inst('a'), p_target uuid default public.installation_id(),
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
    encode(convert_to(p_signed::text, 'UTF8'), 'base64'))->>'outcome';
end $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
insert into public.identity_bindings (installation_id, local_user_id, issuer, subject, verified_via, status, revoked_at)
values (public.installation_id(), pg_temp.u(3), pg_temp.iss(), 'sa', 'oidc_identity', 'active', null);
select is(pg_temp.tx(pg_temp.b(1, 'sa', 1, 'active'), p_secret => repeat('x', 40)) || ' ' ||
          pg_temp.tx(pg_temp.b(2, 'sa', 1, 'active'), p_source => pg_temp.u(9)) || ' ' ||
          pg_temp.tx(pg_temp.b(3, 'sa', 1, 'active'), p_target => pg_temp.id('000004328a99')) || ' ' ||
          pg_temp.tx(pg_temp.b(4, 'sa', 1, 'active'), p_key => 'k9'),
  'unauthorized unauthorized unauthorized unauthorized',
  'a wrong key, an unknown installation, another target and an unknown key are one refusal');
select is(pg_temp.tx(pg_temp.b(5, 'sa', 1, 'active'), p_ts => extract(epoch from now())::bigint + 120), 'future_request',
  'a request newer than the skew allows is refused');
select is(pg_temp.tx(pg_temp.b(6, 'sa', 1, 'active'), p_ts => extract(epoch from now())::bigint - 1000), 'stale_request',
  'a request older than the lifetime and the skew is refused');
select is(pg_temp.tx(pg_temp.b(7, 'sa', 1, 'active'), p_ts => extract(epoch from now())::bigint - 20), 'applied',
  'one within them is accepted');

-- ── an identity from the configured provider binds only under the configured issuer ──
update public.identity_authority set kind = 'oidc', issuer = 'https://id.4328.test/realms/d', oidc_provider = 'custom:kc4328';
delete from public.identity_bindings where subject = 'sa';
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'i' || n || '-4328@deskilo.test', '', now(), now(), now() from generate_series(5, 10) n
on conflict (id) do nothing;
insert into auth.identities (id, provider_id, user_id, identity_data, provider, created_at, updated_at) values
 (gen_random_uuid(), 'kc-5', pg_temp.u(5), '{"sub":"kc-5","iss":"https://id.4328.test/realms/d"}', 'custom:kc4328', now(), now()),
 (gen_random_uuid(), 'kc-6', pg_temp.u(6), '{"sub":"kc-6","email":"i6@x.test"}', 'custom:kc4328', now(), now()),
 (gen_random_uuid(), 'kc-7', pg_temp.u(7), '{"sub":"kc-7","iss":"https://evil.test"}', 'custom:kc4328', now(), now()),
 (gen_random_uuid(), 'kc-8', pg_temp.u(8), '{"sub":"kc-8"}', 'custom:kc4328', now(), now()),
 (gen_random_uuid(), 'kc-9', pg_temp.u(9), '{"sub":"kc-9"}', 'custom:kc4328', now(), now()),
 (gen_random_uuid(), 'em-10', pg_temp.u(10), '{"sub":"em-10","email":"i10@x.test","email_verified":true}', 'email', now(), now());
insert into auth.custom_oauth_providers (provider_type, identifier, name, client_id, client_secret, issuer, discovery_url, enabled)
values ('oidc', 'custom:kc4328', 'kc4328', 'c4328', 'secret', 'https://id.4328.test/realms/d',
        'https://id.4328.test/realms/d/.well-known/openid-configuration', true);
create function pg_temp.bind(p_n int) returns text language plpgsql as $$
declare v jsonb;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.u(p_n), 'role', 'authenticated')::text, true);
  v := public.finalize_identity_binding();
  return coalesce(v->>'reason', v->>'status');
end $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
select is(pg_temp.bind(5), 'verified', 'an identity that names the issuer binds');
select is(pg_temp.bind(6), 'verified', 'one that names none binds when the provider''s own record names the issuer');
select is(pg_temp.bind(7), 'issuer_mismatch', 'one that names another issuer is refused');
update auth.custom_oauth_providers set issuer = 'https://other.4328.test' where identifier = 'custom:kc4328';
select is(pg_temp.bind(8), 'issuer_mismatch', 'one that names none is refused when the provider''s record names another');
update auth.custom_oauth_providers set provider_type = 'oauth2', issuer = null, discovery_url = null,
  authorization_url = 'https://id.4328.test/auth', token_url = 'https://id.4328.test/token', userinfo_url = 'https://id.4328.test/userinfo'
 where identifier = 'custom:kc4328';
select is(pg_temp.bind(9), 'issuer_mismatch', 'and when the provider is a plain OAuth2 one with no issuer');
-- the built-in sign-in methods bind through the native authority, which reads no identity record
update public.identity_authority set kind = 'native', oidc_provider = null;
select is(pg_temp.bind(10), 'verified', 'an email sign-in binds under the native authority');

select * from finish();
rollback;
