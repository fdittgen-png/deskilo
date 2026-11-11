-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3671 (0718) -- apply_payment_to_invoices: one payment over several
-- invoices in one call. Parts as given, oldest first; each part is one
-- match with its own event; what is left stays the payer's credit; a part
-- below what is due needs the note; all or nothing; refused: an invoice of
-- another payer, in another currency, twice, a part beyond its invoice or
-- beyond what is left, an empty list. Two payments against one
-- remainder are never both accepted: not while the first awaits approval,
-- not after it; an approval checks its part again.
begin;
select plan(25);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000036711a1';
  u_p uuid := '00000000-0000-4000-8000-0000036711a2';
  ws uuid; m_o uuid; m_p uuid; st uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'apply-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_p]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Apply payment', 'FR', 'EUR', 'Europe/Paris', u_o,
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
         case n when 'A' then 20000 else 10000 end, 'EUR', 'Payer', 'Apply payment', 'Owner', 'sig'
    from unnest(array['A', 'B', 'C', 'D']) n;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name, signature)
  values (ws, m_p, m_o, 'SP-USD', 'In dollars', '[]'::jsonb, 10000, 'USD', 'Payer', 'Apply payment', 'Owner', 'sig'),
         (ws, m_o, m_o, 'SP-OTHER', 'Another payer', '[]'::jsonb, 10000, 'EUR', 'Owner', 'Apply payment', 'Owner', 'sig');
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
  perform set_config('sp.usd', (select id from public.invoices where workspace_id = ws and number = 'SP-USD')::text, false);
  perform set_config('sp.other', (select id from public.invoices where workspace_id = ws and number = 'SP-OTHER')::text, false);
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


create or replace function pg_temp.apply(p_parts text, p_note text default '') returns text language plpgsql as $f$
declare v text; v_parts jsonb;
begin
  select jsonb_agg(jsonb_build_object('invoice_id', current_setting('sp.' || split_part(p, ':', 1)),
                                      'amount_cents', split_part(p, ':', 2)::int))
    into v_parts from unnest(string_to_array(p_parts, ',')) p;
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('sp.owner'), 'role', 'authenticated')::text, true);
  set local role authenticated;
  select public.apply_payment_to_invoices(current_setting('sp.ws')::uuid,
           current_setting('sp.p1')::uuid, coalesce(v_parts, '[]'::jsonb), p_note)::text into v;
  reset role;
  return v;
exception when others then
  reset role;
  return 'ERROR: ' || sqlerrm;
end
$f$;
create or replace function pg_temp.parts() returns int language sql as $f$
  select count(*)::int from public.invoice_match_payments
   where payment_ledger_id = current_setting('sp.p1')::uuid;
$f$;

-- ── refusals change nothing ───────────────────────────────────────
select is(pg_temp.apply(''), 'ERROR: no invoice to pay', 'an empty list is refused');
select is(pg_temp.apply('other:10000'), 'ERROR: an invoice is not of this payer', 'an invoice of another payer is refused');
select is(pg_temp.apply('usd:10000'), 'ERROR: an invoice is not in the business''s currency', 'an invoice in another currency is refused');
select is(pg_temp.apply('a:10000,a:10000'), 'ERROR: an invoice appears twice', 'the same invoice twice is refused');
select is(pg_temp.apply('a:25000'), 'ERROR: a part is more than what is due on its invoice', 'a part beyond its invoice is refused');
select is(pg_temp.apply('a:20000,b:10000,c:10000'), 'ERROR: the parts are more than what is left of the payment',
          'parts beyond the payment are refused');
select is(pg_temp.apply('a:20000,b:5000'), 'ERROR: a note is required', 'a partial part without the note is refused');
select is(pg_temp.parts(), 0, 'and every refusal is all or nothing: no part was taken');

-- ── one call, two invoices ────────────────────────────────────────
select is(pg_temp.apply('a:20000,b:5000', 'half now, half next week'),
          '{"invoices": 2, "left_cents": 5000}', 'two parts taken, 50.00 left');
select is(pg_temp.parts(), 2, 'one row per invoice');
select is((select resolution from public.invoice_match_payments
            where payment_ledger_id = current_setting('sp.p1')::uuid
              and invoice_id = current_setting('sp.b')::uuid), 'under_accepted',
          'the part below what is due is a standing partial');
select is((select count(*)::int from public.events
            where workspace_id = current_setting('sp.ws')::uuid and type = 'invoice_payment'), 2,
          'one event per part');
select is(pg_temp.credit(), 5000 + 10000, 'what is left stays on account, beside the unused payment');
select is(pg_temp.apply('c:5000', 'the rest of the payment'), '{"invoices": 1, "left_cents": 0}', 'a later call takes what is left');

