-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2563 C2 (snapshot, outbox retention): a workspace installation (W) cuts
-- a full snapshot of the live relationships it holds for its personal home,
-- paged under the inbox limit, every page carrying the manifest (watermark,
-- count, hash). The personal home (P) tombstones a live fact of that source
-- only after a COMPLETE, verified snapshot that does not list it and whose
-- watermark is above its revision; a partial, conflicting, malformed or
-- unverified snapshot, or an older one, changes nothing. The hourly purge
-- removes delivered or expired identity status assertions older than the
-- retention interval and nothing else. Both sides live in this one database.
begin;
select plan(24);

create function pg_temp.id(p_tail text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-' || p_tail)::uuid $$;
create function pg_temp.u(p_n int) returns uuid language sql as $$
  select pg_temp.id('0000280e' || lpad(p_n::text, 4, '0')) $$;
create function pg_temp.iss() returns text language sql as $$ select 'https://p280.test/auth/v1' $$;
create function pg_temp.inst(p_c text) returns uuid language sql as $$
  select pg_temp.id('0000280a000' || p_c) $$;
create function pg_temp.ref(p_c text, p_k int) returns text language sql as $$
  select pg_temp.inst(p_c) || ':' || pg_temp.id('0000280f000' || p_k) $$;
-- One snapshot entry of W-A, as a one-element list (lists concatenate).
create function pg_temp.e(p_n int, p_k int, p_r int, p_st text) returns jsonb language sql as $$
  select jsonb_build_array(jsonb_build_array(pg_temp.u(p_n)::text, pg_temp.ref('a', p_k), p_r, p_st)) $$;
create function pg_temp.h(p_entries jsonb) returns text language sql as $$
  select public.membership_snapshot_digest(p_entries) $$;
create function pg_temp.full_list() returns jsonb language sql as $$
  select pg_temp.e(1, 1, 10, 'active') || pg_temp.e(1, 2, 12, 'paused') $$;
-- P's facts about u1/u2 as source+workspace/person=status@revision.
create function pg_temp.st() returns text language plpgsql as $$
declare v text;
begin
  select string_agg(right(split_part(network_id, ':', 1), 1) || right(network_id, 1) || '/u'
                    || right(user_id::text, 1) || '=' || status || '@' || revision, ' '
                    order by network_id, user_id) into v
    from public.membership_facts where user_id in (pg_temp.u(1), pg_temp.u(2));
  return v;
end $$;

-- ── P: fixtures (u1 consented to W-A and W-B, u2 to W-A) ──────────────
select public.operator_set_installation_roles(array['personal_home', 'workspace_host']);
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', pg_temp.iss());
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || n || '-280@deskilo.test', '', now(), now(), now()
  from generate_series(1, 2) n;
insert into auth.oauth_clients (id, client_name, registration_type, redirect_uris, grant_types,
                                token_endpoint_auth_method)
select pg_temp.id('0000280c000' || c), 'W-' || c, 'manual',
       'https://w280-' || c || '.test/auth/v1/callback', 'authorization_code', 'client_secret_basic'
  from unnest(array['a', 'b']) c;
insert into public.identity_federation_clients (client_id, target_installation_id, target_auth_url, enabled)
select pg_temp.id('0000280c000' || c), pg_temp.inst(c), 'https://w280-' || c || '.test/auth/v1', true
  from unnest(array['a', 'b']) c;
do $c$ declare r record; begin
  for r in select * from unnest(array['a', 'b']) c loop
    perform public.operator_enrol_installation(pg_temp.inst(r.c), 'https://w280-' || r.c || '.test',
      'sb_publishable_w' || r.c || '_key_280', array['workspace_host'], array['workspace@1']);
    perform public.operator_set_federation_key(pg_temp.inst(r.c), 'inbound', 'membership_fact', 'k1', repeat(r.c, 40));
  end loop;
  for r in select * from (values (1, 'a'), (2, 'a'), (1, 'b')) v(n, c) loop
    execute 'insert into auth.oauth_consents (id, user_id, client_id, scopes) values ($1, $2, $3, $4)'
      using gen_random_uuid(), pg_temp.u(r.n), pg_temp.id('0000280c000' || r.c), 'openid';
  end loop;
end $c$;

-- Completes a body as source p_s would, signs it and posts it to the inbox.
create function pg_temp.post(p_s text, p_e int, p_b jsonb, p_at timestamptz default now())
returns text language plpgsql as $$
declare
  v_src uuid := pg_temp.inst(p_s);
  v_to uuid := public.installation_id();
  v_ev uuid := pg_temp.id('0000280100' || lpad(p_e::text, 2, '0'));
  v_ts bigint := extract(epoch from now())::bigint;
  v_body jsonb := p_b || jsonb_build_object('protocol', 1, 'event_id', v_ev, 'source_installation_id', v_src,
    'target_installation_id', v_to, 'issuer', pg_temp.iss(), 'asserted_at', p_at,
    'valid_until', p_at + interval '900 seconds');
  v_digest text := encode(extensions.digest(convert_to(v_body::text, 'UTF8'), 'sha256'), 'hex');
  v_h jsonb := jsonb_build_object('protocol', '1', 'purpose', 'membership_fact', 'source', v_src,
    'target', v_to, 'event', v_ev, 'timestamp', v_ts::text, 'digest', v_digest, 'key', 'k1');
begin
  v_h := v_h || jsonb_build_object('signature', encode(extensions.hmac(convert_to(
    public.federation_signing_input('POST', '/federation-inbox', 'membership_fact', v_src, v_to,
      v_ev, v_ts, v_digest, 'k1'), 'UTF8'), convert_to(repeat(p_s, 40), 'UTF8'), 'sha256'), 'hex'));
  return public.federation_inbox_accept('POST', '/federation-inbox',
    (select jsonb_object_agg('x-deskilo-' || key, value) from jsonb_each(v_h)),
    encode(convert_to(v_body::text, 'UTF8'), 'base64'))->>'outcome';
end $$;
create function pg_temp.f(p_e int, p_s text, p_u int, p_k int, p_r int, p_st text)
returns text language sql as $$
  select pg_temp.post(p_s, p_e, jsonb_build_object('kind', 'membership_fact', 'subject', pg_temp.u(p_u),
    'network_id', pg_temp.ref(p_s, p_k), 'revision', p_r, 'status', p_st)) $$;
-- A page of W-A's snapshot p_snap: watermark, page/pages, count, hash, entries.
create function pg_temp.pg(p_e int, p_snap int, p_wm int, p_page int, p_pages int, p_cnt int,
  p_hash text, p_entries jsonb, p_at timestamptz default now())
returns text language sql as $$
  select pg_temp.post('a', p_e, jsonb_build_object('kind', 'membership_snapshot',
    'snapshot_id', pg_temp.id('0000280b00' || lpad(p_snap::text, 2, '0')), 'watermark', p_wm,
    'page', p_page, 'pages', p_pages, 'count', p_cnt, 'hash', p_hash, 'entries', p_entries), p_at) $$;
create function pg_temp.z() returns text language sql as $$ select repeat('0', 64) $$;

-- ── the doors ─────────────────────────────────────────────────────────
select is_empty($$select p.proname || ' ' || r from pg_proc p
  cross join unnest(array['anon', 'authenticated', 'service_role']) r
  where p.pronamespace = 'public'::regnamespace and has_function_privilege(r, p.oid, 'EXECUTE')
    and (p.proname like 'membership_snapshot%' or p.proname in ('federation_retention_purge', 'protect_federation_history'))$$,
  'no API role executes them');
select is_empty($$select t || r from unnest(array['outbox', 'pages', 'watermarks']) t,
    unnest(array['anon', 'authenticated', 'service_role']) r
  where has_table_privilege(r, 'public.membership_snapshot_' || t, 'SELECT')$$, 'no API role reads the tables');
select is(public.membership_snapshot_issue()::text, '{"issued": 0, "authority": "native"}',
  'P cuts no snapshot');

-- ── P: reconciliation ─────────────────────────────────────────────────
select is(pg_temp.f(1, 'a', 1, 1, 10, 'active') || pg_temp.f(2, 'a', 2, 1, 11, 'active')
          || pg_temp.f(3, 'a', 1, 2, 12, 'paused') || pg_temp.f(4, 'a', 2, 2, 25, 'active')
          || pg_temp.f(5, 'b', 1, 1, 13, 'active') || ' ' || pg_temp.st(),
  'appliedappliedappliedappliedapplied a1/u1=active@10 a1/u2=active@11 a2/u1=paused@12 a2/u2=active@25 b1/u1=active@13',
  'five live facts');
create temp table before as select pg_temp.st() s;
select is(pg_temp.pg(10, 1, 20, 1, 2, 2, pg_temp.h(pg_temp.full_list()), pg_temp.e(1, 1, 10, 'active'))
          || ' ' || pg_temp.st(), 'staged ' || (select s from before), 'a partial snapshot changes nothing');
select is(pg_temp.pg(11, 1, 20, 2, 2, 2, pg_temp.z(), pg_temp.e(1, 2, 12, 'paused')) || ' ' || pg_temp.st(),
  'snapshot_conflict ' || (select s from before), 'a conflicting manifest is refused');
select is(pg_temp.pg(12, 2, 20, 1, 1, 1, pg_temp.z(), pg_temp.e(1, 1, 10, 'active')) || ' '
          || pg_temp.pg(13, 3, 20, 1, 1, 2, pg_temp.h(pg_temp.e(1, 1, 10, 'active')), pg_temp.e(1, 1, 10, 'active'))
          || ' ' || pg_temp.st(),
  'unverified unverified ' || (select s from before), 'a wrong hash or count changes nothing');
select is(pg_temp.pg(14, 4, 20, 1, 1, 1, pg_temp.z(), pg_temp.e(1, 1, 10, 'tombstone')) || ' '
          || pg_temp.pg(15, 5, 20, 1, 1, 1, pg_temp.z(), pg_temp.e(1, 1, 21, 'active')) || ' '
          || pg_temp.pg(16, 6, 20, 1, 1, 1, pg_temp.z(), '[["x"]]') || ' '
          || pg_temp.pg(17, 7, 20, 1, 1, 2, pg_temp.z(), pg_temp.e(1, 1, 10, 'active') || pg_temp.e(1, 1, 10, 'active'))
          || ' ' || pg_temp.pg(18, 8, 20, 1, 1, 1, pg_temp.z(),
                               jsonb_build_array(jsonb_build_array(pg_temp.u(1)::text, pg_temp.ref('b', 1), 10, 'active')))
          || ' ' || pg_temp.st(),
  'malformed malformed malformed malformed foreign_workspace ' || (select s from before),
  'a bad entry sinks the page');
select is(pg_temp.pg(19, 9, 20, 1, 2, 2, pg_temp.h(pg_temp.full_list()), pg_temp.e(1, 1, 10, 'active')) || ' '
          || pg_temp.pg(20, 9, 20, 2, 2, 2, pg_temp.h(pg_temp.full_list()), pg_temp.e(1, 2, 12, 'paused')),
  'staged reconciled', 'a verified snapshot reconciles');
select is(pg_temp.st(), 'a1/u1=active@10 a1/u2=tombstone@20 a2/u1=paused@12 a2/u2=active@25 b1/u1=active@13',
  'only an unlisted older fact ends');
select is((select watermark || ' ' || live_count || ' ' || removed from public.membership_snapshot_watermarks
            where source_installation_id = pg_temp.inst('a')) || ' '
          || public.membership_fact_in_force(pg_temp.u(2), pg_temp.ref('a', 1), array['active', 'paused'])::text,
  '20 2 1 false', 'watermark kept; the fact grants nothing');
select is(pg_temp.pg(21, 10, 15, 1, 1, 0, pg_temp.h('[]'), '[]') || ' '
          || pg_temp.pg(22, 9, 20, 1, 2, 2, pg_temp.h(pg_temp.full_list()), pg_temp.e(1, 1, 10, 'active')) || ' '
          || pg_temp.pg(23, 11, 40, 1, 1, 0, pg_temp.h('[]'), '[]', now() - interval '1000 seconds'),
  'superseded superseded expired_assertion', 'older, replayed or lapsed: refused');
select is(pg_temp.f(24, 'a', 2, 1, 11, 'active') || ' ' || pg_temp.f(25, 'a', 2, 1, 21, 'active'),
  'superseded applied', 'no revival; a rejoin applies');
select is(pg_temp.pg(26, 12, 30, 1, 1, 0, pg_temp.h('[]'), '[]') || ' ' || pg_temp.st(),
  'reconciled a1/u1=tombstone@30 a1/u2=tombstone@30 a2/u1=tombstone@30 a2/u2=tombstone@30 b1/u1=active@13',
  'an empty snapshot ends that source''s facts');

-- ── P: identity status outbox retention ───────────────────────────────
select pg_temp.pg(27, 13, 40, 1, 2, 0, pg_temp.h('[]'), '[]');
select count(public.identity_status_issue(pg_temp.u(1), 'suspended')) from generate_series(1, 3);
create temp table iso as
select event_id, (row_number() over (order by event_id))::int n from public.identity_status_outbox
 where subject = pg_temp.u(1)::text;
alter table public.identity_status_outbox disable trigger protect_federation_history;
update public.identity_status_outbox o
   set issued_at = case when i.n < 6 then now() - interval '27 hours' else o.issued_at end,
       valid_until = case when i.n < 6 then now() - interval '26 hours' else o.valid_until end,
       state = (array['delivered', 'expired', 'refused', 'pending', 'delivered', 'delivered'])[i.n],
       delivered_at = case i.n when 1 then now() - interval '26 hours' when 5 then now() when 6 then now() end
  from iso i where o.event_id = i.event_id;
alter table public.identity_status_outbox enable trigger protect_federation_history;
create function pg_temp.marked_delete(p_n int) returns void language plpgsql as $$
begin
  perform set_config('deskilo.federation_retention', 'on', true);
  delete from public.identity_status_outbox where event_id = (select event_id from iso where n = p_n);
end $$;
select is((select count(*)::int from iso), 6, 'six assertions');
select throws_ok($$delete from public.identity_status_outbox where event_id = (select event_id from iso where n = 1)$$,
  '55000', null, 'no delete outside the purge');
select throws_ok($$select pg_temp.marked_delete(4)$$, '55000', null, 'nor a pending one');
select throws_ok($$select pg_temp.marked_delete(5)$$, '55000', null, 'nor a recent delivery');
update public.membership_snapshot_pages set received_at = now() - interval '25 hours'
 where source_installation_id = pg_temp.inst('a');
create temp table old_rows as
select (select count(*)::int from public.identity_status_outbox where state in ('delivered', 'expired')
           and greatest(valid_until, delivered_at) <= now() - public.federation_retention_interval()) s,
       (select count(*)::int from public.membership_snapshot_pages
         where received_at <= now() - public.federation_retention_interval()) p;
select is((select (v->>'identity_statuses') || ' ' || (v->>'snapshot_pages')
             from (select public.federation_retention_purge() v) x),
          (select s || ' ' || p from old_rows where s >= 2 and p >= 1),
  'old settled assertions and pages go');
select is((select string_agg(i.n::text, ',' order by i.n) from iso i
            where exists (select 1 from public.identity_status_outbox o where o.event_id = i.event_id)),
  '3,4,5,6', 'the rest stays');

-- ── W: cut a snapshot (150 live relationships and one tombstone) ──────
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer, oidc_provider)
values ('oidc', pg_temp.iss(), 'custom:deskilo');
select public.operator_set_personal_home('unset');
select public.operator_set_installation_roles(array['workspace_host']);
select public.operator_set_personal_home('endpoint', 'https://p280.test', 'sb_publishable_p_key_280');
select public.operator_set_federation_key(pg_temp.inst('f'), 'outbound', 'membership_fact', 'k1', repeat('m', 40));
insert into public.membership_fact_state (issuer, subject, network_id, revision, status)
select pg_temp.iss(), 's' || lpad(n::text, 4, '0'), public.installation_id() || ':' || pg_temp.id('0000280f0009'),
       nextval('public.membership_fact_revision'), case when n > 150 then 'tombstone' else 'active' end
  from generate_series(1, 151) n;
