-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2358 (0678) — the Verifactu records are chained by their huella.
--
-- The huella functions reproduce the three examples the AEAT publishes in
-- "Detalle de las especificaciones técnicas para generación de la huella"
-- (a first alta, a second alta chained on it, an anulación chained on that),
-- stated here as published. `record_verifactu_v1` keeps one chain per issuer:
-- each record hashes its predecessor's huella, a second call answers the
-- record kept, an anulación follows its alta, the records are append-only
-- but for their submission state, and only an issuer of the space may keep
-- them, for a Spanish seller.
begin;
select plan(21);

select is(
  public.verifactu_huella_alta('89890001K', '12345678/G33', '01-01-2024', 'F1', '12.35', '123.45',
                               '', '2024-01-01T19:20:30+01:00'),
  '3C464DAF61ACB827C65FDA19F352A4E3BDC2C640E9E9FC4CC058073F38F12F60',
  'the AEAT example: the first alta of a chain');

select is(
  public.verifactu_huella_alta('89890001K', '12345679/G34', '01-01-2024', 'F1', '12.35', '123.45',
                               '3C464DAF61ACB827C65FDA19F352A4E3BDC2C640E9E9FC4CC058073F38F12F60',
                               '2024-01-01T19:20:35+01:00'),
  'F7B94CFD8924EDFF273501B01EE5153E4CE8F259766F88CF6ACB8935802A2B97',
  'the AEAT example: a second alta chained on the first');

select is(
  public.verifactu_huella_anulacion('89890001K', '12345679/G34', '01-01-2024',
                                    'F7B94CFD8924EDFF273501B01EE5153E4CE8F259766F88CF6ACB8935802A2B97',
                                    '2024-01-01T19:20:40+01:00'),
  '177547C0D57AC74748561D054A9CEC14B4C4EA23D1BEFD6F2E69E3A388F90C68',
  'the AEAT example: an anulación chained on the second alta');

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u uuid := '00000000-0000-4000-8000-0000000003b1';
  stranger uuid := '00000000-0000-4000-8000-0000000003b2';
  adm uuid := '00000000-0000-4000-8000-0000000003b3';
  ws uuid; m uuid; ws_fr uuid; m_fr uuid;
  inv1 uuid; inv2 uuid; inv3 uuid; credit uuid; fr uuid;
  parties jsonb := '{"seller": {"name": "Cowork Sevilla SL", "country": "ES", "vat_id": "ES B12345674"},
                     "buyer": {"name": "Cliente SA", "country": "ES", "vat_id": "A58818501"}}';
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'verifactu@deskilo.test', '', now(), now(), now()),
         (stranger, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'stranger@deskilo.test', '', now(), now(), now()),
         (adm, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'verifactu-admin@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Verifactu', 'ES', 'EUR', 'Europe/Madrid', u) returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u, true, true) returning id into m;
  insert into public.members (workspace_id, user_id, is_owner, is_admin) values (ws, adm, false, true);
  perform set_config('deskilo.test.ws', ws::text, false);
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Vérifactu FR', 'FR', 'EUR', 'Europe/Paris', u) returning id into ws_fr;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws_fr, u, true, true) returning id into m_fr;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, issued_at,
                               title, lines, total_cents, currency, member_name,
                               workspace_name, issuer_name, signature, parties, vat_totals)
  values (ws, m, m, 'F-2027-0001', '2027-02-03 09:00+01', 'Febrero', '[]', 12100, 'EUR', 'Cliente',
          'Verifactu', 'Admin', 'sig', parties,
          '[{"percent": 21, "category": "S", "net_cents": 10000, "vat_cents": 2100, "gross_cents": 12100}]')
  returning id into inv1;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, issued_at,
                               title, lines, total_cents, currency, member_name,
                               workspace_name, issuer_name, signature, parties, vat_totals)
  values (ws, m, m, 'F-2027-0002', '2027-02-04 09:00+01', 'Febrero', '[]', 24200, 'EUR', 'Cliente',
          'Verifactu', 'Admin', 'sig', parties,
          '[{"percent": 21, "category": "S", "net_cents": 20000, "vat_cents": 4200, "gross_cents": 24200}]')
  returning id into inv2;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, issued_at,
                               title, lines, total_cents, currency, member_name,
                               workspace_name, issuer_name, signature, parties)
  values (ws, m, m, 'F-2027-0003', '2027-02-06 09:00+01', 'Febrero', '[]', 5000, 'EUR', 'Cliente',
          'Verifactu', 'Admin', 'sig', parties)
  returning id into inv3;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, issued_at,
                               title, lines, total_cents, currency, member_name,
                               workspace_name, issuer_name, signature, parties, vat_totals,
                               replaces_number)
  values (ws, m, m, 'R-2027-0001', '2027-02-05 09:00+01', 'Abono', '[]', -12100, 'EUR', 'Cliente',
          'Verifactu', 'Admin', 'sig', parties,
          '[{"percent": 21, "category": "S", "net_cents": -10000, "vat_cents": -2100, "gross_cents": -12100}]',
          'F-2027-0001')
  returning id into credit;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number,
                               title, lines, total_cents, currency, member_name,
                               workspace_name, issuer_name, signature, parties)
  values (ws_fr, m_fr, m_fr, 'FR-1', 'Mars', '[]', 1000, 'EUR', 'Client', 'FR', 'Admin', 'sig',
          '{"seller": {"name": "Espace", "country": "FR", "vat_id": "FR40303265045"}, "buyer": {}}')
  returning id into fr;
  perform set_config('deskilo.test.u', u::text, false);
  perform set_config('deskilo.test.stranger', stranger::text, false);
  perform set_config('deskilo.test.adm', adm::text, false);
  perform set_config('deskilo.test.inv1', inv1::text, false);
  perform set_config('deskilo.test.inv2', inv2::text, false);
  perform set_config('deskilo.test.inv3', inv3::text, false);
  perform set_config('deskilo.test.credit', credit::text, false);
  perform set_config('deskilo.test.fr', fr::text, false);
  perform set_config('request.jwt.claims',
    json_build_object('sub', u, 'role', 'authenticated')::text, false);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.keep(p text, p_kind text default 'alta') returns public.verifactu_records
