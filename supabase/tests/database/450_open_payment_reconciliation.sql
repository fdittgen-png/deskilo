-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4126 (0798): the open attempts are claimed for reconciliation once their
-- provider's read age passed (a provisional one once the resend window
-- passed), the least recently read first; an attempt is stamped when its run
-- READ it, so one claimed and not read keeps its place; inside its provider's
-- lifetime it is read again every half hour, after it each read waits longer,
-- up to a day; one business at a time under a lease, once per run, a lease
-- left unfinished traced; the record is accepted only from the lease's
-- holder, keeps only the attempts it claimed with a reason word, coerces and
-- names a malformed count, and keeps what the provider last said of an order
-- under which credentials; the tick keeps its outcome; the records past their
-- retention go and the young ones stay; nobody but the service role reads or
-- runs any of it; a second settlement of the same order credits nothing; and
-- an attempt ended for want of an order is still credited once.
begin;
select plan(34);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00004126' || lpad(n::text, 4, '0'))::uuid;
$$;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values (pg_temp.u(1), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
        'reconcile1@example.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by)
values (pg_temp.u(101), 'Reconcile 4126', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1)),
       (pg_temp.u(102), 'Reconcile 4126 elsewhere', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1)),
       (pg_temp.u(103), 'Reconcile 4126 queue', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1));
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', '2026-01-01'),
       (pg_temp.u(202), pg_temp.u(102), pg_temp.u(1), true, true, 'active', '2026-01-01'),
       (pg_temp.u(203), pg_temp.u(103), pg_temp.u(1), true, true, 'active', '2026-01-01');

-- Every other business's attempts are out of the way of these runs, and the
-- queue's business waits for its own part below.
insert into public.payment_reconciliation_state (workspace_id, lease_token, lease_until)
select w.id, gen_random_uuid(), now() + interval '1 hour' from public.workspaces w
 where w.id not in (pg_temp.u(101), pg_temp.u(102))
on conflict (workspace_id) do update set lease_token = excluded.lease_token, lease_until = excluded.lease_until;

insert into public.payment_intents (id, workspace_id, member_id, provider, order_id, period, amount_cents, currency, reference, status, created_at)
values
  (pg_temp.u(301), pg_temp.u(101), pg_temp.u(201), 'stripe', 'cs_due',       '2026-10', 1200, 'EUR', 'PAY-1', 'created',  now() - interval '1 hour'),
  (pg_temp.u(302), pg_temp.u(101), pg_temp.u(201), 'stripe', 'cs_young',     '2026-10', 1200, 'EUR', 'PAY-2', 'created',  now() - interval '10 minutes'),
  (pg_temp.u(303), pg_temp.u(101), pg_temp.u(201), 'mollie', 'tr_due',       '2026-10', 1300, 'EUR', 'PAY-3', 'created',  now() - interval '3 hours'),
  (pg_temp.u(304), pg_temp.u(101), pg_temp.u(201), 'paypal', 'pending:304',  '2026-11', 1400, 'EUR', 'PAY-4', 'created',  now() - interval '30 hours'),
  (pg_temp.u(305), pg_temp.u(101), pg_temp.u(201), 'paypal', 'O-SETTLED',    '2026-10', 1500, 'EUR', 'PAY-5', 'captured', now() - interval '5 hours'),
  (pg_temp.u(306), pg_temp.u(101), pg_temp.u(201), 'stripe', 'pending:306',  '2026-10', 1600, 'EUR', 'PAY-6', 'created',  now() - interval '20 hours'),
  (pg_temp.u(307), pg_temp.u(101), pg_temp.u(201), 'paypal', 'O-GONE',       '2026-10', 1700, 'EUR', 'PAY-7', 'created',  now() - interval '100 hours'),
  (pg_temp.u(311), pg_temp.u(102), pg_temp.u(202), 'stripe', 'cs_other',     '2026-10', 1800, 'EUR', 'PAY-1', 'created',  now() - interval '30 hours');
-- The queue: four attempts inside Stripe's lifetime.
insert into public.payment_intents (id, workspace_id, member_id, provider, order_id, period, amount_cents, currency, reference, status, created_at)
select pg_temp.u(320 + n), pg_temp.u(103), pg_temp.u(203), 'stripe', 'cs_q' || n, '2026-10', 1000, 'EUR', 'PAY-Q' || n, 'created',
       now() - make_interval(hours => 10 - n)
  from generate_series(1, 4) n;

