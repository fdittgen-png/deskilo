-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2380 — the bank statements. The owner imports a notification whose two
-- movements carry the same day, amount and reference but distinct bank ids
-- (two movements), a QR-referenced payment and one without a bank id; the
-- same file again creates nothing; a later file repeating a bank id skips
-- it, and a movement without one that equals a stored one waits for a
-- review instead of collapsing. Money in confirmed against its invoice
-- becomes one payment credit on the value day and an invoice match; a
-- second confirmation, another currency, a duplicate and a movement still
-- waiting for its review are refused; a match the validators reject leaves
-- the payment recorded and the movement matched again with the same
-- payment. Money out reconciles a reported outgoing payment, which nothing
-- else may move to reconciled. A file over the line bound and one mixing
-- currencies are refused whole. A plain member, a stranger, a space with
-- the flag off and an assistant's delegated token are refused; under the
-- authenticated role a plain member reads no statement and the owner does.
-- Positive cases beside every refusal.
begin;
select plan(40);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000023800c1';
  u_m uuid := '00000000-0000-4000-8000-0000023800c2';
  u_x uuid := '00000000-0000-4000-8000-0000023800c3';
  ws uuid; ws2 uuid; m_o uuid; m_m uuid; m_x uuid; ia uuid; ib uuid; ie uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'bank-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_m, u_x]) u;
  -- The flag and every parent on (moneyTab > invoicing > bankImport).
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Bank books', 'CH', 'CHF', 'Europe/Zurich', u_o,
          '{"moneyTab": true, "invoicing": true, "bankImport": true}'::jsonb)
  returning id into ws;
  -- Another space with the flag off.
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Paper bank', 'CH', 'CHF', 'Europe/Zurich', u_x,
          '{"moneyTab": true, "invoicing": true, "bankImport": false}'::jsonb)
  returning id into ws2;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_o, true, true), (ws, u_m, false, false), (ws2, u_x, true, true);
  select id into m_o from public.members where workspace_id = ws and user_id = u_o;
  select id into m_m from public.members where workspace_id = ws and user_id = u_m;
  select id into m_x from public.members where workspace_id = ws2 and user_id = u_x;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name, signature)
  values (ws, m_m, m_o, 'B-1', 'A', '[]'::jsonb, 12000, 'CHF', 'M', 'Bank books', 'O', 's') returning id into ia;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name, signature)
  values (ws, m_m, m_o, 'B-2', 'B', '[]'::jsonb, 3000, 'CHF', 'M', 'Bank books', 'O', 's') returning id into ib;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name, signature)
  values (ws, m_m, m_o, 'B-3', 'C', '[]'::jsonb, 12000, 'EUR', 'M', 'Bank books', 'O', 's') returning id into ie;
  insert into public.outgoing_payments (workspace_id, payee_kind, payee_member_id, currency, amount_cents,
                                        method, reported_paid_on, state, actor_member_id, request_id)
  values (ws, 'member', m_m, 'CHF', 5000, 'bank_transfer', date '2026-10-19', 'reported', m_o,
          '00000000-0000-4000-8000-0000023800f1'),
         (ws, 'member', m_m, 'CHF', 7000, 'bank_transfer', date '2026-10-19', 'reported', m_o,
          '00000000-0000-4000-8000-0000023800f2');
  perform set_config('bk.ws', ws::text, false);
  perform set_config('bk.ws2', ws2::text, false);
  perform set_config('bk.ia', ia::text, false);
  perform set_config('bk.ib', ib::text, false);
  perform set_config('bk.ie', ie::text, false);
  perform set_config('bk.member_m', m_m::text, false);
  perform set_config('bk.owner', u_o::text, false);
  perform set_config('bk.member', u_m::text, false);
  perform set_config('bk.stranger', u_x::text, false);
end
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('bk.' || p_who), 'role', 'authenticated')::text, true);
end
$act$;

-- p_sql's jsonb answer as p_who, or {"refused": sqlstate}.
create or replace function pg_temp.as_json(p_who text, p_sql text) returns jsonb
language plpgsql as $j$
declare v jsonb;
begin
  perform pg_temp.act_as(p_who);
  execute p_sql into v;
  return v;
exception when others then
  return jsonb_build_object('refused', sqlstate, 'message', sqlerrm);
