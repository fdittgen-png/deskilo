-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2574 / 0469 (C2c of #2464): a member's claim offset against an invoice of
-- the same member. Real roles; every refusal is followed by a readback.
-- Expected values written by hand (a 120.00 claim; invoices of 45.00 and
-- 35.00; offsets of 45.00, 10.00 and 25.00).
--   A offset in full   B offset in part, then the rest   C refusals
--   D the claim applied to an invoice   E a validation policy that would hold
--   the match   F history
-- NOT RUN here: two sessions racing the last of a claim.
begin;
select plan(29);

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
  select ('d0000000-0000-4000-8000-00000000' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.ob(n int) returns uuid language sql as $$
  select o.id from public.purchase_obligations o join public.purchase_sources s on s.purchase_id = o.purchase_id
   where s.source_id = pg_temp.ev(n);
$$;
create function pg_temp.rev(n int) returns int language sql as $$
  select revision from public.purchase_obligations where id = pg_temp.ob(n);
$$;
create function pg_temp.off(p_user uuid, n int, p_invoice text, p_amount bigint, p_rev int, p_req int, p_note text default '') returns jsonb
language plpgsql as $$
begin
  return pg_temp.as_json(p_user, format('select public.offset_member_claim_v1(%L, %L, %L, %s, %s, %L, %L)',
    current_setting('t.a'), pg_temp.ob(n), p_invoice, p_amount, p_rev, pg_temp.rq(p_req), p_note));
end;
$$;

-- e1: EUR 120.00 (September); e2: EUR 20.00 (September); e4: the owner's own 10.00.
insert into public.events (id, workspace_id, type, action, actor_member_id, subject_member_id, payload, status, decided_at) values
 (pg_temp.ev(1), current_setting('t.a')::uuid, 'expense', 'submitted', pg_temp.mem(2, 't.a'), pg_temp.mem(2, 't.a'), '{"amount_cents": 12000, "category": "cleaning", "note": "Cleaning"}', 'confirmed', now() - interval '2 days'),
 (pg_temp.ev(2), current_setting('t.a')::uuid, 'expense', 'submitted', pg_temp.mem(2, 't.a'), pg_temp.mem(2, 't.a'), '{"amount_cents": 2000, "category": "tea", "note": "Tea"}', 'confirmed', now() - interval '2 days'),
 (pg_temp.ev(4), current_setting('t.a')::uuid, 'expense', 'submitted', pg_temp.mem(1, 't.a'), pg_temp.mem(1, 't.a'), '{"amount_cents": 1000, "category": "tea", "note": "Tea"}', 'confirmed', now() - interval '2 days');
insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, event_id, created_at) values
 (current_setting('t.a')::uuid, pg_temp.mem(2, 't.a'), 'credit', 'expense', 12000, 'Cleaning', '2026-09', pg_temp.ev(1), now() - interval '1 day'),
 (current_setting('t.a')::uuid, pg_temp.mem(2, 't.a'), 'credit', 'expense', 2000, 'Tea', '2026-09', pg_temp.ev(2), now() - interval '1 day'),
 (current_setting('t.a')::uuid, pg_temp.mem(1, 't.a'), 'credit', 'expense', 1000, 'Tea', '2026-09', pg_temp.ev(4), now() - interval '1 day');
-- Invoices of the claimant: August 45.00 (35.00 fee + 10.00 supply), July 35.00, June 35.00.
insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, vat_percent)
values (current_setting('t.a')::uuid, pg_temp.mem(2, 't.a'), 'charge', 'adjustment', 1000, 'Supply', '2026-08', 20);
select pg_temp.act_as(pg_temp.u(1));
select set_config('t.iaug', public.create_invoice(current_setting('t.a')::uuid, pg_temp.mem(2, 't.a'), '2026-08')::text, true);
select set_config('t.ijul', public.create_invoice(current_setting('t.a')::uuid, pg_temp.mem(2, 't.a'), '2026-07')::text, true);
select set_config('t.ijun', public.create_invoice(current_setting('t.a')::uuid, pg_temp.mem(2, 't.a'), '2026-06')::text, true);
select set_config('t.istr', public.create_invoice(current_setting('t.a')::uuid, pg_temp.mem(3, 't.a'), '2026-08')::text, true);
reset role;
create temp table seed_counts as select
  (select count(*) from public.ledger_entries) as ledger,
  (select count(*) from public.purchase_settlement_allocations) as allocs,
  (select count(*) from public.invoice_matches) as matches;

