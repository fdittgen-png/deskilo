-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2574 / 0470 (C2d of #2464): a supplier's credit note is applied to the
-- bill it reverses. Real roles; every refusal is followed by a readback.
-- Expected values are written by hand (a 144.00 bill, a 24.00 credit note,
-- 120.00 paid afterwards).
--   A refusals   B applying the credit   C paying what remains   D what a
--   credit is not (reversed, repeated, edited)
-- NOT RUN here: two sessions racing the last of a payable.
begin;
select plan(27);


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
 ('00000000-0000-4000-8000-0000257600a2', current_setting('t.a')::uuid, '2', 'Autre Fournisseur'),
 ('00000000-0000-4000-8000-0000257600b1', current_setting('t.b')::uuid, '1', 'Other Ltd');
create temp table seed_counts as select (select count(*) from public.ledger_entries) as ledger;

create function pg_temp.draft(p_json text, p_req int) returns text language sql as $$
  select (pg_temp.call(pg_temp.u(1), format('select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)',
    current_setting('t.a'), pg_temp.rq(p_req), p_json))) ->> 'purchase_id';
$$;
create function pg_temp.credit(p_ref text, p_gross int, p_original text, p_supplier text default '00000000-0000-4000-8000-0000257600a1') returns text
language sql as $$
  select (pg_temp.bill(p_ref, p_gross)::jsonb || jsonb_build_object('kind', 'credit_note', 'supplier_id', p_supplier)
          || case when p_original is null then '{}'::jsonb else jsonb_build_object('original_document_id', p_original) end)::text;
$$;
create function pg_temp.apply(p_user uuid, p_credit text, p_rev int, p_req int) returns jsonb language plpgsql as $$
begin
  return pg_temp.as_json(p_user, format('select public.apply_supplier_credit_note_v1(%L, %L, %s, %L)',
    current_setting('t.a'), p_credit, p_rev, pg_temp.rq(p_req)));
end;
$$;

-- the bill: 144.00, captured and sent by the owner, approved by the admin
select set_config('t.p1', pg_temp.draft(pg_temp.bill('NC-1', 14400), 1), true);
select pg_temp.call(pg_temp.u(1), format('select public.submit_purchase_v1(%L, %L, 1, %L)', current_setting('t.a'), current_setting('t.p1'), pg_temp.rq(2)));
select pg_temp.decide(pg_temp.u(4), current_setting('t.p1'), 1, true, '', 3);
select set_config('t.ob', (select o.id::text from public.purchase_obligations o where o.purchase_id = current_setting('t.p1')::uuid), true);
-- a second bill, still pending
select set_config('t.p2', pg_temp.draft(pg_temp.bill('NC-2', 5000), 4), true);
select pg_temp.call(pg_temp.u(1), format('select public.submit_purchase_v1(%L, %L, 1, %L)', current_setting('t.a'), current_setting('t.p2'), pg_temp.rq(5)));
-- the credit notes
select set_config('t.c1', pg_temp.draft(pg_temp.credit('AV-1', 2400, current_setting('t.p1')), 6), true);
select set_config('t.cnone', pg_temp.draft(pg_temp.credit('AV-0', 500, null), 7), true);
select set_config('t.cpend', pg_temp.draft(pg_temp.credit('AV-P', 500, current_setting('t.p2')), 8), true);
select set_config('t.cother', pg_temp.draft(pg_temp.credit('AV-S', 500, current_setting('t.p1'), '00000000-0000-4000-8000-0000257600a2'), 9), true);
select set_config('t.cbig', pg_temp.draft(pg_temp.credit('AV-B', 20000, current_setting('t.p1')), 10), true);
select set_config('t.czero', pg_temp.draft(pg_temp.credit('AV-Z', 0, current_setting('t.p1')), 11), true);

-- ── A: refusals ────────────────────────────────────────────────────────
select ok((pg_temp.apply(pg_temp.u(2), current_setting('t.c1'), 1, 20)::text) like '%may not decide purchases%', 'A: a plain member cannot apply a credit note');
select ok((pg_temp.apply(pg_temp.u(5), current_setting('t.c1'), 1, 21)::text) like '%not an active member%', 'A: nor a foreign owner');
select ok((pg_temp.apply(pg_temp.u(1), current_setting('t.c1'), 1, 22)::text) like '%another person must apply%', 'A: whoever captured the credit note does not apply it');
select ok((pg_temp.apply(pg_temp.u(4), current_setting('t.c1'), 9, 23)::text) like '%stale revision%', 'A: a stale revision is refused');
select ok((pg_temp.apply(pg_temp.u(4), current_setting('t.p1'), 1, 24)::text) like '%only a credit note%', 'A: a bill is not applied to a bill');
select ok((pg_temp.apply(pg_temp.u(4), current_setting('t.cnone'), 1, 25)::text) like '%name the bill%', 'A: a credit note without its bill is refused');
select ok((pg_temp.apply(pg_temp.u(4), current_setting('t.cpend'), 1, 26)::text) like '%approved first%', 'A: the bill must be approved first');
select ok((pg_temp.apply(pg_temp.u(4), current_setting('t.cother'), 1, 27)::text) like '%same supplier%', 'A: another supplier''s credit note is refused');
select ok((pg_temp.apply(pg_temp.u(4), current_setting('t.cbig'), 1, 28)::text) like '%exceeds what remains%', 'A: a credit note larger than the payable is refused');
select ok((pg_temp.apply(pg_temp.u(4), current_setting('t.czero'), 1, 29)::text) like '%needs an amount%', 'A: a credit note without an amount is refused');
select is((select count(*)::int from public.purchase_settlement_allocations where kind = 'credit'), 0, 'A: readback: no refusal wrote an allocation');
select is((select string_agg(distinct state, ',') from public.purchase_documents where kind = 'credit_note'), 'draft', 'A: and every credit note is still a draft');

-- ── B: applying the credit ─────────────────────────────────────────────
select set_config('t.ap', pg_temp.apply(pg_temp.u(4), current_setting('t.c1'), 1, 30)::text, true);
select is(current_setting('t.ap')::jsonb ->> 'state', 'approved', 'B: another person with approveExpenses applies the 24.00 credit note');
select is((current_setting('t.ap')::jsonb #>> '{obligation,paid_cents}') || '/' || (current_setting('t.ap')::jsonb #>> '{obligation,remaining_cents}'), '2400/12000',
  'B: golden: 24.00 is credited, 120.00 remains to pay');
select is((select concat_ws('/', a.kind, a.amount_cents, (a.credit_document_id = current_setting('t.c1')::uuid)::text, coalesce(a.payment_id::text, 'none'))
             from public.purchase_settlement_allocations a where a.obligation_id = current_setting('t.ob')::uuid), 'credit/2400/true/none',
  'B: the allocation names the credit note and no payment');
select is((select concat_ws('/', d.state, (d.decided_by_member_id = pg_temp.mem(4, 't.a'))::text, d.supplier_snapshot ->> 'name')
             from public.purchase_documents d where d.id = current_setting('t.c1')::uuid), 'approved/true/Net & Clair',
  'B: the credit note is approved by the applier, with the bill''s snapshots');
select is(current_setting('t.ap')::jsonb #>> '{obligation,allocations,0,method}', 'credit', 'B: the allocation reads as a credit');
select is(current_setting('t.ap')::jsonb #>> '{obligation,allocations,0,reference}', 'AV-1', 'B: with the credit note''s reference');
select is(pg_temp.apply(pg_temp.u(4), current_setting('t.c1'), 1, 30), current_setting('t.ap')::jsonb, 'B: the same request answers the original');
select ok((pg_temp.apply(pg_temp.u(4), current_setting('t.c1'), 1, 31)::text) like '%already decided%', 'B: a credit note is applied once');
select is((select count(*)::int from public.ledger_entries), (select ledger::int from seed_counts), 'B: and no member-account row was written');

-- ── C: paying what remains ─────────────────────────────────────────────
select set_config('t.pay', pg_temp.paysup(pg_temp.u(1), current_setting('t.ob'), 12000, 2, 40)::text, true);
select is(current_setting('t.pay')::jsonb #>> '{obligation,remaining_cents}', '0', 'C: paying 120.00 settles the payable');
select ok((pg_temp.paysup(pg_temp.u(1), current_setting('t.ob'), 1, 3, 41)::text) like '%exceeds what remains%', 'C: nothing more can be paid');

-- ── D: what a credit is not ────────────────────────────────────────────
select ok((pg_temp.as_json(pg_temp.u(1), format('select public.reverse_purchase_allocation_v1(%L, %L, 3, ''wrong'', %L)',
  current_setting('t.a'), (current_setting('t.ap')::jsonb ->> 'allocation_id')::uuid, pg_temp.rq(42)))::text) like '%only a payment can be reversed%',
  'D: a credit is not reversed as a payment');
select ok(pg_temp.owner_err(format('update public.purchase_documents set category = ''x'' where id = %L', current_setting('t.c1'))) like '%frozen%',
  'D: an applied credit note is frozen');
select ok(pg_temp.owner_err(format($q$insert into public.purchase_settlement_allocations
  (workspace_id, obligation_id, kind, amount_cents, credit_document_id, request_id, actor_member_id)
  values (%L, %L, 'credit', 100, %L, gen_random_uuid(), %L)$q$, current_setting('t.a'), current_setting('t.ob'), current_setting('t.c1'), pg_temp.mem(4, 't.a')))
  like '%one_credit%', 'D: one credit note feeds one allocation, even for an owner of the table');
select ok(pg_temp.owner_err(format($q$insert into public.purchase_settlement_allocations
  (workspace_id, obligation_id, kind, amount_cents, request_id, actor_member_id)
  values (%L, %L, 'credit', 100, gen_random_uuid(), %L)$q$, current_setting('t.a'), current_setting('t.ob'), pg_temp.mem(4, 't.a')))
  like '%source_check%', 'D: a credit without its document is refused by the table');

select * from finish();
rollback;
