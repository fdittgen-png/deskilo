-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2357 — the server computes the VAT return (0402). compute_vat_return
-- is the SQL twin of the Dart tax-point engine: a French month on
-- receipts keeps S, AE, E and Z apart and a refunded credit note on its
-- own line, declares half of a half-paid two-rate invoice, dates an
-- invoice that printed the debits option at its issue, allocates a
-- settlement's payment to its source and counts neither the settlement
-- nor a voided or unpaid invoice; a German month on the service period
-- dates a September service paid on 2 September in September and one
-- paid on 20 August in August (the same fixtures and figures as
-- test/features/money/vat_return_parity_test.dart). save_vat_declaration
-- stores those figures whatever the client sends; a trigger refuses any
-- direct change; mark_vat_declaration_submitted is the only writer of a
-- filing, needs the authority's receipt and refuses the platform channel
-- and a period that changed since the return was prepared.
begin;
select plan(31);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_fr uuid := '00000000-0000-4000-8000-000000235701';
  u_de uuid := '00000000-0000-4000-8000-000000235702';
  u_m  uuid := '00000000-0000-4000-8000-000000235703';
  u_x  uuid := '00000000-0000-4000-8000-000000235704';
  fr uuid; de uuid; other uuid; mf uuid; mf2 uuid; md uuid; md2 uuid;
  a uuid; g uuid := gen_random_uuid(); s uuid; cn uuid; b uuid; c uuid; d uuid;
  d1 uuid; d2 uuid; pay1 uuid; pay2 uuid;
  fr_legal jsonb := '{"seller_country": "FR", "vat_exigibility": "payment"}';
  de_legal jsonb := '{"seller_country": "DE", "vat_exigibility": "invoice"}';
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'vatreturn-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_fr, u_de, u_m, u_x]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, vat_regime)
  values ('Return FR', 'FR', 'EUR', 'Europe/Paris', u_fr, 'vat_registered') returning id into fr;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, vat_regime)
  values ('Return DE', 'DE', 'EUR', 'Europe/Berlin', u_de, 'vat_registered') returning id into de;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, vat_regime)
  values ('Elsewhere', 'FR', 'EUR', 'Europe/Paris', u_x, 'vat_registered') returning id into other;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (fr, u_fr, true, true) returning id into mf;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (fr, u_m, false, false) returning id into mf2;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (de, u_de, true, true) returning id into md;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (de, u_m, false, false) returning id into md2;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (other, u_x, true, true);

  -- ---------------------------------------------------------------- France
  -- A: 120.00 at 20 % + 33.00 at 10 %, issued in August, paid half on
  -- 5 September and half on 3 October.
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name,
                               signature, kind, issued_at, vat_totals, legal_snapshot)
  values (fr, mf, mf, 'F-A', 'Two rates',
          '[{"label": "Desk", "amount_cents": 12000, "vat_percent": 20},
            {"label": "Coffee", "amount_cents": 3300, "vat_percent": 10}]',
          15300, 'EUR', 'M', 'Return FR', 'M', 's', 'full', '2026-08-20 10:00+00',
          '[{"percent": 20, "category": "S"}, {"percent": 10, "category": "S"}]', fr_legal)
  returning id into a;
  -- B, C, D: zero-rated for three different reasons.
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name,
                               signature, kind, issued_at, vat_totals, legal_snapshot)
  values (fr, mf, mf, 'F-AE', 'Reverse charge', '[{"label": "Office", "amount_cents": 50000, "vat_percent": 0}]',
          50000, 'EUR', 'M', 'Return FR', 'M', 's', 'full', '2026-09-10 10:00+00',
          '[{"percent": 0, "category": "AE"}]', fr_legal)
  returning id into b;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name,
                               signature, kind, issued_at, vat_totals, legal_snapshot)
  values (fr, mf, mf, 'F-E', 'Exempt', '[{"label": "Training", "amount_cents": 8000, "vat_percent": 0}]',
          8000, 'EUR', 'M', 'Return FR', 'M', 's', 'full', '2026-09-15 10:00+00',
          '[{"percent": 0, "category": "E"}]', fr_legal)
  returning id into c;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name,
                               signature, kind, issued_at, vat_totals, legal_snapshot)
  values (fr, mf, mf, 'F-Z', 'Zero rated', '[{"label": "Books", "amount_cents": 3000, "vat_percent": 0}]',
          3000, 'EUR', 'M', 'Return FR', 'M', 's', 'full', '2026-09-16 10:00+00',
          '[{"percent": 0, "category": "Z"}]', fr_legal)
  returning id into d;
  -- A credit note of 24.00 at 20 %, refunded on 25 September.
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name,
                               signature, kind, issued_at, vat_totals, legal_snapshot)
  values (fr, mf, mf, 'CN-1', 'Credit', '[{"label": "Refund", "amount_cents": -2400, "vat_percent": 20}]',
          -2400, 'EUR', 'M', 'Return FR', 'M', 's', 'full', '2026-09-18 10:00+00',
          '[{"percent": 20, "category": "S"}]', fr_legal)
  returning id into cn;
  -- A settlement of G, paid on 8 September: G declares, the settlement not.
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name,
                               signature, kind, issued_at, vat_totals, legal_snapshot, settles)
  values (fr, mf, mf, 'S-1', 'Settlement', '[{"label": "F-G", "amount_cents": 2400, "vat_percent": 20}]',
          2400, 'EUR', 'M', 'Return FR', 'M', 's', 'settlement', '2026-09-01 10:00+00',
          '[{"percent": 20, "category": "S"}]', fr_legal,
          jsonb_build_array(jsonb_build_object('invoice_id', g, 'number', 'F-G', 'total_cents', 2400)))
  returning id into s;
  insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name,
                               signature, kind, issued_at, vat_totals, legal_snapshot, settled_by_invoice_id)
  values (g, fr, mf, mf, 'F-G', 'Regrouped', '[{"label": "Desk", "amount_cents": 2400, "vat_percent": 20}]',
          2400, 'EUR', 'M', 'Return FR', 'M', 's', 'full', '2026-08-25 10:00+00',
          '[{"percent": 20, "category": "S"}]', fr_legal, s);
  -- An invoice that printed « option pour les débits »: the frozen
  -- exigibility wins over the space's receipts, so it is due unpaid.
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name,
                               signature, kind, issued_at, vat_totals, legal_snapshot)
  values (fr, mf, mf, 'F-D', 'Debits', '[{"label": "Desk", "amount_cents": 1200, "vat_percent": 20}]',
          1200, 'EUR', 'M', 'Return FR', 'M', 's', 'full', '2026-09-22 10:00+00',
          '[{"percent": 20, "category": "S"}]', '{"seller_country": "FR", "vat_exigibility": "invoice"}');
  -- Voided, and unpaid: neither declares on receipts.
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name,
                               signature, kind, issued_at, vat_totals, legal_snapshot, voided_at)
  values (fr, mf, mf, 'F-V', 'Voided', '[{"label": "Desk", "amount_cents": 9900, "vat_percent": 20}]',
          9900, 'EUR', 'M', 'Return FR', 'M', 's', 'full', '2026-09-03 10:00+00',
          '[{"percent": 20, "category": "S"}]', fr_legal, '2026-09-04 10:00+00'),
         (fr, mf, mf, 'F-U', 'Unpaid', '[{"label": "Desk", "amount_cents": 6000, "vat_percent": 20}]',
          6000, 'EUR', 'M', 'Return FR', 'M', 's', 'full', '2026-09-20 10:00+00',
          '[{"percent": 20, "category": "S"}]', fr_legal, null);

  insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
  values (fr, mf, 'credit', 'payment', 7650, 'transfer', '2026-09') returning id into pay1;
  insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
  values (fr, mf, 'credit', 'payment', 7650, 'transfer', '2026-10') returning id into pay2;
  insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution, matched_at)
  values (fr, a, 15300, 'exact', '2026-10-03 10:00+00'),
         (fr, b, 50000, 'exact', '2026-09-12 10:00+00'),
         (fr, c, 8000, 'exact', '2026-09-15 10:00+00'),
         (fr, d, 3000, 'exact', '2026-09-20 10:00+00'),
         (fr, cn, 2400, 'exact', '2026-09-25 10:00+00'),
         (fr, s, 2400, 'exact', '2026-09-08 10:00+00');
  insert into public.invoice_match_payments (workspace_id, invoice_id, payment_ledger_id,
                                             amount_cents, resolution, matched_at)
  values (fr, a, pay1, 7650, 'exact', '2026-09-05 10:00+00'),
         (fr, a, pay2, 7650, 'exact', '2026-10-03 10:00+00');

  -- --------------------------------------------------------------- Germany
  -- Three September services at 19 %: paid on 2 September, paid on
  -- 20 August (before the service), and unpaid.
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name,
                               signature, kind, period, issued_at, vat_totals, legal_snapshot)
  values (de, md, md, 'D-1', 'Paid in September', '[{"label": "Desk", "amount_cents": 12000, "vat_percent": 19}]',
          12000, 'EUR', 'M', 'Return DE', 'M', 's', 'full', '2026-09', '2026-08-25 10:00+00',
          '[{"percent": 19, "category": "S"}]', de_legal)
  returning id into d1;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name,
                               signature, kind, period, issued_at, vat_totals, legal_snapshot)
  values (de, md, md, 'D-2', 'Paid in August', '[{"label": "Desk", "amount_cents": 12000, "vat_percent": 19}]',
          12000, 'EUR', 'M', 'Return DE', 'M', 's', 'usage', '2026-09', '2026-08-25 10:00+00',
          '[{"percent": 19, "category": "S"}]', de_legal)
  returning id into d2;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name,
                               signature, kind, period, issued_at, vat_totals, legal_snapshot)
  values (de, md, md, 'D-3', 'Unpaid', '[{"label": "Desk", "amount_cents": 5950, "vat_percent": 19}]',
          5950, 'EUR', 'M', 'Return DE', 'M', 's', 'subscription', '2026-09', '2026-08-25 10:00+00',
          '[{"percent": 19, "category": "S"}]', de_legal);
  insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution, matched_at)
  values (de, d1, 12000, 'exact', '2026-09-02 10:00+00'),
         (de, d2, 12000, 'exact', '2026-08-20 10:00+00');

  perform set_config('vr.fr', fr::text, false);
  perform set_config('vr.de', de::text, false);
  perform set_config('vr.md2', md2::text, false);
  perform set_config('vr.owner_fr', u_fr::text, false);
  perform set_config('vr.owner_de', u_de::text, false);
  perform set_config('vr.member', u_m::text, false);
  perform set_config('vr.stranger', u_x::text, false);
