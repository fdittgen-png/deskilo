-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3504 / 0700: a Mollie settlement records its payout and the costs Mollie
-- kept, once; the costs are one fact per settlement, period and method (no
-- fee per payment); a second report must say the same; a member reads them
-- only with the finance right.
-- #3510 / 0720: the settlement is compared as a whole -- an omitted, added
-- or changed cost, another amount, or a cost in another currency is refused
-- and kept for review, and nothing of it is recorded. Rolled back.
begin;
select plan(22);

do $seed$
declare u uuid := '00000000-0000-4000-8000-0000000037a1'; plain uuid := '00000000-0000-4000-8000-0000000037a2'; ws uuid; m uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner@settle.test', '', now(), now(), now()),
         (plain, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'plain@settle.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by) values ('Settle', 'FR', 'EUR', 'Europe/Paris', u) returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin) values (ws, u, true, true) returning id into m;
  insert into public.members (workspace_id, user_id, is_owner, is_admin) values (ws, plain, false, false);
  perform set_config('deskilo.test.ws', ws::text, false);
end;
$seed$;

select is((public.record_provider_settlement_v1(current_setting('deskilo.test.ws')::uuid, 'mollie', 'stl_1', 34000, 'eur',
  date '2026-03-15', 'paid',
  '[{"period":"2026-03","method":"ideal","description":"iDEAL","cost_count":3,"amount_net_cents":120},
    {"period":"2026-03","method":"creditcard","description":"Credit card","cost_count":1,"amount_net_cents":55}]'::jsonb) ->> 'costs_added')::int,
  2, 'a settlement records its two cost lines');
select is((select amount_cents::int from public.provider_payouts where payout_id = 'stl_1'), 34000, 'and its payout, which carries no payment of ours');
select is((select (arrival_date::text || status) from public.provider_payouts where payout_id = 'stl_1'), '2026-03-15paid', 'paid, on its arrival day');
select is((select sum(amount_net_cents)::int from public.provider_settlement_costs), 175, 'the costs are kept as reported, per period and method');
create or replace function pg_temp.report(p_id text, p_amount bigint, p_costs text) returns jsonb language sql as $f$
  select public.record_provider_settlement_v1(current_setting('deskilo.test.ws')::uuid, 'mollie', p_id, p_amount, 'EUR',
    date '2026-03-15', 'paid', p_costs::jsonb)
$f$;
create or replace function pg_temp.reviews(p_id text) returns text language sql as $f$
  select coalesce(string_agg(reason, ',' order by reason), '') from public.provider_settlement_reviews
   where settlement_id = p_id
$f$;
select set_config('t.both', '[{"period":"2026-03","method":"creditcard","description":"Credit card","cost_count":1,"amount_net_cents":55},
  {"period":"2026-03","method":"ideal","description":"iDEAL","cost_count":3,"amount_net_cents":120}]', false);
select is(pg_temp.report('stl_1', 34000, current_setting('t.both')) ->> 'outcome', 'unchanged',
  'the same report again, in any order, is unchanged');
select is((pg_temp.report('stl_1', 34000, current_setting('t.both')) ->> 'costs_added')::int, 0, 'and adds nothing');
select is(pg_temp.report('stl_1', 34000,
  '[{"period":"2026-03","method":"ideal","description":"iDEAL","cost_count":3,"amount_net_cents":120}]') ->> 'reason',
  'costs_changed', 'a report that omits a cost is a changed settlement');
select is(pg_temp.report('stl_1', 34000, '[{"period":"2026-03","method":"creditcard","description":"Credit card","cost_count":1,"amount_net_cents":55},
  {"period":"2026-03","method":"ideal","description":"iDEAL","cost_count":3,"amount_net_cents":120},
  {"period":"2026-03","method":"paypal","description":"PayPal","cost_count":1,"amount_net_cents":30}]') ->> 'outcome',
  'refused', 'a report that adds a cost is refused');
select is(pg_temp.report('stl_1', 34000, '[{"period":"2026-03","method":"creditcard","description":"Credit card","cost_count":1,"amount_net_cents":55},
  {"period":"2026-03","method":"ideal","description":"iDEAL","cost_count":3,"amount_net_cents":999}]') ->> 'outcome',
  'refused', 'a report that changes a cost is refused');
select is(pg_temp.report('stl_1', 35000, current_setting('t.both')) ->> 'reason', 'amount_changed',
  'a report with another amount is refused');
select is((select count(*)::int || '|' || sum(amount_net_cents)::int from public.provider_settlement_costs where settlement_id = 'stl_1'),
  '2|175', 'nothing of a refused report was recorded');
select is((select amount_cents::int from public.provider_payouts where payout_id = 'stl_1'), 34000, 'nor its amount');
select is(pg_temp.reviews('stl_1'), 'amount_changed,costs_changed', 'each refusal is kept for review, once per reason');
select is((select (reported -> 'costs' -> 1 ->> 'amount_net_cents') from public.provider_settlement_reviews
            where settlement_id = 'stl_1' and reason = 'costs_changed'), '999', 'with the latest report it refused');
select is(pg_temp.report('stl_2', 10000, '[{"period":"2026-03","method":"ideal","description":"iDEAL","cost_count":1,"amount_net_cents":29,"currency":"USD"}]') ->> 'reason',
  'currency_mismatch', 'a cost in another currency than its settlement is refused, never relabelled');
select is((select count(*)::int from public.provider_payouts where payout_id = 'stl_2'), 0, 'and records no payout');
select is(pg_temp.report('stl_3', 10000, '[{"period":"2026-03","method":"ideal","description":"iDEAL","cost_count":1,"amount_net_cents":29,"currency":"eur"}]') ->> 'outcome',
  'new', 'a cost that names the settlement''s own currency is recorded');
select set_config('t.twice', '[{"period":"2026-03","method":"ideal","description":"iDEAL","cost_count":2,"amount_net_cents":58},
  {"period":"2026-03","method":"ideal","description":"iDEAL","cost_count":1,"amount_net_cents":35}]', false);
select is(pg_temp.report('stl_4', 20000, current_setting('t.twice')) ->> 'outcome', 'new',
  'two lines of the same cost (two rates in one month) are recorded');
select is((select count(*)::int || '|' || sum(cost_count)::int || '|' || sum(amount_net_cents)::int
             from public.provider_settlement_costs where settlement_id = 'stl_4'),
  '1|3|93', 'once, with their counts and nets summed');
select is(pg_temp.report('stl_4', 20000, current_setting('t.twice')) ->> 'outcome', 'unchanged',
  'and the same report again is unchanged');
select ok(not has_function_privilege('authenticated', 'public.record_provider_settlement_v1(uuid, text, text, bigint, text, date, text, jsonb)', 'execute'),
  'a member cannot call the recorder');
select ok(not has_table_privilege('authenticated', 'public.provider_settlement_reviews', 'insert'),
  'nor write a review');

select * from finish();
rollback;
