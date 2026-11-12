-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3510 (0732): the settlement schedule's state. Only a workspace with a
-- Mollie key and online payments on is polled; one poll at a time per
-- workspace (a lease, its holder alone finishes); an unfinished read
-- continues where it stopped; the first full read is remembered; a refused
-- key waits a day, a transient failure is retried sooner, doubling to a
-- bound; nobody but the service role touches any of it. Rolled back.
begin;
select plan(25);

do $seed$
declare
  u uuid := '00000000-0000-4000-8000-0000003510b1';
  ws_on uuid; ws_off uuid; ws_nokey uuid; ws_empty uuid;
  k text := repeat('k', 12);
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner@poll.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Poll on', 'FR', 'EUR', 'Europe/Paris', u, '{"onlinePayments": true}') returning id into ws_on;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Poll off', 'FR', 'EUR', 'Europe/Paris', u, '{"onlinePayments": false}') returning id into ws_off;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Poll no key', 'FR', 'EUR', 'Europe/Paris', u, '{"onlinePayments": true}') returning id into ws_nokey;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Poll empty key', 'FR', 'EUR', 'Europe/Paris', u, '{"onlinePayments": true}') returning id into ws_empty;
  insert into public.payment_credentials (workspace_id, provider, config) values
    (ws_on, 'mollie', jsonb_build_object('api_key', k)),
    (ws_off, 'mollie', jsonb_build_object('api_key', k)),
    (ws_empty, 'mollie', jsonb_build_object('api_key', ''));
  -- No other workspace of the project is claimed in this test: the ones
  -- that exist are pushed out of reach for its duration (rolled back).
  insert into public.provider_settlement_polls (workspace_id, provider, next_attempt_at)
  select c.workspace_id, 'mollie', now() + interval '1 year' from public.payment_credentials c
   where c.provider = 'mollie' and c.workspace_id not in (ws_on, ws_off, ws_empty)
  on conflict (workspace_id, provider) do update set next_attempt_at = excluded.next_attempt_at;
  perform set_config('t.on', ws_on::text, false);
  perform set_config('t.off', ws_off::text, false);
end;
$seed$;

-- Claims for a run that started p_seconds after this transaction began
-- (now() stands still inside one transaction); answers the workspace's
-- name, or 'none', and keeps the lease token.
create or replace function pg_temp.claim(p_seconds int) returns text language plpgsql as $f$
declare r record;
begin
  select * into r from public.settlement_poll_claim_v1('mollie', 300, now() + make_interval(secs => p_seconds));
  if r.workspace_id is null then return 'none'; end if;
  perform set_config('t.token', r.lease_token::text, false);
  perform set_config('t.from', coalesce(r.continuation, ''), false);
  perform set_config('t.backfilled', r.backfilled::text, false);
  perform set_config('t.key', coalesce(r.api_key, ''), false);
  return (select name from public.workspaces where id = r.workspace_id);
end
$f$;
create or replace function pg_temp.finish(p_result jsonb, p_token text default null) returns boolean language sql as $f$
  select public.settlement_poll_finish_v1(current_setting('t.on')::uuid, 'mollie',
    coalesce(p_token, current_setting('t.token'))::uuid, p_result)
$f$;
create or replace function pg_temp.state() returns public.provider_settlement_polls language sql as $f$
  select * from public.provider_settlement_polls where workspace_id = current_setting('t.on')::uuid and provider = 'mollie'
$f$;
-- Lets the next attempt come now (time cannot move inside the test).
create or replace function pg_temp.due() returns void language sql as $f$
  update public.provider_settlement_polls set next_attempt_at = now() - interval '1 second'
   where workspace_id = current_setting('t.on')::uuid and provider = 'mollie'
$f$;

-- Who is polled
select is(pg_temp.claim(1), 'Poll on', 'a Mollie key and online payments on: claimed');
select is(current_setting('t.key'), repeat('k', 12), 'with its own key, for the read');
select is(pg_temp.claim(1), 'none', 'nothing else is due: online payments off, no key and an empty key are never claimed, nor the same workspace twice in a run');
select ok((select count(*) = 0 from public.provider_settlement_polls where workspace_id = current_setting('t.off')::uuid and lease_token is not null),
  'the workspace with online payments off holds no lease');

