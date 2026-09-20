-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1226/#1229/#1231 — the two money guards nothing had ever executed.
--
-- Both live in SQL because that is the only place a client cannot skip
-- them, and both had been reasoned about rather than run:
--
--   * `invoices_immutable()` — an issued invoice is an archive document.
--     It may be VOIDED (which writes a new fact beside it) and it may be
--     marked settled; it may not be edited, and it may not be deleted.
--   * the webhook idempotency guard in `settle_online_payment` —
--     `if v_intent.status = 'captured' then return; end if;` under a
--     `for update`. PSPs retry. A retry that credits twice is money
--     invented, and Deno is not in CI, so this function had never run
--     anywhere but production.
begin;
select plan(7);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u uuid := '00000000-0000-4000-8000-0000000000cc';
  ws uuid; m uuid; inv uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'money@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Money', 'FR', 'EUR', 'Europe/Paris', u) returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u, true, true) returning id into m;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number,
                               title, lines, total_cents, currency, member_name,
                               workspace_name, issuer_name, signature)
  values (ws, m, m, 'INV-1', 'September', '[]'::jsonb, 5000, 'EUR', 'Member',
          'Money', 'Member', 'sig') returning id into inv;
  perform set_config('deskilo.test.ws', ws::text, false);
  perform set_config('deskilo.test.m', m::text, false);
  perform set_config('deskilo.test.inv', inv::text, false);
  perform set_config('request.jwt.claims',
    json_build_object('sub', u::text, 'role', 'authenticated')::text, false);
end;
$seed$;

select pg_temp.seed();

-- ------------------------------------------------ an invoice is a fact
select throws_ok(
  format($$ update public.invoices set total_cents = 1 where id = %L $$,
         current_setting('deskilo.test.inv')),
  'invoices are immutable',
  'the total of an issued invoice cannot be edited');

select throws_ok(
  format($$ update public.invoices set member_name = 'someone else' where id = %L $$,
         current_setting('deskilo.test.inv')),
  'invoices are immutable',
  'nor the name it was issued to');

select throws_ok(
  format($$ delete from public.invoices where id = %L $$,
         current_setting('deskilo.test.inv')),
  'invoices are immutable',
  'and it cannot be deleted — voiding is the only way back');

select lives_ok(
  format($$ update public.invoices set voided_at = now() where id = %L $$,
         current_setting('deskilo.test.inv')),
  'voiding IS allowed: it writes a new fact rather than changing an old one');

-- ------------------------------------------- a webhook may be retried
create or replace function pg_temp.pay() returns void language plpgsql as $pay$
declare v_id uuid; v_order text;
begin
  select id into v_id from public.open_payment_intent(
    current_setting('deskilo.test.ws')::uuid,
    current_setting('deskilo.test.m')::uuid,
    'paypal', '2026-09', 5000, 'EUR');
  select order_id into v_order from public.payment_intents where id = v_id;
  perform set_config('deskilo.test.order', v_order, false);
end;
$pay$;

select pg_temp.pay();

select lives_ok(
  $$ select public.settle_online_payment('paypal',
       current_setting('deskilo.test.order'), 'capture-1', 5000) $$,
  'the first webhook settles the intent');

select lives_ok(
  $$ select public.settle_online_payment('paypal',
       current_setting('deskilo.test.order'), 'capture-1', 5000) $$,
  'the retry is accepted rather than refused — a PSP will not stop');

select is(
  (select count(*) from public.ledger_entries
    where workspace_id = current_setting('deskilo.test.ws')::uuid
      and category = 'payment')::int,
  1,
  'but it credits the ledger exactly once: the retry invents no money');

select * from finish();
rollback;
