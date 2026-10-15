-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2357 — input VAT (0408). An expense states the VAT it carried and the
-- share the space may deduct; submit_expense keeps both under the
-- inputVat flag and refuses a rate or a share outside 0..100. The VAT
-- return of a French September holds the sales line and, apart, the
-- deductible VAT of the expenses approved in September — 20.00 of a
-- 120.00 expense at 20 %, half of another, 1.00 of an 11.00 one at 10 %
-- — per rate, marked input; the totals are the sales base and the net
-- payable, here a credit. A pending expense, one without VAT and one
-- approved in October count for nothing; with the flag off the return
-- holds no input line. The filing records the input amounts; the book
-- chart takes a vat_input role on an asset account only. The same
-- figures are pinned in Dart by test/features/money/vat_return_parity_test.dart.
begin;
select plan(17);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-000000235721';
  u_m uuid := '00000000-0000-4000-8000-000000235722';
  ws uuid; mo uuid; site uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'inputvat-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_m]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by,
                                 vat_regime, feature_flags)
  values ('Input FR', 'FR', 'EUR', 'Europe/Paris', u_o, 'vat_registered',
          '{"moneyTab": true, "invoicing": true, "accountingBook": true, "vatManagement": true, "vatDeclarations": true}')
  returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_o, true, true) returning id into mo;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_m, false, false);
  insert into public.sites (workspace_id, name, legal_id) values (ws, 'Atelier', '111')
  returning id into site;

  -- A sale on the debits: 120.00 at 20 %, due when issued on 5 September.
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name,
                               signature, kind, issued_at, vat_totals, legal_snapshot)
  values (ws, mo, mo, 'F-1', 'Desk', '[{"label": "Desk", "amount_cents": 12000, "vat_percent": 20}]',
          12000, 'EUR', 'M', 'Input FR', 'M', 's', 'full', '2026-09-05 10:00+00',
          '[{"percent": 20, "category": "S"}]',
          '{"seller_country": "FR", "vat_exigibility": "invoice"}');

  -- Expenses, as approval leaves them.
  insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id,
                             payload, status, decided_at)
  values
    (ws, 'expense', 'submitted', mo, mo,
     '{"amount_cents": 12000, "category": "equipment", "note": "", "vat": {"percent": 20, "deductible_pct": 100}}',
     'confirmed', '2026-09-10 10:00+00'),
    (ws, 'expense', 'submitted', mo, mo,
     '{"amount_cents": 12000, "category": "equipment", "note": "", "vat": {"percent": 20, "deductible_pct": 50}}',
     'confirmed', '2026-09-12 10:00+00'),
    (ws, 'expense', 'submitted', mo, mo,
     '{"amount_cents": 1100, "category": "coffee", "note": "", "vat": {"percent": 10, "deductible_pct": 100}}',
     'confirmed', '2026-09-20 10:00+00'),
    (ws, 'expense', 'submitted', mo, mo,
     '{"amount_cents": 5000, "category": "other", "note": "", "vat": {"percent": 20, "deductible_pct": 100}}',
     'pending', null),
    (ws, 'expense', 'submitted', mo, mo,
     '{"amount_cents": 3000, "category": "other", "note": ""}',
     'confirmed', '2026-09-21 10:00+00'),
    (ws, 'expense', 'submitted', mo, mo,
     '{"amount_cents": 2400, "category": "other", "note": "", "vat": {"percent": 20, "deductible_pct": 100}}',
     'confirmed', '2026-10-02 10:00+00');

  perform set_config('iv.ws', ws::text, false);
  perform set_config('iv.site', site::text, false);
  perform set_config('iv.owner', u_o::text, false);
end
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('iv.' || p_who), 'role', 'authenticated')::text, true);
end
$act$;

create or replace function pg_temp.flag(p_on boolean) returns void language sql as $f$
  update public.workspaces set feature_flags = feature_flags || jsonb_build_object('inputVat', p_on)
   where id = current_setting('iv.ws')::uuid;
$f$;

create or replace function pg_temp.sept() returns uuid language sql as $q$
  select id from public.vat_declarations
   where workspace_id = current_setting('iv.ws')::uuid and period_start = '2026-09-01';
$q$;

select pg_temp.seed();

-- ------------------------------------------------------- the expense form
select pg_temp.act_as('owner');
select set_config('iv.e1', public.submit_expense(current_setting('iv.ws')::uuid, 6000, 'supplies',
  'Paper', null, '{"percent": 5.5, "deductible_pct": 80}')::text, false);
select is(
  (select payload -> 'vat' from public.events where id = current_setting('iv.e1')::uuid),
  '{"percent": 5.5, "deductible_pct": 80}'::jsonb,
  'an expense keeps the VAT it carried and the deductible share');
select throws_like(
  $$ select public.submit_expense(current_setting('iv.ws')::uuid, 6000, 'supplies', '', null,
                                  '{"percent": 0}') $$,
  '%between 0 and 100%', 'a VAT rate of zero is no VAT to deduct');
select throws_like(
  $$ select public.submit_expense(current_setting('iv.ws')::uuid, 6000, 'supplies', '', null,
                                  '{"percent": 20, "deductible_pct": 150}') $$,
  '%deductible share%', 'a share above 100 % is refused');
