-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2357 — a filed VAT period is locked (0403, ADR 0039). A German space
-- files September; an invoice of that September is voided in October.
-- The filed row stays byte-identical, September's recomputation no
-- longer holds the invoice, and October's return carries the difference
-- as a correction line naming the September return. Filing October
-- records it, so November corrects nothing again. A period that
-- overlaps the filed one is refused; what a return declared is written
-- only by its filing, never changed, readable by whoever reads the
-- finances, and goes only with its return. The same figures are pinned
-- in Dart by test/features/money/vat_return_parity_test.dart.
begin;
select plan(22);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-000000235711';
  u_m uuid := '00000000-0000-4000-8000-000000235712';
  ws uuid; mo uuid; d1 uuid;
  de_legal jsonb := '{"seller_country": "DE", "vat_exigibility": "invoice"}';
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'vatlock-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_m]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, vat_regime)
  values ('Locks DE', 'DE', 'EUR', 'Europe/Berlin', u_o, 'vat_registered') returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_o, true, true) returning id into mo;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_m, false, false);

  -- D-1: a September service paid on 2 September. D-3: a September
  -- service, unpaid (due at the end of September). D-5: an October one.
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name,
                               signature, kind, period, issued_at, vat_totals, legal_snapshot)
  values (ws, mo, mo, 'D-1', 'Paid', '[{"label": "Desk", "amount_cents": 12000, "vat_percent": 19}]',
          12000, 'EUR', 'M', 'Locks DE', 'M', 's', 'full', '2026-09', '2026-08-25 10:00+00',
          '[{"percent": 19, "category": "S"}]', de_legal)
  returning id into d1;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name,
                               signature, kind, period, issued_at, vat_totals, legal_snapshot)
  values (ws, mo, mo, 'D-3', 'Unpaid', '[{"label": "Desk", "amount_cents": 5950, "vat_percent": 19}]',
          5950, 'EUR', 'M', 'Locks DE', 'M', 's', 'usage', '2026-09', '2026-08-25 10:00+00',
          '[{"percent": 19, "category": "S"}]', de_legal),
         (ws, mo, mo, 'D-5', 'October', '[{"label": "Desk", "amount_cents": 2380, "vat_percent": 19}]',
          2380, 'EUR', 'M', 'Locks DE', 'M', 's', 'full', '2026-10', '2026-09-25 10:00+00',
          '[{"percent": 19, "category": "S"}]', de_legal);
  insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution, matched_at)
  values (ws, d1, 12000, 'exact', '2026-09-02 10:00+00');

  perform set_config('vl.ws', ws::text, false);
  perform set_config('vl.owner', u_o::text, false);
  perform set_config('vl.member', u_m::text, false);
end
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('vl.' || p_who), 'role', 'authenticated')::text, true);
end
$act$;

create or replace function pg_temp.decl(p_start date) returns uuid language sql as $q$
  select id from public.vat_declarations
   where workspace_id = current_setting('vl.ws')::uuid and period_start = p_start;
$q$;

create or replace function pg_temp.row_md5(p_start date) returns text language sql as $q$
  select md5(to_jsonb(d)::text) from public.vat_declarations d
   where workspace_id = current_setting('vl.ws')::uuid and period_start = p_start;
$q$;

select pg_temp.seed();

-- ------------------------------------------------------- September, filed
select pg_temp.act_as('owner');
select lives_ok(
  $$ select public.save_vat_declaration(current_setting('vl.ws')::uuid, '2026-09-01', '2026-09-30') $$,
  'September is prepared');
select lives_ok(
  $$ select public.mark_vat_declaration_submitted(pg_temp.decl('2026-09-01'), 'manual', 'ELSTER-09') $$,
  'and filed with its receipt');
select is(
  (select array_agg(gross_cents order by gross_cents) from public.vat_return_entries
    where declaration_id = pg_temp.decl('2026-09-01')),
  array[5950::bigint, 12000], 'the filing records what September declared, per invoice');
select set_config('vl.filed_md5', pg_temp.row_md5('2026-09-01'), false);
select set_config('vl.filed_lines', (select lines::text from public.vat_declarations
                                      where id = pg_temp.decl('2026-09-01')), false);

select is(
  (select count(*)::int from public.compute_vat_return(
     current_setting('vl.ws')::uuid, '2026-10-01', '2026-10-31') where correction),
  0, 'nothing changed in September: October corrects nothing');

-- ------------------------------------------- a September invoice voided
select set_config('request.jwt.claims', '', true);
update public.invoices set voided_at = '2026-10-05 10:00+00', voided_by_name = 'M'
 where workspace_id = current_setting('vl.ws')::uuid and number = 'D-3';
select pg_temp.act_as('owner');

select is(pg_temp.row_md5('2026-09-01'), current_setting('vl.filed_md5'),
  'the filed September row is byte-identical after the void');