end
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('vr.' || p_who), 'role', 'authenticated')::text, true);
end
$act$;

create or replace function pg_temp.fr_decl() returns uuid language sql as $q$
  select id from public.vat_declarations
   where workspace_id = current_setting('vr.fr')::uuid and period_start = '2026-09-01';
$q$;

select pg_temp.seed();

-- ------------------------------------------------------- the computation
select pg_temp.act_as('owner_fr');
select results_eq(
  $$ select percent, category, tax_point, credit_note, gross_cents, net_cents, vat_cents, invoice_count
       from public.compute_vat_return(current_setting('vr.fr')::uuid, '2026-09-01', '2026-09-30') $$,
  $$ values (20::numeric, 'S'::text, '2026-09-05'::date, false, 6000::bigint, 5000::bigint, 1000::bigint, 1),
            (20, 'S', '2026-09-08', false, 2400, 2000, 400, 1),
            (20, 'S', '2026-09-22', false, 1200, 1000, 200, 1),
            (20, 'S', '2026-09-25', true, -2400, -2000, -400, 1),
            (10, 'S', '2026-09-05', false, 1650, 1500, 150, 1),
            (0, 'AE', '2026-09-12', false, 50000, 50000, 0, 1),
            (0, 'E', '2026-09-15', false, 8000, 8000, 0, 1),
            (0, 'Z', '2026-09-20', false, 3000, 3000, 0, 1) $$,
  'France, September on receipts: a line per rate, category, tax point and credit note');