select set_config('iv.e2', public.submit_expense(current_setting('iv.ws')::uuid, 6000, 'supplies', '')::text, false);
select is(
  (select payload ? 'vat' from public.events where id = current_setting('iv.e2')::uuid),
  false, 'an expense without VAT carries none');
select pg_temp.flag(false);
select throws_like(
  $$ select public.submit_expense(current_setting('iv.ws')::uuid, 6000, 'supplies', '', null,
                                  '{"percent": 20}') $$,
  '%switched off%', 'with input VAT off, an expense states no VAT');
select pg_temp.flag(true);

-- ------------------------------------------------------- the return
select results_eq(
  $$ select direction, percent, tax_point, gross_cents, net_cents, vat_cents, invoice_count
       from public.compute_vat_return(current_setting('iv.ws')::uuid, '2026-09-01', '2026-09-30') $$,
  $$ values ('output'::text, 20::numeric, '2026-09-05'::date, 12000::bigint, 10000::bigint, 2000::bigint, 1),
            ('input', 20, '2026-09-10', 12000, 10000, 2000, 1),
            ('input', 20, '2026-09-12', 11000, 10000, 1000, 1),
            ('input', 10, '2026-09-20', 1100, 1000, 100, 1) $$,
  'September: the sale, then the deductible VAT of each approved expense, half of the half-deductible one');
select is(
  (select count(*)::int from public.compute_vat_return(
     current_setting('iv.ws')::uuid, '2026-10-01', '2026-10-31') where direction = 'input'),
  1, 'the expense approved on 2 October is October''s');

select lives_ok(
  $$ select public.save_vat_declaration(current_setting('iv.ws')::uuid, '2026-09-01', '2026-09-30') $$,
  'September is prepared');
select is(
  (select lines from public.vat_declarations where id = pg_temp.sept()),
  '[{"percent": 20, "category": "S", "gross_cents": 12000, "net_cents": 10000, "vat_cents": 2000, "invoice_count": 1},
    {"percent": 20, "category": "S", "gross_cents": 23000, "net_cents": 20000, "vat_cents": 3000, "invoice_count": 2, "direction": "input"},
    {"percent": 10, "category": "S", "gross_cents": 1100, "net_cents": 1000, "vat_cents": 100, "invoice_count": 1, "direction": "input"}]'::jsonb,
  'the stored lines: the sales, then the deductible VAT per rate, marked input');
select is(
  (select array[total_net_cents, total_vat_cents, invoice_count]
     from public.vat_declarations where id = pg_temp.sept()),
  array[10000, -1100, 1],
  'the totals: the sales base, and 20.00 collected minus 31.00 deducted — a credit of 11.00');

select set_config('request.jwt.claims', '', true);
select pg_temp.flag(false);
select pg_temp.act_as('owner');
select is(
  (select count(*)::int from public.compute_vat_return(
     current_setting('iv.ws')::uuid, '2026-09-01', '2026-09-30') where direction = 'input'),
  0, 'with input VAT off, the return declares the VAT collected only');
select set_config('request.jwt.claims', '', true);
select pg_temp.flag(true);
select pg_temp.act_as('owner');

select lives_ok(
  $$ select public.mark_vat_declaration_submitted(pg_temp.sept(), 'manual', 'EFI-09') $$,
  'September is filed');
select is(
  (select array_agg(gross_cents order by gross_cents) from public.vat_return_entries
    where declaration_id = pg_temp.sept() and direction = 'input'),
  array[1100::bigint, 11000, 12000], 'the filing records each deductible amount, as input');

-- ------------------------------------------------------- the book
select set_config('iv.asset', public.save_book_account(current_setting('iv.ws')::uuid,
  current_setting('iv.site')::uuid, null, '445660', 'TVA déductible', 'asset', true, 'suggested', 0) ->> 'id', false);
select set_config('iv.liability', public.save_book_account(current_setting('iv.ws')::uuid,
  current_setting('iv.site')::uuid, null, '445710', 'TVA collectée', 'liability', true, 'suggested', 0) ->> 'id', false);
select lives_ok(
  format($$ select public.save_book_mapping(%L, %L, 'vat_input', %L, '2026-01-01', 0) $$,
         current_setting('iv.ws'), current_setting('iv.site'), current_setting('iv.asset')),
  'deductible VAT maps to an asset account');
select throws_like(
  format($$ select public.save_book_mapping(%L, %L, 'vat_input', %L, '2026-02-01', 0) $$,
         current_setting('iv.ws'), current_setting('iv.site'), current_setting('iv.liability')),
  '%books to a asset account%', 'never to the collected VAT''s liability');
select lives_ok(
  format($$ select public.save_book_mapping(%L, %L, 'vat_output', %L, '2026-01-01', 0) $$,
         current_setting('iv.ws'), current_setting('iv.site'), current_setting('iv.liability')),
  'and the collected VAT keeps its own role');
select throws_like(
  format($$ select public.save_book_mapping(%L, %L, 'vat_other', %L, '2026-01-01', 0) $$,
         current_setting('iv.ws'), current_setting('iv.site'), current_setting('iv.asset')),
  '%unknown role%', 'an unknown role is still refused');

select * from finish();
rollback;
