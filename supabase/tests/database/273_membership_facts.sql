-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2563 C2: a workspace installation (W) commits a membership fact with the
-- membership change itself and keeps a high-water that survives deletion;
-- a personal home (P) accepts, over #2562's signed inbox, only an authentic
-- fact from the workspace's own installation about a person of its own
-- identity who consented to that installation, and decides my_spaces and
-- chosen_spaces from facts in force. Both sides live in this one database:
-- W-A and W-B are foreign ids on the P side, P is a foreign id on the W
-- side. pg_net only queues inside the rolled-back transaction.
begin;
select plan(40);

create function pg_temp.id(p_tail text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-' || p_tail)::uuid $$;
create function pg_temp.u(p_n int) returns uuid language sql as $$
  select pg_temp.id('00002563e' || lpad(p_n::text, 3, '0')) $$;
create function pg_temp.iss() returns text language sql as $$ select 'https://p.test/auth/v1' $$;
-- W-A, W-B, P and a stranger, by letter.
create function pg_temp.inst(p_c text) returns uuid language sql as $$
  select pg_temp.id('000002563a0' || p_c) $$;
create function pg_temp.ws() returns uuid language sql as $$ select pg_temp.id('000002563f01') $$;
create function pg_temp.ref(p_c text) returns text language sql as $$ select pg_temp.inst(p_c) || ':' || pg_temp.ws() $$;
-- plpgsql, not an inlinable SQL function: its own statement takes a fresh
-- snapshot, so it sees what an earlier go() in the same statement wrote.
create function pg_temp.sees(p_field text, p_viewer int) returns text language plpgsql as $$
begin return public.account_field_visible_to(pg_temp.u(1), p_field, pg_temp.u(p_viewer))::text; end $$;
create function pg_temp.mine(p_c text) returns text language plpgsql as $$
declare v jsonb;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.u(1), 'role', 'authenticated')::text, true);
  select e into v from jsonb_array_elements(public.my_personal_workspace_refs_v1()->'refs') e
   where e->>'network_id' = pg_temp.ref(p_c);
  perform set_config('request.jwt.claims', '', true);
  return coalesce((v->>'freshness') || ' ' || coalesce(v->>'status', '-'), 'none');
end $$;

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
  p_at timestamptz default now(), p_issuer text default pg_temp.iss(), p_ws text default null)
returns jsonb language sql as $$
  select jsonb_build_object('protocol', 1, 'kind', 'membership_fact',
    'event_id', pg_temp.id('0000025631' || lpad(p_e::text, 2, '0')),
    'source_installation_id', pg_temp.inst(p_s), 'target_installation_id', public.installation_id(),
    'issuer', p_issuer, 'subject', pg_temp.u(p_u), 'network_id', pg_temp.ref(coalesce(p_ws, p_s)),
    'revision', p_r, 'status', p_st, 'asserted_at', p_at,
    'valid_until', p_at + interval '900 seconds') $$;
-- Signs the fact as its source would and posts it to the inbox.
create function pg_temp.go(p_e int, p_s text, p_u int, p_r int, p_st text,
  p_at timestamptz default now(), p_issuer text default pg_temp.iss(), p_ws text default null)
returns text language plpgsql as $$
declare
  v_body jsonb := pg_temp.f(p_e, p_s, p_u, p_r, p_st, p_at, p_issuer, p_ws);
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

-- ── the doors ─────────────────────────────────────────────────────────
select is((select count(*)::int from pg_policy
            where polrelid in ('public.membership_facts'::regclass, 'public.membership_fact_state'::regclass,
                               'public.membership_fact_outbox'::regclass)
              and not polpermissive and polname in ('mcp_delegated_deny', 'personal_native_session')),
  6, 'both restrictive policies on all three tables');
select is_empty($$select t || r from unnest(array['membership_facts', 'membership_fact_state',
    'membership_fact_outbox']) t
  cross join unnest(array['anon', 'authenticated', 'service_role', 'deskilo_identity']) r
  where has_table_privilege(r, 'public.' || t, 'SELECT, INSERT, UPDATE, DELETE')$$,
  'no API role holds any privilege on them');
select is_empty($$select p.proname || ' ' || r from pg_proc p
  cross join unnest(array['anon', 'authenticated', 'service_role', 'deskilo_identity']) r
  where p.pronamespace = 'public'::regnamespace
    and (p.proname like 'membership\_fact\_%' or p.proname in ('protect_membership_fact',
      'account_field_visible_to', 'operator_set_federation_key'))
    and has_function_privilege(r, p.oid, 'EXECUTE')$$,
  'no API role executes the internal functions');