select is(
  (select count(distinct category)::int from public.compute_vat_return(
     current_setting('vr.fr')::uuid, '2026-09-01', '2026-09-30') where percent = 0),
  3, 'reverse charge, exempt and zero-rated stay three lines at 0 %');
select is(
  (select array_agg(gross_cents) from public.compute_vat_return(
     current_setting('vr.fr')::uuid, '2026-09-01', '2026-09-30') where credit_note),
  array[-2400::bigint], 'the refunded credit note is a line of its own, negative');
select is(
  (select gross_cents from public.compute_vat_return(
     current_setting('vr.fr')::uuid, '2026-09-01', '2026-09-30') where tax_point = '2026-09-22'),
  1200::bigint, 'an invoice that printed the debits option is due when issued, unpaid');
select is(
  (select sum(gross_cents)::bigint from public.compute_vat_return(
     current_setting('vr.fr')::uuid, '2026-09-01', '2026-09-30') where tax_point = '2026-09-05'),
  7650::bigint, 'half paid: half of the two-rate invoice is due in September');
select results_eq(
  $$ select percent, gross_cents, net_cents from public.compute_vat_return(
       current_setting('vr.fr')::uuid, '2026-10-01', '2026-10-31') $$,
  $$ values (20::numeric, 6000::bigint, 5000::bigint), (10, 1650, 1500) $$,
  'and the other half in October, adding up to the invoice to the cent');
