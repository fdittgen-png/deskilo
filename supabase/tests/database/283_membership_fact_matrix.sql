-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2563 acceptance, the cases 273/278/280 leave open, named by case number:
--   case 3  a fact's status keeps the pre-split policy: active (the default
--           my_spaces audience) shares a space, exited and pending share
--           nothing, and a field whose default is nobody stays hidden;
--   case 4  a malformed status or revision is refused, a signed-in person
--           cannot write a fact, and my own export names my references only;
--   case 5  delivery faults on both sides: the personal home (P) answers a
--           retry of an applied event as that event (no renewal), keeps the
--           higher revision whatever the arrival order, refuses a longer
--           deadline at the same assertion time, and a crash before its
--           commit leaves nothing, so the retry applies. The workspace
--           installation (W) heals a lost enqueue in the reconcile, never
--           sends twice while an answer may still come, retries a lost answer
--           as the SAME event and digest, settles on the acknowledgement and
--           never resends what was acknowledged or refused for good;
--   case 6  a fact holds at most to the source's own deadline plus the skew,
--           whatever lifetime the source claims; once it lapses the shared
--           space discloses nothing and a new message is only a request,
--           while an accepted conversation still works; a snapshot changes
--           nothing until it is complete and verified: a page out of order
--           waits, a repeated page is a duplicate, a contradicting page is
--           refused, a page that lapsed in transit sinks the snapshot, an
--           older partial snapshot is dropped by a newer complete one, and a
--           source that sends no snapshot loses nothing.
--   case 7  no foreign server, foreign table or dblink call, and a fact
--           carries no role, permission or copied member field.
-- Both sides live in this one database as in 273: W-A and W-B are foreign
-- ids on the P side, P is a foreign id on the W side; pg_net only queues
-- inside the rolled-back transaction and its answers are inserted here.
-- Writes and their checks are separate statements.
begin;
select plan(42);

