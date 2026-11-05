-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2380 item 4 (0687) — a provider's fee, net and payout are recorded as
-- facts: once, reconciled, and readable only to whoever may see the books.
--
-- The issue's Stripe fixture: three payments of 120.00, each 3.78 fee and
-- 116.22 net, carried to the bank by one payout of 348.66.
begin;
select plan(12);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u uuid := '00000000-0000-4000-8000-0000000003c1';
  plain uuid := '00000000-0000-4000-8000-0000000003c2';
  ws uuid; m uuid; mp uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'payouts@deskilo.test', '', now(), now(), now()),
         (plain, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'payouts-member@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Payouts', 'FR', 'EUR', 'Europe/Paris', u) returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin) values (ws, u, true, true) returning id into m;
  insert into public.members (workspace_id, user_id, is_owner, is_admin) values (ws, plain, false, false) returning id into mp;
  insert into public.payment_intents (workspace_id, member_id, provider, order_id, period, amount_cents, currency)
  values (ws, m, 'stripe', 'cs_A', '2026-10', 12000, 'EUR'),
         (ws, m, 'stripe', 'cs_B', '2026-10', 12000, 'EUR'),
         (ws, m, 'stripe', 'cs_C', '2026-10', 12000, 'EUR'),
         (ws, mp, 'stripe', 'cs_D', '2026-10', 12000, 'EUR');
  perform set_config('deskilo.test.ws', ws::text, false);
  perform set_config('deskilo.test.u', u::text, false);
  perform set_config('deskilo.test.plain', plain::text, false);
end;
$seed$;
select pg_temp.seed();

select public.record_provider_fee_v1('stripe', o, 378, 11622, 'eur', 'txn_' || o)
  from unnest(array['cs_A', 'cs_B', 'cs_C']) o;

select ok(
  (select provider_fee_cents = 378 and provider_net_cents = 11622 and provider_fee_currency = 'EUR'
          and provider_transaction_id = 'txn_cs_A'
     from public.payment_intents where order_id = 'cs_A'),
  'a payment keeps the fee and net the provider reported, and its transaction');

select lives_ok($$select public.record_provider_fee_v1('stripe', 'cs_A', 378, 11622, 'EUR', 'txn_cs_A')$$,
  'the same report again changes nothing');

select throws_ok($$select public.record_provider_fee_v1('stripe', 'cs_A', 400, 11600, 'EUR', 'txn_cs_A')$$,
  'the provider reported another fee for this payment',
  'another fee for a payment already reported is refused');

select throws_ok($$select public.record_provider_fee_v1('stripe', 'cs_D', 378, 11600, 'EUR', 'txn_cs_D')$$,
  'the provider''s net and fee do not add up to the payment',
  'a fee and net that do not add up to the payment are refused');

create temp table p1 as select public.record_provider_payout_v1(
  current_setting('deskilo.test.ws')::uuid, 'stripe', 'po_1', 34866, 'eur', null, 'in_transit',
  array['txn_cs_A', 'txn_cs_B', 'txn_cs_C']) as r;

select is((select (r ->> 'payments')::int from p1), 3, 'the payout carries the three payments it names');
select ok((select (r ->> 'reconciled')::boolean and (r ->> 'net_cents')::bigint = 34866 from p1),
  'their nets add up to the payout: 3 × 116.22 = 348.66');

select is(
  (select public.record_provider_payout_v1(current_setting('deskilo.test.ws')::uuid, 'stripe', 'po_1', 34866,
            'EUR', '2026-10-20', 'paid', array['txn_cs_A', 'txn_cs_B', 'txn_cs_C']) ->> 'payments')::int,
  3, 'the payout reported paid keeps its payments');
select ok((select status = 'paid' and arrival_date = '2026-10-20' from public.provider_payouts where payout_id = 'po_1'),
  'and moves to paid on its arrival date');

select throws_ok(
  format($$select public.record_provider_payout_v1(%L, 'stripe', 'po_1', 30000, 'EUR', null, 'paid', '{}')$$,
         current_setting('deskilo.test.ws')),
  'the provider reported this payout with another amount',
  'a payout reported with another amount is refused');

select throws_ok(
  format($$select public.record_provider_payout_v1(%L, 'stripe', 'po_2', 11622, 'EUR', null, 'paid', array['txn_cs_A'])$$,
         current_setting('deskilo.test.ws')),
  'a payment of this payout is carried by another one',
  'a payment carried by one payout is not taken by another');

select ok(not has_function_privilege('authenticated', 'public.record_provider_fee_v1(text, text, bigint, bigint, text, text)', 'execute')
      and not has_function_privilege('authenticated', 'public.record_provider_payout_v1(uuid, text, text, bigint, text, date, text, text[])', 'execute'),
  'only the server records provider facts');

-- The owner reads the payout; a member without the finances reads none.
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('deskilo.test.plain'), 'role', 'authenticated')::text, true);
set local role authenticated;
create temp table seen_plain as select count(*)::int as n from public.provider_payouts;
reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('deskilo.test.u'), 'role', 'authenticated')::text, true);
set local role authenticated;
create temp table seen_owner as select count(*)::int as n from public.provider_payouts;
reset role;
select ok((select n from seen_owner) = 1 and (select n from seen_plain) = 0,
  'the books'' reader sees the payout, a member without the finances does not');

select * from finish();
rollback;
