-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2576 / 0500 (C2a): the accountant's valuations, on the setup of 231 (the
-- equipment register). A purchase line classified as
-- long-lasting equipment is registered as a candidate; a reviewer decides the
-- treatment; nothing is inferred. Real roles; every refusal is followed by a
-- readback. Expected values are written by hand:
--   machine net 1 200.00 + VAT 240.00, fully recoverable   -> cost 1 200.00
--   machine net 1 200.00 + VAT 240.00, 120.00 recoverable  -> cost 1 320.00
--   machine whose deductible share is not qualified        -> cost unknown
begin;
select plan(50);
create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.as_err(p_user uuid, p_sql text) returns text
language plpgsql as $$
begin
  perform pg_temp.act_as(p_user);
  execute p_sql;
  reset role;
  return '';
exception when others then
  reset role;
  return sqlerrm;
end;
$$;
create function pg_temp.as_json(p_user uuid, p_sql text) returns jsonb
language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.act_as(p_user);
  execute p_sql into v;
  reset role;
  return v;
exception when others then
  reset role;
  return jsonb_build_object('error', sqlerrm);
end;
$$;
create function pg_temp.owner_err(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return '';
exception when others then
  return sqlerrm;
end;
$$;
create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00002576' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.mem(n int, w text) returns uuid language sql as $$
  select id from public.members
   where user_id = pg_temp.u(n) and workspace_id = current_setting(w)::uuid;
$$;
create function pg_temp.ev(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00002576e' || lpad(n::text, 3, '0'))::uuid;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@supplierbills.test', '', now(), now(), now()
  from generate_series(1, 5) i;
-- 1 owner of A, 2 and 3 plain members of A, 4 a second admin of A, 5 owner of B.

select pg_temp.act_as(pg_temp.u(1));
select set_config('t.a', public.create_workspace('Supplier A', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select pg_temp.act_as(pg_temp.u(5));
select set_config('t.b', public.create_workspace('Supplier B', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces
   set feature_flags = coalesce(feature_flags, '{}'::jsonb)
       || '{"services": true, "supplyExpenses": true, "purchases": true, "invoicing": true,
          "numberSequences": true, "vatManagement": true, "vatDeclarations": true, "inputVat": true}',
       street = '1 rue du Pilote', city = 'Pézenas', postal_code = '34120',
       vat_regime = 'vat_registered', vat_id = 'FR12345678901'
 where id = current_setting('t.a')::uuid;
insert into public.members (workspace_id, user_id, is_owner, is_admin, status, subscription_pct, joined_at, customer_capacity) values
 (current_setting('t.a')::uuid, pg_temp.u(2), false, false, 'active', 1, '2026-01-01', 'consumer'),
 (current_setting('t.a')::uuid, pg_temp.u(3), false, false, 'active', 1, '2026-01-01', 'consumer'),
 (current_setting('t.a')::uuid, pg_temp.u(4), false, true, 'active', 1, '2026-01-01', 'consumer');
insert into public.vat_rates (workspace_id, label, percent, is_default)
values (current_setting('t.a')::uuid, 'Synthetic standard', 20, true);
delete from public.fee_bands where workspace_id = current_setting('t.a')::uuid;
insert into public.fee_bands (workspace_id, from_pct, to_pct, fee_cents, overage_fee_cents)
values (current_setting('t.a')::uuid, 0, 100, 3500, 1000);
update public.profiles set first_name = 'Synthetic', last_name = 'Client', country_code = 'FR',
       street = '2 rue du Test', city = 'Pézenas', postal_code = '34120'
 where id = pg_temp.u(2);


create function pg_temp.rq(n int) returns uuid language sql as $$
  select ('c0000000-0000-4000-8000-00000000' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.today() returns date language sql as $$
  select (now() at time zone 'Europe/Paris')::date;
$$;
create function pg_temp.call(p_user uuid, p_sql text) returns jsonb language plpgsql as $$
begin
  return pg_temp.as_json(p_user, p_sql);
end;
$$;
create function pg_temp.bill(p_ref text, p_gross int) returns text language sql as $$
  select jsonb_build_object('kind', 'bill', 'supplier_id', '00000000-0000-4000-8000-0000257600a1',
    'original_reference', p_ref, 'due_on', '2026-12-15', 'payer_kind', 'unpaid',
    'lines', jsonb_build_array(jsonb_build_object('description', 'Cleaning', 'gross_cents', p_gross,
      'net_cents', p_gross * 5 / 6, 'tax_cents', p_gross - p_gross * 5 / 6, 'tax_rate_percent', 20)))::text;
$$;
create function pg_temp.decide(p_user uuid, p_purchase text, p_rev int, p_approve boolean, p_reason text, p_req int) returns jsonb
language plpgsql as $$
begin
  return pg_temp.as_json(p_user, format('select public.decide_purchase_v1(%L, %L, %s, %L, %L, %L)',
    current_setting('t.a'), p_purchase, p_rev, p_approve, p_reason, pg_temp.rq(p_req)));
end;
$$;
create function pg_temp.paysup(p_user uuid, p_ob text, p_amount bigint, p_rev int, p_req int, p_paid_on date default null) returns jsonb
language plpgsql as $$
begin
  return pg_temp.as_json(p_user, format('select public.record_supplier_payment_v1(%L, %L, %s, %s, %L, %L, ''bank_transfer'', ''wire'')',
    current_setting('t.a'), p_ob, p_amount, p_rev, pg_temp.rq(p_req), coalesce(p_paid_on, pg_temp.today() - 1)));
end;
$$;

insert into public.suppliers (id, workspace_id, supplier_number, name) values
 ('00000000-0000-4000-8000-0000257600a1', current_setting('t.a')::uuid, '1', 'Net & Clair'),
 ('00000000-0000-4000-8000-0000257600b1', current_setting('t.b')::uuid, '1', 'Other Ltd');

reset role;
create function pg_temp.line(p_gross int, p_net int, p_tax int, p_rec int, p_kind text) returns jsonb language sql as $$
  select jsonb_build_object('description', 'Espresso machine', 'gross_cents', p_gross, 'net_cents', p_net,
    'tax_cents', p_tax, 'tax_rate_percent', 20, 'recoverable_tax_cents', p_rec, 'recognition_kind', p_kind);
$$;
create function pg_temp.draft(p_req int, p_lines jsonb) returns jsonb language plpgsql as $$
begin
  return pg_temp.call(pg_temp.u(1), format('select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)',
    current_setting('t.a'), pg_temp.rq(p_req), jsonb_build_object('kind', 'bill',
      'supplier_id', '00000000-0000-4000-8000-0000257600a1', 'original_reference', 'M-' || p_req,
      'due_on', '2026-12-15', 'payer_kind', 'unpaid', 'lines', p_lines)::text));
end;
$$;
create function pg_temp.lineid(p_purchase text, p_no int) returns text language sql as $$
  select id::text from public.purchase_lines where purchase_id = p_purchase::uuid and line_no = p_no;
$$;
create function pg_temp.reg(p_user uuid, p_line text, p_req int) returns jsonb language plpgsql as $$
begin
  return pg_temp.as_json(p_user, format('select public.register_asset_candidate_v1(%L, %L, '''', %L)',
    current_setting('t.a'), p_line, pg_temp.rq(p_req)));
end;
$$;
create function pg_temp.decide(p_user uuid, p_asset text, p_rev int, p_decision text, p_basis text, p_from date, p_req int) returns jsonb language plpgsql as $$
begin
  return pg_temp.as_json(p_user, format('select public.decide_asset_v1(%L, %L, %s, %L, %L, %L, null, null, '''', %L)',
    current_setting('t.a'), p_asset, p_rev, p_decision, p_basis, p_from, pg_temp.rq(p_req)));
end;
$$;

select set_config('t.p', pg_temp.draft(200, jsonb_build_array(
  pg_temp.line(144000, 120000, 24000, 24000, 'asset'),
  pg_temp.line(144000, 120000, 24000, 12000, 'asset'),
  pg_temp.line(144000, 120000, 24000, null, 'asset'),
  pg_temp.line(5000, 4167, 833, 833, 'operating'),
  pg_temp.line(144000, 120000, 24000, 24000, 'asset')))->>'purchase_id', true);
select set_config('t.l1', pg_temp.lineid(current_setting('t.p'), 1), true);
select set_config('t.l2', pg_temp.lineid(current_setting('t.p'), 2), true);
select set_config('t.l3', pg_temp.lineid(current_setting('t.p'), 3), true);
select set_config('t.l4', pg_temp.lineid(current_setting('t.p'), 4), true);
select set_config('t.l5', pg_temp.lineid(current_setting('t.p'), 5), true);

-- ── the flag and the rights ────────────────────────────────────────────
select ok((pg_temp.reg(pg_temp.u(1), current_setting('t.l1'), 201)::text) like '%switched off%', 'with the flag off nothing is registered');
update public.workspaces set feature_flags = feature_flags || '{"assetRegister": true, "configurableSettings": true}' where id = current_setting('t.a')::uuid;
select ok((pg_temp.reg(pg_temp.u(4), current_setting('t.l1'), 202)::text) like '%may not register equipment%', 'an admin without managePurchases registers nothing');
select ok((pg_temp.reg(pg_temp.u(5), current_setting('t.l1'), 203)::text) like '%not an active member%', 'nor does a foreign owner');
select is((select count(*)::int from public.workspace_assets), 0, 'readback: no refusal left a row');

-- ── what can be registered ─────────────────────────────────────────────
select is(jsonb_array_length(pg_temp.as_json(pg_temp.u(1), format('select public.asset_candidate_lines_v1(%L)', current_setting('t.a'))) -> 'lines'), 4,
  'the four equipment lines are offered, the operating line is not');
select ok((pg_temp.as_json(pg_temp.u(4), format('select public.asset_candidate_lines_v1(%L)', current_setting('t.a')))::text) like '%may not register equipment%',
  'an admin without managePurchases is offered nothing');

-- ── registering ────────────────────────────────────────────────────────
select ok((pg_temp.reg(pg_temp.u(1), current_setting('t.l4'), 204)::text) like '%not classified as long-lasting equipment%', 'a line that is not equipment is refused');
select set_config('t.a1', pg_temp.reg(pg_temp.u(1), current_setting('t.l1'), 205)::text, true);
select is(current_setting('t.a1')::jsonb ->> 'acquisition_cost_cents', '120000', 'golden: net 1 200.00 + 0 non-recoverable VAT = cost 1 200.00');
select is(current_setting('t.a1')::jsonb ->> 'asset_number', '1', 'and it is asset number 1');
select is(pg_temp.reg(pg_temp.u(1), current_setting('t.l1'), 205), current_setting('t.a1')::jsonb, 'the same request answers the original');
select ok((pg_temp.reg(pg_temp.u(1), current_setting('t.l1'), 206)::text) like '%already registered%', 'a line is registered once');
select set_config('t.a2', pg_temp.reg(pg_temp.u(1), current_setting('t.l2'), 207)::text, true);
select is(current_setting('t.a2')::jsonb ->> 'acquisition_cost_cents', '132000', 'golden: only 120.00 of the 240.00 VAT is recovered: cost 1 320.00');
select set_config('t.a3', pg_temp.reg(pg_temp.u(1), current_setting('t.l3'), 208)::text, true);
select ok(current_setting('t.a3')::jsonb -> 'acquisition_cost_cents' = 'null'::jsonb, 'an unqualified deductible share leaves the cost unknown, not zero');

select set_config('t.a5', pg_temp.as_json(pg_temp.u(1), format('select public.register_asset_candidate_v1(%L, %L, 5, ''Second machine'', %L)',
  current_setting('t.a'), current_setting('t.p'), pg_temp.rq(216)))::text, true);
select is(current_setting('t.a5')::jsonb ->> 'description', 'Second machine', 'a line is registered by its purchase and number too, with the name given');
select is(jsonb_array_length(pg_temp.as_json(pg_temp.u(1), format('select public.asset_candidate_lines_v1(%L)', current_setting('t.a'))) -> 'lines'), 0,
  'and once all are registered nothing is offered');

-- ── deciding ───────────────────────────────────────────────────────────
select ok((pg_temp.decide(pg_temp.u(4), current_setting('t.a1')::jsonb ->> 'id', 1, 'capitalise', 'IAS 16', date '2026-03-01', 209)::text) like '%may not decide%', 'an admin without manageBilling decides nothing');
select ok((pg_temp.decide(pg_temp.u(1), current_setting('t.a1')::jsonb ->> 'id', 1, 'capitalise', '', date '2026-03-01', 210)::text) like '%basis%', 'a decision states its basis');
select ok((pg_temp.decide(pg_temp.u(1), current_setting('t.a3')::jsonb ->> 'id', 1, 'capitalise', 'IAS 16', null, 211)::text) like '%qualify the deductible share%', 'an unknown cost is not capitalised');
select ok((pg_temp.decide(pg_temp.u(1), current_setting('t.a1')::jsonb ->> 'id', 9, 'capitalise', 'IAS 16', date '2026-03-01', 212)::text) like '%stale revision%', 'a stale revision is refused');
select set_config('t.d1', pg_temp.decide(pg_temp.u(1), current_setting('t.a1')::jsonb ->> 'id', 1, 'capitalise', 'IAS 16: lasting equipment', date '2026-03-01', 213)::text, true);
select is(current_setting('t.d1')::jsonb ->> 'state', 'in_use', 'capitalised with the date it was available for use: in use');
select set_config('t.d2', pg_temp.decide(pg_temp.u(1), current_setting('t.a2')::jsonb ->> 'id', 1, 'expense', 'below the space''s approved policy', null, 214)::text, true);
select is(current_setting('t.d2')::jsonb ->> 'state', 'expensed', 'an expensed item is not an asset');
select ok((pg_temp.decide(pg_temp.u(1), current_setting('t.a1')::jsonb ->> 'id', 2, 'expense', 'changed my mind', null, 215)::text) like '%corrected in the open period%', 'a decided asset is not re-decided here');
select is((select count(*)::int from public.workspace_assets where state = 'candidate'), 2, 'readback: two candidates left, the unqualified one and the second machine');


-- ── the accountant's valuations ───────────────────────────────────────
create function pg_temp.hash(p text) returns text language sql as $$ select encode(sha256(p::bytea), 'hex'); $$;
create function pg_temp.meta(p_basis text, p_from date, p_to date, p_hash text, p_currency text default 'EUR', p_movements text default 'period') returns jsonb language sql as $$
  select jsonb_build_object('basis', p_basis, 'source_system', 'Cabinet Martin', 'source_reference', 'FY2026',
    'source_hash', pg_temp.hash(p_hash), 'period_from', p_from, 'period_to', p_to, 'currency', p_currency,
    'movements', p_movements, 'complete_scope', false);
$$;
create function pg_temp.vrow(p_no int, p_open bigint, p_add bigint, p_disp bigint, p_dep bigint, p_imp bigint, p_close bigint) returns jsonb language sql as $$
  select jsonb_build_object('asset_number', p_no, 'external_reference', 'X' || p_no, 'opening_minor', p_open,
    'additions_minor', p_add, 'disposals_minor', p_disp, 'depreciation_minor', p_dep, 'impairment_minor', p_imp, 'closing_minor', p_close);
$$;
create function pg_temp.stage(p_user uuid, p_meta jsonb, p_rows jsonb, p_req int) returns jsonb language plpgsql as $$
begin
  return pg_temp.as_json(p_user, format('select public.stage_asset_valuations_v1(%L, %L, %L::jsonb, %L::jsonb)',
    current_setting('t.a'), pg_temp.rq(p_req), p_meta::text, p_rows::text));
end;
$$;
create function pg_temp.confirm(p_user uuid, p_batch text, p_rev int, p_sup text, p_reason text, p_req int) returns jsonb language plpgsql as $$
begin
  return pg_temp.as_json(p_user, format('select public.confirm_asset_valuations_v1(%L, %L, %s, %L, %L, %L)',
    current_setting('t.a'), p_batch, p_rev, p_sup, p_reason, pg_temp.rq(p_req)));
end;
$$;

select ok((pg_temp.stage(pg_temp.u(4), pg_temp.meta('book', date '2026-03-01', date '2026-03-31', 'b1'),
  jsonb_build_array(pg_temp.vrow(1, 120000, 0, 0, 2000, 0, 118000)), 300)::text) like '%may not import valuations%',
  'V1 an admin without manageBilling stages nothing');
select set_config('t.b1', pg_temp.stage(pg_temp.u(1), pg_temp.meta('book', date '2026-03-01', date '2026-03-31', 'b1'),
  jsonb_build_array(pg_temp.vrow(1, 120000, 0, 0, 2000, 0, 118000),
                    jsonb_build_object('asset_number', 3, 'external_reference', 'X3')), 301)::text, true);
select is(current_setting('t.b1')::jsonb ->> 'status', 'staged', 'V2 a staged batch is not yet evidence');
select is((current_setting('t.b1')::jsonb ->> 'rows')::int, 2, 'V2b with its two rows, the second all unknown');
select is(pg_temp.stage(pg_temp.u(1), pg_temp.meta('book', date '2026-03-01', date '2026-03-31', 'b1'),
  jsonb_build_array(pg_temp.vrow(1, 120000, 0, 0, 2000, 0, 118000)), 302) ->> 'id', current_setting('t.b1')::jsonb ->> 'id',
  'V3 the same source bytes answer the same batch');
select is((select count(*)::int from public.asset_valuation_batches), 1, 'V3b readback: one batch');
select ok((pg_temp.stage(pg_temp.u(1), pg_temp.meta('book', date '2026-03-01', date '2026-03-31', 'b2'),
  jsonb_build_array(pg_temp.vrow(9, 1, 0, 0, 0, 0, 1)), 303)::text) like '%unknown asset number 9%', 'V4 an unknown asset number refuses the batch');
select ok((pg_temp.stage(pg_temp.u(1), pg_temp.meta('book', date '2026-03-01', date '2026-03-31', 'b2', 'USD'),
  jsonb_build_array(pg_temp.vrow(1, 1, 0, 0, 0, 0, 1)), 304)::text) like '%the asset is in EUR%', 'V5 a currency that is not the asset''s refuses');
select ok((pg_temp.stage(pg_temp.u(1), pg_temp.meta('book', date '2026-03-01', date '2026-03-31', 'b2'),
  jsonb_build_array(pg_temp.vrow(1, 1, 0, 0, 0, 0, -5)), 305)::text) like '%closing_minor%', 'V6 a negative closing value refuses');
select ok((pg_temp.stage(pg_temp.u(1), pg_temp.meta('book', date '2026-03-01', date '2026-03-31', 'b2'),
  jsonb_build_array(pg_temp.vrow(1, 1, 0, 0, 0, 0, 1), pg_temp.vrow(1, 1, 0, 0, 0, 0, 1)), 306)::text) like '%appears twice%', 'V7 an asset twice in a batch refuses');
select is((select count(*)::int from public.asset_valuation_batches), 1, 'V7b readback: no refusal left a batch');

select set_config('t.bm', pg_temp.stage(pg_temp.u(1), pg_temp.meta('book', date '2026-04-01', date '2026-04-30', 'bm'),
  jsonb_build_array(pg_temp.vrow(1, 118000, 0, 0, 2000, 0, 115000)), 307)::text, true);
select is((current_setting('t.bm')::jsonb ->> 'mismatches')::int, 1, 'V8 a row that does not balance is flagged');
select ok((pg_temp.confirm(pg_temp.u(1), current_setting('t.bm')::jsonb ->> 'id', 1, null, '', 308)::text) like '%does not balance%', 'V8b and cannot be confirmed');

select is(pg_temp.confirm(pg_temp.u(1), current_setting('t.b1')::jsonb ->> 'id', 1, null, '', 309) ->> 'status', 'confirmed', 'V9 a balanced batch is confirmed');
select ok((pg_temp.confirm(pg_temp.u(1), current_setting('t.b1')::jsonb ->> 'id', 1, null, '', 310)::text) like '%changed meanwhile%', 'V9b a stale revision is refused');
select ok((pg_temp.confirm(pg_temp.u(1), current_setting('t.b1')::jsonb ->> 'id', 2, null, '', 311)::text) like '%only a staged batch%', 'V9c a confirmed batch is not confirmed again');

select set_config('t.b3', pg_temp.stage(pg_temp.u(1), pg_temp.meta('book', date '2026-03-15', date '2026-04-15', 'b3'),
  jsonb_build_array(pg_temp.vrow(1, 119000, 0, 0, 1000, 0, 118000)), 312)::text, true);
select ok((pg_temp.confirm(pg_temp.u(1), current_setting('t.b3')::jsonb ->> 'id', 1, null, '', 313)::text) like '%already values some of these assets%', 'V10 an overlapping period is refused');
select ok((pg_temp.confirm(pg_temp.u(1), current_setting('t.b3')::jsonb ->> 'id', 1, current_setting('t.b1')::jsonb ->> 'id', '', 314)::text) like '%say why%', 'V10b replacing one needs a reason');
select is(pg_temp.confirm(pg_temp.u(1), current_setting('t.b3')::jsonb ->> 'id', 1, current_setting('t.b1')::jsonb ->> 'id', 'the accountant re-issued March', 315) ->> 'status',
  'confirmed', 'V11 naming the batch and why replaces it');
select is((select status from public.asset_valuation_batches where id = (current_setting('t.b1')::jsonb ->> 'id')::uuid), 'superseded',
  'V11b readback: the earlier batch is kept, superseded');

select set_config('t.bt', pg_temp.stage(pg_temp.u(1), pg_temp.meta('tax', date '2026-03-01', date '2026-03-31', 'bt'),
  jsonb_build_array(pg_temp.vrow(1, 120000, 0, 0, 10000, 0, 110000)), 316)::text, true);
select is(pg_temp.confirm(pg_temp.u(1), current_setting('t.bt')::jsonb ->> 'id', 1, null, '', 317) ->> 'status', 'confirmed',
  'V12 a tax batch for the same period is another basis: no overlap with the book batch');

select is(jsonb_array_length(pg_temp.as_json(pg_temp.u(1), format('select public.asset_valuations_page_v1(%L, ''{}'', null)', current_setting('t.a'))) -> 'batches'), 4,
  'V13 the four batches are listed');
select is(jsonb_array_length(pg_temp.as_json(pg_temp.u(1), format('select public.asset_valuations_page_v1(%L, %L, null)', current_setting('t.a'),
  jsonb_build_object('basis', 'tax')::text)) -> 'batches'), 1, 'V13b filtered by basis');
select is((select r ->> 'bridge' from jsonb_array_elements(pg_temp.as_json(pg_temp.u(1), format('select public.asset_valuations_page_v1(%L, %L, null)', current_setting('t.a'),
  jsonb_build_object('batch_id', current_setting('t.b1')::jsonb ->> 'id')::text)) -> 'rows') r where (r ->> 'asset_number') = '3'), 'unknown',
  'V14 an unknown figure stays unknown, the bridge says so');
select ok((select r -> 'closing_minor' = 'null'::jsonb from jsonb_array_elements(pg_temp.as_json(pg_temp.u(1), format('select public.asset_valuations_page_v1(%L, %L, null)', current_setting('t.a'),
  jsonb_build_object('batch_id', current_setting('t.b1')::jsonb ->> 'id')::text)) -> 'rows') r where (r ->> 'asset_number') = '3'),
  'V14b the closing value is null, not zero');
select ok((pg_temp.as_json(pg_temp.u(2), format('select public.asset_valuations_page_v1(%L, ''{}'', null)', current_setting('t.a')))::text) like '%may not read valuations%', 'V15 a plain member reads nothing');
select ok((pg_temp.as_json(pg_temp.u(5), format('select public.asset_valuations_page_v1(%L, ''{}'', null)', current_setting('t.a')))::text) like '%not an active member%', 'V16 nor does a foreign owner');
select pg_temp.act_as(pg_temp.u(2));
select is((select count(*)::int from public.asset_valuation_batches), 0, 'V17 the tables are closed to a plain member');
reset role;

select * from finish();
rollback;
