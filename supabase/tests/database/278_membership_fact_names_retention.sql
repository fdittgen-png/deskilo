-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2563 C2 (names, retention): a workspace installation (W) asserts its
-- workspace's name with every non-tombstone fact; the personal home (P)
-- decodes it strictly and shows it only to the person the fact is about,
-- while its source is enrolled. The hourly purge removes receipts and P's
-- tombstones older than federation.retention_hours (never less than the
-- largest assertion lifetime plus twice the largest skew), and nothing else
-- may delete a receipt. Both sides live in this one database, as in 273.
begin;
select plan(22);

create function pg_temp.id(p_tail text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-' || p_tail)::uuid $$;
create function pg_temp.u(p_n int) returns uuid language sql as $$
  select pg_temp.id('0000278e' || lpad(p_n::text, 4, '0')) $$;
create function pg_temp.iss() returns text language sql as $$ select 'https://p278.test/auth/v1' $$;
create function pg_temp.inst(p_c text) returns uuid language sql as $$
  select pg_temp.id('0000278a000' || p_c) $$;
create function pg_temp.ws() returns uuid language sql as $$ select pg_temp.id('0000278f0001') $$;
create function pg_temp.ref(p_c text) returns text language sql as $$
  select pg_temp.inst(p_c) || ':' || pg_temp.ws() $$;
-- The label u(p_n)'s references give W-p_c's workspace ('none': not listed).
create function pg_temp.lab(p_n int, p_c text) returns text language plpgsql as $$
declare v jsonb;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.u(p_n), 'role', 'authenticated')::text, true);
  select e into v from jsonb_array_elements(public.my_personal_workspace_refs_v1()->'refs') e
   where e->>'network_id' = pg_temp.ref(p_c);
  perform set_config('request.jwt.claims', '', true);
  return case when v is null then 'none' else coalesce(v->>'label', '-') end;
end $$;

-- The name P holds on u(p_n)'s fact about W-p_c ('gone': no fact). plpgsql,
-- so it reads what an earlier call in the same statement wrote.
create function pg_temp.fname(p_n int, p_c text) returns text language plpgsql as $$
declare v text;
begin
  select coalesce(f.workspace_name, '-') into v from public.membership_facts f
   where f.user_id = pg_temp.u(p_n) and f.network_id = pg_temp.ref(p_c);
  return coalesce(v, 'gone');
end $$;

-- ── P: fixtures (u1 consented to W-A, u2 to W-B) ──────────────────────
select public.operator_set_installation_roles(array['personal_home', 'workspace_host']);
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', pg_temp.iss());
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || n || '-278@deskilo.test', '', now(), now(), now()
  from generate_series(1, 3) n;
insert into auth.oauth_clients (id, client_name, registration_type, redirect_uris, grant_types,
                                token_endpoint_auth_method)
select pg_temp.id('0000278c000' || c), 'W-' || c, 'manual',
       'https://w278-' || c || '.test/auth/v1/callback', 'authorization_code', 'client_secret_basic'
  from unnest(array['a', 'b']) c;
insert into public.identity_federation_clients (client_id, target_installation_id, target_auth_url, enabled)
select pg_temp.id('0000278c000' || c), pg_temp.inst(c), 'https://w278-' || c || '.test/auth/v1', true
  from unnest(array['a', 'b']) c;
do $c$ declare r record; begin
  for r in select * from (values (1, 'a'), (2, 'b')) v(n, c) loop
    execute 'insert into auth.oauth_consents (id, user_id, client_id, scopes) values ($1, $2, $3, $4)'
      using gen_random_uuid(), pg_temp.u(r.n), pg_temp.id('0000278c000' || r.c), 'openid';
  end loop;
  for r in select * from unnest(array['a', 'b']) c loop
    perform public.operator_enrol_installation(pg_temp.inst(r.c), 'https://w278-' || r.c || '.test',
      'sb_publishable_w' || r.c || '_key_278', array['workspace_host'], array['workspace@1']);
    perform public.operator_set_federation_key(pg_temp.inst(r.c), 'inbound', 'membership_fact', 'k1', repeat(r.c, 40));
  end loop;
end $c$;
-- u1 also names W-B's workspace (a chosen space), without any fact of its own.
insert into public.account_field_audience (user_id, field, audience)
values (pg_temp.u(1), 'about', 'chosen_spaces');
insert into public.account_field_audience_spaces (user_id, field, workspace_network_id)
values (pg_temp.u(1), 'about', pg_temp.ref('b'));