-- The lease
select is(pg_temp.claim(2), 'none', 'a held lease keeps a second poll away, even in a later run');
select is(pg_temp.finish('{"complete": false, "continuation": "stl_x"}', gen_random_uuid()::text), false,
  'a result from someone else than the lease''s holder is refused');
select is((pg_temp.state()).continuation, null, 'and writes nothing');

-- An unfinished first read continues where it stopped
select is(pg_temp.finish('{"complete": false, "continuation": "stl_551", "new": 500, "pages": 10}'), true,
  'the holder''s result is taken');
select is((pg_temp.state()).continuation, 'stl_551', 'the continuation is kept');
select is((pg_temp.state()).backfilled, false, 'the first full read has not ended');
select ok((pg_temp.state()).lease_token is null and (pg_temp.state()).last_success_at is not null and (pg_temp.state()).failures = 0,
  'the lease is freed and the success noted');
select is(pg_temp.claim(3) || '|' || current_setting('t.from') || '|' || current_setting('t.backfilled'),
  'Poll on|stl_551|false', 'the next run resumes the first read where it stopped');
select is(pg_temp.finish('{"complete": true, "continuation": null, "new": 30, "pages": 1}'), true, 'the end of the list');
select ok((pg_temp.state()).backfilled and (pg_temp.state()).continuation is null,
  'the first full read is remembered; the next read starts from the newest');

-- Failures
select is(pg_temp.claim(4), 'Poll on', 'claimed again in a later run');
select is(pg_temp.finish('{"complete": false, "continuation": "stl_200", "failure": {"kind": "unreachable", "status": 503}}'), true,
  'a transient failure is taken');
select ok((pg_temp.state()).failures = 1 and (pg_temp.state()).next_attempt_at = now() + interval '5 minutes'
          and (pg_temp.state()).continuation = 'stl_200' and (pg_temp.state()).last_error ->> 'kind' = 'unreachable',
  'retried in five minutes, from the page that failed');
select is(pg_temp.claim(5), 'none', 'not before its retry time');
select pg_temp.due();
select is(pg_temp.claim(6), 'Poll on', 'claimed once its retry time passed');
select is(pg_temp.finish('{"complete": false, "continuation": "stl_200", "failure": {"kind": "record_failed", "settlement": "stl_201"}}'), true,
  'a second failure in a row');
select ok((pg_temp.state()).failures = 2 and (pg_temp.state()).next_attempt_at = now() + interval '10 minutes',
  'the wait doubles');
update public.provider_settlement_polls set failures = 40, next_attempt_at = now() - interval '1 second'
 where workspace_id = current_setting('t.on')::uuid;
select pg_temp.claim(7);
select pg_temp.finish('{"complete": false, "failure": {"kind": "unreachable"}}');
select is((pg_temp.state()).next_attempt_at, now() + interval '6 hours', 'up to six hours, however many failures');
select pg_temp.due();
select pg_temp.claim(8);
select pg_temp.finish('{"complete": false, "failure": {"kind": "refused", "status": 401}}');
select is((pg_temp.state()).next_attempt_at, now() + interval '24 hours', 'a key Mollie refuses waits a day');
select pg_temp.due();
select pg_temp.claim(9);
select throws_ok($$select pg_temp.finish('{"complete": true, "failure": {"kind": "whatever"}}')$$, '22023', NULL,
  'an unknown failure is refused');

-- Nobody but the service role
select ok(not has_function_privilege('authenticated', 'public.settlement_poll_claim_v1(text, integer, timestamptz)', 'execute')
      and not has_function_privilege('anon', 'public.settlement_poll_claim_v1(text, integer, timestamptz)', 'execute')
      and not has_function_privilege('authenticated', 'public.settlement_poll_finish_v1(uuid, text, uuid, jsonb)', 'execute')
      and not has_function_privilege('anon', 'public.settlement_poll_finish_v1(uuid, text, uuid, jsonb)', 'execute')
      and not has_function_privilege('authenticated', 'public.settlement_poll_tick()', 'execute')
      and not has_function_privilege('anon', 'public.settlement_poll_tick()', 'execute')
      and not has_table_privilege('authenticated', 'public.provider_settlement_polls', 'select')
      and not has_table_privilege('anon', 'public.provider_settlement_polls', 'select'),
  'no client may claim, finish, tick or read the schedule''s state');

select * from finish();
rollback;
