-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2574 / 0483: the maker-checker policy of supplier bills and payments is two
-- settings of the space. Real roles; every refusal is followed by a readback.
-- Expected values are written by hand. Defaults are today's rules: another
-- person approves every bill, and nobody is barred from paying.
--   bill 144.00 and bill 300.00; single-approval limit 200 units;
--   payment-checker limit 100 units on a 144.00 payable
begin;
select plan(15);
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
update public.workspaces set feature_flags = feature_flags || '{"configurableSettings": true}' where id = current_setting('t.a')::uuid;
create function pg_temp.draft_and_submit(p_ref text, p_gross int, p_req int) returns text language plpgsql as $$
declare v_d jsonb; v_p text;
begin
  v_d := pg_temp.call(pg_temp.u(1), format('select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)',
    current_setting('t.a'), pg_temp.rq(p_req), pg_temp.bill(p_ref, p_gross)));
  v_p := v_d ->> 'purchase_id';
  perform pg_temp.call(pg_temp.u(1), format('select public.submit_purchase_v1(%L, %L, 1, %L)', current_setting('t.a'), v_p, pg_temp.rq(p_req + 1)));
  return v_p;
end;
$$;
create function pg_temp.rev(p text) returns int language sql as $$
  select revision from public.purchase_documents where id = p::uuid;
$$;
create function pg_temp.setting(p_key text, p_value text) returns jsonb language plpgsql as $$
begin
  return pg_temp.as_json(pg_temp.u(1), format('select public.set_setting(%L, %L, %L::jsonb, ''policy'')', current_setting('t.a'), p_key, p_value));
end;
$$;

-- ── defaults: today's rules ────────────────────────────────────────────
select set_config('t.p1', pg_temp.draft_and_submit('NC-1', 14400, 100), true);
select ok((pg_temp.decide(pg_temp.u(1), current_setting('t.p1'), pg_temp.rev(current_setting('t.p1')), true, '', 102)::text) like '%another person must decide%',
  'by default the person who sent a bill cannot approve it');

-- ── a bill below the single-approval limit ─────────────────────────────
select is(pg_temp.setting('purchase.single_approval_below_units', '200') ->> 'status', 'saved', 'the owner sets a limit of 200 units');
select is(pg_temp.decide(pg_temp.u(1), current_setting('t.p1'), pg_temp.rev(current_setting('t.p1')), false, 'no', 103) ->> 'error', 'another person must decide a purchase you submitted',
  'rejecting one''s own bill is still refused below the limit');
select is(pg_temp.decide(pg_temp.u(1), current_setting('t.p1'), pg_temp.rev(current_setting('t.p1')), true, '', 104) ->> 'state', 'approved',
  'a 144.00 bill is approved by the person who sent it');
select set_config('t.p2', pg_temp.draft_and_submit('NC-2', 30000, 110), true);
select ok((pg_temp.decide(pg_temp.u(1), current_setting('t.p2'), pg_temp.rev(current_setting('t.p2')), true, '', 112)::text) like '%another person must decide%',
  'a 300.00 bill is above the limit: another person is needed');
select is(pg_temp.decide(pg_temp.u(4), current_setting('t.p2'), pg_temp.rev(current_setting('t.p2')), true, '', 113) ->> 'state', 'approved', 'and the second person approves it');

-- ── payments ───────────────────────────────────────────────────────────
-- the second person who pays is a second owner: only owners hold recordOutgoingPayments by default
reset role;
update public.members set is_owner = true where id = pg_temp.mem(4, 't.a');
select set_config('t.ob', (select o.id::text from public.purchase_obligations o where o.purchase_id = current_setting('t.p1')::uuid), true);
select is(pg_temp.setting('purchase.payment_checker_from_units', '100') ->> 'status', 'saved', 'the owner sets the payment limit to 100 units');
select ok((pg_temp.paysup(pg_temp.u(1), current_setting('t.ob'), 10000, 1, 120)::text) like '%another person than the approver%',
  'the approver cannot pay a 144.00 payable, the limit being 100.00');
select is((select count(*)::int from public.purchase_settlement_allocations where obligation_id = current_setting('t.ob')::uuid), 0, 'readback: nothing was paid');
select ok((pg_temp.paysup(pg_temp.u(1), current_setting('t.ob'), 9999, 1, 121)::text) like '%another person than the approver%',
  'nor in small pieces: 99.99 is refused too');
select ok(pg_temp.paysup(pg_temp.u(4), current_setting('t.ob'), 9999, 1, 122) ? 'payment_id', 'a second person records 99.99');
select ok(pg_temp.paysup(pg_temp.u(4), current_setting('t.ob'), 4401, 2, 123) ? 'payment_id', 'and the rest');
select is((select sum(amount_cents)::int from public.purchase_settlement_allocations where obligation_id = current_setting('t.ob')::uuid), 14400, 'and the 144.00 payable is paid in full');

-- a payable below the limit is paid by whoever approved it
select set_config('t.p3', pg_temp.draft_and_submit('NC-3', 5000, 130), true);
select is(pg_temp.decide(pg_temp.u(4), current_setting('t.p3'), pg_temp.rev(current_setting('t.p3')), true, '', 132) ->> 'state', 'approved', 'a 50.00 bill is approved by the second owner');
select set_config('t.ob3', (select o.id::text from public.purchase_obligations o where o.purchase_id = current_setting('t.p3')::uuid), true);
select ok(pg_temp.paysup(pg_temp.u(4), current_setting('t.ob3'), 5000, 1, 133) ? 'payment_id', 'who may pay it in full, being below the limit');

select * from finish();
rollback;
