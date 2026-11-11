-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3671 (0717) -- one payment settles several invoices, each its own part.
-- A whole match without an amount reads as before; a payment of 300.00 is
-- split 200.00 + 100.00 over two invoices; what is left of it is its credit
-- on account and on the next invoice, and nothing more can be taken from it;
-- the parts can never add up to more than the payment; a bank line on a
-- split payment reads matched (it raised before); reconcile accepts a valid
-- split and flags a broken sum; the money received is the payment once.
begin;
select plan(20);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000036710a1';
  u_p uuid := '00000000-0000-4000-8000-0000036710a2';
  ws uuid; m_o uuid; m_p uuid; st uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'split-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_p]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Split payment', 'FR', 'EUR', 'Europe/Paris', u_o,
          '{"moneyTab": true, "invoicing": true, "bankImport": true}'::jsonb)
  returning id into ws;
  -- No approval policy: every match stands at once.
  delete from public.validation_policies where workspace_id = ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
  values (ws, u_o, true, true, 'active', '2026-01-01'), (ws, u_p, false, false, 'active', '2026-01-01');
  select id into m_o from public.members where workspace_id = ws and user_id = u_o;
  select id into m_p from public.members where workspace_id = ws and user_id = u_p;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name, signature)
  select ws, m_p, m_o, 'SP-' || n, 'Invoice ' || n, '[]'::jsonb,
         case n when 'A' then 20000 else 10000 end, 'EUR', 'Payer', 'Split payment', 'Owner', 'sig'
    from unnest(array['A', 'B', 'C', 'D']) n;
  -- Two payments of a past month: P1 300.00 (to split), P2 100.00 (whole).
  insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
  values (ws, m_p, 'credit', 'payment', 30000, 'P1', '2026-09'),
         (ws, m_p, 'credit', 'payment', 10000, 'P2', '2026-09');
  insert into public.bank_statements (workspace_id, format, account, currency, source_sha256, period_from, period_to)
  values (ws, 'camt053', 'FR7630006000011234567890189', 'EUR', repeat('a', 64), '2026-09-01', '2026-09-30')
  returning id into st;
  insert into public.bank_statement_lines (statement_id, workspace_id, account, position, booking_date, value_date,
                                           amount_cents, currency, transaction_id, reference, line_hash,
                                           payment_ledger_id)
  values (st, ws, 'FR7630006000011234567890189', 1, '2026-09-20', '2026-09-20', 30000, 'EUR', 'T1', 'R1',
          repeat('1', 64), (select id from public.ledger_entries where workspace_id = ws and description = 'P1'));
  perform set_config('sp.ws', ws::text, false);
  perform set_config('sp.m_p', m_p::text, false);
  perform set_config('sp.owner', u_o::text, false);
  perform set_config('sp.p1', (select id from public.ledger_entries where workspace_id = ws and description = 'P1')::text, false);
  perform set_config('sp.p2', (select id from public.ledger_entries where workspace_id = ws and description = 'P2')::text, false);
  perform set_config('sp.line', (select id from public.bank_statement_lines where statement_id = st)::text, false);
  perform set_config('sp.a', (select id from public.invoices where workspace_id = ws and number = 'SP-A')::text, false);
  perform set_config('sp.b', (select id from public.invoices where workspace_id = ws and number = 'SP-B')::text, false);
  perform set_config('sp.c', (select id from public.invoices where workspace_id = ws and number = 'SP-C')::text, false);
  perform set_config('sp.d', (select id from public.invoices where workspace_id = ws and number = 'SP-D')::text, false);
end
$seed$;
select pg_temp.seed();

-- As the owner: match, read the account, reconcile.
create or replace function pg_temp.as_owner(p_sql text) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('sp.owner'), 'role', 'authenticated')::text, true);
  set local role authenticated;
  execute p_sql into v;
  reset role;
  return v;
exception when others then
  reset role;
  return 'ERROR: ' || sqlerrm;
end
$f$;
create or replace function pg_temp.credit() returns int language sql as $f$
  select (pg_temp.as_owner(format('select public.member_account(%L)::text', current_setting('sp.m_p')))::jsonb
          ->> 'credit_cents')::int;
$f$;
create or replace function pg_temp.line_status() returns text language sql as $f$
  select public.bank_line_status(l) from public.bank_statement_lines l
   where l.id = current_setting('sp.line')::uuid;
