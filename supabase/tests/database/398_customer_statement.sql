-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3673 (0731): the customer statement, open items as of a date. Each
-- document and each payment counts once per currency: an invoice shows what
-- is still due after its allocated parts, a payment appears only as those
-- parts and as its unapplied remainder, never twice. The balance is still
-- due minus unapplied, per currency; nothing is added across currencies.
-- A pending approval keeps its invoice due; a credit note is negative; a
-- voided document and a payment after the cutoff are not there; a currency
-- with three decimals keeps its minor units. Only the customer, finance and
-- issuers read it; an assistant's session does not. Rolled back.
begin;
select plan(14);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000036732a1';
  u_1 uuid := '00000000-0000-4000-8000-0000036732a2';
  u_2 uuid := '00000000-0000-4000-8000-0000036732a3';
  u_x uuid := '00000000-0000-4000-8000-0000036732a4';
  ws uuid; m_o uuid; m_1 uuid; m_2 uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'statement-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_1, u_2, u_x]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Statement', 'FR', 'EUR', 'Europe/Paris', u_o,
          '{"moneyTab": true, "invoicing": true}'::jsonb)
  returning id into ws;
  -- No approval policy: every match stands at once (one is set pending below).
  delete from public.validation_policies where workspace_id = ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
  values (ws, u_o, true, true, 'active', '2026-01-01'), (ws, u_1, false, false, 'active', '2026-01-01'),
         (ws, u_2, false, false, 'active', '2026-01-01'), (ws, u_x, false, false, 'active', '2026-01-01');
  select id into m_o from public.members where workspace_id = ws and user_id = u_o;
  select id into m_1 from public.members where workspace_id = ws and user_id = u_1;
  select id into m_2 from public.members where workspace_id = ws and user_id = u_2;
  -- Customer 1, the decision's case: invoice 100.00, payment 70.00, 40.00 of it allocated.
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name, signature)
  values (ws, m_1, m_o, 'ST-1A', 'One', '[]'::jsonb, 10000, 'EUR', 'One', 'Statement', 'Owner', 'sig');
  -- Customer 2: A shares a payment with B; C awaits approval; D is a credit
  -- note; E is voided; G is in a currency with three decimals.
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name, signature)
  select ws, m_2, m_o, 'ST-2' || n, 'Two', '[]'::jsonb,
         case n when 'A' then 10000 when 'B' then 2000 when 'C' then 3000 when 'D' then -1500
                when 'E' then 5000 else 12345 end,
         case n when 'G' then 'KWD' else 'EUR' end, 'Two', 'Statement', 'Owner', 'sig'
    from unnest(array['A', 'B', 'C', 'D', 'E', 'G']) n;
  insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
  values (ws, m_1, 'credit', 'payment', 7000, 'P1', '2026-09'),
         (ws, m_2, 'credit', 'payment', 7000, 'P', '2026-09'),
         (ws, m_2, 'credit', 'payment', 3000, 'Q', '2026-09');
  perform set_config('st.ws', ws::text, false);
  perform set_config('st.m1', m_1::text, false);
  perform set_config('st.m2', m_2::text, false);
  perform set_config('st.owner', u_o::text, false);
  perform set_config('st.u1', u_1::text, false);
  perform set_config('st.ux', u_x::text, false);
end
$seed$;
select pg_temp.seed();

create or replace function pg_temp.id(p_kind text, p_name text) returns uuid language sql as $f$
  select case p_kind
    when 'inv' then (select id from public.invoices where workspace_id = current_setting('st.ws')::uuid and number = p_name)
    else (select id from public.ledger_entries where workspace_id = current_setting('st.ws')::uuid and description = p_name) end;
$f$;
create or replace function pg_temp.as_user(p_user uuid, p_sql text, p_delegated boolean default false)
returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims', (case when p_delegated
    then json_build_object('sub', p_user, 'role', 'authenticated', 'client_id', 'delegated')
    else json_build_object('sub', p_user, 'role', 'authenticated') end)::text, true);
  set local role authenticated;
  execute p_sql into v;
  reset role;
  return v;
exception when others then
  reset role;
  return 'ERROR: ' || sqlerrm;
end
$f$;
create or replace function pg_temp.apply(p_payment text, p_parts jsonb) returns text language sql as $f$
  select pg_temp.as_user(current_setting('st.owner')::uuid, format(
    'select public.apply_payment_to_invoices(%L, %L, %L::jsonb, ''a part'')::text',
    current_setting('st.ws'), pg_temp.id('pay', p_payment), p_parts));
$f$;
create or replace function pg_temp.statement(p_member text, p_as_of date default current_date,
                                             p_user uuid default null, p_delegated boolean default false)