create function pg_temp.id(p_tail text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-' || p_tail)::uuid $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.u(p_n int) returns uuid language sql as $$
  select pg_temp.id('9999e' || lpad(p_n::text, 7, '0')) $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.ev(p_n int) returns uuid language sql as $$
  select pg_temp.id('99991' || lpad(p_n::text, 7, '0')) $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.snap(p_n int) returns uuid language sql as $$
  select pg_temp.id('9999b' || lpad(p_n::text, 7, '0')) $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.iss() returns text language sql as $$ select 'https://p9999.test/auth/v1' $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.inst(p_c text) returns uuid language sql as $$
  select pg_temp.id('9999a000000' || p_c) $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.ref(p_c text, p_k int default 1) returns text language sql as $$
  select pg_temp.inst(p_c) || ':' || pg_temp.id('9999f000000' || p_k) $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.act(p_n int) returns void language sql as $$
  select set_config('request.jwt.claims', case when p_n is null then ''
    else jsonb_build_object('sub', pg_temp.u(p_n), 'role', 'authenticated')::text end, true)::void $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
-- plpgsql: each call reads what earlier statements wrote.
create function pg_temp.sees(p_field text, p_viewer int) returns text language plpgsql as $$
begin return public.account_field_visible_to(pg_temp.u(1), p_field, pg_temp.u(p_viewer))::text; end $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.fact(p_u int, p_ref text) returns text language plpgsql as $$
declare v text;
begin
  select status || '@' || revision || ' ' || extract(epoch from valid_until - asserted_at)::int
    into v from public.membership_facts where user_id = pg_temp.u(p_u) and network_id = p_ref;
  return coalesce(v, 'none');
end $$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create function pg_temp.in_force(p_u int, p_ref text) returns text language plpgsql as $$
begin return public.membership_fact_in_force(pg_temp.u(p_u), p_ref, array['active']::text[])::text; end $$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- ── P: fixtures ───────────────────────────────────────────────────────
select public.operator_set_installation_roles(array['personal_home', 'workspace_host']);
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', pg_temp.iss());
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || n || '-9999m@deskilo.test', '', now(), now(), now()
  from generate_series(1, 7) n;
insert into auth.oauth_clients (id, client_name, registration_type, redirect_uris, grant_types,
                                token_endpoint_auth_method)
select pg_temp.id('9999c000000' || c), 'W-' || c, 'manual',
       'https://w9999-' || c || '.test/auth/v1/callback', 'authorization_code', 'client_secret_basic'
  from unnest(array['a', 'b']) c;
insert into public.identity_federation_clients (client_id, target_installation_id, target_auth_url, enabled)
select pg_temp.id('9999c000000' || c), pg_temp.inst(c), 'https://w9999-' || c || '.test/auth/v1', true
  from unnest(array['a', 'b']) c;
-- u1..u5 consented to W-A; u1 and u6 to W-B; u7 is W's local person.
do $c$ declare r record; begin
  for r in select * from (values (1, 'a'), (2, 'a'), (3, 'a'), (4, 'a'), (5, 'a'), (1, 'b'), (6, 'b')) v(n, c) loop
    execute 'insert into auth.oauth_consents (id, user_id, client_id, scopes) values ($1, $2, $3, $4)'
      using gen_random_uuid(), pg_temp.u(r.n), pg_temp.id('9999c000000' || r.c), 'openid';
  end loop;
  for r in select * from unnest(array['a', 'b']) c loop
    perform public.operator_enrol_installation(pg_temp.inst(r.c), 'https://w9999-' || r.c || '.test',
      'sb_publishable_w' || r.c || '_key_9999', array['workspace_host'], array['workspace@1']);
    perform public.operator_set_federation_key(pg_temp.inst(r.c), 'inbound', 'membership_fact', 'k1', repeat(r.c, 40));
  end loop;
end $c$;
-- u1: identity keeps its default (my spaces), about keeps its default
-- (nobody), reachability is my spaces.
delete from public.account_field_audience where user_id = pg_temp.u(1);
insert into public.account_field_audience (user_id, field, audience)
values (pg_temp.u(1), 'reachability', 'my_spaces');

-- Completes a body as source p_s signs it and posts it to the inbox; the
-- whole answer. now() is the transaction's, so a rebuilt body is identical.
create function pg_temp.post(p_s text, p_e int, p_b jsonb, p_at timestamptz default now(),
  p_life interval default interval '900 seconds')
returns jsonb language plpgsql as $$
declare
  v_src uuid := pg_temp.inst(p_s);
  v_to uuid := public.installation_id();
  v_ts bigint := extract(epoch from now())::bigint;
  v_body jsonb := p_b || jsonb_build_object('protocol', 1, 'event_id', pg_temp.ev(p_e),
    'source_installation_id', v_src, 'target_installation_id', v_to, 'issuer', pg_temp.iss(),
    'asserted_at', p_at, 'valid_until', p_at + p_life);
  v_digest text := encode(extensions.digest(convert_to(v_body::text, 'UTF8'), 'sha256'), 'hex');
  v_h jsonb := jsonb_build_object('protocol', '1', 'purpose', 'membership_fact', 'source', v_src,
    'target', v_to, 'event', pg_temp.ev(p_e), 'timestamp', v_ts::text, 'digest', v_digest, 'key', 'k1');
begin
  v_h := v_h || jsonb_build_object('signature', encode(extensions.hmac(convert_to(
    public.federation_signing_input('POST', '/federation-inbox', 'membership_fact', v_src, v_to,
      pg_temp.ev(p_e), v_ts, v_digest, 'k1'), 'UTF8'), convert_to(repeat(p_s, 40), 'UTF8'), 'sha256'), 'hex'));
  return public.federation_inbox_accept('POST', '/federation-inbox',
    (select jsonb_object_agg('x-deskilo-' || key, value) from jsonb_each(v_h)),
    encode(convert_to(v_body::text, 'UTF8'), 'base64'));
end $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
-- One fact of source p_s about person p_u and the workspace p_ref.
create function pg_temp.go(p_e int, p_s text, p_u int, p_r bigint, p_st text,
  p_at timestamptz default now(), p_ref text default null,
  p_life interval default interval '900 seconds')
returns text language sql as $$
  select pg_temp.post(p_s, p_e, jsonb_build_object('kind', 'membership_fact',
    'subject', pg_temp.u(p_u), 'network_id', coalesce(p_ref, pg_temp.ref(p_s)),
    'revision', p_r, 'status', p_st), p_at, p_life)->>'outcome' $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
-- A page of W-B's snapshot.
create function pg_temp.pg(p_e int, p_snap int, p_wm int, p_page int, p_pages int, p_cnt int,
  p_hash text, p_entries jsonb)
returns text language sql as $$
  select pg_temp.post('b', p_e, jsonb_build_object('kind', 'membership_snapshot',
    'snapshot_id', pg_temp.snap(p_snap), 'watermark', p_wm, 'page', p_page, 'pages', p_pages,
    'count', p_cnt, 'hash', p_hash, 'entries', p_entries))->>'outcome' $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
-- One snapshot entry of W-B, as a one-element list (lists concatenate).
create function pg_temp.e(p_n int, p_k int, p_r int, p_st text) returns jsonb language sql as $$
  select jsonb_build_array(jsonb_build_array(pg_temp.u(p_n)::text, pg_temp.ref('b', p_k), p_r, p_st)) $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.full_list() returns jsonb language sql as $$
  select pg_temp.e(1, 1, 10, 'active') || pg_temp.e(6, 1, 11, 'active') $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.h(p_entries jsonb) returns text language sql as $$
  select public.membership_snapshot_digest(p_entries) $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
-- W-B's facts at P as person+workspace=status@revision.
create function pg_temp.bst() returns text language plpgsql as $$
declare v text;
begin
  select string_agg('u' || right(user_id::text, 1) || 'b' || right(network_id, 1) || '=' || status
                    || '@' || revision, ' ' order by user_id, network_id) into v
    from public.membership_facts where source_installation_id = pg_temp.inst('b');
  return v;
end $$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- ── case 7: P decides from its own facts, never through a link to W ───
select is_empty($$select srvname::text from pg_foreign_server
                  union all select ftrelid::regclass::text from pg_foreign_table$$,
  'case 7: no foreign server and no foreign table');
select is_empty($$select p.proname::text from pg_proc p
   where p.pronamespace = 'public'::regnamespace and p.prosrc ~* '(dblink|postgres_fdw)'$$,
  'case 7: no public function reaches another database');
select is_empty($$select column_name::text from information_schema.columns
   where table_schema = 'public' and table_name = 'membership_facts'
     and column_name ~ '(role|permission|admin|owner|plan|email)'$$,
  'case 7: a fact holds a relationship status, never a role, a permission or a copied member');

-- ── case 3: a fact's status keeps the pre-split policy ────────────────
select is(pg_temp.go(1, 'a', 1, 10, 'active') || ' ' || pg_temp.go(2, 'a', 2, 11, 'active'),
  'applied applied', 'case 3: u1 and u2 active at W-A');
select is(pg_temp.sees('identity', 2) || ' ' || pg_temp.sees('reachability', 2) || ' '
          || pg_temp.sees('about', 2),
  'true true false', 'case 3: the default identity audience shares the verified space; about stays nobody');
select is(pg_temp.go(3, 'a', 4, 12, 'exited') || ' ' || pg_temp.go(4, 'a', 5, 13, 'pending') || ' '
          || pg_temp.sees('identity', 4) || ' ' || pg_temp.sees('identity', 5),
  'applied applied false false', 'case 3: an exited or a pending relationship shares nothing');

-- ── case 4: malformed facts and the doors ─────────────────────────────
select is(pg_temp.go(5, 'a', 2, 14, 'owner') || ' ' || pg_temp.go(6, 'a', 2, 0, 'active') || ' '
          || pg_temp.fact(2, pg_temp.ref('a')),
  'malformed malformed active@11 900', 'case 4: an unknown status or revision 0 is malformed and changes nothing');
select is(pg_temp.go(7, 'a', 2, 1, 'active', p_ref => pg_temp.ref('a', 3)), 'applied',
  'case 4: u2 alone holds a fact for W-A space 3');
select pg_temp.act(1);
set local role authenticated;
select throws_ok($$insert into public.membership_facts (user_id, network_id, issuer, source_installation_id,
    revision, status, asserted_at, valid_until, enrolment_epoch, event_id)
  values (auth.uid(), pg_temp.ref('a', 9), pg_temp.iss(), pg_temp.inst('a'), 1, 'active', now(),
    now() + interval '900 seconds', now(), gen_random_uuid())$$, '42501', null,
  'case 4: a signed-in person cannot write a fact');
select is((select count(*) filter (where e->>'network_id' = pg_temp.ref('a'))::text || ' '
               || count(*) filter (where e->>'network_id' = pg_temp.ref('a', 3))::text
             from jsonb_array_elements(public.export_my_personal_data_v1() -> 'workspace_refs') e),
  '1 0', 'case 4: my export names my reference, never another person''s');
reset role;
select pg_temp.act(null);

-- ── case 5 (P): retries, order and crashes ────────────────────────────
select is(pg_temp.go(8, 'a', 1, 10, 'active', now() + interval '10 seconds') || ' '
          || pg_temp.go(9, 'a', 1, 10, 'active', now() + interval '20 seconds'),
  'renewed renewed', 'case 5: two genuinely newer assertions of revision 10 renew');
create temp table r5 as
select pg_temp.post('a', 8, jsonb_build_object('kind', 'membership_fact', 'subject', pg_temp.u(1),
         'network_id', pg_temp.ref('a'), 'revision', 10, 'status', 'active'),
         now() + interval '10 seconds') v;
select is((select (v->>'outcome') || ' ' || (v->>'first_outcome') from r5) || ' '
          || (select (event_id = pg_temp.ev(9))::text || ' '
                     || extract(epoch from valid_until - now())::int
                from public.membership_facts where user_id = pg_temp.u(1) and network_id = pg_temp.ref('a')),
  'duplicate renewed true 920',
  'case 5: a retry of an earlier event answers as that event and renews nothing');
select is(pg_temp.go(10, 'a', 1, 10, 'active', now() + interval '20 seconds', p_life => interval '600 seconds')
          || ' ' || pg_temp.fact(1, pg_temp.ref('a')),
  'superseded active@10 900',
  'case 5: the same revision and assertion time with another digest changes nothing');
select is(pg_temp.go(11, 'a', 2, 12, 'paused', p_ref => pg_temp.ref('a', 4)) || ' '
          || pg_temp.go(12, 'a', 2, 11, 'active', p_ref => pg_temp.ref('a', 4)) || ' '
          || pg_temp.fact(2, pg_temp.ref('a', 4)),
  'applied superseded paused@12 900', 'case 5: out of order, the higher revision stays');
create function pg_temp.crashed(p_e int) returns text language plpgsql as $$
declare v text;
begin
  begin
    v := pg_temp.go(p_e, 'a', 3, 5, 'active', p_ref => pg_temp.ref('a', 2));
    raise exception 'crash before commit' using errcode = 'P0001';
  exception when sqlstate 'P0001' then
    null;
  end;
  return v || ' ' || (select count(*) from public.federation_inbox_receipts
                       where event_id = pg_temp.ev(p_e))::text
           || ' ' || pg_temp.fact(3, pg_temp.ref('a', 2));
end $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
select is(pg_temp.crashed(13), 'applied 0 none', 'case 5: a crash before P commits leaves no receipt and no fact');
select is(pg_temp.go(13, 'a', 3, 5, 'active', p_ref => pg_temp.ref('a', 2)) || ' '
          || pg_temp.fact(3, pg_temp.ref('a', 2)),
  'applied active@5 900', 'case 5: so the retry of that event applies');

-- ── case 6: the deadline is the source's ──────────────────────────────
select is(pg_temp.go(14, 'a', 3, 50, 'active', now() - interval '925 seconds') || ' '
          || pg_temp.in_force(3, pg_temp.ref('a')),
  'applied true', 'case 6: asserted 925 s ago, inside lifetime plus skew: in force');
select is(pg_temp.go(15, 'a', 3, 51, 'active', now() - interval '935 seconds') || ' '
          || pg_temp.fact(3, pg_temp.ref('a')),
  'expired_assertion active@50 900', 'case 6: asserted 935 s ago, past lifetime plus skew: refused');
select is(pg_temp.go(16, 'a', 2, 7, 'active', p_ref => pg_temp.ref('a', 5), p_life => interval '3600 seconds')
          || ' ' || pg_temp.fact(2, pg_temp.ref('a', 5)),
  'applied active@7 900', 'case 6: a longer claimed life is cut to the lifetime');

-- ── case 6: a lapsed fact discloses nothing; an accepted thread works ──
select pg_temp.act(2);
set local role authenticated;
select set_config('m9999.thread', public.send_account_message(pg_temp.u(1), 'hello', pg_temp.u(2))::text, true);
reset role;
select is((select request_state from public.account_conversations
            where id = current_setting('m9999.thread')::uuid), 'accepted',
  'case 6: in a verified common space u2 starts an accepted conversation');
alter table public.membership_facts disable trigger protect_membership_fact;
update public.membership_facts set asserted_at = now() - interval '2 hours', valid_until = now() - interval '1 hour'
 where user_id = pg_temp.u(1);
alter table public.membership_facts enable trigger protect_membership_fact;
set local role authenticated;
select is((public.visible_account(pg_temp.u(1)) ? 'identity')::text || ' '
          || (public.visible_account(pg_temp.u(1)) ->> 'can_message'),
  'false true', 'case 6: u1''s fact lapsed: no identity for u2, the accepted thread stays open');
select is(public.send_account_message(pg_temp.u(1), 'still here', pg_temp.u(2))::text,
  current_setting('m9999.thread'), 'case 6: and u2 still writes in it');
select pg_temp.act(3);
select set_config('m9999.request', public.send_account_message(pg_temp.u(1), 'hi', pg_temp.u(3))::text, true);
reset role;
select is((select request_state from public.account_conversations
            where id = current_setting('m9999.request')::uuid) || ' '
          || (select count(*) from public.account_messages
               where conversation_id = current_setting('m9999.thread')::uuid)::text || ' '
          || pg_temp.fact(1, pg_temp.ref('a')),
  'pending 2 active@10 3600',
  'case 6: a new conversation is only a request; the lapsed fact is kept, not erased');
select pg_temp.act(null);

-- ── case 6: a snapshot changes nothing until it is complete ──────────
select is(pg_temp.go(20, 'b', 1, 10, 'active', p_ref => pg_temp.ref('b', 1)) || ' '
          || pg_temp.go(21, 'b', 6, 11, 'active', p_ref => pg_temp.ref('b', 1)) || ' '
          || pg_temp.go(22, 'b', 6, 12, 'active', p_ref => pg_temp.ref('b', 2)) || ' ' || pg_temp.bst(),
  'applied applied applied u1b1=active@10 u6b1=active@11 u6b2=active@12', 'case 6: three live facts of W-B');
create temp table b6 as select pg_temp.bst() s;
select is(pg_temp.pg(30, 1, 20, 2, 2, 2, pg_temp.h(pg_temp.full_list()), pg_temp.e(6, 1, 11, 'active'))
          || ' ' || pg_temp.bst(), 'staged ' || (select s from b6),
  'case 6: the second page first: staged, nothing changes');
select is(pg_temp.pg(31, 1, 20, 2, 2, 2, pg_temp.h(pg_temp.full_list()), pg_temp.e(6, 1, 11, 'active'))
          || ' ' || pg_temp.pg(32, 1, 20, 2, 2, 2, pg_temp.h(pg_temp.full_list()), pg_temp.e(1, 1, 10, 'active'))
          || ' ' || pg_temp.bst(), 'duplicate snapshot_conflict ' || (select s from b6),
  'case 6: the same page again is a duplicate, another list for it is refused');
create temp table r6 as
select pg_temp.post('b', 30, jsonb_build_object('kind', 'membership_snapshot', 'snapshot_id', pg_temp.snap(1),
         'watermark', 20, 'page', 2, 'pages', 2, 'count', 2, 'hash', pg_temp.h(pg_temp.full_list()),
         'entries', pg_temp.e(6, 1, 11, 'active'))) v;
select is((select (v->>'outcome') || ' ' || (v->>'first_outcome') from r6), 'duplicate staged',
  'case 5: a page retried after a lost answer answers as that event');
update public.membership_snapshot_pages set asserted_at = now() - interval '2 hours',
       valid_until = now() - interval '1 hour'
 where source_installation_id = pg_temp.inst('b') and snapshot_id = pg_temp.snap(1);
select is(pg_temp.pg(33, 1, 20, 1, 2, 2, pg_temp.h(pg_temp.full_list()), pg_temp.e(1, 1, 10, 'active'))
          || ' ' || pg_temp.bst(), 'expired_snapshot ' || (select s from b6),
  'case 6: a page that lapsed in transit sinks the whole snapshot');
select is((select count(*)::int from public.membership_snapshot_pages
            where source_installation_id = pg_temp.inst('b')), 0, 'case 6: and its pages are dropped');
select is(pg_temp.pg(34, 2, 30, 1, 2, 2, pg_temp.h(pg_temp.full_list()), pg_temp.e(1, 1, 10, 'active'))
          || ' ' || pg_temp.bst(), 'staged ' || (select s from b6),
  'case 6: an older snapshot, one page of two: nothing changes');
select is(pg_temp.pg(35, 3, 40, 1, 1, 2, pg_temp.h(pg_temp.full_list()), pg_temp.full_list())
          || ' ' || pg_temp.bst(), 'reconciled u1b1=active@10 u6b1=active@11 u6b2=tombstone@40',
  'case 6: a newer complete snapshot ends only the unlisted fact');
select is(pg_temp.pg(36, 2, 30, 2, 2, 2, pg_temp.h(pg_temp.full_list()), pg_temp.e(6, 1, 11, 'active'))
          || ' ' || (select count(*) from public.membership_snapshot_pages
                      where source_installation_id = pg_temp.inst('b'))::text || ' ' || pg_temp.bst(),
  'superseded 0 u1b1=active@10 u6b1=active@11 u6b2=tombstone@40',
  'case 6: the rest of the older snapshot arrives too late and changes nothing');
select is((select count(*) filter (where status = 'tombstone')::text || ' ' || count(*)::text
             from public.membership_facts where source_installation_id = pg_temp.inst('a')),
  '0 9', 'case 6: W-A sent no snapshot, so none of its facts ended');

-- ── W: fixtures (u7 is the local person bound to P's subject u1) ──────
-- The replay starts with no relationship; a probe on a used database starts
-- from the same empty W, so the counts below are this file's alone.
delete from public.membership_fact_outbox;
alter table public.membership_fact_state disable trigger protect_membership_fact;
delete from public.membership_fact_state;
alter table public.membership_fact_state enable trigger protect_membership_fact;
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer, oidc_provider)
values ('oidc', pg_temp.iss(), 'custom:deskilo');
select public.operator_set_personal_home('unset');
select public.operator_set_installation_roles(array['workspace_host']);
select public.operator_set_personal_home('endpoint', 'https://p9999.test', 'sb_publishable_p_key_9999');
select public.operator_set_federation_key(pg_temp.inst('f'), 'outbound', 'membership_fact', 'k1', repeat('m', 40));
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, environment, booking_rules, feature_flags)
values (pg_temp.id('9999f0000009'), 'Matrix', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(7), 'dev', '{}', '{}');
insert into public.identity_bindings (installation_id, local_user_id, issuer, subject, verified_via, status, revoked_at)
values (public.installation_id(), pg_temp.u(7), pg_temp.iss(), pg_temp.u(1)::text, 'oidc_identity', 'active', null);
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status)
values (pg_temp.id('9999d0000001'), pg_temp.id('9999f0000009'), pg_temp.u(7), false, false, 'active');
-- The outbox as status:state:attempts:outcome, by revision.
create function pg_temp.box() returns text language plpgsql as $$
declare v text;
begin
  select string_agg(status || ':' || state || ':' || attempts || ':' || coalesce(outcome, '-'), ' '
                    order by revision, asserted_at) into v
    from public.membership_fact_outbox where subject = pg_temp.u(1)::text;
  return v;