-- ── A: in full ─────────────────────────────────────────────────────────
select is((select total_cents from public.invoices where id = current_setting('t.iaug')::uuid), 4500, 'A: seed: the August invoice is 45.00');
select set_config('t.o1', pg_temp.off(pg_temp.u(1), 1, current_setting('t.iaug'), 4500, 1, 1)::text, true);
select is((current_setting('t.o1')::jsonb ->> 'resolution') || '/' || (current_setting('t.o1')::jsonb #>> '{obligation,paid_cents}') || '/' || (current_setting('t.o1')::jsonb #>> '{obligation,remaining_cents}'),
  'exact/4500/7500', 'A: golden: 45.00 of the 120.00 claim settles the 45.00 invoice, 75.00 remains');
select is((select concat_ws('/', m.resolution, m.paid_cents, m.status) from public.invoice_matches m where m.invoice_id = current_setting('t.iaug')::uuid),
  'exact/4500/confirmed', 'A: the invoice stands paid: matched exact, confirmed');
select is((select concat_ws('/', l.kind, l.category, l.amount_cents, l.period, l.vat_percent)
             from public.ledger_entries l where l.category = 'reimbursement' and l.workspace_id = current_setting('t.a')::uuid),
  'charge/reimbursement/4500/2026-09/0.000000', 'A: the claim fell by 45.00 in the account of its own period');
select is((select count(*)::int from public.invoice_match_payments p join public.ledger_entries l on l.id = p.payment_ledger_id
            where p.invoice_id = current_setting('t.iaug')::uuid and l.category = 'payment' and l.amount_cents = 4500), 1,
  'A: the matched payment is a registered 45.00 credit of the member');
select is((select o ->> 'method' || '/' || (o ->> 'reference') from jsonb_array_elements(current_setting('t.o1')::jsonb #> '{obligation,allocations}') o limit 1),
  'offset/' || (select number from public.invoices where id = current_setting('t.iaug')::uuid), 'A: the allocation reads as an offset against the invoice number');
select is((select total_cents from public.invoices where id = current_setting('t.iaug')::uuid), 4500, 'A: the invoice itself is untouched: gross sales unchanged');
select is(pg_temp.off(pg_temp.u(1), 1, current_setting('t.iaug'), 4500, 1, 1), current_setting('t.o1')::jsonb, 'A: the same request answers the original');
select is((select (ledger + 2 = (select count(*) from public.ledger_entries) and allocs + 1 = (select count(*) from public.purchase_settlement_allocations)
                   and matches + 1 = (select count(*) from public.invoice_matches))::text from seed_counts), 'true',
  'A: and the replay made no new row');
select is((select (x ->> 'amount_cents')::int from public.invoices i, jsonb_array_elements(public.invoice_lines_for(pg_temp.mem(2, 't.a'), '2026-09')) x
            where i.id = current_setting('t.iaug')::uuid and x ->> 'kind' = 'expense' and (x ->> 'amount_cents')::int = -7500), -7500,
  'A: the claim''s credit reads net of the offset on its own invoice: -75.00');

-- ── B: in part, then the rest ──────────────────────────────────────────
select set_config('t.o2', pg_temp.off(pg_temp.u(1), 1, current_setting('t.ijul'), 1000, 2, 2)::text, true);
select is((current_setting('t.o2')::jsonb ->> 'resolution') || '/' || (current_setting('t.o2')::jsonb #>> '{obligation,remaining_cents}'), 'under_accepted/6500',
  'B: 10.00 against the 35.00 July invoice is a standing partial, 65.00 remains');
select is((select concat_ws('/', m.resolution, m.paid_cents, m.status, (m.writeoff_at is null)::text) from public.invoice_matches m where m.invoice_id = current_setting('t.ijul')::uuid),
  'under_accepted/1000/confirmed/true', 'B: the invoice stays open for the rest (not written off)');
select set_config('t.o3', pg_temp.off(pg_temp.u(1), 1, current_setting('t.ijul'), 2500, 3, 3)::text, true);
select is((current_setting('t.o3')::jsonb ->> 'resolution') || '/' || (current_setting('t.o3')::jsonb #>> '{obligation,remaining_cents}'), 'exact/4000',
  'B: the 25.00 left of the invoice settles it, 40.00 of the claim remains');
select is((select concat_ws('/', m.resolution, m.paid_cents) from public.invoice_matches m where m.invoice_id = current_setting('t.ijul')::uuid), 'exact/3500',
  'B: the invoice stands paid in full by two offsets');

-- ── C: refusals ────────────────────────────────────────────────────────
create temp table c_counts as select
  (select count(*) from public.ledger_entries) as ledger,
  (select count(*) from public.purchase_settlement_allocations) as allocs,
  (select count(*) from public.invoice_matches) as matches,
  (select count(*) from public.invoice_match_payments) as pays;
select ok((pg_temp.off(pg_temp.u(1), 1, current_setting('t.ijun'), 3501, 4, 10)::text) like '%exceeds what the invoice still owes%', 'C: more than the invoice owes is refused');
select ok((pg_temp.off(pg_temp.u(1), 2, current_setting('t.ijun'), 2001, 1, 11)::text) like '%exceeds what remains of the claim%', 'C: more than the claim has is refused (20.01 of 20.00)');
select ok((pg_temp.off(pg_temp.u(1), 1, current_setting('t.ijun'), 100, 1, 12)::text) like '%stale revision%', 'C: a stale revision is refused');
select ok((pg_temp.off(pg_temp.u(1), 1, current_setting('t.ijun'), 0, 4, 13)::text) like '%must be positive%', 'C: a zero amount is refused');
select ok((pg_temp.off(pg_temp.u(1), 1, current_setting('t.istr'), 100, 4, 14)::text) like '%invoice of the same member%', 'C: another member''s invoice is refused');
select ok((pg_temp.off(pg_temp.u(1), 1, current_setting('t.iaug'), 100, 4, 15)::text) like '%open invoice to settle%', 'C: an invoice already paid in full is refused');
select ok((pg_temp.off(pg_temp.u(4), 1, current_setting('t.ijun'), 100, 4, 16)::text) like '%may not record outgoing payments%', 'C: an admin without the permission cannot offset');
select ok((pg_temp.off(pg_temp.u(2), 1, current_setting('t.ijun'), 100, 4, 17)::text) like '%may not record outgoing payments%', 'C: nor the claimant');
select ok((pg_temp.off(pg_temp.u(5), 1, current_setting('t.ijun'), 100, 4, 18)::text) like '%not an active member%', 'C: nor a foreign owner');
select ok((pg_temp.off(pg_temp.u(1), 4, current_setting('t.ijun'), 100, 1, 19)::text) like '%another person must offset%', 'C: the owner cannot offset their own claim');
select is((select (ledger = (select count(*) from public.ledger_entries) and allocs = (select count(*) from public.purchase_settlement_allocations)
                   and matches = (select count(*) from public.invoice_matches) and pays = (select count(*) from public.invoice_match_payments))::text from c_counts), 'true',
  'C: readback: no refusal wrote a ledger row, an allocation or a match');
select ok((pg_temp.as_json(pg_temp.u(1), format('select public.reverse_purchase_allocation_v1(%L, %L, 4, ''oops'', %L)',
  current_setting('t.a'), (current_setting('t.o1')::jsonb ->> 'allocation_id')::uuid, pg_temp.rq(20)))::text) like '%only a payment can be reversed%',
  'C: an offset is not reversed as a payment');

-- ── E: a validation policy that would hold the match ───────────────────
insert into public.validation_policies (workspace_id, event_type, required_count)
values (current_setting('t.a')::uuid, 'invoice_payment', 1);
select ok((pg_temp.off(pg_temp.u(1), 1, current_setting('t.ijun'), 100, 4, 30)::text) like '%validation policy holds invoice payments%', 'E: with a policy on invoice payments the offset is refused');
select is((select (ledger = (select count(*) from public.ledger_entries) and allocs = (select count(*) from public.purchase_settlement_allocations)
                   and matches = (select count(*) from public.invoice_matches))::text from c_counts), 'true',
  'E: readback: the claim did not fall and no payment stands without its invoice');
delete from public.validation_policies where workspace_id = current_setting('t.a')::uuid;

-- ── D: the claim applied to an invoice ─────────────────────────────────
select pg_temp.act_as(pg_temp.u(1));
select set_config('t.isep', public.create_invoice(current_setting('t.a')::uuid, pg_temp.mem(2, 't.a'), '2026-09')::text, true);
reset role;
select ok((pg_temp.off(pg_temp.u(1), 1, current_setting('t.ijun'), 100, 4, 40)::text) like '%already applied to an invoice%', 'D: a claim an invoice has applied is not offset');

select * from finish();
rollback;
