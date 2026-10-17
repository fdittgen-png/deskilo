-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2574 / 0466 (C1 of #2464): who is owed what for an approved purchase.
-- Real roles (authenticated through the definer RPCs and the RLS policies);
-- every refusal is followed by a readback proving nothing changed. Expected
-- values are written here by hand (a 50.00 and a 120.00 claim, a 35.00 fee),
-- never read from the function under test.
--   A history: an approved expense has its claim, linked to its ONE credit;
--     a pending or rejected one has none
--   B the live path: approval files one claim and no second credit; replays
--     and the backfill change nothing, write no ledger row
--   C usage: open until an issued invoice of the period carries the credit's
--     line; the Nth equal credit needs N lines; a later credit stays open
--   D the page: owner reads all, a member their own, a stranger nothing;
--     filter and paging
--   E the table: own rows only, no client write, a frozen identity, the keys
--   F the detail carries the claim for the claimant and the manager only
begin;
select plan(38);

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
  select ('00000000-0000-4000-8000-00002574' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.mem(n int, w text) returns uuid language sql as $$
  select id from public.members
   where user_id = pg_temp.u(n) and workspace_id = current_setting(w)::uuid;
$$;
create function pg_temp.ev(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00002574e' || lpad(n::text, 3, '0'))::uuid;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@obligations.test', '', now(), now(), now()
  from generate_series(1, 5) i;
-- 1 owner of A, 2 and 3 plain members of A, 4 a second admin of A, 5 owner of B.

select pg_temp.act_as(pg_temp.u(1));
select set_config('t.a', public.create_workspace('Obligations A', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select pg_temp.act_as(pg_temp.u(5));
select set_config('t.b', public.create_workspace('Obligations B', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
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
 ('00000000-0000-4000-8000-0000257400a1', current_setting('t.a')::uuid, '1', 'ACME Sarl'),
 ('00000000-0000-4000-8000-0000257400b1', current_setting('t.b')::uuid, '1', 'Other Ltd');

-- ── A: the history ─────────────────────────────────────────────────────
-- e1, e2: approved EUR 50.00 expenses of member 2 with their credit booked to
-- September, a day ago; e3 pending; e4 rejected.
insert into public.events (id, workspace_id, type, action, actor_member_id, subject_member_id, payload, status, decided_at) values
 (pg_temp.ev(1), current_setting('t.a')::uuid, 'expense', 'submitted', pg_temp.mem(2, 't.a'), pg_temp.mem(2, 't.a'),
  '{"amount_cents": 5000, "category": "coffee", "note": "Coffee one"}', 'confirmed', now() - interval '2 days'),
 (pg_temp.ev(2), current_setting('t.a')::uuid, 'expense', 'submitted', pg_temp.mem(2, 't.a'), pg_temp.mem(2, 't.a'),
  '{"amount_cents": 5000, "category": "coffee", "note": "Coffee two"}', 'confirmed', now() - interval '2 days'),
 (pg_temp.ev(3), current_setting('t.a')::uuid, 'expense', 'submitted', pg_temp.mem(3, 't.a'), pg_temp.mem(3, 't.a'),
  '{"amount_cents": 7000, "category": "tea", "note": "Tea"}', 'pending', null),
 (pg_temp.ev(4), current_setting('t.a')::uuid, 'expense', 'submitted', pg_temp.mem(3, 't.a'), pg_temp.mem(3, 't.a'),
  '{"amount_cents": 9000, "category": "tools", "note": "Tools"}', 'rejected', now() - interval '1 day');
insert into public.ledger_entries (id, workspace_id, member_id, kind, category, amount_cents, description, period, event_id, created_at) values
 ('00000000-0000-4000-8000-00002574c001', current_setting('t.a')::uuid, pg_temp.mem(2, 't.a'), 'credit', 'expense', 5000,
  'Coffee one', '2026-09', pg_temp.ev(1), now() - interval '1 day'),
 ('00000000-0000-4000-8000-00002574c002', current_setting('t.a')::uuid, pg_temp.mem(2, 't.a'), 'credit', 'expense', 5000,
  'Coffee two', '2026-09', pg_temp.ev(2), now() - interval '1 day' + interval '1 second');
create temp table ledger_after_seed as select count(*) as n from public.ledger_entries;

select is((select count(*)::int from public.purchase_obligations where workspace_id = current_setting('t.a')::uuid), 2,
  'A: golden: the two approved expenses have a claim, the pending and the rejected one have none');
select is((select concat_ws('/', o.creditor_kind, (o.creditor_member_id = pg_temp.mem(2, 't.a'))::text,
                          o.amount_cents, o.currency, o.state, o.revision)
             from public.purchase_obligations o join public.purchase_sources s on s.purchase_id = o.purchase_id
            where s.source_id = pg_temp.ev(1)), 'member/true/5000/EUR/open/1',
  'A: the claim is the paying member''s, for the amount of the outlay, open');
select is((select o.legacy_member_credit_id from public.purchase_obligations o
             join public.purchase_sources s on s.purchase_id = o.purchase_id
            where s.source_id = pg_temp.ev(1)), '00000000-0000-4000-8000-00002574c001'::uuid,
  'A: the claim links the credit the approval issued, completed when that credit was booked');
select is((select count(*)::int from public.ledger_entries), (select n::int from ledger_after_seed),
  'A: filing the claims wrote no ledger row');

-- ── B: the live path ───────────────────────────────────────────────────
select set_config('t.e5', pg_temp.as_json(pg_temp.u(2),
  format('select to_jsonb(public.submit_expense(%L, 12000, ''cleaning'', ''Cleaning'', null, %L::jsonb))',
         current_setting('t.a'), '{"percent": 20, "deductible_pct": 100}'))#>>'{}', true);
select is((select count(*)::int from public.purchase_obligations o join public.purchase_sources s on s.purchase_id = o.purchase_id
            where s.source_id = current_setting('t.e5')::uuid), 0, 'B: a pending expense has no claim yet');
select is(pg_temp.as_err(pg_temp.u(1), format('select public.respond_to_event(%L, true)', current_setting('t.e5'))), '',
  'B: another admin approves it');
select is((select concat_ws('/', o.amount_cents, (o.legacy_member_credit_id is not null)::text)
             from public.purchase_obligations o join public.purchase_sources s on s.purchase_id = o.purchase_id
            where s.source_id = current_setting('t.e5')::uuid), '12000/true',
  'B: approval files ONE claim of EUR 120.00 and links the credit it issued');
select is((select count(*)::int from public.ledger_entries where event_id = current_setting('t.e5')::uuid), 1,
  'B: and there is exactly one credit for it');
select set_config('t.e6', pg_temp.as_json(pg_temp.u(2),
  format('select to_jsonb(public.submit_expense(%L, 800, ''stamps'', ''Stamps'', null, null))', current_setting('t.a')))#>>'{}', true);
select pg_temp.as_err(pg_temp.u(1), format('select public.respond_to_event(%L, false)', current_setting('t.e6')));
select is((select count(*)::int from public.purchase_obligations o join public.purchase_sources s on s.purchase_id = o.purchase_id
            where s.source_id = current_setting('t.e6')::uuid), 0, 'B: a rejection files no claim');
create temp table obl_digest as
  select md5(string_agg(row(o.id, o.purchase_id, o.creditor_member_id, o.amount_cents, o.currency, o.state,
                            o.revision, o.legacy_member_credit_id)::text, ',' order by o.id)) as d,
         count(*) as n
    from public.purchase_obligations o where o.workspace_id = current_setting('t.a')::uuid;
create temp table ledger_after_live as select count(*) as n from public.ledger_entries;
select public.purchase_obligation_sync(d.id) from public.purchase_documents d
 where d.workspace_id = current_setting('t.a')::uuid;
select public.purchase_obligation_sync(d.id) from public.purchase_documents d
 where d.workspace_id = current_setting('t.a')::uuid;
select is((select md5(string_agg(row(o.id, o.purchase_id, o.creditor_member_id, o.amount_cents, o.currency, o.state,
                            o.revision, o.legacy_member_credit_id)::text, ',' order by o.id))
             from public.purchase_obligations o where o.workspace_id = current_setting('t.a')::uuid),
          (select d from obl_digest), 'B: running the sync twice changes no claim');
-- the backfill alone: drop the claims, run the one path again
delete from public.purchase_obligations where workspace_id = current_setting('t.a')::uuid;
select public.purchase_obligation_sync(d.id) from public.purchase_documents d
 where d.workspace_id = current_setting('t.a')::uuid order by d.created_datetime;
select is((select count(*)::int from public.purchase_obligations where workspace_id = current_setting('t.a')::uuid),
          (select n::int from obl_digest), 'B: the backfill restores one claim per approved receipt');
select is((select count(*)::int from public.ledger_entries), (select n::int from ledger_after_live),
  'B: and no sync wrote a ledger row');

-- ── C: usage ───────────────────────────────────────────────────────────
select is((select count(*)::int
             from jsonb_array_elements(pg_temp.as_json(pg_temp.u(1), format(
               'select public.purchase_payables_page_v1(%L, ''member'', 200) -> ''rows''', current_setting('t.a')))) r
            where (r -> 'obligation' ->> 'applied_cents')::int = 0
              and (r -> 'obligation' ->> 'remaining_cents')::int = (r -> 'obligation' ->> 'amount_cents')::int
              and r -> 'obligation' -> 'applied_invoice' = 'null'::jsonb), 3,
  'C: before any invoice the three claims are open: nothing applied, the whole amount remaining');
-- a third equal credit AFTER the invoice (September, created later)
select pg_temp.act_as(pg_temp.u(1));
select set_config('t.inv', public.create_invoice(current_setting('t.a')::uuid, pg_temp.mem(2, 't.a'), '2026-09')::text, true);
reset role;
select is((select count(*)::int from public.invoices where id = current_setting('t.inv')::uuid and voided_at is null), 1,
  'C: the September invoice is issued');
select is((select count(*)::int from public.invoices i, jsonb_array_elements(i.lines) x
            where i.id = current_setting('t.inv')::uuid and x ->> 'kind' = 'expense' and (x ->> 'amount_cents')::int = -5000), 2,
  'C: it carries both expense credits as negative lines (35.00 fee, minus 100.00)');
insert into public.events (id, workspace_id, type, action, actor_member_id, subject_member_id, payload, status, decided_at)
values (pg_temp.ev(7), current_setting('t.a')::uuid, 'expense', 'submitted', pg_temp.mem(2, 't.a'), pg_temp.mem(2, 't.a'),
        '{"amount_cents": 5000, "category": "coffee", "note": "Coffee three"}', 'confirmed', now());
insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, event_id, created_at)
values (current_setting('t.a')::uuid, pg_temp.mem(2, 't.a'), 'credit', 'expense', 5000, 'Coffee three', '2026-09',
        pg_temp.ev(7), now() + interval '1 hour');
select is((select count(*)::int
             from jsonb_array_elements(pg_temp.as_json(pg_temp.u(1), format(
               'select public.purchase_payables_page_v1(%L, ''member'', 200) -> ''rows''', current_setting('t.a')))) r
            where (r -> 'obligation' ->> 'amount_cents')::int = 5000
              and (r -> 'obligation' ->> 'applied_cents')::int = 5000
              and (r -> 'obligation' -> 'applied_invoice' ->> 'id') = current_setting('t.inv')), 2,
  'C: golden: the two credits the invoice carries are applied to it, 0.00 remaining each');
select is((select count(*)::int
             from jsonb_array_elements(pg_temp.as_json(pg_temp.u(1), format(
               'select public.purchase_payables_page_v1(%L, ''member'', 200) -> ''rows''', current_setting('t.a')))) r
            where (r -> 'obligation' ->> 'amount_cents')::int = 5000
              and (r -> 'obligation' ->> 'applied_cents')::int = 0
              and (r -> 'obligation' ->> 'remaining_cents')::int = 5000), 1,
  'C: the third equal credit, booked after the invoice, stays open: 50.00 remaining');
select is((select count(*)::int
             from jsonb_array_elements(pg_temp.as_json(pg_temp.u(1), format(
               'select public.purchase_payables_page_v1(%L, ''member'', 200) -> ''rows''', current_setting('t.a')))) r
            where (r -> 'obligation' ->> 'amount_cents')::int = 12000
              and (r -> 'obligation' ->> 'applied_cents')::int = 0), 1,
  'C: the claim of another period (October) is untouched by the September invoice');

-- ── D: the page ────────────────────────────────────────────────────────
select is(jsonb_array_length(pg_temp.as_json(pg_temp.u(1), format(
  'select public.purchase_payables_page_v1(%L) -> ''rows''', current_setting('t.a')))), 4,
  'D: the owner reads all four claims of the workspace');
select is(jsonb_array_length(pg_temp.as_json(pg_temp.u(2), format(
  'select public.purchase_payables_page_v1(%L) -> ''rows''', current_setting('t.a')))), 4,
  'D: positive control: the claimant reads their own four (all theirs)');
select is(jsonb_array_length(pg_temp.as_json(pg_temp.u(3), format(
  'select public.purchase_payables_page_v1(%L) -> ''rows''', current_setting('t.a')))), 0,
  'D: another plain member reads none of them');
select is(pg_temp.as_json(pg_temp.u(5), format('select public.purchase_payables_page_v1(%L)', current_setting('t.a'))) ->> 'error',
  'unknown workspace', 'D: the owner of another workspace is refused');
select is(jsonb_array_length(pg_temp.as_json(pg_temp.u(1), format(
  'select public.purchase_payables_page_v1(%L, ''supplier'') -> ''rows''', current_setting('t.a')))), 0,
  'D: no supplier is owed anything yet');
select is(pg_temp.as_json(pg_temp.u(1), format(
  'select public.purchase_payables_page_v1(%L, ''bank'')', current_setting('t.a'))) ->> 'error',
  'unknown creditor kind', 'D: an unknown creditor kind is refused');
select set_config('t.p1', pg_temp.as_json(pg_temp.u(1), format(
  'select public.purchase_payables_page_v1(%L, null, 3)', current_setting('t.a')))::text, true);
select is(jsonb_array_length(current_setting('t.p1')::jsonb -> 'rows') || '/' || (current_setting('t.p1')::jsonb -> 'next' is not null)::text,
  '3/true', 'D: a page of three says there is more');
select is(jsonb_array_length(pg_temp.as_json(pg_temp.u(1), format(
  'select public.purchase_payables_page_v1(%L, null, 3, %L::timestamptz, %L::uuid) -> ''rows''',
  current_setting('t.a'), current_setting('t.p1')::jsonb -> 'next' ->> 'created', current_setting('t.p1')::jsonb -> 'next' ->> 'id'))), 1,
  'D: the next page has the remaining claim, and no further cursor');

-- ── E: the table ───────────────────────────────────────────────────────
select pg_temp.act_as(pg_temp.u(3));
select is((select count(*)::int from public.purchase_obligations), 0, 'E: another member reads no claim from the table');
select pg_temp.act_as(pg_temp.u(2));
select is((select count(*)::int from public.purchase_obligations where workspace_id = current_setting('t.a')::uuid), 4,
  'E: positive control: the claimant reads their own claims');
select pg_temp.act_as(pg_temp.u(5));
select is((select count(*)::int from public.purchase_obligations where workspace_id = current_setting('t.a')::uuid), 0,
  'E: the owner of B reads none of A''s');
reset role;
select ok(pg_temp.as_err(pg_temp.u(2), 'update public.purchase_obligations set amount_cents = 1') like '%permission denied%',
  'E: a client cannot write a claim');
select ok(pg_temp.as_err(pg_temp.u(1), 'delete from public.purchase_obligations') like '%permission denied%',
  'E: not even the owner');
select is((select sum(amount_cents)::int from public.purchase_obligations where workspace_id = current_setting('t.a')::uuid), 27000,
  'E: readback: 5000 + 5000 + 5000 + 12000, nothing changed');
select ok(pg_temp.owner_err('update public.purchase_obligations set amount_cents = amount_cents + 1') like '%keeps its purchase, creditor and amount%',
  'E: the amount is frozen, even for the table owner');
select ok(pg_temp.owner_err(format('insert into public.purchase_obligations (workspace_id, purchase_id, creditor_kind, creditor_supplier_id, amount_cents, currency) select workspace_id, id, ''supplier'', ''00000000-0000-4000-8000-0000257400b1'', 100, ''EUR'' from public.purchase_documents where workspace_id = %L limit 1',
    current_setting('t.a'))) like '%foreign key%',
  'E: a supplier of another workspace is refused by the composite key');
select ok(pg_temp.owner_err(format('insert into public.purchase_obligations (workspace_id, purchase_id, creditor_kind, amount_cents, currency) select workspace_id, id, ''member'', 100, ''EUR'' from public.purchase_documents where workspace_id = %L limit 1',
    current_setting('t.a'))) like '%check%',
  'E: a member claim needs a member creditor');

-- ── F: the detail ──────────────────────────────────────────────────────
select is(jsonb_array_length(pg_temp.as_json(pg_temp.u(2), format(
  'select public.purchase_detail_v1(%L, %L) -> ''obligations''', current_setting('t.a'),
  (select purchase_id from public.purchase_sources where source_id = current_setting('t.e5')::uuid)))), 1,
  'F: the claimant''s detail carries the claim');
select is(pg_temp.as_json(pg_temp.u(3), format(
  'select public.purchase_detail_v1(%L, %L)', current_setting('t.a'),
  (select purchase_id from public.purchase_sources where source_id = current_setting('t.e5')::uuid))) ->> 'error',
  'unknown purchase', 'F: another member''s detail is refused');
select is(jsonb_array_length(pg_temp.as_json(pg_temp.u(1), format(
  'select public.purchase_detail_v1(%L, %L) -> ''obligations''', current_setting('t.a'),
  (select purchase_id from public.purchase_sources where source_id = current_setting('t.e5')::uuid)))), 1,
  'F: the manager''s detail carries it too');

select * from finish();
rollback;