returns jsonb language plpgsql as $f$
declare v text;
begin
  v := pg_temp.as_user(coalesce(p_user, current_setting('st.owner')::uuid), format(
    'select public.customer_statement_v1(%L, %L, %L)::text',
    current_setting('st.ws'), current_setting('st.' || p_member), p_as_of), p_delegated);
  return case when v like 'ERROR%' then jsonb_build_object('error', v) else v::jsonb end;
end
$f$;
create or replace function pg_temp.cur(p_statement jsonb, p_currency text) returns jsonb language sql as $f$
  select c from jsonb_array_elements(p_statement -> 'currencies') c where c ->> 'currency' = p_currency;
$f$;
create or replace function pg_temp.numbers(p_currency jsonb) returns text language sql as $f$
  select string_agg(i ->> 'number', ',' order by i ->> 'number') from jsonb_array_elements(p_currency -> 'invoices') i;
$f$;

create or replace function pg_temp.summary(p_statement jsonb) returns jsonb language sql as $f$
  select coalesce(jsonb_object_agg(c ->> 'currency', jsonb_build_object(
           'still_due_cents', (c ->> 'still_due_cents')::int,
           'unapplied_cents', (c ->> 'unapplied_cents')::int,
           'balance_cents', (c ->> 'balance_cents')::int,
           'invoices', (select coalesce(jsonb_object_agg(i ->> 'number', (i ->> 'still_due_cents')::int), '{}'::jsonb)
                          from jsonb_array_elements(c -> 'invoices') i),
           'credits', (select coalesce(jsonb_object_agg(cr ->> 'description', (cr ->> 'left_cents')::int), '{}'::jsonb)
                         from jsonb_array_elements(c -> 'credits') cr))), '{}'::jsonb)
    from jsonb_array_elements(p_statement -> 'currencies') c;
$f$;

do $s$ begin
  perform pg_temp.apply('P1', jsonb_build_array(jsonb_build_object('invoice_id', pg_temp.id('inv', 'ST-1A'), 'amount_cents', 4000)));
  perform pg_temp.apply('P', jsonb_build_array(
    jsonb_build_object('invoice_id', pg_temp.id('inv', 'ST-2A'), 'amount_cents', 4000),
    jsonb_build_object('invoice_id', pg_temp.id('inv', 'ST-2B'), 'amount_cents', 2000)));
  perform pg_temp.apply('Q', jsonb_build_array(jsonb_build_object('invoice_id', pg_temp.id('inv', 'ST-2C'), 'amount_cents', 3000)));
end $s$;
-- C's match awaits approval; E is voided (test data only, triggers off).
set local session_replication_role = replica;
update public.invoice_matches set status = 'pending' where invoice_id = pg_temp.id('inv', 'ST-2C');
update public.events set status = 'pending'
 where id in (select event_id from public.invoice_match_payments where invoice_id = pg_temp.id('inv', 'ST-2C'));
update public.invoices set voided_at = now() where id = pg_temp.id('inv', 'ST-2E');
set local session_replication_role = origin;

-- ── the decision's case ─────────────────────────────────────────────
select ok(pg_temp.cur(pg_temp.statement('m1'), 'EUR') ->> 'still_due_cents' = '6000'
          and pg_temp.cur(pg_temp.statement('m1'), 'EUR') ->> 'unapplied_cents' = '3000'
          and pg_temp.cur(pg_temp.statement('m1'), 'EUR') ->> 'balance_cents' = '3000',
          'invoice 100.00, payment 70.00 with 40.00 allocated: 60.00 due, 30.00 unapplied, balance 30.00 (not -10.00)');
select ok(jsonb_array_length(pg_temp.cur(pg_temp.statement('m1'), 'EUR') -> 'invoices') = 1
          and pg_temp.cur(pg_temp.statement('m1'), 'EUR') -> 'invoices' -> 0 -> 'allocations' -> 0 ->> 'amount_cents' = '4000'
          and jsonb_array_length(pg_temp.cur(pg_temp.statement('m1'), 'EUR') -> 'credits') = 1,
          'the payment appears as the 40.00 part under its invoice and as its 30.00 remainder, nowhere else');

-- ── a shared payment, a pending approval, a credit note, a voided document ──
select is(pg_temp.numbers(pg_temp.cur(pg_temp.statement('m2'), 'EUR')), 'ST-2A,ST-2C,ST-2D',
          'open: A after its part, C awaiting approval, the credit note D; B settled and E voided are not there');
