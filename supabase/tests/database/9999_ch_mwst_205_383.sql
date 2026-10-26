-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2360 (9999) -- the two Ziffern of the Swiss MWST return the lines did not
-- carry: 205 (supplies opted for, art. 22 MWSTG) and 383 (acquisition tax,
-- art. 45). A Swiss September holds an opted bare letting with a coffee
-- line (10 000.00 of its 11 000.00 is the letting), a package and a bare
-- letting that was not opted; and three expenses: two services bought
-- abroad (100.00 and 20.00 at 8.1 %, the second half deductible) and an
-- ordinary one. The expense keeps `acquisition`; the return files the tax
-- owed among the output, its deductible share among the input; the stored
-- taxed line states its opted part; the turnover and the document count
-- are the sales'. With input VAT off nothing of the expenses is declared;
-- on again, it is. The filing records the acquisition tax as output; a
-- plain member reads no return. The split's figures are pinned in Dart by
-- test/features/money/vat_return_parity_test.dart. Rolled back.
begin;
select plan(17);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-000000236001';
  u_m uuid := '00000000-0000-4000-8000-000000236002';
  ws uuid; mo uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'mwst-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_m]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by,
                                 vat_regime, feature_flags)
  values ('Bezug CH', 'CH', 'CHF', 'Europe/Zurich', u_o, 'vat_registered',
          '{"moneyTab": true, "invoicing": true, "vatManagement": true, "vatDeclarations": true, "inputVat": true}')
  returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_o, true, true) returning id into mo;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_m, false, false);

  -- Issued on 5 September, due then (the agreed consideration).
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name,
                               signature, kind, issued_at, vat_totals, legal_snapshot)
  values
    -- The bare letting, taxed under the option, and a coffee beside it.
    (ws, mo, mo, 'R-1', 'Room',
     '[{"label": "Room", "amount_cents": 10810, "vat_percent": 8.1, "vat_category": "S"},
       {"label": "Coffee", "amount_cents": 1081, "vat_percent": 8.1, "vat_category": "S", "supply": "general"}]',
     11891, 'CHF', 'M', 'Bezug CH', 'M', 's', 'full', '2026-09-05 10:00+00',
     '[{"percent": 8.1, "category": "S"}]',
     '{"seller_country": "CH", "land_taxation": {"bare_letting": true, "option_to_tax": true, "option_to_tax_date": "2026-01-01"}}'),
    -- A desk package.
    (ws, mo, mo, 'P-1', 'Desk',
     '[{"label": "Desk", "amount_cents": 5405, "vat_percent": 8.1, "vat_category": "S"}]',
     5405, 'CHF', 'M', 'Bezug CH', 'M', 's', 'full', '2026-09-05 10:00+00',
     '[{"percent": 8.1, "category": "S"}]',
     '{"seller_country": "CH", "land_taxation": {"bare_letting": false}}'),
    -- A bare letting without the option: exempt.
    (ws, mo, mo, 'E-1', 'Room',
     '[{"label": "Room", "amount_cents": 3000, "vat_percent": 0, "vat_category": "E"}]',
     3000, 'CHF', 'M', 'Bezug CH', 'M', 's', 'full', '2026-09-05 10:00+00',
     '[{"percent": 0, "category": "E"}]',
     '{"seller_country": "CH", "land_taxation": {"bare_letting": true, "option_to_tax": false}}');

  insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id,
                             payload, status, decided_at)
  values
    (ws, 'expense', 'submitted', mo, mo,
     '{"amount_cents": 10000, "category": "other", "note": "", "vat": {"percent": 8.1, "deductible_pct": 100, "acquisition": true}}',
     'confirmed', '2026-09-10 10:00+00'),
    (ws, 'expense', 'submitted', mo, mo,
     '{"amount_cents": 2000, "category": "other", "note": "", "vat": {"percent": 8.1, "deductible_pct": 50, "acquisition": true}}',
     'confirmed', '2026-09-12 10:00+00'),
    (ws, 'expense', 'submitted', mo, mo,
     '{"amount_cents": 2162, "category": "supplies", "note": "", "vat": {"percent": 8.1, "deductible_pct": 100}}',
     'confirmed', '2026-09-14 10:00+00');

  perform set_config('ch.ws', ws::text, false);
  perform set_config('ch.owner', u_o::text, false);
  perform set_config('ch.member', u_m::text, false);
end
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('ch.' || p_who), 'role', 'authenticated')::text, true);
end
$act$;

create or replace function pg_temp.flag(p_on boolean) returns void language sql as $f$
  update public.workspaces set feature_flags = feature_flags || jsonb_build_object('inputVat', p_on)
   where id = current_setting('ch.ws')::uuid;
$f$;

create or replace function pg_temp.sept() returns uuid language sql as $q$
  select id from public.vat_declarations
   where workspace_id = current_setting('ch.ws')::uuid and period_start = '2026-09-01';
$q$;

-- The stored line of [p_category], of the input tax or of the output.
create or replace function pg_temp.line(p_category text, p_input boolean) returns jsonb language sql as $q$
  select l from public.vat_declarations d cross join jsonb_array_elements(d.lines) l
   where d.id = pg_temp.sept() and l ->> 'category' = p_category
     and (l ->> 'direction' = 'input') is not distinct from (case when p_input then true end);
$q$;

select pg_temp.seed();

-- ------------------------------------------------------- the split
select is(
  (select array[tax_cents, deductible_cents] from public.vat_acquisition_split(10000, 8.1, 100)),
  array[810::bigint, 810], '8.1 % of 100.00 is owed, all of it deductible');