$f$;
create or replace function pg_temp.unbacked() returns int language sql as $f$
  select count(*)::int from jsonb_array_elements(coalesce(pg_temp.as_owner(format(
    'select coalesce(jsonb_agg(to_jsonb(r)), ''[]'')::text from public.reconcile_workspace(%L) r',
    current_setting('sp.ws')))::jsonb, '[]')) x
   where x::text like '%extra_payment_unbacked%';
$f$;
create or replace function pg_temp.match(p_inv text, p_pay text, p_amount int) returns text language sql as $f$
  select case when r like 'ERROR%' then r else 'ok' end from (select pg_temp.as_owner(format(
    'select public.match_invoice(%L, %L, ''exact'', '''', %s)::text',
    current_setting('sp.' || p_inv), current_setting('sp.' || p_pay),
    coalesce(p_amount::text, 'null'))) r) x;
$f$;

-- ── before: both payments are on account ───────────────────────────
select is(pg_temp.credit(), 40000, 'two unused payments are 400.00 on account');

-- ── a whole match reads as before ──────────────────────────────────
select is(pg_temp.match('c', 'p2', null), 'ok', 'a match without an amount takes the whole payment');
select is((select amount_cents from public.invoice_match_payments
            where payment_ledger_id = current_setting('sp.p2')::uuid), 10000,
          'its part is the whole payment');
select is(pg_temp.credit(), 30000, 'a used payment leaves the account, as before');
select is(pg_temp.match('d', 'p2', null), 'ERROR: payment already matched',
          'a used payment is refused with the same words');

-- ── a payment split over two invoices ──────────────────────────────
select is(pg_temp.match('a', 'p1', 20000), 'ok', 'the first part settles invoice A');
select is(pg_temp.credit(), 10000, 'what is left of the payment is on account');
select is(pg_temp.line_status(), 'recorded', 'its bank line can still be matched');
select ok(public.invoice_lines_for(current_setting('sp.m_p')::uuid, '2026-09')::text like '%-10000%',
          'the next invoice deducts only what is left');
select is(pg_temp.match('b', 'p1', 20000), 'ERROR: the amount is more than what is left of the payment',
          'a part larger than what is left is refused');
select is(pg_temp.match('b', 'p1', 10000), 'ok', 'the second part settles invoice B');
select is((select count(*)::int from public.invoice_match_payments
            where payment_ledger_id = current_setting('sp.p1')::uuid), 2,
          'two rows, one per invoice');
select is(pg_temp.credit(), 0, 'nothing is left on account');
select is(pg_temp.line_status(), 'matched', 'the bank line of a split payment reads matched');
select is(pg_temp.match('d', 'p1', null), 'ERROR: payment already matched',
          'nothing more can be taken from it');
select is((select sum(amount_cents)::int from public.invoice_match_payments
            where payment_ledger_id = current_setting('sp.p1')::uuid), 30000,
          'the money received is the payment once: 300.00');

-- ── the invariant ──────────────────────────────────────────────────
select is(pg_temp.unbacked(), 0, 'reconcile accepts a valid split');
select throws_ok(format($$insert into public.invoice_match_payments
    (workspace_id, invoice_id, payment_ledger_id, amount_cents, resolution, note, by_name)
    values (%L, %L, %L, 1, 'exact', '', 'test')$$,
    current_setting('sp.ws'), current_setting('sp.d'), current_setting('sp.p1')),
  '22023', 'the parts of a payment add up to more than the payment',
  'a part beyond the payment is refused by the table itself');
select throws_ok(format($$update public.invoice_match_payments set amount_cents = 25000
    where payment_ledger_id = %L and invoice_id = %L$$,
    current_setting('sp.p1'), current_setting('sp.a')),
  '22023', 'the parts of a payment add up to more than the payment',
  'a part cannot be raised past the payment');
alter table public.invoice_match_payments disable trigger invoice_match_payments_allocation_sum;
update public.invoice_match_payments set amount_cents = 25000
 where payment_ledger_id = current_setting('sp.p1')::uuid and invoice_id = current_setting('sp.a')::uuid;
alter table public.invoice_match_payments enable trigger invoice_match_payments_allocation_sum;
select ok(pg_temp.unbacked() > 0, 'reconcile flags a payment whose parts exceed it');

select * from finish();
rollback;
