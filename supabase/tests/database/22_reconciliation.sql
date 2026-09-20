-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1230 — the reconciliation, proved to be clean AND proved to bite.
--
-- A reconciliation that only ever returns no rows is indistinguishable
-- from a reconciliation that does not look. So each rule is asserted
-- twice: once on a workspace that is right, and once after breaking
-- exactly the thing the rule is about.
--
-- #1231 rides along: **duplicate payment** and **webhook retry** are the
-- two money scenarios that could never be tested against a Dart fake,
-- because the guard is a `for update` inside a plpgsql function.
begin;
select plan(8);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u uuid := '00000000-0000-4000-8000-0000000000e0';
  ws uuid; m uuid; inv uuid; credit uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'recon@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Recon', 'FR', 'EUR', 'Europe/Paris', u) returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u, true, true) returning id into m;

  insert into public.invoices (workspace_id, member_id, issuer_member_id, number,
                               title, lines, total_cents, currency, member_name,
                               workspace_name, issuer_name, signature)
  values (ws, m, m, 'R-1', 'September', '[]'::jsonb, 5000, 'EUR', 'Member',
          'Recon', 'Member', 'sig') returning id into inv;

  insert into public.ledger_entries (workspace_id, member_id, kind, category,
                                     amount_cents, description, period)
  values (ws, m, 'credit', 'payment', 5000, 'bank transfer', '2026-09')
  returning id into credit;
  insert into public.invoice_matches (workspace_id, invoice_id, paid_cents,
                                      resolution, credit_ledger_id)
  values (ws, inv, 5000, 'exact', credit);

  perform set_config('deskilo.recon.ws', ws::text, false);
  perform set_config('deskilo.recon.m', m::text, false);
  perform set_config('deskilo.recon.inv', inv::text, false);
  perform set_config('deskilo.recon.credit', credit::text, false);
  perform set_config('request.jwt.claims',
    json_build_object('sub', u::text, 'role', 'authenticated')::text, false);
end;
$seed$;

select pg_temp.seed();

create or replace function pg_temp.findings() returns text[] language sql as $$
  select coalesce(array_agg(r."check" order by r."check"), '{}')
    from public.reconcile_workspace(current_setting('deskilo.recon.ws')::uuid) r;
$$;

-- ------------------------------------------------------------ it is clean
select is(pg_temp.findings(), '{}'::text[],
  'a workspace whose invoice, ledger and match agree reconciles clean');

-- -------------------------------------------- and it refuses the wrong eyes
select throws_ok(
  format($$ select public.reconcile_workspace(%L) $$, gen_random_uuid()),
  'only someone who may see the finances may reconcile them',
  'reconciling a workspace you are not in is refused, not answered');

-- ------------------------------------------------------ #1231 duplicate pay
-- Two webhooks for one intent. The guard is
-- `if v_intent.status = 'captured' then return; end if;` under a
-- `for update`, and no Dart fake can execute it.
do $pay$
declare v_id uuid; v_order text;
begin
  select id into v_id from public.open_payment_intent(
    current_setting('deskilo.recon.ws')::uuid,
    current_setting('deskilo.recon.m')::uuid,
    'mollie', '2026-10', 7500, 'EUR');
  select order_id into v_order from public.payment_intents where id = v_id;
  perform set_config('deskilo.recon.order', v_order, false);
  perform public.settle_online_payment('mollie', v_order, 'cap-1', 7500);
  perform public.settle_online_payment('mollie', v_order, 'cap-1', 7500);
  perform public.settle_online_payment('mollie', v_order, 'cap-1', 7500);
end;
$pay$;

select is(
  (select count(*) from public.ledger_entries
    where workspace_id = current_setting('deskilo.recon.ws')::uuid
      and period = '2026-10' and category = 'payment')::int,
  1, 'three webhooks for one intent credit the ledger once');

select is(pg_temp.findings(), '{}'::text[],
  'and the captured intent reconciles against the credit it posted');

-- A webhook that reports a different figure is refused outright: a wrong
-- credit is worse than a retry, and the refusal is what makes a
-- conversion bug visible (#1138). It has to be a FRESH intent — an
-- already-captured one returns at the idempotency guard before the
-- amount is ever compared, which is the correct order and is why this
-- assertion silently passed for nothing on the first attempt.
do $fresh$
declare v_id uuid; v_order text;
begin
  select id into v_id from public.open_payment_intent(
    current_setting('deskilo.recon.ws')::uuid,
    current_setting('deskilo.recon.m')::uuid,
    'mollie', '2026-12', 4400, 'EUR');
  select order_id into v_order from public.payment_intents where id = v_id;
  perform set_config('deskilo.recon.fresh', v_order, false);
end;
$fresh$;

select throws_ok(
  format($$ select public.settle_online_payment('mollie', %L, 'cap-x', 9900) $$,
         current_setting('deskilo.recon.fresh')),
  'captured amount 9900 does not match the intent (4400)',
  'a webhook whose amount disagrees with the intent is refused');

-- ---------------------------------------------- now break each rule in turn
-- A credit that says 4200 against a match that says 5000 was paid.
do $wrong$
declare v uuid;
begin
  delete from public.ledger_entries
   where id = current_setting('deskilo.recon.credit')::uuid;
  insert into public.ledger_entries (workspace_id, member_id, kind, category,
                                     amount_cents, description, period)
  values (current_setting('deskilo.recon.ws')::uuid,
          current_setting('deskilo.recon.m')::uuid,
          'credit', 'payment', 4200, 'bank transfer', '2026-09')
  returning id into v;
  update public.invoice_matches set credit_ledger_id = v
   where invoice_id = current_setting('deskilo.recon.inv')::uuid;
end;
$wrong$;

select ok('match_credit_amount' = any(pg_temp.findings()),
  'a credit for 4200 against a match that says 5000 is reported');

-- An additional payment pointing at a ledger row that says something else.
do $extra$
declare v uuid;
begin
  insert into public.ledger_entries (workspace_id, member_id, kind, category,
                                     amount_cents, description, period)
  values (current_setting('deskilo.recon.ws')::uuid,
          current_setting('deskilo.recon.m')::uuid,
          'credit', 'payment', 100, 'a hundred', '2026-09')
  returning id into v;
  insert into public.invoice_match_payments (workspace_id, invoice_id,
                                             payment_ledger_id, amount_cents,
                                             resolution)
  values (current_setting('deskilo.recon.ws')::uuid,
          current_setting('deskilo.recon.inv')::uuid, v, 9900, 'exact');
end;
$extra$;

select ok('extra_payment_unbacked' = any(pg_temp.findings()),
  'an additional payment of 9900 backed by a ledger row of 100 is reported');

-- A captured intent with nothing in the ledger.
do $orphan$
begin
  insert into public.payment_intents (workspace_id, member_id, provider, order_id,
                                      period, amount_cents, currency, reference,
                                      status)
  values (current_setting('deskilo.recon.ws')::uuid,
          current_setting('deskilo.recon.m')::uuid,
          'stripe', 'ghost-1', '2026-11', 12300, 'EUR', 'PAY-GHOST', 'captured');
end;
$orphan$;

select ok('captured_payment_uncredited' = any(pg_temp.findings()),
  'money a provider says it took that the ledger never heard about is reported');

select * from finish();
rollback;