-- ── P: verified facts decide the shared spaces ────────────────────────
select is(pg_temp.sees('identity', 2), 'false', 'no fact: no shared space');
select is(pg_temp.go(1, 'a', 1, 10, 'active') || ' ' ||
          pg_temp.go(2, 'b', 2, 20, 'active') || ' ' ||
          pg_temp.sees('identity', 2), 'applied applied false',
  'the same local workspace on two installations is two spaces');
select is(pg_temp.go(3, 'a', 2, 11, 'paused') || ' ' ||
          pg_temp.sees('identity', 2) || ' ' || pg_temp.sees('about', 2), 'applied true true',
  'a paused co-member of a verified space: my spaces and the chosen space');
select is(pg_temp.go(4, 'b', 3, 21, 'active') || ' ' ||
          pg_temp.sees('about', 3) || ' ' || pg_temp.sees('identity', 3), 'applied false false',
  'a member of the other installation''s space sees neither');
select is(pg_temp.go(5, 'a', 3, 12, 'active', p_ws => 'b'), 'foreign_workspace',
  'W-A cannot assert a W-B membership');
select is(pg_temp.go(6, 'a', 4, 13, 'active') || ' ' ||
          pg_temp.go(7, 'a', 3, 14, 'active'),
  'unlinked_subject unlinked_subject', 'a person who did not consent to the source is refused');
select is(pg_temp.go(8, 'a', 1, 15, 'active',
    p_issuer => 'https://other.test/auth/v1'), 'wrong_issuer', 'only this home''s own people');
select is(pg_temp.go(9, 'a', 1, 16, 'active', now() - interval '1000 seconds'),
  'expired_assertion', 'an expired fact is refused');
select is(pg_temp.go(1, 'a', 1, 10, 'active'), 'duplicate',
  'the same event is a retry');
select is(pg_temp.go(1, 'a', 1, 99, 'active'), 'event_conflict',
  'same event, other body: tampering');
select is(pg_temp.go(10, 'a', 1, 10, 'active'), 'superseded',
  'the same revision, not newer: no renewal');
select is(pg_temp.go(11, 'a', 1, 10, 'active', now() + interval '10 seconds'), 'renewed',
  'the same fact asserted later renews');
select is((select extract(epoch from valid_until - now())::int from public.membership_facts
            where user_id = pg_temp.u(1)), 910, 'to the source''s deadline');
select is(pg_temp.go(12, 'a', 1, 10, 'paused', now() + interval '20 seconds'),
  'revision_conflict', 'the same revision with another status is refused');
select is(pg_temp.go(13, 'a', 2, 5, 'active'), 'superseded',
  'a lower revision changes nothing');
select is(pg_temp.go(14, 'a', 2, 30, 'tombstone') || ' ' ||
          pg_temp.sees('identity', 2) || ' ' ||
          pg_temp.go(15, 'a', 2, 29, 'active'),
  'applied false superseded', 'a tombstone removes the space, and an older active cannot undo it');
select is(pg_temp.go(16, 'a', 2, 31, 'active') || ' ' ||
          pg_temp.sees('identity', 2), 'applied true', 'a rejoin is a newer revision');
select is(pg_temp.mine('a') || ', ' || pg_temp.mine('b'), 'verified active, none',
  'my references: verified from my fact, nothing about W-B');
alter table public.membership_facts disable trigger protect_membership_fact;
update public.membership_facts set asserted_at = now() - interval '2 hours', valid_until = now() - interval '1 hour'
 where user_id = pg_temp.u(1);
alter table public.membership_facts enable trigger protect_membership_fact;
select is(pg_temp.sees('identity', 2) || ' ' || pg_temp.sees('about', 2) || ' ' || pg_temp.mine('a'),
  'false false stale active', 'a lapsed fact authorizes nothing and reads stale');
do $c$ begin
  execute 'update auth.oauth_consents set revoked_at = now() where user_id = $1 and client_id = $2'
    using pg_temp.u(2), pg_temp.id('000002563c0a');
end $c$;
select is(pg_temp.go(17, 'a', 2, 40, 'active') || ' ' ||
          pg_temp.go(18, 'a', 2, 41, 'tombstone'),
  'unlinked_subject applied', 'consent withdrawn: no active fact, but a tombstone lands');
select ok(public.membership_fact_in_force(pg_temp.u(3), pg_temp.ref('b'), array['active']),
  'in force under the enrolment');
