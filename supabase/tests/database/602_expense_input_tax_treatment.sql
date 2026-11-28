-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4479 (0994): an expense keeps its input-tax treatment, the identity of its rate and the facts of its document. A domestic or
-- acquisition expense names an active rate of the space (the percent is resolved from it; an inactive or foreign rate is refused,
-- a bare percent still works); an old payload reads as before; VAT a supplier abroad charged is a document fact (the stated rate
-- and amount) that carries no percent, no rate of the space and no deduction, so no return reads it; the country of the supplier
-- agrees with the treatment; a space whose return has no acquisition box still refuses an acquisition. Rolled back.
begin;
select plan(21);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.t(p_ws int, p_vat text) returns text language plpgsql as $f$
begin
  return public.expense_vat_payload(pg_temp.u(p_ws), p_vat::jsonb)::text;
exception when others then
  return 'ERR ' || sqlerrm;
end
$f$;
create or replace function pg_temp.j(p_ws int, p_vat text) returns jsonb language sql as $f$
  select pg_temp.t(p_ws, p_vat)::jsonb
$f$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values (pg_temp.u(1), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'expensetax@deskilo.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, feature_flags) values
  (pg_temp.u(101), 'Expenses CH', 'CH', 'CHF', 'Europe/Zurich', pg_temp.u(1), 'vat_registered',
   '{"moneyTab": true, "invoicing": true, "vatManagement": true, "vatDeclarations": true, "inputVat": true}'),
  (pg_temp.u(102), 'Expenses DE', 'DE', 'EUR', 'Europe/Berlin', pg_temp.u(1), 'vat_registered',
   '{"moneyTab": true, "invoicing": true, "vatManagement": true, "vatDeclarations": true, "inputVat": true}');
insert into public.vat_rates (id, workspace_id, label, percent, active) values
  (pg_temp.u(901), pg_temp.u(101), 'Normal 8.1', 8.1, true),
  (pg_temp.u(902), pg_temp.u(101), 'Reduced 2.6', 2.6, true),
  (pg_temp.u(903), pg_temp.u(101), 'Old 7.7', 7.7, false),
  (pg_temp.u(904), pg_temp.u(102), 'Normal 19', 19, true);

-- a domestic expense names a rate of the space
select is(pg_temp.j(101, format('{"vat_rate_id": "%s", "deductible_pct": 50}', pg_temp.u(901))) ->> 'percent', '8.1', 'the percent is the rate''s');
select is(pg_temp.j(101, format('{"vat_rate_id": "%s"}', pg_temp.u(901))) ->> 'vat_rate_id', pg_temp.u(901)::text, 'the rate''s identity is kept');
select is(pg_temp.j(101, '{"percent": 8.1}'), '{"percent": 8.1, "deductible_pct": 100}'::jsonb, 'a domestic expense is stored in the shape it always had');
select is(pg_temp.j(101, '{"percent": 20, "asset": true}'), '{"percent": 20, "deductible_pct": 100, "asset": true}'::jsonb, 'so is an asset');
select is(pg_temp.j(101, format('{"vat_rate_id": "%s", "percent": 99}', pg_temp.u(902))) ->> 'percent', '2.6', 'the identity wins over a percent sent beside it');
select is(pg_temp.j(101, '{"percent": 8.1}') ->> 'percent', '8.1', 'a percent alone still works (a schedule, the MCP)');
select ok(not (pg_temp.j(101, '{"percent": 8.1}') ? 'vat_rate_id'), 'and keeps no identity it was not given');
select matches(pg_temp.t(101, format('{"vat_rate_id": "%s"}', pg_temp.u(903))), 'vat_rate_unknown', 'an inactive rate is refused');
select matches(pg_temp.t(101, format('{"vat_rate_id": "%s"}', pg_temp.u(904))), 'vat_rate_unknown', 'a rate of another space is refused');

-- an acquisition from abroad, the flag read as a treatment
select is(pg_temp.j(101, '{"percent": 8.1, "acquisition": true}'), '{"percent": 8.1, "deductible_pct": 100, "acquisition": true}'::jsonb, 'the old flag is the acquisition treatment, stored as it always was');
select is(pg_temp.j(101, format('{"vat_rate_id": "%s", "treatment": "acquisition", "supplier_country": "de", "document_number": " R-77 ", "document_date": "2026-09-12"}', pg_temp.u(901))) ->> 'supplier_country', 'DE', 'the supplier''s country is kept, as a code');
select is(pg_temp.j(101, format('{"vat_rate_id": "%s", "treatment": "acquisition", "document_number": " R-77 ", "document_date": "2026-09-12"}', pg_temp.u(901))) ->> 'document_number', 'R-77', 'the document number is kept, trimmed');
select matches(pg_temp.t(101, '{"percent": 8.1, "treatment": "acquisition", "supplier_country": "CH"}'), 'supplier abroad', 'an acquisition from the space''s own country is refused');
select matches(pg_temp.t(101, '{"percent": 8.1, "supplier_country": "DE"}'), 'space''s country', 'a domestic expense from another country is refused');
select matches(pg_temp.t(102, '{"percent": 19, "acquisition": true}'), 'acquisition tax box', 'a space whose return has no acquisition box still refuses it');

-- the VAT a supplier abroad charged: a fact, not input tax of this return
select is(pg_temp.j(101, '{"treatment": "foreign_charged", "supplier_country": "DE", "stated_percent": 19, "stated_tax_cents": 1900}') ->> 'stated_tax_cents', '1900', 'the stated amount is kept');
select ok(not (pg_temp.j(101, '{"treatment": "foreign_charged", "supplier_country": "DE", "stated_percent": 19}') ?| array['percent', 'vat_rate_id', 'deductible_pct', 'acquisition']), 'it carries no percent, rate, deduction or acquisition: no return reads it');
select matches(pg_temp.t(101, format('{"treatment": "foreign_charged", "supplier_country": "DE", "stated_percent": 19, "vat_rate_id": "%s"}', pg_temp.u(901))), 'no rate of this space', 'it never takes a rate of the space''s catalogue');
select matches(pg_temp.t(101, '{"treatment": "foreign_charged", "stated_percent": 19}'), 'country', 'it names the supplier''s country');

-- without VAT, and what is refused
select is(pg_temp.t(101, '{"treatment": "none"}'), '{"treatment": "none"}', 'no VAT states only that');
select matches(pg_temp.t(101, '{"treatment": "refund"}'), 'unknown input tax treatment', 'an unknown treatment is refused');

select * from finish();
rollback;
