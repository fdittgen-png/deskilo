-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3905 (0757): a payment the provider reverses is recorded on its online
-- payment, once, and only when it was captured; a capture event of a reversed
-- payment credits nothing. Rolled back.
begin;
select plan(9);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00003905' || lpad(n::text, 4, '0'))::uuid;
$$;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values (pg_temp.u(1), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
        'reversal@example.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by)
values (pg_temp.u(101), 'Reversals', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1));
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active');
insert into public.payment_intents (workspace_id, member_id, provider, order_id, period, amount_cents, currency, status)
values (pg_temp.u(101), pg_temp.u(201), 'stripe', 'rev-captured', '2026-11', 1200, 'EUR', 'created'),
       (pg_temp.u(101), pg_temp.u(201), 'stripe', 'rev-created', '2026-11', 900, 'EUR', 'created');
-- The first payment is captured the way the provider's event captures it,
-- and the provider's fee is recorded.
select public.settle_online_payment('stripe', 'rev-captured', 'cap-1', 1200);
update public.payment_intents set provider_fee_cents = 50, provider_fee_currency = 'EUR'
 where provider = 'stripe' and order_id = 'rev-captured';
create function pg_temp.postings() returns jsonb language sql as $$
  select public.provider_settlement_postings(pg_temp.u(101), null, current_date - 30, current_date + 30,
    'FR', 'Europe/Paris', 'EUR');
$$;
select set_config('t.before', pg_temp.postings()::text, true);

create function pg_temp.state(p_order text) returns text language sql as $$
  select status || ' ' || coalesce(reversal_reason, '-') from public.payment_intents
   where provider = 'stripe' and order_id = p_order;
$$;

select is(public.mark_payment_reversed('stripe', 'rev-captured', 'charge.dispute.created'), 'reversed',
  'the provider''s report answers the payment''s state');
select is(pg_temp.state('rev-captured'), 'reversed charge.dispute.created',
  'a captured payment the provider reverses is recorded as reversed, with why');
select ok(current_setting('t.before') <> '[]' and pg_temp.postings()::text = current_setting('t.before'),
  'the postings of a reversed payment are the ones of its capture: a past period never changes');
select set_config('t.at', (select reversed_at::text from public.payment_intents where order_id = 'rev-captured'), true);
select public.mark_payment_reversed('stripe', 'rev-captured', 'charge.refunded');
select is(pg_temp.state('rev-captured') || ' ' || (select (reversed_at::text = current_setting('t.at'))::text
            from public.payment_intents where order_id = 'rev-captured'),
  'reversed charge.dispute.created true', 'a second report changes nothing');
select is(public.mark_payment_reversed('stripe', 'rev-created', 'charge.refunded'), 'created',
  'a reversal reported before the capture answers "created", so the provider asks again');
select is(pg_temp.state('rev-created'), 'created -', 'a payment that was not captured is never marked reversed');

select is((select count(*)::int from public.ledger_entries where workspace_id = pg_temp.u(101)), 1,
  'the capture credited the member once');
select public.settle_online_payment('stripe', 'rev-captured', 'cap-1', 1200);
select is((select count(*)::int from public.ledger_entries where workspace_id = pg_temp.u(101)), 1,
  'a capture event of a reversed payment credits nothing');

select ok(not has_function_privilege('anon', 'public.mark_payment_reversed(text, text, text)', 'execute')
      and not has_function_privilege('authenticated', 'public.mark_payment_reversed(text, text, text)', 'execute'),
  'only the server records a reversal');

select * from finish();
rollback;