select is(
  (select count(*)::int from public.compute_vat_return(
     current_setting('vr.fr')::uuid, '2026-08-01', '2026-08-31')),
  0, 'nothing is due in August on receipts: issued is not paid');

select pg_temp.act_as('owner_de');
select results_eq(
  $$ select percent, category, tax_point, credit_note, gross_cents, net_cents, vat_cents, invoice_count
       from public.compute_vat_return(current_setting('vr.de')::uuid, '2026-09-01', '2026-09-30') $$,
  $$ values (19::numeric, 'S'::text, '2026-09-02'::date, false, 12000::bigint, 10084::bigint, 1916::bigint, 1),
            (19, 'S', '2026-09-30', false, 5950, 5000, 950, 1) $$,
  'Germany: a September service paid on 2 September is September; unpaid, the end of the month');
select results_eq(
  $$ select tax_point, gross_cents, vat_cents
       from public.compute_vat_return(current_setting('vr.de')::uuid, '2026-08-01', '2026-08-31') $$,
  $$ values ('2026-08-20'::date, 12000::bigint, 1916::bigint) $$,
  'paid on 20 August, before the service: August (Mindest-Ist)');

select pg_temp.act_as('member');
select throws_like(
  $$ select * from public.compute_vat_return(current_setting('vr.fr')::uuid, '2026-09-01', '2026-09-30') $$,
  '%not allowed%', 'a member without viewFinances reads no return');
select pg_temp.act_as('stranger');
select throws_like(
  $$ select * from public.compute_vat_return(current_setting('vr.fr')::uuid, '2026-09-01', '2026-09-30') $$,
  '%not allowed%', 'nor does the owner of another workspace');

-- ------------------------------------------------ the save takes no figures
select pg_temp.act_as('owner_fr');
select lives_ok(
  $$ select public.save_vat_declaration(current_setting('vr.fr')::uuid, '2026-09-01', '2026-09-30',
       '[{"percent": 20, "gross_cents": 999999, "net_cents": 999999, "vat_cents": 0, "invoice_count": 99}]',
       999999, 999999, 'USD', 99) $$,
  'an older client still saves with its own figures');
select is(
  (select lines from public.vat_declarations where id = pg_temp.fr_decl()),
  '[{"percent": 20, "category": "S", "gross_cents": 7200, "net_cents": 6000, "vat_cents": 1200, "invoice_count": 4},
    {"percent": 10, "category": "S", "gross_cents": 1650, "net_cents": 1500, "vat_cents": 150, "invoice_count": 1},
    {"percent": 0, "category": "AE", "gross_cents": 50000, "net_cents": 50000, "vat_cents": 0, "invoice_count": 1},
    {"percent": 0, "category": "E", "gross_cents": 8000, "net_cents": 8000, "vat_cents": 0, "invoice_count": 1},
    {"percent": 0, "category": "Z", "gross_cents": 3000, "net_cents": 3000, "vat_cents": 0, "invoice_count": 1}]'::jsonb,
  'but the stored lines are the server''s, per rate and category');
select is(
  (select array[total_net_cents, total_vat_cents, invoice_count]
     from public.vat_declarations where id = pg_temp.fr_decl()),
  array[68500, 1350, 7],
  'totals are the server''s; the settlement, the voided and the unpaid invoice count for nothing');
select is(
  (select status || ' ' || currency from public.vat_declarations where id = pg_temp.fr_decl()),
  'prepared EUR', 'the return is prepared, in the workspace''s currency');
select lives_ok(
  $$ select public.save_vat_declaration(current_setting('vr.fr')::uuid, '2026-09-01', '2026-09-30') $$,
  'a newer client sends the period alone, and preparing again is allowed');

-- --------------------------------------------- nothing changes it directly
select set_config('request.jwt.claims', '', true);
select throws_like(
  $$ update public.vat_declarations set total_vat_cents = 1 where id = pg_temp.fr_decl() $$,
  '%come only from compute_vat_return%', 'a direct change of the figures is refused');
select throws_like(
  $$ update public.vat_declarations set status = 'filed', submitted_channel = 'platform'
      where id = pg_temp.fr_decl() $$,
  '%filed only through mark_vat_declaration_submitted%',
  'a direct filing (what the upload channel did) is refused');
