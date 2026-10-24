-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2563 C2: three delivery defects of the backchannel.
--   1. A duplicate answer whose first outcome was a refusal is booked
--      refused, for that reason, by all three drains; a duplicate of a
--      success, or one without a first outcome, stays delivered.
--   2. membership_fact_reconcile tombstones and renews only the current
--      issuer's relationships; an old issuer's rows stay untouched.
--   3. The wait for an answer is the platform setting
--      federation.answer_wait_seconds, not a literal.
-- The answers are rows in net._http_response, as pg_net would write them;
-- pg_net only queues inside the rolled-back transaction.
begin;
select plan(15);

create function pg_temp.id(p_tail text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-' || p_tail)::uuid $$;
create function pg_temp.iss() returns text language sql as $$ select 'https://pfx2563.test/auth/v1' $$;
-- W-A (an enrolled workspace installation) and P (the personal home).
create function pg_temp.inst(p_c text) returns uuid language sql as $$
  select pg_temp.id('00000256390' || p_c) $$;
create function pg_temp.ev(p_n int) returns uuid language sql as $$
  select pg_temp.id('0000025638' || lpad(p_n::text, 2, '0')) $$;
create function pg_temp.ref() returns text language sql as $$
  select public.installation_id() || ':' || pg_temp.id('000002563901') $$;

-- ── the setting and the helpers ───────────────────────────────────────
select is((select key || '=' || (default_value #>> '{}') || ' ' || min_value || '..' || max_value || ' '
                  || unit || ' ' || array_to_string(scopes, ',') || ' floor ' || floor_value
             from public.setting_definitions where key = 'federation.answer_wait_seconds')
          || ' ' || public.federation_answer_wait()::text,
  'federation.answer_wait_seconds=120 30..600 seconds platform floor 30 00:02:00',
  'the wait for an answer is a platform setting of two minutes');
select is_empty($$select p.proname || ' ' || r from pg_proc p
  cross join unnest(array['anon', 'authenticated', 'service_role']) r
  where p.pronamespace = 'public'::regnamespace
    and p.proname in ('federation_outcome_refused', 'federation_answer_wait')
    and has_function_privilege(r, p.oid, 'EXECUTE')$$,
  'no API role executes the helpers');
select is((select string_agg(o || '=' || public.federation_outcome_refused(o)::text, ' ' order by n)
             from unnest(array['applied', 'renewed', 'staged', 'reconciled', 'duplicate', 'superseded',
                               'wrong_issuer', 'snapshot_conflict', 'malformed', 'maybe']) with ordinality u(o, n))
          || ' null=' || public.federation_outcome_refused(null)::text,
  'applied=false renewed=false staged=false reconciled=false duplicate=false superseded=false '
  || 'wrong_issuer=true snapshot_conflict=true malformed=true maybe=true null=false',
  'every outcome but a success is a refusal');

-- ── P: an enrolled W-A and its outbound status key ────────────────────
select public.operator_set_installation_roles(array['personal_home', 'workspace_host']);
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', pg_temp.iss());
select public.operator_enrol_installation(pg_temp.inst('a'), 'https://wfx2563.test',
  'sb_publishable_wfx_key_123', array['workspace_host'], array['workspace@1']);
select public.operator_set_federation_key(pg_temp.inst('a'), 'outbound', 'identity_status', 'k1', repeat('i', 40));

-- ── W: the personal home P and the outbound fact key ──────────────────
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer, oidc_provider)
values ('oidc', pg_temp.iss(), 'custom:deskilo');
select public.operator_set_personal_home('unset');
select public.operator_set_installation_roles(array['workspace_host']);
select public.operator_set_personal_home('endpoint', 'https://pfx2563.test', 'sb_publishable_pfx_key_123');
select public.operator_set_federation_key(pg_temp.inst('f'), 'outbound', 'membership_fact', 'k1', repeat('m', 40));

-- One sent message per case, attempted p_ago seconds ago; its answer, if
-- any, is a pg_net response row.
create function pg_temp.fact(p_n int, p_ago int) returns void language sql as $$
  insert into public.membership_fact_outbox (event_id, target_installation_id, issuer, subject, network_id,
    revision, status, asserted_at, valid_until, body, state, attempts, last_attempt_at, net_request_id)
  values (pg_temp.ev(p_n), pg_temp.inst('f'), pg_temp.iss(), 'f' || p_n, pg_temp.ref(), p_n, 'active',
    now() - make_interval(secs => p_ago), now() + interval '10 minutes', jsonb_build_object('n', p_n),
    'sent', 1, now() - make_interval(secs => p_ago), 925630000 + p_n) $$;
create function pg_temp.page(p_n int, p_ago int) returns void language sql as $$
  insert into public.membership_snapshot_outbox (event_id, target_installation_id, snapshot_id, page, pages,
    watermark, entry_count, manifest_hash, asserted_at, valid_until, body, state, attempts, last_attempt_at,
    net_request_id)
  values (pg_temp.ev(p_n), pg_temp.inst('f'), pg_temp.ev(p_n), 1, 1, 0, 0, repeat('0', 64),
    now() - make_interval(secs => p_ago), now() + interval '10 minutes', jsonb_build_object('n', p_n),
    'sent', 1, now() - make_interval(secs => p_ago), 925630000 + p_n) $$;
create function pg_temp.status(p_n int, p_ago int) returns void language sql as $$
  insert into public.identity_status_outbox (event_id, target_installation_id, issuer, subject, revision,
    status, issued_at, valid_until, body, state, attempts, last_attempt_at, net_request_id)
  values (pg_temp.ev(p_n), pg_temp.inst('a'), pg_temp.iss(), 'i' || p_n, p_n, 'active',
    now() - make_interval(secs => p_ago), now() + interval '10 minutes', jsonb_build_object('n', p_n),
    'sent', 1, now() - make_interval(secs => p_ago), 925630000 + p_n) $$;
create function pg_temp.answer(p_n int, p_code int, p_content text) returns void language sql as $$
  insert into net._http_response (id, status_code, content, timed_out, created)
  values (925630000 + p_n, p_code, p_content, false, now()) $$;
create function pg_temp.booked(p_table text, p_n int) returns text language plpgsql as $$
declare v text;
begin
  execute format('select state || '' '' || coalesce(outcome, ''-'') || '' '' || attempts from public.%I
                   where event_id = $1', p_table) into v using pg_temp.ev(p_n);
  return v;
end $$;

select pg_temp.fact(1, 30), pg_temp.answer(1, 200, '{"outcome":"duplicate","first_outcome":"wrong_issuer"}');
select pg_temp.fact(2, 30), pg_temp.answer(2, 200, '{"outcome":"duplicate","first_outcome":"applied"}');
select pg_temp.fact(3, 30), pg_temp.answer(3, 200, '{"outcome":"duplicate"}');
select pg_temp.fact(4, 90);
select pg_temp.fact(5, 150);
select pg_temp.fact(6, 30), pg_temp.answer(6, 422, '{"outcome":"wrong_issuer"}');
select pg_temp.fact(7, 40);
select pg_temp.page(11, 30), pg_temp.answer(11, 200, '{"outcome":"duplicate","first_outcome":"snapshot_conflict"}');
select pg_temp.page(12, 150);
select pg_temp.page(13, 30), pg_temp.answer(13, 200, '{"outcome":"duplicate","first_outcome":"staged"}');
select pg_temp.status(21, 30), pg_temp.answer(21, 200, '{"outcome":"duplicate","first_outcome":"unlinked_subject"}');
select pg_temp.status(22, 30), pg_temp.answer(22, 200, '{"outcome":"applied"}');
select pg_temp.status(23, 150);

-- ── 1. a retry of a refused event stays refused ───────────────────────
select public.membership_fact_drain() is not null;
select is(pg_temp.booked('membership_fact_outbox', 1), 'refused wrong_issuer 1',
  'a duplicate of a refused fact is refused, for the first reason');
select is(pg_temp.booked('membership_fact_outbox', 2) || ', ' || pg_temp.booked('membership_fact_outbox', 3),
  'delivered duplicate 1, delivered duplicate 1',
  'a duplicate of a success, or without a first outcome, is delivered');
select is(pg_temp.booked('membership_fact_outbox', 6), 'refused wrong_issuer 1',
  'a refusal answered directly is refused, as before');
select public.membership_snapshot_drain() is not null;
select is(pg_temp.booked('membership_snapshot_outbox', 11) || ', ' || pg_temp.booked('membership_snapshot_outbox', 13),
  'refused snapshot_conflict 1, delivered duplicate 1',
  'the snapshot drain books a duplicate by its first outcome');
select public.identity_status_drain() is not null;
select is(pg_temp.booked('identity_status_outbox', 21) || ', ' || pg_temp.booked('identity_status_outbox', 22),
  'refused unlinked_subject 1, delivered applied 1',
  'the identity status drain books a duplicate by its first outcome');

-- ── 3. the wait for an answer is the setting ──────────────────────────
select is(pg_temp.booked('membership_fact_outbox', 4) || ', ' || pg_temp.booked('membership_fact_outbox', 7)
          || ', ' || pg_temp.booked('membership_fact_outbox', 5),
  'sent - 1, sent - 1, sent no_answer 2',
  'within the two minutes a sent fact waits; after them it is sent again');
select is(pg_temp.booked('membership_snapshot_outbox', 12), 'sent no_answer 2',
  'a snapshot page waits as long');
select is(pg_temp.booked('identity_status_outbox', 23), 'sent no_answer 2',
  'an identity status waits as long');
update public.setting_definitions set default_value = '60'::jsonb
 where key = 'federation.answer_wait_seconds';
select public.membership_fact_drain() is not null;
select is(public.federation_answer_wait()::text || ' ' || pg_temp.booked('membership_fact_outbox', 4)
          || ', ' || pg_temp.booked('membership_fact_outbox', 7),
  '00:01:00 sent no_answer 2, sent - 1',
  'a shorter wait sends the 90-second-old fact again, not the 40-second-old one');

-- ── 2. the reconcile keeps to the current issuer ──────────────────────
insert into public.membership_fact_state (issuer, subject, network_id, revision, status, last_asserted_at)
values ('https://oldfx2563.test/auth/v1', 'old-live', pg_temp.ref(), nextval('public.membership_fact_revision'), 'active', null),
       ('https://oldfx2563.test/auth/v1', 'old-tomb', pg_temp.ref(), nextval('public.membership_fact_revision'), 'tombstone', null),
       (pg_temp.iss(), 'cur-gone', pg_temp.ref(), nextval('public.membership_fact_revision'), 'active', null),
       (pg_temp.iss(), 'cur-tomb', pg_temp.ref(), nextval('public.membership_fact_revision'), 'tombstone', null);
select is(public.membership_fact_reconcile()::text, '{"changed": 1, "renewed": 1}',
  'one current relationship tombstoned, one current tombstone asserted');
select is((select string_agg(issuer || ' ' || subject || ' ' || status, ', ' order by subject)
             from public.membership_fact_outbox
            where subject in ('old-live', 'old-tomb', 'cur-gone', 'cur-tomb')),
  'https://pfx2563.test/auth/v1 cur-gone tombstone, https://pfx2563.test/auth/v1 cur-tomb tombstone',
  'nothing of the old issuer is enqueued');
select is((select string_agg(subject || ' ' || status || ' ' || coalesce(last_asserted_at::text, '-'), ', '
                             order by subject)
             from public.membership_fact_state where issuer = 'https://oldfx2563.test/auth/v1'),
  'old-live active -, old-tomb tombstone -',
  'the old issuer''s rows stay as the high-water, untouched');

select * from finish();
rollback;
