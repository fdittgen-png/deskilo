-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2574 / 0467 (C2a of #2464): recording the cash a member is paid back.
-- Real roles (authenticated through the definer RPCs and the RLS policies);
-- every refusal is followed by a readback proving nothing changed. Expected
-- values are written here by hand (a 120.00 claim, 50.00 paid, a 35.00 fee),
-- never read from the function under test.
--   A pay part of a claim: payment, allocation, member account, replay
--   B refusals: stale, over, malformed, future, unauthorised, own claim
--   C the invoice states the credit net of the cash; a claim applied to an
--     invoice is neither paid nor reversed again
--   D reversal: the credit is whole again, once
--   E a fully paid claim leaves no expense line
--   F history is append-only; who reads what
--   G the invoice guard
-- NOT RUN here: two synchronized sessions racing the last of a claim.
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
  select ('00000000-0000-4000-8000-00002575' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.mem(n int, w text) returns uuid language sql as $$
  select id from public.members
   where user_id = pg_temp.u(n) and workspace_id = current_setting(w)::uuid;
$$;
create function pg_temp.ev(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00002575e' || lpad(n::text, 3, '0'))::uuid;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@reimburse.test', '', now(), now(), now()
  from generate_series(1, 5) i;
-- 1 owner of A, 2 and 3 plain members of A, 4 a second admin of A, 5 owner of B.

select pg_temp.act_as(pg_temp.u(1));
select set_config('t.a', public.create_workspace('Reimburse A', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select pg_temp.act_as(pg_temp.u(5));
select set_config('t.b', public.create_workspace('Reimburse B', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
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
insert into public.suppliers (id, workspace_id, supplier_number, name) values
 ('00000000-0000-4000-8000-0000257500a1', current_setting('t.a')::uuid, '1', 'ACME Sarl'),
 ('00000000-0000-4000-8000-0000257500b1', current_setting('t.b')::uuid, '1', 'Other Ltd');


create function pg_temp.rq(n int) returns uuid language sql as $$
  select ('b0000000-0000-4000-8000-00000000' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.today() returns date language sql as $$
  select (now() at time zone 'Europe/Paris')::date;
$$;
create function pg_temp.ob(n int) returns uuid language sql as $$
  select o.id from public.purchase_obligations o join public.purchase_sources s on s.purchase_id = o.purchase_id
   where s.source_id = pg_temp.ev(n);
$$;
create function pg_temp.rev(n int) returns int language sql as $$
  select revision from public.purchase_obligations where id = pg_temp.ob(n);
$$;
create function pg_temp.pay(p_user uuid, n int, p_amount bigint, p_rev int, p_req int, p_paid_on date default null) returns jsonb
language plpgsql as $$
begin
  return pg_temp.as_json(p_user, format(
    'select public.record_member_reimbursement_v1(%L, %L, %s, %s, %L, %L, ''bank_transfer'', ''transfer ref'')',
    current_setting('t.a'), pg_temp.ob(n), p_amount, p_rev, pg_temp.rq(p_req), coalesce(p_paid_on, pg_temp.today() - 1)));
end;
$$;
create function pg_temp.page_obligation(p_n int) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  for r in select x from jsonb_array_elements(pg_temp.as_json(pg_temp.u(1), format(
        'select public.purchase_payables_page_v1(%L, ''member'', 200) -> ''rows''', current_setting('t.a')))) x loop
    if (r #>> '{obligation,id}')::uuid = pg_temp.ob(p_n) then return r -> 'obligation'; end if;
  end loop;
  return null;
end;
$$;

-- e1: EUR 120.00, September; e2: EUR 120.00, August; e3: EUR 50.00, July;
-- e4: the owner's own claim of EUR 10.00. All approved, credits booked a day ago.
insert into public.events (id, workspace_id, type, action, actor_member_id, subject_member_id, payload, status, decided_at) values
 (pg_temp.ev(1), current_setting('t.a')::uuid, 'expense', 'submitted', pg_temp.mem(2, 't.a'), pg_temp.mem(2, 't.a'), '{"amount_cents": 12000, "category": "cleaning", "note": "Cleaning"}', 'confirmed', now() - interval '2 days'),
 (pg_temp.ev(2), current_setting('t.a')::uuid, 'expense', 'submitted', pg_temp.mem(2, 't.a'), pg_temp.mem(2, 't.a'), '{"amount_cents": 12000, "category": "cleaning", "note": "Cleaning Aug"}', 'confirmed', now() - interval '2 days'),
 (pg_temp.ev(3), current_setting('t.a')::uuid, 'expense', 'submitted', pg_temp.mem(2, 't.a'), pg_temp.mem(2, 't.a'), '{"amount_cents": 5000, "category": "coffee", "note": "Coffee Jul"}', 'confirmed', now() - interval '2 days'),
 (pg_temp.ev(4), current_setting('t.a')::uuid, 'expense', 'submitted', pg_temp.mem(1, 't.a'), pg_temp.mem(1, 't.a'), '{"amount_cents": 1000, "category": "tea", "note": "Tea"}', 'confirmed', now() - interval '2 days');
insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, event_id, created_at) values
 (current_setting('t.a')::uuid, pg_temp.mem(2, 't.a'), 'credit', 'expense', 12000, 'Cleaning', '2026-09', pg_temp.ev(1), now() - interval '1 day'),
 (current_setting('t.a')::uuid, pg_temp.mem(2, 't.a'), 'credit', 'expense', 12000, 'Cleaning Aug', '2026-08', pg_temp.ev(2), now() - interval '1 day'),
 (current_setting('t.a')::uuid, pg_temp.mem(2, 't.a'), 'credit', 'expense', 5000, 'Coffee Jul', '2026-07', pg_temp.ev(3), now() - interval '1 day'),
 (current_setting('t.a')::uuid, pg_temp.mem(1, 't.a'), 'credit', 'expense', 1000, 'Tea', '2026-09', pg_temp.ev(4), now() - interval '1 day');
create temp table seed_counts as select
  (select count(*) from public.ledger_entries) as ledger,
  (select count(*) from public.outgoing_payments) as pays,
  (select count(*) from public.purchase_settlement_allocations) as allocs;

-- ── A: part of a claim ─────────────────────────────────────────────────
select set_config('t.r1', pg_temp.pay(pg_temp.u(1), 1, 5000, 1, 1)::text, true);
select is((current_setting('t.r1')::jsonb #>> '{obligation,paid_cents}') || '/' || (current_setting('t.r1')::jsonb #>> '{obligation,remaining_cents}') || '/' || (current_setting('t.r1')::jsonb #>> '{obligation,revision}'),
  '5000/7000/2', 'A: golden: EUR 50 of 120 paid leaves 70, revision 2');
select is((select concat_ws('/', p.state, p.amount_cents, p.method, p.reported_paid_on = pg_temp.today() - 1, p.actor_member_id = pg_temp.mem(1, 't.a'), p.payee_member_id = pg_temp.mem(2, 't.a'))
             from public.outgoing_payments p where p.id = (current_setting('t.r1')::jsonb ->> 'payment_id')::uuid),
  'reported/5000/bank_transfer/t/t/t', 'A: the payment is reported (not reconciled) with its actor and payee');
select is((select concat_ws('/', l.kind, l.category, l.amount_cents, l.period, l.vat_percent, l.member_id = pg_temp.mem(2, 't.a'))
             from public.ledger_entries l where l.category = 'reimbursement' and l.workspace_id = current_setting('t.a')::uuid),
  'charge/reimbursement/5000/2026-09/0.000000/t', 'A: the member account carries a 50.00 charge in the credit''s own period, no VAT');
select is((select sum(case when kind = 'credit' then amount_cents else -amount_cents end)::int from public.ledger_entries
            where member_id = pg_temp.mem(2, 't.a') and category in ('expense', 'reimbursement') and period = '2026-09'), 7000,
  'A: the account of the claim stands at 70.00 (credit 120 - paid 50)');
select is(pg_temp.pay(pg_temp.u(1), 1, 5000, 1, 1), current_setting('t.r1')::jsonb,
  'A: the same request id with the same entries answers the original');
select is((select (ledger + 1 = (select count(*) from public.ledger_entries) and pays + 1 = (select count(*) from public.outgoing_payments)
                   and allocs + 1 = (select count(*) from public.purchase_settlement_allocations))::text from seed_counts), 'true',
  'A: and the replay made no second payment, allocation or ledger row');
select ok((pg_temp.pay(pg_temp.u(1), 1, 4000, 1, 1)::text) like '%different request%', 'A: the same request id with another amount is refused');

-- ── B: refusals ────────────────────────────────────────────────────────
create temp table b_counts as select
  (select count(*) from public.ledger_entries) as ledger,
  (select count(*) from public.outgoing_payments) as pays,
  (select count(*) from public.purchase_settlement_allocations) as allocs,
  (select sum(amount_cents) from public.purchase_settlement_allocations) as total;
select ok((pg_temp.pay(pg_temp.u(1), 1, 1000, 1, 2)::text) like '%stale revision%', 'B: a stale revision is refused');
select ok((pg_temp.pay(pg_temp.u(1), 1, 7001, 2, 3)::text) like '%exceeds what remains%', 'B: more than remains is refused (70.01 of 70.00)');
select ok((pg_temp.pay(pg_temp.u(1), 1, 0, 2, 4)::text) like '%must be positive%', 'B: a zero amount is refused');
select ok((pg_temp.pay(pg_temp.u(1), 1, -5, 2, 5)::text) like '%must be positive%', 'B: a negative amount is refused');
select ok((pg_temp.pay(pg_temp.u(1), 1, 1000, 2, 6, pg_temp.today() + 3)::text) like '%future%', 'B: a payment dated in the future is refused (it is not a payment yet)');
select ok((pg_temp.as_json(pg_temp.u(1), format('select public.record_member_reimbursement_v1(%L, %L, 1000, 2, %L, %L, ''gold'', '''')',
    current_setting('t.a'), pg_temp.ob(1), pg_temp.rq(7), pg_temp.today() - 1))::text) like '%unknown payment method%', 'B: an unknown method is refused');
select ok((pg_temp.pay(pg_temp.u(4), 1, 1000, 2, 8)::text) like '%may not record outgoing payments%', 'B: an admin without the permission cannot record cash');
select ok((pg_temp.pay(pg_temp.u(3), 1, 1000, 2, 9)::text) like '%may not record outgoing payments%', 'B: nor a plain member');
select ok((pg_temp.pay(pg_temp.u(2), 1, 1000, 2, 10)::text) like '%may not record outgoing payments%', 'B: nor the claimant');
select ok((pg_temp.pay(pg_temp.u(5), 1, 1000, 2, 11)::text) like '%not an active member%', 'B: nor the owner of another workspace');
select ok((pg_temp.as_json(pg_temp.u(5), format('select public.record_member_reimbursement_v1(%L, %L, 1000, 2, %L, %L, ''cash'', '''')',
    current_setting('t.b'), pg_temp.ob(1), pg_temp.rq(12), pg_temp.today() - 1))::text) like '%unknown obligation%', 'B: a foreign owner naming A''s claim under their own workspace finds nothing');
select ok((pg_temp.pay(pg_temp.u(1), 4, 500, 1, 13)::text) like '%another person must record%', 'B: the owner cannot pay their own claim');
select is((select (ledger = (select count(*) from public.ledger_entries) and pays = (select count(*) from public.outgoing_payments)
                   and allocs = (select count(*) from public.purchase_settlement_allocations)
                   and total = (select sum(amount_cents) from public.purchase_settlement_allocations))::text from b_counts), 'true',
  'B: readback: no refusal wrote a payment, allocation or ledger row');
select is(pg_temp.rev(1), 2, 'B: and the claim is still at revision 2');

-- ── C: the invoice nets the credit; applied is final ───────────────────
select pg_temp.act_as(pg_temp.u(1));
select set_config('t.inv1', public.create_invoice(current_setting('t.a')::uuid, pg_temp.mem(2, 't.a'), '2026-09')::text, true);
reset role;
select is((select string_agg((x ->> 'kind') || ':' || (x ->> 'amount_cents'), ',' order by x ->> 'kind')
             from public.invoices i, jsonb_array_elements(i.lines) x where i.id = current_setting('t.inv1')::uuid),
  'expense:-7000,subscription:3500', 'C: golden: the September invoice states the credit net of the cash (-70.00), no reimbursement line');
select is((select total_cents from public.invoices where id = current_setting('t.inv1')::uuid), -3500, 'C: total 35.00 - 70.00 = -35.00 (a credit note)');
select is((pg_temp.page_obligation(1) ->> 'paid_cents') || '/' || (pg_temp.page_obligation(1) ->> 'applied_cents') || '/' || (pg_temp.page_obligation(1) ->> 'remaining_cents'),
  '5000/7000/0', 'C: paid 50 + applied 70 = the whole 120, nothing remaining');
select ok((pg_temp.pay(pg_temp.u(1), 1, 100, 2, 14)::text) like '%already applied to an invoice%', 'C: a claim applied to an invoice cannot be paid again');
select ok((pg_temp.as_json(pg_temp.u(1), format('select public.reverse_purchase_allocation_v1(%L, %L, 2, ''oops'', %L)',
    current_setting('t.a'), (current_setting('t.r1')::jsonb ->> 'allocation_id')::uuid, pg_temp.rq(15)))::text) like '%already applied to an invoice%', 'C: nor can its payment be reversed');

-- ── D: reversal ────────────────────────────────────────────────────────
select set_config('t.r2', pg_temp.pay(pg_temp.u(1), 2, 5000, 1, 20)::text, true);
select is(pg_temp.as_json(pg_temp.u(1), format('select public.reverse_purchase_allocation_v1(%L, %L, 2, '''', %L)',
    current_setting('t.a'), (current_setting('t.r2')::jsonb ->> 'allocation_id')::uuid, pg_temp.rq(21))) ->> 'error', 'state why it is reversed',
  'D: a reversal needs its reason');
select set_config('t.r3', pg_temp.as_json(pg_temp.u(1), format('select public.reverse_purchase_allocation_v1(%L, %L, 2, ''paid twice by mistake'', %L)',
    current_setting('t.a'), (current_setting('t.r2')::jsonb ->> 'allocation_id')::uuid, pg_temp.rq(22)))::text, true);
select is((current_setting('t.r3')::jsonb #>> '{obligation,paid_cents}') || '/' || (current_setting('t.r3')::jsonb #>> '{obligation,remaining_cents}') || '/' || (current_setting('t.r3')::jsonb #>> '{obligation,revision}'),
  '0/12000/3', 'D: golden: reversed, the whole 120.00 remains again, revision 3');
select is((select concat_ws('/', p.state, (select a.amount_cents from public.purchase_settlement_allocations a where a.original_allocation_id = (current_setting('t.r2')::jsonb ->> 'allocation_id')::uuid))
             from public.outgoing_payments p where p.id = (current_setting('t.r2')::jsonb ->> 'payment_id')::uuid), 'reversed/-5000',
  'D: the payment is marked reversed and the reversal is a signed -50.00 allocation');
select is((select sum(case when kind = 'credit' then amount_cents else -amount_cents end)::int from public.ledger_entries
            where member_id = pg_temp.mem(2, 't.a') and category in ('expense', 'reimbursement') and period = '2026-08'), 12000,
  'D: the account of that claim is back at 120.00');
select ok((pg_temp.as_json(pg_temp.u(1), format('select public.reverse_purchase_allocation_v1(%L, %L, 3, ''again'', %L)',
    current_setting('t.a'), (current_setting('t.r2')::jsonb ->> 'allocation_id')::uuid, pg_temp.rq(23)))::text) like '%already reversed%', 'D: a payment is reversed once');
select ok((pg_temp.as_json(pg_temp.u(1), format('select public.reverse_purchase_allocation_v1(%L, %L, 3, ''again'', %L)',
    current_setting('t.a'), (select a.id from public.purchase_settlement_allocations a where a.kind = 'reversal'), pg_temp.rq(24)))::text) like '%only a payment can be reversed%', 'D: a reversal is not itself reversed');
select pg_temp.act_as(pg_temp.u(1));
select set_config('t.inv2', public.create_invoice(current_setting('t.a')::uuid, pg_temp.mem(2, 't.a'), '2026-08')::text, true);
reset role;
select is((select string_agg((x ->> 'kind') || ':' || (x ->> 'amount_cents'), ',' order by x ->> 'kind')
             from public.invoices i, jsonb_array_elements(i.lines) x where i.id = current_setting('t.inv2')::uuid),
  'expense:-12000,subscription:3500', 'D: the August invoice carries the whole credit again after the reversal');

-- ── E: a claim paid in full ────────────────────────────────────────────
select set_config('t.r4', pg_temp.pay(pg_temp.u(1), 3, 5000, 1, 30)::text, true);
select is(current_setting('t.r4')::jsonb #>> '{obligation,remaining_cents}', '0', 'E: paying the whole claim leaves nothing remaining');
select pg_temp.act_as(pg_temp.u(1));
select set_config('t.inv3', public.create_invoice(current_setting('t.a')::uuid, pg_temp.mem(2, 't.a'), '2026-07')::text, true);
reset role;
select is((select string_agg((x ->> 'kind') || ':' || (x ->> 'amount_cents'), ',') from public.invoices i, jsonb_array_elements(i.lines) x
            where i.id = current_setting('t.inv3')::uuid), 'subscription:3500',
  'E: golden: a fully paid claim leaves no expense line on its invoice');

-- ── F: history, and who reads what ─────────────────────────────────────
select ok(pg_temp.owner_err('update public.purchase_settlement_allocations set reason = ''x''') like '%never edited or removed%', 'F: an allocation is never edited, even by the table owner');
select ok(pg_temp.owner_err('delete from public.purchase_settlement_allocations') like '%never edited or removed%', 'F: nor removed');
select ok(pg_temp.owner_err('delete from public.outgoing_payments') like '%never removed%', 'F: nor is a payment removed');
select ok(pg_temp.owner_err('update public.outgoing_payments set amount_cents = amount_cents + 1') like '%keeps what was reported%', 'F: nor its amount changed');
select ok(pg_temp.as_err(pg_temp.u(1), 'update public.outgoing_payments set reference = ''x''') like '%permission denied%', 'F: a client cannot write a payment');
select pg_temp.act_as(pg_temp.u(2));
select ok((select count(*) from public.outgoing_payments) >= 3, 'F: positive control: the payee reads their own payments');
select pg_temp.act_as(pg_temp.u(3));
select is((select count(*)::int from public.outgoing_payments) + (select count(*)::int from public.purchase_settlement_allocations), 0, 'F: another member reads none of them');
select pg_temp.act_as(pg_temp.u(5));
select is((select count(*)::int from public.outgoing_payments) + (select count(*)::int from public.purchase_settlement_allocations), 0, 'F: nor does a foreign owner');
reset role;
select ok('recordOutgoingPayments' = any(public.role_permission_catalog()), 'F: the permission is in the catalogue');
select is(pg_temp.as_json(pg_temp.u(4), format('select to_jsonb(public.has_permission(%L, ''recordOutgoingPayments''))', current_setting('t.a'))), 'false'::jsonb, 'F: an admin does not hold it by default');
select is(pg_temp.as_json(pg_temp.u(1), format('select to_jsonb(public.has_permission(%L, ''recordOutgoingPayments''))', current_setting('t.a'))), 'true'::jsonb, 'F: an owner holds it');

-- ── G: the invoice guard ───────────────────────────────────────────────
-- (the September account holds a 50.00 reimbursement; the lines below ignore it)
select ok(pg_temp.owner_err(format($i$insert into public.invoices
   (workspace_id, member_id, issuer_member_id, number, period, title, lines, total_cents, currency, member_name, workspace_name, issuer_name, signature, kind)
   values (%L, %L, %L, 'GUARD-1', '2026-09', 'stale', '[{"kind":"expense","label":"x","amount_cents":-12000}]'::jsonb, -12000, 'EUR', 'm', 'w', 'i', 's', 'usage')$i$,
   current_setting('t.a'), pg_temp.mem(2, 't.a'), pg_temp.mem(1, 't.a'))) like '%account changed while the invoice was being issued%',
  'G: an invoice whose expense lines ignore a payment that committed meanwhile is refused');

select * from finish();
rollback;