select is(
  (select array_agg(x order by o) from (
     select 1 as o, array[tax_cents, deductible_cents] as x from public.vat_acquisition_split(2000, 8.1, 50)
     union all select 2, array[tax_cents, deductible_cents] from public.vat_acquisition_split(500, 8.1, 50)
     union all select 3, array[tax_cents, deductible_cents] from public.vat_acquisition_split(-1000, 8.1, 100)) q),
  array[array[162::bigint, 81], array[41::bigint, 21], array[-81::bigint, -81]],
  'half of 16.20; 40.50 and 20.25 rounded half away from zero; a credit is negative');

-- ------------------------------------------------------- the expense form
select pg_temp.act_as('owner');
select set_config('ch.e1', public.submit_expense(current_setting('ch.ws')::uuid, 5000, 'other',
  'Software', null, '{"percent": 8.1, "acquisition": true}')::text, false);
select is(
  (select payload -> 'vat' from public.events where id = current_setting('ch.e1')::uuid),
  '{"percent": 8.1, "deductible_pct": 100, "acquisition": true}'::jsonb,
  'an expense bought abroad says so');
select set_config('ch.e2', public.submit_expense(current_setting('ch.ws')::uuid, 5000, 'other',
  'Paper', null, '{"percent": 8.1, "acquisition": false}')::text, false);
select is(
  (select payload -> 'vat' from public.events where id = current_setting('ch.e2')::uuid),
  '{"percent": 8.1, "deductible_pct": 100}'::jsonb,
  'an ordinary one carries no flag');
select set_config('request.jwt.claims', '', true);
select pg_temp.flag(false);
select pg_temp.act_as('owner');
select throws_like(
  $$ select public.submit_expense(current_setting('ch.ws')::uuid, 5000, 'other', '', null,
                                  '{"percent": 8.1, "acquisition": true}') $$,
  '%switched off%', 'with input VAT off, an expense states no acquisition either');
select set_config('request.jwt.claims', '', true);
select pg_temp.flag(true);

-- ------------------------------------------------------- the return
select pg_temp.act_as('owner');
select results_eq(
  $$ select direction, percent, category, tax_point, gross_cents, net_cents, vat_cents, invoice_count
       from public.compute_vat_return(current_setting('ch.ws')::uuid, '2026-09-01', '2026-09-30')
      order by direction collate "C", category collate "C", tax_point $$,
  $$ values ('input'::text, 8.1::numeric, 'S'::text, '2026-09-10'::date, 10810::bigint, 10000::bigint, 810::bigint, 1),
            ('input', 8.1, 'S', '2026-09-12', 2081, 2000, 81, 1),
            ('input', 8.1, 'S', '2026-09-14', 2162, 2000, 162, 1),
            ('output', 0, 'E', '2026-09-05', 3000, 3000, 0, 1),
            ('output', 8.1, 'S', '2026-09-05', 17296, 16000, 1296, 2),
            ('output', 8.1, 'acquisition', '2026-09-10', 10810, 10000, 810, 1),
            ('output', 8.1, 'acquisition', '2026-09-12', 2162, 2000, 162, 1) $$,
  'September: the sales, the acquisition tax owed as output, its deductible share as input');

select lives_ok(
  $$ select public.save_vat_declaration(current_setting('ch.ws')::uuid, '2026-09-01', '2026-09-30') $$,
  'September is prepared');
select is((pg_temp.line('S', false) ->> 'opted_net_cents')::int, 10000,
  'the taxed line states its opted part: the letting, not the coffee, not the package');
select is(pg_temp.line('E', false) ? 'opted_net_cents', false,
  'a bare letting that was not opted is exempt, and no part of it was opted for');
select is(pg_temp.line('acquisition', false),
  '{"percent": 8.1, "category": "acquisition", "gross_cents": 12972, "net_cents": 12000, "vat_cents": 972, "invoice_count": 2}'::jsonb,
  'the acquisition tax is one output line per rate: 97.20 on 120.00');
select is(pg_temp.line('S', true) - 'direction',
  '{"percent": 8.1, "category": "S", "gross_cents": 15053, "net_cents": 14000, "vat_cents": 1053, "invoice_count": 3}'::jsonb,
  'and its deductible share is input tax beside the ordinary expense''s');
select is(
  (select array[total_net_cents, total_vat_cents, invoice_count]
     from public.vat_declarations where id = pg_temp.sept()),
  array[19000, 1215, 3],
  'the turnover and the documents are the sales''; the tax is 12.96 + 9.72 owed less 10.53 deducted');

select set_config('request.jwt.claims', '', true);
select pg_temp.flag(false);
select pg_temp.act_as('owner');
select is(
  (select count(*)::int from public.compute_vat_return(
     current_setting('ch.ws')::uuid, '2026-09-01', '2026-09-30')
    where direction = 'input' or category = 'acquisition'),
  0, 'with input VAT off, nothing of the expenses is declared');
select set_config('request.jwt.claims', '', true);
select pg_temp.flag(true);
select pg_temp.act_as('owner');
select is(
  (select count(*)::int from public.compute_vat_return(
     current_setting('ch.ws')::uuid, '2026-09-01', '2026-09-30')
    where category = 'acquisition'),
  2, 'on again, the acquisition tax is back');

select lives_ok(
  $$ select public.mark_vat_declaration_submitted(pg_temp.sept(), 'manual', 'ESTV-09') $$,
  'September is filed');
select is(
  (select array_agg(gross_cents order by gross_cents) from public.vat_return_entries
    where declaration_id = pg_temp.sept() and category = 'acquisition' and direction = 'output'),
  array[2162::bigint, 10810], 'the filing records the acquisition tax as output');

select pg_temp.act_as('member');
select throws_like(
  $$ select * from public.compute_vat_return(current_setting('ch.ws')::uuid, '2026-09-01', '2026-09-30') $$,
  '%not allowed%', 'a plain member reads no return');

select * from finish();
rollback;
