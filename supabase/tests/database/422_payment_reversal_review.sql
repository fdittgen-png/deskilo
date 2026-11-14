-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3925 (0763): a reversed payment waits until a person who sees the
-- finances marks it looked at; a plain member cannot, nor anyone for a
-- payment that was not reversed; the member's own history lists the reversed
-- payment. Rolled back.
begin;
select plan(10);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00003925' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.act_as(p uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
end $$;
grant execute on all functions in schema pg_temp to authenticated;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'review' || n || '@example.test', '', now(), now(), now()
  from unnest(array[1, 2]) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by)
values (pg_temp.u(101), 'Reviews', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1));
-- 1 the owner, 2 a plain member whose payment the provider reverses
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
       (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active');
insert into public.payment_intents (workspace_id, member_id, provider, order_id, period, amount_cents, currency, status)
values (pg_temp.u(101), pg_temp.u(202), 'stripe', 'rv-1', '2026-11', 1200, 'EUR', 'created'),
       (pg_temp.u(101), pg_temp.u(202), 'stripe', 'rv-2', '2026-11', 900, 'EUR', 'created');
select public.settle_online_payment('stripe', 'rv-1', 'cap-1', 1200);
select public.mark_payment_reversed('stripe', 'rv-1', 'charge.dispute.created 12.00 EUR');
create function pg_temp.id(p_order text) returns uuid language sql as $$
  select id from public.payment_intents where order_id = p_order;
$$;
grant execute on all functions in schema pg_temp to authenticated;

select is((select reversal_reviewed_at from public.payment_intents where order_id = 'rv-1'), null,
  'a reversed payment waits to be looked at');

-- the member's own history
select pg_temp.act_as(pg_temp.u(2));
set local role authenticated;
select ok(exists (select 1 from jsonb_array_elements(public.my_financial_activity('payments')) e
                  where e ->> 'status' = 'reversed'),
  'the member''s own payments list the reversed one');
select throws_ok(format('select public.review_payment_reversal_v1(%L)', pg_temp.id('rv-1')), '42501', null,
  'a plain member does not mark a reversal looked at');
reset role;

-- a person who sees the finances
select pg_temp.act_as(pg_temp.u(1));
set local role authenticated;
select throws_ok(format('select public.review_payment_reversal_v1(%L)', pg_temp.id('rv-2')), '22023', null,
  'a payment that was not reversed is not reviewed');
select throws_ok('select public.review_payment_reversal_v1(gen_random_uuid())', '22023', null,
  'an unknown payment is refused');
select ok(public.review_payment_reversal_v1(pg_temp.id('rv-1')) is not null,
  'the owner marks the reversal looked at');
reset role;
select ok((select reversal_reviewed_at from public.payment_intents where order_id = 'rv-1') is not null,
  'and it no longer waits');
select set_config('t.at', (select reversal_reviewed_at::text from public.payment_intents where order_id = 'rv-1'), true);
select pg_temp.act_as(pg_temp.u(1));
set local role authenticated;
select is(public.review_payment_reversal_v1(pg_temp.id('rv-1'))::text, current_setting('t.at'),
  'marking it again keeps the first time');
reset role;

select ok(not has_function_privilege('anon', 'public.review_payment_reversal_v1(uuid)', 'execute'),
  'anon reviews nothing');
select is((select status from public.payment_intents where order_id = 'rv-1'), 'reversed',
  'looking at a reversal changes nothing of the payment''s state');

select * from finish();
rollback;
