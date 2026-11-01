-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2521 (0640): a functionality that is switched off is refused by the
-- server, not only hidden by the app. With the feature on, the owner's writes
-- behind /billing, /payment-methods and the expense repartition go through
-- (positive controls); with it off, the RPCs refuse with 55000, direct writes
-- are refused by the restrictive policies or the column trigger, and the
-- configuration can still be read.
begin;
select plan(16);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', case when p_user is null then '' else
    jsonb_build_object('sub', p_user, 'role', 'authenticated')::text end, true);
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- One owner and one workspace, seeded before any role switch.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values ('00000000-0000-4000-8000-0000002521a1', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'owner@server-gates.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by) values
 ('00000000-0000-4000-8000-0000002521b1', 'Gates', 'FR', 'EUR', 'Europe/Paris',
  '00000000-0000-4000-8000-0000002521a1');
insert into public.members (workspace_id, user_id, is_owner, is_admin, status) values
 ('00000000-0000-4000-8000-0000002521b1', '00000000-0000-4000-8000-0000002521a1', true, true, 'active');
update public.workspaces
   set feature_flags = coalesce(feature_flags, '{}'::jsonb)
       || '{"moneyTab": true, "invoicing": true, "expenseRepartition": true, "carnets": true}'
 where id = '00000000-0000-4000-8000-0000002521b1';

select ok(public.feature_effective('00000000-0000-4000-8000-0000002521b1', 'moneyTab')
          and public.feature_effective('00000000-0000-4000-8000-0000002521b1', 'expenseRepartition')
          and public.feature_effective('00000000-0000-4000-8000-0000002521b1', 'carnets'),
  'fixture: money, expense repartition and carnets are on');

-- ── features on: the owner's writes go through ─────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000002521a1');
set local role authenticated;
select lives_ok($$select public.replace_fee_bands('00000000-0000-4000-8000-0000002521b1',
    '[{"from_pct":0,"to_pct":100,"fee_cents":1000,"overage_fee_cents":0}]')$$,
  'on: the fee bands are replaced');
select lives_ok($$select public.set_repartition_rule('00000000-0000-4000-8000-0000002521b1', '{"method":"equal"}')$$,
  'on: the repartition rule is saved');
select lives_ok($$update public.workspaces set payment_instructions = coalesce(payment_instructions, '{}'::jsonb) || '{"bank_name":"Gates bank"}'
                  where id = '00000000-0000-4000-8000-0000002521b1'$$,
  'on: the payment instructions are saved directly');
select lives_ok($$insert into public.packages (workspace_id, name, days, price_cents) values ('00000000-0000-4000-8000-0000002521b1', 'Ten days', 10, 15000)$$,
  'on: a pack is added directly');
select lives_ok($$insert into public.credit_products (workspace_id, name, half_days) values ('00000000-0000-4000-8000-0000002521b1', 'Carnet', 10)$$,
  'on: a carnet is added directly');
reset role;

-- ── features off ───────────────────────────────────────────────────────
update public.workspaces
   set feature_flags = feature_flags || '{"moneyTab": false, "expenseRepartition": false, "carnets": false}'
 where id = '00000000-0000-4000-8000-0000002521b1';
select pg_temp.act_as('00000000-0000-4000-8000-0000002521a1');
set local role authenticated;
select throws_ok($$select public.replace_fee_bands('00000000-0000-4000-8000-0000002521b1',
    '[{"from_pct":0,"to_pct":100,"fee_cents":1,"overage_fee_cents":0}]')$$,
  '55000', null, 'off: replace_fee_bands is refused');
select throws_ok($$select public.set_repartition_rule('00000000-0000-4000-8000-0000002521b1', '{"method":"equal"}')$$,
  '55000', null, 'off: set_repartition_rule is refused');
select throws_ok($$select public.distribute_expense('00000000-0000-4000-8000-0000002521b1', 'Heating', 1000, 'equal', '2026-10',
    '[{"member_id":"00000000-0000-0000-0000-000000000000","amount_cents":1000}]')$$,
  '55000', null, 'off: distribute_expense is refused before its arguments are read');
select throws_ok($$update public.workspaces set payment_instructions = payment_instructions || '{"bank_name":"Other"}'
                  where id = '00000000-0000-4000-8000-0000002521b1'$$,
  '55000', null, 'off: the owner cannot change the payment instructions directly');
select lives_ok($$update public.workspaces set subscription_levels = subscription_levels
                  where id = '00000000-0000-4000-8000-0000002521b1'$$,
  'off: an update that changes no money column is not refused');
select throws_ok($$insert into public.packages (workspace_id, name, days, price_cents) values ('00000000-0000-4000-8000-0000002521b1', 'Five days', 5, 8000)$$,
  '42501', null, 'off: a pack cannot be added directly');
select throws_ok($$insert into public.credit_products (workspace_id, name, half_days) values ('00000000-0000-4000-8000-0000002521b1', 'Carnet 2', 20)$$,
  '42501', null, 'off: a carnet cannot be added directly');
select lives_ok($$delete from public.fee_bands where workspace_id = '00000000-0000-4000-8000-0000002521b1'$$,
  'off: a direct delete of the fee bands is not an error (the policy filters it)');
reset role;
select is((select count(*)::int from public.fee_bands where workspace_id = '00000000-0000-4000-8000-0000002521b1'), 1,
  'off: a direct delete removes no fee band');
select pg_temp.act_as('00000000-0000-4000-8000-0000002521a1');
set local role authenticated;
select is((select count(*)::int from public.packages where workspace_id = '00000000-0000-4000-8000-0000002521b1' and name = 'Ten days'), 1,
  'off: the configuration can still be read');
reset role;

select * from finish();
rollback;