-- ── two payments against one remainder (an approval policy now) ──
-- B owes 50.00 after its partial. P2 pays it exactly and waits for
-- approval; P3 then finds nothing due, before and after the approval.
create or replace function pg_temp.match_r(p_inv text, p_pay text, p_res text, p_amount int, p_note text)
returns text language sql as $f$
  select case when r like 'ERROR%' then r else 'ok' end from (select pg_temp.as_owner(format(
    'select public.match_invoice(%L, %L, %L, %L, %s)::text',
    current_setting('sp.' || p_inv), current_setting('sp.' || p_pay), p_res, p_note, p_amount)) r) x;
$f$;
create or replace function pg_temp.decide(p_pay text, p_inv text, p_accept boolean) returns text language sql as $f$
  select case when r like 'ERROR%' then r else 'ok' end from (select pg_temp.as_owner(format(
    'select public.respond_to_event(%L, %L)::text',
    (select e.id from public.events e
      where e.type = 'invoice_payment' and e.status = 'pending'
        and e.payload ->> 'payment_ledger_id' = current_setting('sp.' || p_pay)
        and e.payload ->> 'invoice_id' = current_setting('sp.' || p_inv)), p_accept)) r) x;
$f$;
create or replace function pg_temp.more_payments() returns void language plpgsql as $f$
begin
  insert into public.validation_policies (workspace_id, event_type, required_count, owner_may_self_validate)
  values (current_setting('sp.ws')::uuid, 'invoice_payment', 1, true);
  insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
  select current_setting('sp.ws')::uuid, current_setting('sp.m_p')::uuid, 'credit', 'payment', a, d, '2026-09'
    from (values (5000, 'P3'), (2000, 'P4'), (3000, 'P5')) v(a, d);
  perform set_config('sp.p3', (select id from public.ledger_entries
    where workspace_id = current_setting('sp.ws')::uuid and description = 'P3')::text, false);
  perform set_config('sp.p4', (select id from public.ledger_entries
    where workspace_id = current_setting('sp.ws')::uuid and description = 'P4')::text, false);
  perform set_config('sp.p5', (select id from public.ledger_entries
    where workspace_id = current_setting('sp.ws')::uuid and description = 'P5')::text, false);
end
$f$;
select pg_temp.more_payments();

select is(pg_temp.match_r('b', 'p2', 'exact', 5000, ''), 'ok', 'P2 settles what B still owes, awaiting approval');
select isnt(pg_temp.match_r('b', 'p3', 'exact', 5000, ''), 'ok',
            'P3 cannot take the same remainder while P2 awaits approval');
select is(pg_temp.match_r('b', 'p3', 'over_forced', 5000, 'too much'), 'ERROR: nothing is due on this invoice',
          'not even an intended overpayment goes to an invoice a waiting part covers');
create or replace function pg_temp.capacity(p_pay text) returns jsonb language sql as $f$
  select pg_temp.as_owner(format('select public.payment_invoice_capacity_v1(%L, %L)::text',
    current_setting('sp.ws'), current_setting('sp.' || p_pay)))::jsonb;
$f$;
create or replace function pg_temp.cap_of(p_pay text, p_inv text) returns jsonb language sql as $f$
  select x from jsonb_array_elements(pg_temp.capacity(p_pay)) x
   where x ->> 'invoice_id' = current_setting('sp.' || p_inv);
$f$;
select is(pg_temp.cap_of('p3', 'b'),
          jsonb_build_object('invoice_id', current_setting('sp.b'), 'still_due_cents', 0,
                             'can_take', false, 'reason', 'awaiting_approval'),
          'the capacity read lists B as waiting for approval, nothing to take');
select is(pg_temp.cap_of('p3', 'd'),
          jsonb_build_object('invoice_id', current_setting('sp.d'), 'still_due_cents', 10000,
                             'can_take', true, 'reason', null),
          'and D, untouched, with all of it due');
select is((select count(*)::int from jsonb_array_elements(pg_temp.capacity('p3')) x
            where x ->> 'invoice_id' in (current_setting('sp.usd'), current_setting('sp.other'), current_setting('sp.a'))),
          0, 'not another payer''s, not another currency''s, not one paid in full');
select is(pg_temp.decide('p2', 'b', true), 'ok', 'P2 is approved');
select isnt(pg_temp.match_r('b', 'p3', 'exact', 5000, ''), 'ok', 'nor after it: B is paid');
-- C owes 50.00: P4 20.00 as a partial and P5 30.00 as the exact rest wait
-- together. P4 is refused, so P5 no longer settles C: its approval refuses.
do $s$ begin perform pg_temp.match_r('c', 'p4', 'under_accepted', 2000, 'a part'); end $s$;
select is(pg_temp.match_r('c', 'p5', 'exact', 3000, ''), 'ok', 'P5 settles the rest beside the pending P4');
select is(pg_temp.cap_of('p3', 'c') ->> 'still_due_cents', '0',
          'C: what is still due leaves out both waiting parts');
do $s$ begin perform pg_temp.decide('p4', 'c', false); end $s$;
select is(pg_temp.decide('p5', 'c', true),
          'ERROR: the invoice changed while this part waited for approval',
          'an approval checks its part again: with P4 refused, P5 is not the rest');

select * from finish();
rollback;
