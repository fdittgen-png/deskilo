-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3504 / 0700: a Mollie settlement records its payout and the costs Mollie
-- kept, once; the costs are one fact per settlement, period and method (no
-- fee per payment); a second report must say the same; a member reads them
-- only with the finance right. Rolled back.
begin;
select plan(8);

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
select is((public.record_provider_settlement_v1(current_setting('deskilo.test.ws')::uuid, 'mollie', 'stl_1', 34000, 'EUR',
  date '2026-03-15', 'paid',
  '[{"period":"2026-03","method":"ideal","description":"iDEAL","cost_count":3,"amount_net_cents":120}]'::jsonb) ->> 'costs_added')::int,
  0, 'the same report again adds nothing');
select throws_ok($$select public.record_provider_settlement_v1(current_setting('deskilo.test.ws')::uuid, 'mollie', 'stl_1', 34000, 'EUR',
  date '2026-03-15', 'paid', '[{"period":"2026-03","method":"ideal","description":"iDEAL","cost_count":3,"amount_net_cents":999}]'::jsonb)$$,
  'P0001', 'the provider reported other costs for this settlement', 'other costs for a recorded settlement are refused');
select is((select count(*)::int from public.provider_settlement_costs where settlement_id = 'stl_1'), 2, 'nothing was added by the refused report');
select ok(not has_function_privilege('authenticated', 'public.record_provider_settlement_v1(uuid, text, text, bigint, text, date, text, jsonb)', 'execute'),
  'a member cannot call the recorder');

select * from finish();
rollback;
