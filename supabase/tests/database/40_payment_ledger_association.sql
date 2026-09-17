-- SPDX-License-Identifier: 0BSD
--
-- #1452 — a captured payment names the credit it posted, and one credit
-- settles one payment.
--
-- Before 0240 any credit with the same member, amount and period "proved"
-- a capture, so two equal payments with one posting reconciled clean.
-- Each rule here is asserted clean and then broken.
begin;
select plan(9);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u uuid := '00000000-0000-4000-8000-000000001452';
  v uuid := '00000000-0000-4000-8000-000000001453';
  ws uuid; m uuid; other uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'assoc@deskilo.test', '', now(), now(), now()),
         (v, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'assoc-other@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Assoc', 'FR', 'EUR', 'Europe/Paris', u) returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u, true, true) returning id into m;
  insert into public.members (workspace_id, user_id) values (ws, v) returning id into other;
  perform set_config('deskilo.assoc.ws', ws::text, false);
  perform set_config('deskilo.assoc.m', m::text, false);
  perform set_config('deskilo.assoc.other', other::text, false);
  perform set_config('request.jwt.claims',
    json_build_object('sub', u::text, 'role', 'authenticated')::text, false);
end;
$seed$;

select pg_temp.seed();

create or replace function pg_temp.findings() returns text[] language sql as $$
  select coalesce(array_agg(r."check" order by r."check"), '{}')
    from public.reconcile_workspace(current_setting('deskilo.assoc.ws')::uuid) r;
$$;

-- Two equal payments in one month, each settled twice (a webhook retry).
do $pay$
declare v_id uuid; v_order text;
begin
  for i in 1..2 loop
    select id into v_id from public.open_payment_intent(
      current_setting('deskilo.assoc.ws')::uuid, current_setting('deskilo.assoc.m')::uuid,
      'stripe', '2026-10', 2500, 'EUR');
    select order_id into v_order from public.payment_intents where id = v_id;
    perform public.settle_online_payment('stripe', v_order, 'cap-' || i, 2500);
    perform public.settle_online_payment('stripe', v_order, 'cap-' || i, 2500);
    perform set_config('deskilo.assoc.i' || i, v_id::text, false);
  end loop;
end;
$pay$;

select is(
  (select count(distinct ledger_entry_id)::int from public.payment_intents
    where workspace_id = current_setting('deskilo.assoc.ws')::uuid and status = 'captured'),
  2, 'two equal captured payments name two distinct postings');

select is(
  (select count(*)::int from public.ledger_entries
    where workspace_id = current_setting('deskilo.assoc.ws')::uuid and category = 'payment'),
  2, 'and retries posted nothing more');

select is(pg_temp.findings(), '{}'::text[], 'and they reconcile clean');

select throws_like(
  $$ update public.payment_intents
        set ledger_entry_id = (select ledger_entry_id from public.payment_intents
                                where id = current_setting('deskilo.assoc.i1')::uuid)
      where id = current_setting('deskilo.assoc.i2')::uuid $$,
  '%payment_intents_ledger_entry_once%',
  'one posting cannot settle two payments');

select throws_ok(
  $$ with l as (
       insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
       values (current_setting('deskilo.assoc.ws')::uuid, current_setting('deskilo.assoc.other')::uuid,
               'credit', 'payment', 2500, 'someone else', '2026-10') returning id)
     update public.payment_intents set ledger_entry_id = (select id from l)
      where id = current_setting('deskilo.assoc.i2')::uuid $$,
  'a payment intent is associated only with its own payment credit (same workspace, member and amount)',
  'a payment cannot name another member''s credit, even from a privileged writer');

select throws_ok(
  $$ with l as (
       insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
       values (current_setting('deskilo.assoc.ws')::uuid, current_setting('deskilo.assoc.m')::uuid,
               'credit', 'payment', 9900, 'wrong amount', '2026-10') returning id)
     update public.payment_intents set ledger_entry_id = (select id from l)
      where id = current_setting('deskilo.assoc.i2')::uuid $$,
  'a payment intent is associated only with its own payment credit (same workspace, member and amount)',
  'nor a credit of another amount');

-- Break it: the second capture loses its association — exactly the state
-- in which the old rule still found "a" matching credit (the first one).
update public.payment_intents set ledger_entry_id = null
 where id = current_setting('deskilo.assoc.i2')::uuid;

select ok('captured_payment_uncredited' = any(pg_temp.findings()),
  'a captured payment with no associated credit is reported, although an equal credit exists');

select ok(
  (select bool_or(r.detail like '%no ledger credit is associated%')
     from public.reconcile_workspace(current_setting('deskilo.assoc.ws')::uuid) r
    where r.subject = current_setting('deskilo.assoc.i2')::uuid),
  'and the finding says the association is missing');

select is(
  (select count(*)::int from public.reconcile_workspace(current_setting('deskilo.assoc.ws')::uuid) r
    where r.subject = current_setting('deskilo.assoc.i1')::uuid),
  0, 'while the payment that kept its posting stays clean');

select * from finish();
rollback;