select set_config('t.run', public.payment_reconciliation_begin_v1()::text, true);
create temp table c1 as select * from public.payment_reconciliation_claim_v1(300, current_setting('t.run')::timestamptz, 50);

-- ── what is due ──
select is((select count(*)::int from c1), 1, 'one business is claimed at a time');
select is((select array_agg(e ->> 'order_id' order by e ->> 'order_id' collate "C") from c1, jsonb_array_elements(intents) e
            where workspace_id = pg_temp.u(101)),
  array['O-GONE', 'cs_due', 'pending:304', 'tr_due'],
  'a known order past its read age, a provisional one past the resend window; not a young one, not a provisional one inside the window, not a settled one');
select is((select (e ->> 'gone_may_end')::boolean from c1, jsonb_array_elements(intents) e where e ->> 'order_id' = 'O-GONE'),
  true, 'a PayPal order past its longest lifetime may be ended if PayPal no longer knows it');
select is((select (e ->> 'gone_may_end')::boolean from c1, jsonb_array_elements(intents) e where e ->> 'order_id' = 'pending:304'),
  false, 'one inside it may not');
select is((select jsonb_object_agg(e ->> 'order_id', (e ->> 'may_capture')::boolean) from c1, jsonb_array_elements(intents) e
            where e ->> 'order_id' in ('cs_due', 'O-GONE')),
  '{"cs_due": true, "O-GONE": false}'::jsonb, 'an approval is captured by the job only inside its provider''s lifetime');
select is((select count(*)::int from public.payment_reconciliation_checks where workspace_id = pg_temp.u(101)), 0,
  'claiming stamps nothing: an attempt is stamped when it is read');

-- ── the lease and the run ──
create temp table c2 as select * from public.payment_reconciliation_claim_v1(300, current_setting('t.run')::timestamptz, 50);
select ok((select workspace_id from c2) is not null and (select workspace_id from c2) <> (select workspace_id from c1),
  'the next claim takes another business, never the leased one');
select is(public.payment_reconciliation_finish_v1(pg_temp.u(101), gen_random_uuid(), '{"read": 3}'),
  false, 'a result without the lease is refused');
select is(public.payment_reconciliation_finish_v1(pg_temp.u(101), (select lease_token from c1),
  jsonb_build_object('read', 3, 'settled', 1, 'ended', 'one', 'left', 0, 'abandoned', 1,
    'unreadable', jsonb_build_array(
      jsonb_build_object('intent', pg_temp.u(303), 'reason', 'unreachable', 'body', 'a provider payload'),
      jsonb_build_object('intent', pg_temp.u(302), 'reason', 'unreachable'),
      jsonb_build_object('intent', pg_temp.u(311), 'reason', 'unreachable'),
      jsonb_build_object('intent', pg_temp.u(307), 'reason', 'a sentence of the provider')),
    'read_items', jsonb_build_array(
      jsonb_build_object('intent', pg_temp.u(301)),
      jsonb_build_object('intent', pg_temp.u(303)),
      jsonb_build_object('intent', pg_temp.u(307), 'seen_state', 'CREATED', 'seen_client', 'a1b2c3d4e5f60718'),
      jsonb_build_object('intent', pg_temp.u(302), 'seen_state', 'CREATED')))),
  true, 'the lease''s holder records its run');
select is((select jsonb_build_array(read_count, settled_count, ended_count, left_count, abandoned_count, unreadable_count)
             from public.payment_reconciliation_runs where workspace_id = pg_temp.u(101)),
  '[3, 1, 0, 0, 1, 1]'::jsonb, 'with its counts, a malformed one recorded as 0');
select is((select malformed from public.payment_reconciliation_runs where workspace_id = pg_temp.u(101)),
  array['ended'], 'and named');
select is((select unreadable from public.payment_reconciliation_runs where workspace_id = pg_temp.u(101)),
  jsonb_build_array(jsonb_build_object('intent', pg_temp.u(303), 'reason', 'unreachable')),
  'only attempts this lease claimed, with a reason word: no payload, no unclaimed attempt, no other business, no free text');
select is((select array_agg(c.intent_id order by c.intent_id) from public.payment_reconciliation_checks c
            where c.workspace_id = pg_temp.u(101))::text,
  array[pg_temp.u(301), pg_temp.u(303), pg_temp.u(307)]::text, 'the attempts read are stamped, only those this lease claimed');