create temp table snap as select public.membership_snapshot_issue() v;
create temp table pg_out as select * from public.membership_snapshot_outbox
 where snapshot_id = (select (v->>'snapshot_id')::uuid from snap);
select is((select (v->>'count') || ' ' || (v->>'watermark' = (select max(revision)::text from public.membership_fact_state
             where issuer = pg_temp.iss()))::text || ' ' || ((v->>'issued')::int = (select count(*)::int from pg_out)
             and (v->>'issued')::int > 1)::text from snap),
  '150 true true', 'live list, watermark, pages');
select ok((select bool_and(octet_length(body::text) < 16384 and pages = (select count(*) from pg_out)
                           and manifest_hash = (select max(manifest_hash) from pg_out)
                           and body->>'hash' = manifest_hash and (body->>'count')::int = 150) from pg_out),
  'pages fit and share the manifest');
select is((select pg_temp.h(jsonb_agg(e)) = max(p.manifest_hash) and count(*) = count(distinct e->>0)
             and not bool_or(e->>0 = 's0151')
             from pg_out p cross join lateral jsonb_array_elements(p.body->'entries') e)::text,
  'true', 'the pages hold the hashed list');
select is(public.membership_snapshot_issue()::text, '{"due": false, "issued": 0}',
  'one snapshot per interval');

select * from finish();
rollback;