language sql as $$
  select * from public.record_verifactu_v1(current_setting('deskilo.test.' || p)::uuid, p_kind)
$$;

create temp table r1 as select * from pg_temp.keep('inv1');
create temp table r2 as select * from pg_temp.keep('inv2');

select ok(
  (select chain_position = 1 and previous_huella = '' and issuer_nif = 'B12345674'
          and invoice_type = 'F1' and tax_total = '21.00' and grand_total = '121.00'
          and issue_date = '03-02-2027' from r1),
  'the first record opens the chain, from the invoice''s own number, date, NIF and totals');

select is(
  (select huella from r1),
  (select public.verifactu_huella_alta(issuer_nif, invoice_number, issue_date, invoice_type,
                                       tax_total, grand_total, previous_huella, generated_at) from r1),
  'its huella is the AEAT concatenation of the fields it keeps');

select ok((select generated_at ~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}$' from r1),
  'its generation time carries the offset it hashed');

select ok(
  (select r2.chain_position = 2 and r2.previous_huella = r1.huella
          and r2.previous_number = 'F-2027-0001' and r2.previous_issue_date = '03-02-2027'
     from r1, r2),
  'the second record hashes its predecessor''s huella');

select is(
  (select (pg_temp.keep('inv1')).id),
  (select id from r1),
  'a second call answers the record already kept');

create temp table rc as select * from pg_temp.keep('credit');
select ok(
  (select invoice_type = 'R1' and tax_total = '-21.00' and grand_total = '-121.00' and chain_position = 3 from rc),
  'a rectification is an R1 with the amounts it takes back');

create temp table ra as select * from pg_temp.keep('inv1', 'anulacion');
select ok(
  (select ra.chain_position = 4 and ra.previous_huella = rc.huella and ra.invoice_type = ''
          and ra.huella = public.verifactu_huella_anulacion(ra.issuer_nif, ra.invoice_number,
                                                          ra.issue_date, ra.previous_huella, ra.generated_at)
     from ra, rc),
  'an anulación follows its alta in the chain and hashes the anulación fields');

select throws_ok(
  format($$select public.record_verifactu_v1(%L, 'anulacion')$$, current_setting('deskilo.test.inv3')),
  'there is no alta record to cancel',
  'an anulación needs the alta it cancels');

select throws_ok(
  format($$update public.verifactu_records set huella = repeat('0', 64) where id = %L$$, (select id from r1)),
  'verifactu records are immutable',
  'a kept record never changes');

select lives_ok(
  format($$update public.verifactu_records set submission_status = 'accepted' where id = %L$$, (select id from r1)),
  'only its submission state moves');

select throws_ok(
  format($$delete from public.verifactu_records where id = %L$$, (select id from r1)),
  'verifactu records are kept',
  'a kept record is never deleted');

select throws_ok(
  format($$select public.record_verifactu_v1(%L)$$, current_setting('deskilo.test.fr')),
  'Verifactu records are kept for a Spanish seller only',
  'a seller outside Spain keeps no Verifactu record');

-- The role matrix reads them: the space's invoice issuer sees its four
-- records, someone outside the space none (#1321, never is_admin_of).
set local role authenticated;
select is((select count(*)::int from public.verifactu_records), 4,
  'the space''s invoice issuer reads its records');
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('deskilo.test.stranger'), 'role', 'authenticated')::text, false);
select is((select count(*)::int from public.verifactu_records), 0,
  'someone outside the space reads none');
reset role;

-- An admin the owner took invoicing and the finances away from (the admin
-- row of the matrix emptied) reads none and keeps none: is_admin_of would
-- still answer yes.
update public.workspaces set role_permissions = '{"admin": []}'::jsonb
 where id = current_setting('deskilo.test.ws')::uuid;
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('deskilo.test.adm'), 'role', 'authenticated')::text, false);
set local role authenticated;
select is((select count(*)::int from public.verifactu_records), 0,
  'an admin the matrix took the finances from reads no record');
reset role;
select throws_ok(
  format($$select public.record_verifactu_v1(%L)$$, current_setting('deskilo.test.inv2')),
  'you may not keep this invoice''s records',
  'and keeps none');

-- The space's own admin, through a delegated (MCP) session: the claims carry
-- the OAuth client, as the MCP tests mark them.
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('deskilo.test.u'), 'role', 'authenticated',
                    'client_id', 'claude-test')::text, false);
select throws_ok(
  format($$select public.record_verifactu_v1(%L)$$, current_setting('deskilo.test.inv2')),
  '42501', null,
  'a delegated session keeps no record, though its user may');

select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('deskilo.test.stranger'), 'role', 'authenticated')::text, false);
select throws_ok(
  format($$select public.record_verifactu_v1(%L)$$, current_setting('deskilo.test.inv2')),
  'you may not keep this invoice''s records',
  'someone outside the space keeps no record of its invoices');

select * from finish();
rollback;