select is((select seen_state || ' ' || seen_client from public.payment_reconciliation_checks where intent_id = pg_temp.u(307)),
  'CREATED a1b2c3d4e5f60718', 'with what the provider last said of the order, and under which credentials');
select is((select checks from public.payment_reconciliation_checks where intent_id = pg_temp.u(307)), 1,
  'a read after the provider''s lifetime counts toward the backoff');
select is(public.payment_reconciliation_finish_v1(pg_temp.u(101), (select lease_token from c1), '{"read": 3}'),
  false, 'a replayed result is refused');
-- A new attempt of the finished business is due, and unread.
insert into public.payment_intents (id, workspace_id, member_id, provider, order_id, period, amount_cents, currency, reference, status, created_at)
values (pg_temp.u(308), pg_temp.u(101), pg_temp.u(201), 'stripe', 'cs_late_due', '2026-10', 1200, 'EUR', 'PAY-8', 'created', now() - interval '2 hours');
select is((select count(*)::int from public.payment_reconciliation_claim_v1(300, current_setting('t.run')::timestamptz, 50)),
  0, 'a business finished in this run is not claimed again in it, though an attempt of it is due');

-- ── the queue keeps moving ──
-- Only the queue's business is free; its lease was left unfinished.
update public.payment_reconciliation_state set lease_until = now() - interval '1 second'
 where workspace_id = pg_temp.u(103);
update public.payment_reconciliation_state set lease_token = gen_random_uuid(), lease_until = now() + interval '1 hour'
 where workspace_id = pg_temp.u(101);
select set_config('t.run2', (clock_timestamp() + interval '1 second')::text, true);
create temp table q1 as select * from public.payment_reconciliation_claim_v1(300, current_setting('t.run2')::timestamptz, 3)
  where workspace_id = pg_temp.u(103);
select is((select array_agg(e ->> 'order_id' order by ord) from q1, jsonb_array_elements(intents) with ordinality as x(e, ord)),
  array['cs_q1', 'cs_q2', 'cs_q3'], 'at most the limit, the oldest first');
select ok((select last_error = 'unfinished' and last_unfinished_at is not null from public.payment_reconciliation_state
            where workspace_id = pg_temp.u(103)), 'a lease left unfinished is traced when it is taken over');
-- The run stops at its budget after reading one.
select ok(public.payment_reconciliation_finish_v1(pg_temp.u(103), (select lease_token from q1),
  jsonb_build_object('read', 1, 'left', 1, 'read_items', jsonb_build_array(jsonb_build_object('intent', pg_temp.u(321))))),
  'a run stopped by its budget records what it read');
select set_config('t.run3', (clock_timestamp() + interval '2 seconds')::text, true);
create temp table q2 as select * from public.payment_reconciliation_claim_v1(300, current_setting('t.run3')::timestamptz, 3);
select is((select array_agg(e ->> 'order_id' order by ord) from q2, jsonb_array_elements(intents) with ordinality as x(e, ord)),
  array['cs_q2', 'cs_q3', 'cs_q4'], 'and the next run reads the ones it left, before the one it read');
-- A notification settles one of them meanwhile; the run reads all three.
update public.payment_intents set status = 'captured' where id = pg_temp.u(322);
select ok(public.payment_reconciliation_finish_v1(pg_temp.u(103), (select lease_token from q2),
  jsonb_build_object('read', 3, 'read_items', jsonb_build_array(
    jsonb_build_object('intent', pg_temp.u(322)), jsonb_build_object('intent', pg_temp.u(323)),
    jsonb_build_object('intent', pg_temp.u(324))))), 'the next run records them');
select is((select array_agg(c.intent_id order by c.intent_id) from public.payment_reconciliation_checks c
            where c.workspace_id = pg_temp.u(103))::text,
  array[pg_temp.u(321), pg_temp.u(323), pg_temp.u(324)]::text, 'the check of an attempt no longer open is removed');
select set_config('t.run4', (clock_timestamp() + interval '3 seconds')::text, true);
select is((select count(*)::int from public.payment_reconciliation_claim_v1(300, current_setting('t.run4')::timestamptz, 3)
            where workspace_id = pg_temp.u(103)),
  0, 'inside the lifetime an attempt read is read again only after half an hour');
select ok(public.payment_reconcile_backoff(0) = interval '30 minutes'
          and public.payment_reconcile_backoff(1) < public.payment_reconcile_backoff(3),
  'each read after the lifetime waits longer');
