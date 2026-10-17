-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2574 / 0468 (C2b of #2464): a supplier bill is submitted, decided by a
-- second person, becomes what the space owes the supplier, and is paid.
-- Real roles; every refusal is followed by a readback. Expected values are
-- written by hand (a 144.00 bill, 90.00 then 54.00 paid).
--   A capture and submit   B the second person decides   C paying the
--   supplier   D a reversal   E who reads what
-- NOT RUN here: two sessions racing the last of a payable.
begin;
select plan(47);

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
create temp table seed_counts as select (select count(*) from public.ledger_entries) as ledger;

-- ── A: capture and submit ──────────────────────────────────────────────
select set_config('t.d1', pg_temp.call(pg_temp.u(1), format('select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)',
  current_setting('t.a'), pg_temp.rq(1), pg_temp.bill('NC-1', 14400)))::text, true);
select set_config('t.p1', current_setting('t.d1')::jsonb ->> 'purchase_id', true);
select is(current_setting('t.d1')::jsonb ->> 'state', 'draft', 'A: the owner captures a bill of 144.00 as a draft');
select ok((pg_temp.call(pg_temp.u(2), format('select public.submit_purchase_v1(%L, %L, 1, %L)', current_setting('t.a'), current_setting('t.p1'), pg_temp.rq(2)))::text) like '%not allowed to capture supplier bills%',
  'A: a member without managePurchases cannot send it to approval');
select set_config('t.s1', pg_temp.call(pg_temp.u(1), format('select public.submit_purchase_v1(%L, %L, 1, %L)', current_setting('t.a'), current_setting('t.p1'), pg_temp.rq(3)))::text, true);
select is(current_setting('t.s1')::jsonb ->> 'state', 'pending', 'A: submitting puts the bill to approval');
select is(pg_temp.call(pg_temp.u(1), format('select public.submit_purchase_v1(%L, %L, 1, %L)', current_setting('t.a'), current_setting('t.p1'), pg_temp.rq(3))),
  current_setting('t.s1')::jsonb, 'A: the same request answers the original');
select ok((pg_temp.call(pg_temp.u(1), format('select public.save_purchase_draft_v1(%L, %L, 1, %L::jsonb)', current_setting('t.a'), pg_temp.rq(4),
  (pg_temp.bill('NC-1', 14400)::jsonb || jsonb_build_object('purchase_id', current_setting('t.p1')))::text))::text) like '%only a draft can be edited%',
  'A: a bill awaiting approval cannot be edited');
select set_config('t.nosup', pg_temp.call(pg_temp.u(1), format('select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)',
  current_setting('t.a'), pg_temp.rq(5), jsonb_build_object('kind', 'bill', 'lines', jsonb_build_array(jsonb_build_object('gross_cents', 500)))::text))::text, true);
select ok((pg_temp.call(pg_temp.u(1), format('select public.submit_purchase_v1(%L, %L, 1, %L)', current_setting('t.a'), current_setting('t.nosup')::jsonb ->> 'purchase_id', pg_temp.rq(6)))::text) like '%needs its supplier%',
  'A: a bill without its supplier is not submitted');
select set_config('t.cn', pg_temp.call(pg_temp.u(1), format('select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)',
  current_setting('t.a'), pg_temp.rq(7), (pg_temp.bill('AV-1', 2400)::jsonb || '{"kind":"credit_note"}'::jsonb)::text))::text, true);
select ok((pg_temp.call(pg_temp.u(1), format('select public.submit_purchase_v1(%L, %L, 1, %L)', current_setting('t.a'), current_setting('t.cn')::jsonb ->> 'purchase_id', pg_temp.rq(8)))::text) like '%credit note is applied%',
  'A: a credit note waits for the step that applies it to its bill');
select set_config('t.paid', pg_temp.call(pg_temp.u(1), format('select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)',
  current_setting('t.a'), pg_temp.rq(9), (pg_temp.bill('PAID-1', 1000)::jsonb || '{"payer_kind":"workspace"}'::jsonb)::text))::text, true);
select ok((pg_temp.call(pg_temp.u(1), format('select public.submit_purchase_v1(%L, %L, 1, %L)', current_setting('t.a'), current_setting('t.paid')::jsonb ->> 'purchase_id', pg_temp.rq(10)))::text) like '%still to be paid%',
  'A: a bill already paid by the space is not a payable');

-- ── B: the second person decides ───────────────────────────────────────
select ok((pg_temp.decide(pg_temp.u(1), current_setting('t.p1'), 1, true, '', 11)::text) like '%another person must decide%', 'B: the submitter cannot decide their own bill');
select ok((pg_temp.decide(pg_temp.u(2), current_setting('t.p1'), 1, true, '', 12)::text) like '%may not decide purchases%', 'B: a plain member cannot decide');
select ok((pg_temp.decide(pg_temp.u(5), current_setting('t.p1'), 1, true, '', 13)::text) like '%not an active member%', 'B: nor a foreign owner');
select ok((pg_temp.decide(pg_temp.u(4), current_setting('t.p1'), 9, true, '', 14)::text) like '%stale revision%', 'B: a stale revision is refused');
select ok((pg_temp.decide(pg_temp.u(4), current_setting('t.p1'), 1, false, '', 15)::text) like '%state why it is rejected%', 'B: a rejection needs its reason');
select is((select count(*)::int from public.purchase_obligations where workspace_id = current_setting('t.a')::uuid and creditor_kind = 'supplier'), 0, 'B: readback: no refusal filed a payable');
select is((select state from public.purchase_documents where id = current_setting('t.p1')::uuid), 'pending', 'B: and the bill is still pending');
select set_config('t.ok', pg_temp.decide(pg_temp.u(4), current_setting('t.p1'), 1, true, '', 16)::text, true);
select is(current_setting('t.ok')::jsonb ->> 'state', 'approved', 'B: another person with approveExpenses approves');
select is((select concat_ws('/', o.creditor_kind, o.amount_cents, o.state, (o.creditor_supplier_id = '00000000-0000-4000-8000-0000257600a1')::text)
             from public.purchase_obligations o where o.purchase_id = current_setting('t.p1')::uuid), 'supplier/14400/open/true',
  'B: golden: the payable is 144.00 owed to the supplier');
select is((select concat_ws('/', d.supplier_snapshot ->> 'name', (d.decided_by_member_id = pg_temp.mem(4, 't.a'))::text, d.recipient_snapshot ->> 'name')
             from public.purchase_documents d where d.id = current_setting('t.p1')::uuid), 'Net & Clair/true/Supplier A',
  'B: the supplier and the recipient are snapshotted with the decider');
select is(pg_temp.decide(pg_temp.u(4), current_setting('t.p1'), 1, true, '', 16), current_setting('t.ok')::jsonb, 'B: the same request answers the original');
select is((select count(*)::int from public.purchase_obligations where purchase_id = current_setting('t.p1')::uuid), 1, 'B: and files no second payable');
select ok((pg_temp.decide(pg_temp.u(4), current_setting('t.p1'), 1, false, 'late', 17)::text) like '%only a purchase awaiting approval%', 'B: a decided bill is not decided again');
select ok(pg_temp.owner_err(format('update public.purchase_documents set category = ''x'' where id = %L', current_setting('t.p1'))) like '%frozen%', 'B: a decided bill is frozen');
select ok(pg_temp.owner_err(format('update public.purchase_documents set state = ''approved'' where id = %L', current_setting('t.nosup')::jsonb ->> 'purchase_id')) like '%purchase_documents_approval_check%',
  'B: nothing is approved without an event or a person');
-- a second bill, rejected
select set_config('t.d2', pg_temp.call(pg_temp.u(1), format('select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)',
  current_setting('t.a'), pg_temp.rq(18), pg_temp.bill('NC-2', 6000)))::text, true);
select pg_temp.call(pg_temp.u(1), format('select public.submit_purchase_v1(%L, %L, 1, %L)', current_setting('t.a'), current_setting('t.d2')::jsonb ->> 'purchase_id', pg_temp.rq(19)));
select is(pg_temp.decide(pg_temp.u(4), current_setting('t.d2')::jsonb ->> 'purchase_id', 1, false, 'not ours', 20) ->> 'state', 'rejected', 'B: a bill can be rejected with a reason');
select is((select count(*)::int from public.purchase_obligations where purchase_id = (current_setting('t.d2')::jsonb ->> 'purchase_id')::uuid), 0, 'B: and a rejection files no payable');
select is((select decision_reason from public.purchase_documents where id = (current_setting('t.d2')::jsonb ->> 'purchase_id')::uuid), 'not ours', 'B: the reason is kept');

-- ── C: paying the supplier ─────────────────────────────────────────────
select set_config('t.ob', (select o.id::text from public.purchase_obligations o where o.purchase_id = current_setting('t.p1')::uuid), true);
select set_config('t.pay1', pg_temp.paysup(pg_temp.u(1), current_setting('t.ob'), 9000, 1, 30)::text, true);
select is((current_setting('t.pay1')::jsonb #>> '{obligation,paid_cents}') || '/' || (current_setting('t.pay1')::jsonb #>> '{obligation,remaining_cents}') || '/' || (current_setting('t.pay1')::jsonb #>> '{obligation,creditor_name}'),
  '9000/5400/Net & Clair', 'C: golden: 90.00 of 144.00 paid leaves 54.00, the supplier named');
select is((select concat_ws('/', p.state, p.payee_kind, (p.payee_supplier_id is not null)::text, p.amount_cents)
             from public.outgoing_payments p where p.id = (current_setting('t.pay1')::jsonb ->> 'payment_id')::uuid), 'reported/supplier/true/9000', 'C: the payment is reported to the supplier');
select is((select count(*)::int from public.ledger_entries), (select ledger::int from seed_counts), 'C: and no member-account row was written');
select is(pg_temp.paysup(pg_temp.u(1), current_setting('t.ob'), 9000, 1, 30), current_setting('t.pay1')::jsonb, 'C: the same request answers the original');
select ok((pg_temp.paysup(pg_temp.u(1), current_setting('t.ob'), 5401, 2, 31)::text) like '%exceeds what remains%', 'C: more than remains is refused');
select ok((pg_temp.paysup(pg_temp.u(1), current_setting('t.ob'), 100, 1, 32)::text) like '%stale revision%', 'C: a stale revision is refused');
select ok((pg_temp.paysup(pg_temp.u(4), current_setting('t.ob'), 100, 2, 33)::text) like '%may not record outgoing payments%', 'C: an admin without the permission cannot record cash');
select ok((pg_temp.paysup(pg_temp.u(2), current_setting('t.ob'), 100, 2, 34)::text) like '%may not record outgoing payments%', 'C: nor a plain member');
select ok((pg_temp.paysup(pg_temp.u(1), current_setting('t.ob'), 100, 2, 35, pg_temp.today() + 2)::text) like '%future%', 'C: nor a payment dated in the future');
select ok((pg_temp.as_json(pg_temp.u(1), format('select public.record_member_reimbursement_v1(%L, %L, 100, 2, %L, %L, ''cash'', '''')',
    current_setting('t.a'), current_setting('t.ob'), pg_temp.rq(36), pg_temp.today() - 1))::text) like '%supplier is paid once%',
  'C: a supplier payable is not paid through the member path');
select set_config('t.pay2', pg_temp.paysup(pg_temp.u(1), current_setting('t.ob'), 5400, 2, 37)::text, true);
select is(current_setting('t.pay2')::jsonb #>> '{obligation,remaining_cents}', '0', 'C: paying the rest leaves nothing to pay');
select ok((pg_temp.paysup(pg_temp.u(1), current_setting('t.ob'), 1, 3, 38)::text) like '%exceeds what remains%', 'C: nothing more can be paid');

-- ── D: a reversal ──────────────────────────────────────────────────────
select set_config('t.rv', pg_temp.as_json(pg_temp.u(1), format('select public.reverse_purchase_allocation_v1(%L, %L, 3, ''paid to the wrong account'', %L)',
  current_setting('t.a'), (current_setting('t.pay2')::jsonb ->> 'allocation_id')::uuid, pg_temp.rq(40)))::text, true);
select is((current_setting('t.rv')::jsonb #>> '{obligation,paid_cents}') || '/' || (current_setting('t.rv')::jsonb #>> '{obligation,remaining_cents}'), '9000/5400',
  'D: the 54.00 payment is reversed: 54.00 is owed again');
select is((select p.state from public.outgoing_payments p where p.id = (current_setting('t.pay2')::jsonb ->> 'payment_id')::uuid), 'reversed', 'D: the payment is marked reversed');
select is((select count(*)::int from public.ledger_entries), (select ledger::int from seed_counts), 'D: and no member-account row was written');
select ok((pg_temp.as_json(pg_temp.u(1), format('select public.reverse_purchase_allocation_v1(%L, %L, 4, ''again'', %L)',
  current_setting('t.a'), (current_setting('t.pay2')::jsonb ->> 'allocation_id')::uuid, pg_temp.rq(41)))::text) like '%already reversed%', 'D: a payment is reversed once');

-- ── E: who reads what ──────────────────────────────────────────────────
select is(jsonb_array_length(pg_temp.as_json(pg_temp.u(1), format('select public.purchase_payables_page_v1(%L, ''supplier'') -> ''rows''', current_setting('t.a')))), 1,
  'E: the owner reads the supplier payable');
select is(pg_temp.as_json(pg_temp.u(1), format('select to_jsonb(public.purchase_payables_page_v1(%L, ''supplier'') #>> ''{rows,0,obligation,creditor_name}'')', current_setting('t.a'))) #>> '{}', 'Net & Clair',
  'E: and the supplier''s name');
select is(jsonb_array_length(pg_temp.as_json(pg_temp.u(2), format('select public.purchase_payables_page_v1(%L, ''supplier'') -> ''rows''', current_setting('t.a')))), 0,
  'E: a plain member reads no supplier payable');
select is(jsonb_array_length(pg_temp.as_json(pg_temp.u(4), format('select public.purchase_payables_page_v1(%L, ''supplier'') -> ''rows''', current_setting('t.a')))), 1,
  'E: positive control: the admin reading the finances does');
select pg_temp.act_as(pg_temp.u(2));
select is((select count(*)::int from public.outgoing_payments where payee_kind = 'supplier') + (select count(*)::int from public.purchase_settlement_allocations), 0,
  'E: a plain member reads no supplier payment nor allocation');
reset role;

select * from finish();
rollback;