select public.operator_revoke_installation(pg_temp.inst('b'));
select is(public.membership_fact_in_force(pg_temp.u(3), pg_temp.ref('b'), array['active'])::text || ' ' ||
          pg_temp.go(19, 'b', 3, 22, 'active'),
  'false unenrolled_source', 'a revoked enrolment ends its facts');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00002563e001","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select count(*) from public.membership_facts$$, '42501', null,
  'a signed-in person reads no fact');
select throws_ok($$select public.membership_fact_apply('{}', null, null, 0)$$, '42501', null,
  'nor applies one');
reset role;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok($$select public.federation_inbox_accept('POST', '/federation-inbox', '{}', '')$$, '42501', null,
  'an anonymous caller reaches no inbox');
reset role;
select set_config('request.jwt.claims', '', true);

-- ── W: fixtures (u4 is the local person bound to P's subject u1) ──────
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

-- ── W: a membership change commits its fact ───────────────────────────
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status)
values (pg_temp.id('000002563d01'), pg_temp.ws(), pg_temp.u(4), false, false, 'active');
select is((select status || ' ' || (network_id = public.installation_id() || ':' || pg_temp.ws()) || ' ' ||
                  (target_installation_id = pg_temp.inst('f')) || ' ' ||
                  extract(epoch from valid_until - asserted_at)::int || ' ' || (body->>'revision' = revision::text)
             from public.membership_fact_outbox where subject = pg_temp.u(1)::text),
  'active true true 900 true', 'a membership commits its fact for the personal home');
update public.members set status = 'paused' where id = pg_temp.id('000002563d01');
update public.members set status = 'paused' where id = pg_temp.id('000002563d01');
select is(pg_temp.out(), 'active<paused', 'a status change is a newer revision; no change asserts nothing');
delete from public.members where id = pg_temp.id('000002563d01');
select is(pg_temp.out() || ' ' || (select status from public.membership_fact_state where subject = pg_temp.u(1)::text),
  'active<paused<tombstone tombstone', 'a deletion is a tombstone, and the high-water stays');
select throws_ok($$delete from public.membership_fact_state$$, '55000', null, 'the high-water is never deleted');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status)
values (pg_temp.id('000002563d02'), pg_temp.ws(), pg_temp.u(4), false, false, 'active');
select is(pg_temp.out(), 'active<paused<tombstone<active', 'a rejoin is newer than the tombstone');
select is(public.membership_fact_reconcile()::text, '{"changed": 0, "renewed": 0}',
  'a fresh relationship needs nothing');
update public.membership_fact_state set last_asserted_at = now() - interval '10 minutes';
select is(public.membership_fact_reconcile()::text, '{"changed": 0, "renewed": 1}',
  'a quiet relationship is re-asserted');
select is((select count(*)::int from public.membership_fact_outbox
            where revision = (select max(revision) from public.membership_fact_outbox)), 2,
  'at the same revision');
update public.identity_bindings set status = 'revoked', revoked_at = now() where local_user_id = pg_temp.u(4);
select is((select status from public.membership_fact_state where subject = pg_temp.u(1)::text), 'tombstone',
  'a revoked binding tombstones the relationship');
select is((public.membership_fact_drain()->>'sent')::int,
  (select count(*)::int from public.membership_fact_outbox), 'the drain sends every fact');
select is((select count(*)::int from net.http_request_queue q join public.membership_fact_outbox o
             on o.net_request_id = q.id
           where q.url = 'https://p.test/functions/v1/federation-inbox'
             and q.headers->>'x-deskilo-purpose' = 'membership_fact'
             and q.headers->>'x-deskilo-digest' = encode(extensions.digest(q.body, 'sha256'), 'hex')
             and q.headers->>'x-deskilo-signature' = encode(extensions.hmac(convert_to(
                   public.federation_signing_input('POST', '/federation-inbox', 'membership_fact',
                     public.installation_id(), pg_temp.inst('f'), o.event_id,
                     (q.headers->>'x-deskilo-timestamp')::bigint, q.headers->>'x-deskilo-digest', 'k1'),
                   'UTF8'), convert_to(repeat('m', 40), 'UTF8'), 'sha256'), 'hex')),
  (select count(*)::int from public.membership_fact_outbox), 'signed with the membership key, to the home''s inbox');
select throws_ok($$select public.operator_set_federation_key(pg_temp.inst('e'),
    'outbound', 'membership_fact', 'k1', repeat('n', 40))$$, '55000', null,
  'facts go to one personal home');

select * from finish();
rollback;