end $$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- ── case 5 (W): a lost enqueue heals ──────────────────────────────────
alter table public.members disable trigger membership_fact_on_member_change;
update public.members set status = 'paused' where id = pg_temp.id('9999d0000001');
alter table public.members enable trigger membership_fact_on_member_change;
select is(pg_temp.box(), 'active:pending:0:-', 'case 5: a change whose enqueue was lost asserts nothing yet');
select is((public.membership_fact_reconcile()->>'changed') || ' ' || pg_temp.box(),
  '1 active:pending:0:- paused:pending:0:-', 'case 5: the reconcile asserts it as a newer revision');

-- ── case 5 (W): crash before and after the acknowledgement ───────────
select is(public.membership_fact_drain()->>'sent', '2', 'case 5: the drain sends both');
select is((public.membership_fact_drain()->>'sent') || ' ' || pg_temp.box(),
  '0 active:sent:1:- paused:sent:1:-', 'case 5: no answer yet: nothing is sent twice');
update public.membership_fact_outbox set last_attempt_at = now() - interval '3 minutes'
 where subject = pg_temp.u(1)::text;
select is((public.membership_fact_drain()->>'sent') || ' ' || pg_temp.box(),
  '2 active:sent:2:no_answer paused:sent:2:no_answer', 'case 5: the answer was lost: both are sent again');