-- Signs a fact as its source would (273's shape, with an optional name).
create function pg_temp.go(p_e int, p_s text, p_u int, p_r int, p_st text,
  p_at timestamptz default now(), p_name jsonb default null)
returns text language plpgsql as $$
declare
  v_body jsonb := jsonb_build_object('protocol', 1, 'kind', 'membership_fact',
    'event_id', pg_temp.id('0000278100' || lpad(p_e::text, 2, '0')),
    'source_installation_id', pg_temp.inst(p_s), 'target_installation_id', public.installation_id(),
    'issuer', pg_temp.iss(), 'subject', pg_temp.u(p_u), 'network_id', pg_temp.ref(p_s),
    'revision', p_r, 'status', p_st, 'asserted_at', p_at, 'valid_until', p_at + interval '900 seconds')
    || case when p_name is null then '{}'::jsonb else jsonb_build_object('workspace_name', p_name) end;
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
-- A delete that sets the purge's marker by hand, on a fresh receipt.
create function pg_temp.marked_delete() returns void language plpgsql as $$
begin
  perform set_config('deskilo.federation_retention', 'on', true);
  delete from public.federation_inbox_receipts;
end $$;

-- ── the doors and the setting ─────────────────────────────────────────
select is_empty($$select p.proname || ' ' || r from pg_proc p
  cross join unnest(array['anon', 'authenticated', 'service_role']) r
  where p.pronamespace = 'public'::regnamespace
    and p.proname in ('federation_retention_interval', 'federation_retention_purge',
      'protect_federation_history', 'membership_fact_enqueue', 'membership_fact_apply')
    and has_function_privilege(r, p.oid, 'EXECUTE')$$,
  'no API role executes the retention or fact functions');
select is((select key || '=' || (default_value #>> '{}') || ' ' || min_value || '..' || max_value || ' ' || unit
             || ' ' || array_to_string(scopes, ',') from public.setting_definitions
            where key = 'federation.retention_hours') || ' ' || public.federation_retention_interval()::text,
  'federation.retention_hours=24 1..720 hours platform 24:00:00', 'the retention is a platform setting of 24 hours');

-- ── P: the name ───────────────────────────────────────────────────────
select is(pg_temp.go(1, 'a', 1, 10, 'active', p_name => '"Atelier A"') || ' ' || pg_temp.lab(1, 'a'),
  'applied Atelier A', 'my reference shows the name my own fact asserted');
select is(pg_temp.go(2, 'a', 1, 10, 'active', now() + interval '10 seconds', '"Atelier Nord"') || ' ' ||
          pg_temp.lab(1, 'a'), 'renewed Atelier Nord', 'a renewal carries the current name');
select is(pg_temp.go(3, 'a', 1, 11, 'active', p_name => '42') || ' ' ||
          pg_temp.go(4, 'a', 1, 11, 'active', p_name => '""') || ' ' ||
          pg_temp.go(5, 'a', 1, 11, 'active', p_name => to_jsonb(E'A\nB'::text)) || ' ' ||
          pg_temp.go(6, 'a', 1, 11, 'active', p_name => to_jsonb(repeat('x', 121))),
  'malformed malformed malformed malformed', 'a name that is not a valid workspace name sinks the fact');
select is(pg_temp.fname(1, 'a'), 'Atelier Nord', 'and changes nothing');
select is(pg_temp.go(7, 'b', 2, 20, 'active', p_name => '"Secret B"') || ' ' ||
          pg_temp.lab(2, 'b') || ' ' || pg_temp.lab(1, 'b'),
  'applied Secret B -', 'another person''s fact names nothing in my references');
select is(pg_temp.go(8, 'a', 1, 12, 'tombstone', p_name => '"Atelier A"') || ' ' ||
          pg_temp.fname(1, 'a') || ' ' || pg_temp.lab(1, 'a'),
  'applied - none', 'a tombstone keeps no name');

-- ── P: retention ──────────────────────────────────────────────────────
select throws_ok($$delete from public.federation_inbox_receipts$$, '55000', null,
  'a receipt is not deleted outside the purge');
select throws_ok($$select pg_temp.marked_delete()$$, '55000', null,
  'nor a fresh one under the purge''s marker');
alter table public.federation_inbox_receipts disable trigger protect_federation_history;
update public.federation_inbox_receipts set received_at = now() - interval '25 hours'
 where source_installation_id = pg_temp.inst('a')
   and event_id in (select pg_temp.id('0000278100' || lpad(n::text, 2, '0')) from generate_series(1, 6) n);
alter table public.federation_inbox_receipts enable trigger protect_federation_history;
alter table public.membership_facts disable trigger protect_membership_fact;
update public.membership_facts set received_at = now() - interval '25 hours'
 where user_id in (pg_temp.u(1), pg_temp.u(2));
alter table public.membership_facts enable trigger protect_membership_fact;
create temp table old_rows as
select (select count(*)::int from public.federation_inbox_receipts
         where received_at <= now() - public.federation_retention_interval()) r,
       (select count(*)::int from public.membership_facts
         where status = 'tombstone' and received_at <= now() - public.federation_retention_interval()) t;
select is(public.federation_retention_purge() - array['identity_statuses', 'snapshot_pages'], (select jsonb_build_object('receipts', r, 'tombstones', t)
                                                  from old_rows where r >= 6 and t >= 1),
  'the purge removes every old receipt (ours: six) and old tombstone (ours: one)');
select is((select string_agg(right(event_id::text, 2), ',' order by event_id) from public.federation_inbox_receipts
            where source_installation_id in (pg_temp.inst('a'), pg_temp.inst('b'))) || ' ' ||
          (select string_agg(status, ',') from public.membership_facts
            where user_id in (pg_temp.u(1), pg_temp.u(2))),
  '07,08 active', 'fresh receipts and a fact that is not a tombstone stay');
select is(pg_temp.go(9, 'a', 1, 11, 'active', now() - interval '1000 seconds'), 'expired_assertion',
  'an older fact arriving after its tombstone went is refused on its own deadline');
select is((public.federation_retention_purge() - array['identity_statuses', 'snapshot_pages'])::text,
  '{"receipts": 0, "tombstones": 0}',
  'a second purge finds nothing');
update public.setting_definitions set max_value = 5000 where key = 'identity.status_assertion_lifetime_seconds';
select is(extract(epoch from public.federation_retention_interval())::int, 86400,
  'the setting wins over a shorter floor');
update public.setting_definitions set max_value = 100000 where key = 'identity.status_assertion_lifetime_seconds';
select is(extract(epoch from public.federation_retention_interval())::int, 100060,
  'never less than the largest lifetime plus twice the largest skew');
update public.setting_definitions set max_value = 900 where key = 'identity.status_assertion_lifetime_seconds';
select public.operator_revoke_installation(pg_temp.inst('b'));
select is(pg_temp.lab(2, 'b'), '-', 'a source no longer enrolled names nothing');

-- ── W: fixtures (u3 is the local person bound to P's subject u1) ──────
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer, oidc_provider)
values ('oidc', pg_temp.iss(), 'custom:deskilo');
select public.operator_set_personal_home('unset');
select public.operator_set_installation_roles(array['workspace_host']);
select public.operator_set_personal_home('endpoint', 'https://p278.test', 'sb_publishable_p_key_278');
select public.operator_set_federation_key(pg_temp.inst('f'), 'outbound', 'membership_fact', 'k1', repeat('m', 40));
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, environment, booking_rules, feature_flags)
values (pg_temp.ws(), 'Facts', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(3), 'dev', '{}', '{}');
insert into public.identity_bindings (installation_id, local_user_id, issuer, subject, verified_via, status, revoked_at)
values (public.installation_id(), pg_temp.u(3), pg_temp.iss(), pg_temp.u(1)::text, 'oidc_identity', 'active', null);
create function pg_temp.names() returns text language sql as $$
  select string_agg(status || '=' || coalesce(body->>'workspace_name', '-'), ' '
                    order by revision, body->>'workspace_name' nulls last)
    from public.membership_fact_outbox where subject = pg_temp.u(1)::text $$;

insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status)
values (pg_temp.id('0000278d0001'), pg_temp.ws(), pg_temp.u(3), false, false, 'active');
select is(pg_temp.names(), 'active=Facts', 'a fact names its workspace as W holds it');
update public.workspaces set name = 'Facts Two' where id = pg_temp.ws();
update public.membership_fact_state set last_asserted_at = now() - interval '10 minutes'
 where subject = pg_temp.u(1)::text;
select is(public.membership_fact_reconcile()->>'renewed', '1', 'a quiet relationship is re-asserted');
select is(pg_temp.names(), 'active=Facts active=Facts Two', 'with the new name');
delete from public.members where id = pg_temp.id('0000278d0001');
select is(pg_temp.names(), 'active=Facts active=Facts Two tombstone=-', 'a tombstone carries no name');
select ok(not exists (select 1 from public.membership_fact_outbox
                       where subject = pg_temp.u(1)::text and status = 'tombstone' and body ? 'workspace_name'),
  'not even an empty one');

select * from finish();
rollback;