end
$j$;

create or replace function pg_temp.as_delegated(p_who text, p_sql text) returns jsonb
language plpgsql as $j$
declare v jsonb;
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('bk.' || p_who), 'role', 'authenticated',
                      'client_id', 'assistant')::text, true);
  execute p_sql into v;
  return v;
exception when others then
  return jsonb_build_object('refused', sqlstate);
end
$j$;

-- p_sql's first value as p_who under the authenticated role (grants, RLS).
create or replace function pg_temp.as_role(p_who text, p_sql text) returns text
language plpgsql as $j$
declare v text;
begin
  perform pg_temp.act_as(p_who);
  execute 'set local role authenticated';
  execute p_sql into v;
  reset role;
  return v;
exception when others then
  reset role;
  return sqlstate;
end
$j$;

create or replace function pg_temp.v(p_key text) returns text language sql as $v$
  select current_setting('bk.' || p_key)
$v$;

-- One movement as the app sends it.
create or replace function pg_temp.mv(p_pos int, p_cents int, p_ref text, p_tx text,
                                      p_currency text default 'CHF', p_text text default '')
returns jsonb language sql as $mv$
  select jsonb_build_object('position', p_pos, 'booking_date', '2026-10-20', 'value_date', '2026-10-21',
    'amount_cents', p_cents, 'currency', p_currency, 'transaction_id', p_tx,
    'counterparty_name', 'Demo Member', 'counterparty_iban', '', 'reference', p_ref,
    'end_to_end_id', '', 'remittance', p_text)
$mv$;

create or replace function pg_temp.stmt(p_sha text) returns jsonb language sql as $st$
  select jsonb_build_object('format', 'camt054', 'account', 'CH9300762011623852957', 'currency', 'CHF',
    'statement_ref', 'N-1', 'source_sha256', repeat(p_sha, 64), 'file_name', 'n.xml')
$st$;

-- The import as p_who of p_lines under the file digest p_sha.
create or replace function pg_temp.import(p_who text, p_sha text, p_lines jsonb, p_ws text default 'ws')
returns jsonb language sql as $im$
  select pg_temp.as_json(p_who, format('select public.import_bank_statement_v1(%L, %L, %L)',
    pg_temp.v(p_ws), pg_temp.stmt(p_sha), p_lines))
$im$;

create or replace function pg_temp.line(p_tx text) returns text language sql as $l$
  select id::text from public.bank_statement_lines where transaction_id = p_tx
$l$;

select pg_temp.seed();

-- ── the tables and the registries ───────────────────────────────────
select is((select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public' and c.relrowsecurity
              and c.relname in ('bank_statements', 'bank_statement_lines')),
          2, 'both tables have row level security');
select is((select count(*)::int from information_schema.role_table_grants
            where grantee in ('authenticated', 'anon') and table_schema = 'public'
              and table_name in ('bank_statements', 'bank_statement_lines')
              and privilege_type <> 'SELECT'),
          0, 'no client role may write the tables directly');
select is(public.feature_registry() -> 'bankImport',
          '{"parent": "invoicing", "default": false, "core": false}'::jsonb,
          'the server knows the flag, under invoicing');
select ok(exists (select 1 from jsonb_array_elements(public.template_field_registry()) r
                   where r ->> 'id' = 'workspace.feature_flags.bankImport'),
          'the template field registry knows the flag');