select ok(public.payment_reconcile_backoff(40) = interval '24 hours', 'at most a day');

-- ── the tick and retention ──
insert into public.payment_reconciliation_runs (workspace_id, started_at, finished_at, read_count, settled_count, ended_count, left_count, unreadable_count)
values (pg_temp.u(102), now() - interval '400 days', now() - public.payment_reconciliation_retention() - interval '1 day', 1, 0, 0, 1, 0),
       (pg_temp.u(102), now() - interval '2 days', now() - interval '2 days', 1, 0, 0, 1, 0);
select set_config('t.tick', public.payment_reconciliation_tick(), true);
select is((select last_tick_outcome from public.payment_reconciliation_schedule), current_setting('t.tick'),
  'the tick keeps its outcome, a missing secret among them');
select is((select count(*)::int from public.payment_reconciliation_runs where workspace_id = pg_temp.u(102)),
  1, 'the record past its retention goes, the young one stays');

-- ── who reads it ──
select ok(not has_table_privilege('anon', 'public.payment_reconciliation_runs', 'select')
          and not has_table_privilege('authenticated', 'public.payment_reconciliation_runs', 'select')
          and not has_table_privilege('authenticated', 'public.payment_reconciliation_state', 'select')
          and not has_table_privilege('authenticated', 'public.payment_reconciliation_checks', 'select')
          and not has_table_privilege('authenticated', 'public.payment_reconciliation_schedule', 'select')
          and not has_function_privilege('authenticated', 'public.payment_reconciliation_begin_v1()', 'execute')
          and not has_function_privilege('authenticated', 'public.payment_reconciliation_claim_v1(integer, timestamptz, integer)', 'execute')
          and not has_function_privilege('authenticated', 'public.payment_reconciliation_finish_v1(uuid, uuid, jsonb)', 'execute')
          and not has_function_privilege('authenticated', 'public.payment_reconciliation_tick()', 'execute'),
  'no client reads the record or runs the schedule');
select is((select count(*)::int from pg_class c
            where c.oid in ('public.payment_reconciliation_runs'::regclass, 'public.payment_reconciliation_state'::regclass,
                            'public.payment_reconciliation_checks'::regclass, 'public.payment_reconciliation_schedule'::regclass)
              and c.relrowsecurity
              and exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = c.relname
                             and p.policyname = 'mcp_delegated_deny')),
  4, 'row level security is on, with the deny rule for assistants, on all four');
select ok(exists (select 1 from pg_policy p where p.polrelid = 'public.payment_reconciliation_schedule'::regclass
                    and p.polname = 'personal_native_session' and not p.polpermissive and p.polcmd = '*'),
  'the schedule''s row, which names no business, is reached only by a native session');

-- ── a second settlement of the same order ──
do $both$
begin
  perform public.settle_online_payment('stripe', 'cs_due', 'pi_due', 1200);
  perform public.settle_online_payment('stripe', 'cs_due', 'pi_due', 1200);
end;
$both$;
select is((select count(*)::int from public.ledger_entries
            where workspace_id = pg_temp.u(101) and member_id = pg_temp.u(201)
              and period = '2026-10' and category = 'payment'),
  1, 'a second settlement of the same order credits nothing');

-- ── ended for want of an order, then a late notification ──
do $late$
begin
  -- the reconciliation ends it: no order was ever known
  perform public.mark_payment_failed('paypal', 'pending:304');
  -- the late notification attaches the order it names: the statement
  -- attachOrder (_shared/provisional_intent.ts, #3917) runs, with no status
  -- filter, then the settlement it makes
  update public.payment_intents set order_id = 'O-LATE'
   where id = pg_temp.u(304) and order_id like 'pending:%';
  perform public.settle_online_payment('paypal', 'O-LATE', 'CAP-LATE', 1400);
  perform public.settle_online_payment('paypal', 'O-LATE', 'CAP-LATE', 1400);
end;
$late$;
select is((select status from public.payment_intents where id = pg_temp.u(304)), 'captured',
  'an attempt ended for want of an order is still settled by a late notification');
select is((select count(*)::int from public.ledger_entries
            where workspace_id = pg_temp.u(101) and member_id = pg_temp.u(201)
              and period = '2026-11' and category = 'payment'),
  1, 'and credited once');

select * from finish();
rollback;