select ok(pg_temp.cur(pg_temp.statement('m2'), 'EUR') ->> 'still_due_cents' = '7500'
          and pg_temp.cur(pg_temp.statement('m2'), 'EUR') ->> 'unapplied_cents' = '1000'
          and pg_temp.cur(pg_temp.statement('m2'), 'EUR') ->> 'balance_cents' = '6500',
          'still due 60.00 + 30.00 - 15.00 = 75.00; the shared payment leaves 10.00; balance 65.00');
select ok((select bool_and(i ->> 'state' = case i ->> 'number' when 'ST-2C' then 'awaiting_approval'
                                                               when 'ST-2D' then 'credit_note' else 'partly_paid' end)
             from jsonb_array_elements(pg_temp.cur(pg_temp.statement('m2'), 'EUR') -> 'invoices') i)
          and (select (i ->> 'still_due_cents')::int from jsonb_array_elements(pg_temp.cur(pg_temp.statement('m2'), 'EUR') -> 'invoices') i
                where i ->> 'number' = 'ST-2D') = -1500,
          'each line says what it is; the credit note is owed by the business');
select is((select string_agg(c ->> 'description', ',') from jsonb_array_elements(pg_temp.cur(pg_temp.statement('m2'), 'EUR') -> 'credits') c),
          'P', 'Q, fully spoken for by the part awaiting approval, leaves nothing unapplied');

-- ── one statement per currency; three decimals kept ─────────────────
select is(jsonb_array_length(pg_temp.statement('m2') -> 'currencies'), 2, 'two currencies, two statements');
select ok(pg_temp.cur(pg_temp.statement('m2'), 'KWD') ->> 'still_due_cents' = '12345'
          and pg_temp.cur(pg_temp.statement('m2'), 'KWD') ->> 'balance_cents' = '12345'
          and pg_temp.cur(pg_temp.statement('m2'), 'KWD') ->> 'unapplied_cents' = '0',
          'a three-decimal currency keeps its minor units, and nothing of the euros is added to it');

-- ── parity with the customer page (test/fixtures/customer_statement_parity.json;
--    test/features/money/customer_statement_parity_test.dart reads the same) ──
select is(pg_temp.summary(pg_temp.statement('m2')),
          '{"EUR": {"balance_cents": 6500, "credits": {"P": 1000}, "invoices": {"ST-2A": 6000, "ST-2C": 3000, "ST-2D": -1500}, "still_due_cents": 7500, "unapplied_cents": 1000}, "KWD": {"balance_cents": 12345, "credits": {}, "invoices": {"ST-2G": 12345}, "still_due_cents": 12345, "unapplied_cents": 0}}'::jsonb,
          'the server''s figures are the shared parity fixture''s, which the customer page''s also are');

-- ── the cutoff ──────────────────────────────────────────────────────
set local session_replication_role = replica;
update public.invoices set issued_at = now() - interval '10 days'
 where workspace_id = current_setting('st.ws')::uuid;
update public.ledger_entries set created_at = now() - interval '10 days'
 where workspace_id = current_setting('st.ws')::uuid;
update public.invoice_match_payments set created_datetime = now() - interval '10 days'
 where workspace_id = current_setting('st.ws')::uuid;
update public.invoice_matches set created_datetime = now() - interval '10 days'
 where workspace_id = current_setting('st.ws')::uuid;
update public.invoices set voided_at = now() - interval '10 days' where id = pg_temp.id('inv', 'ST-2E');
set local session_replication_role = origin;
insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
values (current_setting('st.ws')::uuid, current_setting('st.m2')::uuid, 'credit', 'payment', 2000, 'F', '2026-10');
select is(pg_temp.cur(pg_temp.statement('m2', current_date - 1), 'EUR') ->> 'unapplied_cents', '1000',
          'a payment after the cutoff is not on the statement of the day before');
select ok(pg_temp.cur(pg_temp.statement('m2'), 'EUR') ->> 'unapplied_cents' = '3000'
          and pg_temp.cur(pg_temp.statement('m2'), 'EUR') ->> 'balance_cents' = '4500',
          'the same payment is there as of today');

-- ── who may read it ─────────────────────────────────────────────────
select is(pg_temp.cur(pg_temp.statement('m1', current_date, current_setting('st.u1')::uuid), 'EUR') ->> 'balance_cents', '3000',
          'the customer reads their own statement');
select is(pg_temp.statement('m2', current_date, current_setting('st.ux')::uuid) ->> 'error', 'ERROR: not allowed',
          'another member does not');
select is(pg_temp.statement('m2', current_date, null, true) ->> 'error', 'ERROR: not allowed',
          'an assistant''s delegated session does not');

select * from finish();
rollback;