select is((public.setting_value(null, 'bank.import_max_lines') #>> '{}')::int, 5000,
          'the line bound is a setting');

-- ── refusals before anything is stored ──────────────────────────────
select is(pg_temp.import('member', 'a', jsonb_build_array(pg_temp.mv(1, 100, '', 'Z1'))) ->> 'refused',
          '42501', 'a plain member may not import');
select is(pg_temp.import('stranger', 'a', jsonb_build_array(pg_temp.mv(1, 100, '', 'Z1'))) ->> 'refused',
          '42501', 'a stranger may not import into the space');
select is(pg_temp.import('stranger', 'a', jsonb_build_array(pg_temp.mv(1, 100, '', 'Z1')), 'ws2') ->> 'refused',
          '0A000', 'a space with the flag off is refused');
select is(pg_temp.as_delegated('owner', format('select public.import_bank_statement_v1(%L, %L, %L)',
            pg_temp.v('ws'), pg_temp.stmt('a'), jsonb_build_array(pg_temp.mv(1, 100, '', 'Z1')))) ->> 'refused',
          '42501', 'an assistant''s delegated token is refused');
select is(pg_temp.import('owner', 'a',
            (select jsonb_agg(pg_temp.mv(n, 100, '', 'M' || n)) from generate_series(1, 5001) n)) ->> 'refused',
          '22023', 'a file over the line bound is refused');
select is(pg_temp.import('owner', 'a', jsonb_build_array(pg_temp.mv(1, 100, '', 'Z1'),
            pg_temp.mv(2, 100, '', 'Z2', 'EUR'))) ->> 'refused',
          '22023', 'a file mixing currencies is refused');
select is((select count(*)::int from public.bank_statements), 0, 'and nothing of them was stored');

-- ── the first import ─────────────────────────────────────────────────
select is(pg_temp.import('owner', 'a', jsonb_build_array(
            pg_temp.mv(1, 12000, '210000000003139471430009017', 'T1'),
            pg_temp.mv(2, 12000, '210000000003139471430009017', 'T5'),
            pg_temp.mv(3, 3000, 'RF18539007547034', 'T2'),
            pg_temp.mv(4, 4500, '', '', 'CHF', 'Coffee'),
            pg_temp.mv(5, -5000, '', 'T9'))) - 'statement_id',
          '{"repeated": false, "created": 5, "known": 0, "review": 0}'::jsonb,
          'five movements are created');
select is((select count(*)::int from public.bank_statement_lines
            where reference = '210000000003139471430009017'),
          2, 'equal day, amount and reference with distinct bank ids are two movements');
select is(pg_temp.import('owner', 'a', jsonb_build_array(pg_temp.mv(1, 12000, '', 'T1'))) - 'statement_id',
          '{"repeated": true, "created": 0, "known": 1, "review": 0}'::jsonb,
          'the same file again creates nothing');
select is((select count(*)::int from public.bank_statements), 1, 'one statement is kept');

-- ── an overlapping file ──────────────────────────────────────────────
select is(pg_temp.import('owner', 'b', jsonb_build_array(
            pg_temp.mv(1, 3000, 'RF18539007547034', 'T2'),
            pg_temp.mv(2, 4500, '', '', 'CHF', 'Coffee'),
            pg_temp.mv(3, 900, '', 'T6'))) - 'statement_id',
          '{"repeated": false, "created": 1, "known": 1, "review": 1}'::jsonb,
          'a known bank id is skipped, an equal movement without one waits for a review');

-- ── money in confirmed ───────────────────────────────────────────────
select is(pg_temp.as_json('owner', format($q$select public.match_bank_line_v1(%L, %L, 'exact', '')$q$,
            pg_temp.line('T1'), pg_temp.v('ia'))) ->> 'status',
          'matched', 'money in confirmed against its invoice is matched');
select is((select l.occurred_on::text || '/' || l.member_id::text || '/' || l.amount_cents
             from public.ledger_entries l
             join public.bank_statement_lines b on b.payment_ledger_id = l.id
            where b.transaction_id = 'T1'),
          '2026-10-21/' || pg_temp.v('member_m') || '/12000',
          'as one payment credit of the invoice''s member on the value day');
select is((select paid_cents from public.invoice_matches where invoice_id = pg_temp.v('ia')::uuid),
          12000, 'and an invoice match');
select is(pg_temp.as_json('owner', format($q$select public.match_bank_line_v1(%L, %L, 'exact', '')$q$,
            pg_temp.line('T1'), pg_temp.v('ib'))) ->> 'refused',
          '22023', 'a movement already settling an invoice is refused');
select is(pg_temp.as_json('owner', format($q$select public.match_bank_line_v1(%L, %L, 'exact', '')$q$,
            pg_temp.line('T5'), pg_temp.v('ia'))) ->> 'refused',
          'P0001', 'a second movement against the settled invoice is refused by the match');
select is(pg_temp.as_json('owner', format($q$select public.match_bank_line_v1(%L, %L, 'exact', '')$q$,
            pg_temp.line('T5'), pg_temp.v('ie'))) ->> 'refused',
          '22023', 'an invoice in another currency is refused');
select is(pg_temp.as_json('member', format($q$select public.match_bank_line_v1(%L, %L, 'exact', '')$q$,
            pg_temp.line('T2'), pg_temp.v('ib'))) ->> 'refused',
          '42501', 'a plain member may not match');
select is(pg_temp.as_json('owner', format($q$select public.match_bank_line_v1(%L, %L, 'exact', '')$q$,
            pg_temp.line('T9'), pg_temp.v('ib'))) ->> 'refused',
          '22023', 'money out settles no invoice');
select is((select count(*)::int from public.ledger_entries where category = 'payment'
            and workspace_id = pg_temp.v('ws')::uuid),
          1, 'the refusals created no payment');

-- ── a rejected match, matched again ──────────────────────────────────
select is(pg_temp.as_json('owner', format($q$select public.match_bank_line_v1(%L, %L, 'exact', '')$q$,
            pg_temp.line('T2'), pg_temp.v('ib'))) ->> 'status',
          'matched', 'the RF movement settles its invoice');
select lives_ok(format('select public.release_invoice_payment(%L)',
            (select event_id from public.invoice_matches where invoice_id = pg_temp.v('ib')::uuid)),
          'the validators reject that match');
select is(pg_temp.as_json('owner', format('select public.bank_statement_lines_v1(%L)',
            (select statement_id from public.bank_statement_lines where transaction_id = 'T2')))
            @> jsonb_build_array(jsonb_build_object('transaction_id', 'T2', 'status', 'recorded')),
          true, 'the movement reads recorded: its payment stays, it settles nothing');
select is(pg_temp.as_json('owner', format($q$select public.match_bank_line_v1(%L, %L, 'exact', '')$q$,
            pg_temp.line('T2'), pg_temp.v('ib'))) ->> 'status',
          'matched', 'it is matched again');
select is((select count(*)::int from public.ledger_entries where category = 'payment'
            and workspace_id = pg_temp.v('ws')::uuid),
          2, 'with the same payment, never a second one');

-- ── a review ─────────────────────────────────────────────────────────
select is(pg_temp.as_json('owner', format($q$select public.match_bank_line_v1(%L, %L, 'exact', '')$q$,
            (select id from public.bank_statement_lines where state = 'review'), pg_temp.v('ib'))) ->> 'refused',
          '22023', 'a movement waiting for its review settles nothing');
select is(pg_temp.as_json('owner', format('select public.review_bank_line_v1(%L, true)',
            (select id from public.bank_statement_lines where state = 'review'))) ->> 'status',
          'duplicate', 'the review declares it a duplicate');
select is(pg_temp.as_json('owner', format('select public.review_bank_line_v1(%L, false)',
            (select id from public.bank_statement_lines where state = 'duplicate'))) ->> 'refused',
          '22023', 'a decided review is not decided again');

-- ── money out reconciled ─────────────────────────────────────────────
select is(pg_temp.as_json('owner', format('select public.reconcile_bank_line_out_v1(%L, %L)',
            pg_temp.line('T9'),
            (select id from public.outgoing_payments where amount_cents = 7000))) ->> 'refused',
          '22023', 'a payment of another amount is refused');
select is(pg_temp.as_json('owner', format('select public.reconcile_bank_line_out_v1(%L, %L)',
            pg_temp.line('T9'),
            (select id from public.outgoing_payments where amount_cents = 5000))) ->> 'status',
          'reconciled', 'money out reconciles the reported payment of its amount');
select is((select state || '/' || booking_date::text from public.outgoing_payments where amount_cents = 5000),
          'reconciled/2026-10-20', 'the payment is reconciled on the bank''s day; nothing else is created');
select throws_ok($t$update public.outgoing_payments set state = 'reconciled' where amount_cents = 7000$t$,
          'P0001', null, 'no bank line, no reconciliation');

-- ── who reads ────────────────────────────────────────────────────────
select is(pg_temp.as_role('member', 'select count(*) from public.bank_statements'), '0',
          'a plain member reads no statement');
select is(pg_temp.as_role('owner', 'select count(*) from public.bank_statements'), '2',
          'the owner reads both');

select * from finish();
rollback;