select is(
  (select lines::text from public.vat_declarations where id = pg_temp.decl('2026-09-01')),
  current_setting('vl.filed_lines'), 'its lines still say what was filed');
select results_eq(
  $$ select tax_point, gross_cents, correction from public.compute_vat_return(
       current_setting('vl.ws')::uuid, '2026-09-01', '2026-09-30') $$,
  $$ values ('2026-09-02'::date, 12000::bigint, false) $$,
  'recomputed, September no longer holds the voided invoice');
select results_eq(
  $$ select percent, category, tax_point, credit_note, correction, corrects,
            gross_cents, net_cents, vat_cents, invoice_count
       from public.compute_vat_return(current_setting('vl.ws')::uuid, '2026-10-01', '2026-10-31') $$,
  $$ values (19::numeric, 'S'::text, '2026-10-31'::date, false, false, null::uuid,
             2380::bigint, 2000::bigint, 380::bigint, 1),
            (19, 'S', '2026-09-30', false, true, pg_temp.decl('2026-09-01'),
             -5950, -5000, -950, 1) $$,
  'October: its own line, and the void as a correction of the September return');

select throws_like(
  $$ select public.save_vat_declaration(current_setting('vl.ws')::uuid, '2026-07-01', '2026-09-30') $$,
  '%overlaps a filed return%', 'a quarter overlapping the filed September is refused');
select throws_like(
  $$ select public.save_vat_declaration(current_setting('vl.ws')::uuid, '2026-09-01', '2026-09-30') $$,
  '%already filed%', 'and September itself is not prepared again');

-- ------------------------------------------------ October carries it
select lives_ok(
  $$ select public.save_vat_declaration(current_setting('vl.ws')::uuid, '2026-10-01', '2026-10-31') $$,
  'October is prepared');
select is(
  (select lines from public.vat_declarations where id = pg_temp.decl('2026-10-01')),
  jsonb_build_array(
    '{"percent": 19, "category": "S", "gross_cents": 2380, "net_cents": 2000, "vat_cents": 380, "invoice_count": 1}'::jsonb,
    jsonb_build_object('percent', 19, 'category', 'S', 'gross_cents', -5950, 'net_cents', -5000,
                       'vat_cents', -950, 'invoice_count', 1, 'correction', true,
                       'corrects', pg_temp.decl('2026-09-01'),
                       'corrects_start', '2026-09-01', 'corrects_end', '2026-09-30')),
  'the stored lines: October''s own, then the correction naming the September return');
select is(
  (select array[total_net_cents, total_vat_cents, invoice_count]
     from public.vat_declarations where id = pg_temp.decl('2026-10-01')),
  array[-3000, -570, 2], 'the totals net the correction off the period''s own VAT');
select lives_ok(
  $$ select public.mark_vat_declaration_submitted(pg_temp.decl('2026-10-01'), 'manual', 'ELSTER-10') $$,
  'October is filed');
select is(
  (select count(*)::int from public.compute_vat_return(
     current_setting('vl.ws')::uuid, '2026-11-01', '2026-11-30')),
  0, 'November corrects nothing again: the correction was declared once');
select is(pg_temp.row_md5('2026-09-01'), current_setting('vl.filed_md5'),
  'and September is still byte-identical');

-- ------------------------------------------------ the ledger is the filing's
select set_config('request.jwt.claims', '', true);
select throws_like(
  $$ insert into public.vat_return_entries (workspace_id, declaration_id, invoice_id, tax_point,
                                            percent, gross_cents, net_cents)
     values (current_setting('vl.ws')::uuid, pg_temp.decl('2026-09-01'), gen_random_uuid(),
             '2026-09-30', 19, 100, 84) $$,
  '%recorded only by its filing%', 'nothing but a filing writes what a return declared');
select throws_like(
  $$ update public.vat_return_entries set gross_cents = 0
      where declaration_id = pg_temp.decl('2026-09-01') $$,
  '%immutable%', 'it is never changed');
select throws_like(
  $$ delete from public.vat_return_entries where declaration_id = pg_temp.decl('2026-09-01') $$,
  '%immutable%', 'nor deleted on its own');

select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('vl.owner'), 'role', 'authenticated')::text, true);
set local role authenticated;
select is((select count(*)::int from public.vat_return_entries
            where workspace_id = current_setting('vl.ws')::uuid),
  4, 'the owner reads what September and October declared');
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('vl.member'), 'role', 'authenticated')::text, true);
select is((select count(*)::int from public.vat_return_entries
            where workspace_id = current_setting('vl.ws')::uuid),
  0, 'a member without viewFinances reads none of it');
reset role;

delete from public.vat_declarations where id = pg_temp.decl('2026-10-01');
select is((select count(*)::int from public.vat_return_entries
            where workspace_id = current_setting('vl.ws')::uuid),
  2, 'the entries go with their return (the cascade passes the guard)');

select * from finish();
rollback;