select throws_like(
  $$ insert into public.vat_declarations (workspace_id, period_start, period_end, status, lines,
                                          total_net_cents, total_vat_cents)
     values (current_setting('vr.fr')::uuid, '2026-07-01', '2026-07-31', 'filed', '[]', 0, 0) $$,
  '%filed only through mark_vat_declaration_submitted%', 'and so is inserting a filed return');
select is(
  (select status || ' ' || total_vat_cents from public.vat_declarations where id = pg_temp.fr_decl()),
  'prepared 1350', 'the row is unchanged');

-- ------------------------------------------------------- the only filing
select pg_temp.act_as('owner_fr');
select throws_like(
  $$ select public.mark_vat_declaration_submitted(pg_temp.fr_decl(), 'platform', 'ACK-1') $$,
  '%unknown channel%', 'the platform channel is gone');
select throws_like(
  $$ select public.mark_vat_declaration_submitted(pg_temp.fr_decl(), 'manual', '  ') $$,
  '%receipt reference%', 'filing needs the authority''s receipt reference');
select lives_ok(
  $$ select public.mark_vat_declaration_submitted(pg_temp.fr_decl(), 'manual', 'EFI-2026-09-0042') $$,
  'the owner records the filing with its receipt');
select is(
  (select status || ' ' || submitted_channel || ' ' || submitted_receipt || ' ' || (number like 'DECL-%')::text
     from public.vat_declarations where id = pg_temp.fr_decl()),
  'filed manual EFI-2026-09-0042 true', 'filed, numbered, with the receipt');
select throws_like(
  $$ select public.save_vat_declaration(current_setting('vr.fr')::uuid, '2026-09-01', '2026-09-30') $$,
  '%already filed%', 'a filed period is not prepared again');

select set_config('deskilo.vat_return_writer', 'file:' || pg_temp.fr_decl(), true);
select throws_like(
  $$ update public.vat_declarations set submitted_receipt = 'forged' where id = pg_temp.fr_decl() $$,
  '%immutable%', 'a filed return never moves, even with the writer''s token');
select set_config('deskilo.vat_return_writer', '', true);

-- ----------------------------------------- a stale or legacy return
select pg_temp.act_as('owner_de');
select lives_ok(
  $$ select public.save_vat_declaration(current_setting('vr.de')::uuid, '2026-09-01', '2026-09-30') $$,
  'Germany prepares September');
select set_config('request.jwt.claims', '', true);
insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                             total_cents, currency, member_name, workspace_name, issuer_name,
                             signature, kind, period, issued_at, vat_totals,
                             legal_snapshot)
values (current_setting('vr.de')::uuid, current_setting('vr.md2')::uuid,
        current_setting('vr.md2')::uuid, 'D-4', 'Late', '[{"label": "Desk", "amount_cents": 1190, "vat_percent": 19}]',
        1190, 'EUR', 'M', 'Return DE', 'M', 's', 'full', '2026-09', '2026-10-02 10:00+00',
        '[{"percent": 19, "category": "S"}]', '{"seller_country": "DE", "vat_exigibility": "invoice"}');
select pg_temp.act_as('owner_de');
select throws_like(
  $$ select public.mark_vat_declaration_submitted(
       (select id from public.vat_declarations where workspace_id = current_setting('vr.de')::uuid
          and period_start = '2026-09-01'), 'manual', 'ELSTER-1') $$,
  '%changed since this return was prepared%',
  'a September invoice issued after preparing: the stale figures are not filed');
select set_config('request.jwt.claims', '', true);
insert into public.vat_declarations (workspace_id, period_start, period_end, lines,
                                     total_net_cents, total_vat_cents)
values (current_setting('vr.de')::uuid, '2026-07-01', '2026-07-31', '[]', 0, 0);
select pg_temp.act_as('owner_de');
select throws_like(
  $$ select public.mark_vat_declaration_submitted(
       (select id from public.vat_declarations where workspace_id = current_setting('vr.de')::uuid
          and period_start = '2026-07-01'), 'manual', 'ELSTER-2') $$,
  '%prepare the return%', 'a draft from an older client is prepared before it can be filed');
select lives_ok(
  $$ select public.save_vat_declaration(current_setting('vr.de')::uuid, '2026-07-01', '2026-07-31') $$,
  'and preparing it replaces its figures with the server''s');
select is(
  (select status || ' ' || jsonb_array_length(lines) from public.vat_declarations
    where workspace_id = current_setting('vr.de')::uuid and period_start = '2026-07-01'),
  'prepared 0', 'an empty July, prepared');

reset role;
select * from finish();
rollback;