select is((select count(*)::int from (
             select q.headers->>'x-deskilo-event' from net.http_request_queue q
              where q.url = 'https://p9999.test/functions/v1/federation-inbox'
              group by 1
             having count(*) = 2 and count(distinct q.headers->>'x-deskilo-digest') = 1
                and count(distinct q.body) = 1
                and bool_and(q.headers->>'x-deskilo-digest' = encode(extensions.digest(q.body, 'sha256'), 'hex'))) x),
  2, 'case 5: each retry is the same event with the same body and digest, so P answers duplicate');
insert into net._http_response (id, status_code, content, timed_out, created)
select o.net_request_id, case o.status when 'active' then 200 else 503 end,
       case o.status when 'active' then '{"outcome":"duplicate"}' else '{"outcome":"unavailable"}' end,
       false, now()
  from public.membership_fact_outbox o where o.subject = pg_temp.u(1)::text;
select is((public.membership_fact_drain()->>'sent') || ' ' || pg_temp.box(),
  '1 active:delivered:2:duplicate paused:sent:3:unavailable',
  'case 5: the acknowledgement settles one; a 5xx is sent again');
select is((public.membership_fact_drain()->>'sent') || ' ' || pg_temp.box(),
  '0 active:delivered:2:duplicate paused:sent:3:unavailable',
  'case 5: after the acknowledgement nothing is sent again');
insert into net._http_response (id, status_code, content, timed_out, created)
select o.net_request_id, 409, '{"outcome":"revision_conflict"}', false, now()
  from public.membership_fact_outbox o where o.subject = pg_temp.u(1)::text and o.state = 'sent';
select is((public.membership_fact_drain()->>'sent') || ' ' || pg_temp.box(),
  '0 active:delivered:2:duplicate paused:refused:3:revision_conflict',
  'case 5: a refusal for good is never retried');

select * from finish();
rollback;
