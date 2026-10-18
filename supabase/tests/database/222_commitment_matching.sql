-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2575 / 0479 (C1): a lessor's bill is matched to the rent the lease already
-- expects. Real roles; every refusal is followed by a readback. Expected
-- values are written by hand: rent 1 000.00 a month from 1 January 2026.
--   A one bill, one month   B partial bills and an overmatch   C one bill for
--   two months   D a bill above the expectation   E refusals   F reversal
--   G replay   H who reads
-- NOT RUN here: two sessions matching the same occurrence at once.
begin;
select plan(36);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.as_json(p_user uuid, p_sql text) returns jsonb language plpgsql as $$
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
create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00002575' || lpad(n::text, 4, '1'))::uuid;
$$;
create function pg_temp.rq(n int) returns uuid language sql as $$
  select ('c0000000-0000-4000-8000-00000000' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.mem(n int) returns uuid language sql as $$
  select id from public.members where user_id = pg_temp.u(n) and workspace_id = current_setting('t.a')::uuid;
$$;
-- a bill of the lessor with the given lines (gross cents), submitted by the owner
create function pg_temp.bill(p_ref text, p_lines int[], p_supplier uuid default '00000000-0000-4000-8000-0000257500a1', p_submit boolean default true) returns text
language plpgsql as $$
declare
  v_lines jsonb := '[]'::jsonb;
  g int;
  v_id text;
begin
  foreach g in array p_lines loop
    v_lines := v_lines || jsonb_build_array(jsonb_build_object('description', 'Rent', 'gross_cents', g,
      'net_cents', g * 5 / 6, 'tax_cents', g - g * 5 / 6, 'tax_rate_percent', 20));
  end loop;
  v_id := pg_temp.as_json(pg_temp.u(1), format('select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)',
    current_setting('t.a'), gen_random_uuid(), jsonb_build_object('kind', 'bill', 'supplier_id', p_supplier,
      'original_reference', p_ref, 'due_on', '2026-12-15', 'payer_kind', 'unpaid', 'lines', v_lines)::text)) ->> 'purchase_id';
  if p_submit then
    perform pg_temp.as_json(pg_temp.u(1), format('select public.submit_purchase_v1(%L, %L, 1, %L)', current_setting('t.a'), v_id, gen_random_uuid()));
  end if;
  return v_id;
end;
$$;
create function pg_temp.line(p_purchase text, p_no int default 1) returns uuid language sql as $$
  select id from public.purchase_lines where purchase_id = p_purchase::uuid and line_no = p_no;
$$;
create function pg_temp.occ(p_month int) returns uuid language sql as $$
  select o.id from public.expense_occurrences o join public.lease_terms t on t.schedule_id = o.schedule_id
   where t.lease_id = current_setting('t.lease')::uuid and o.due_on = make_date(2026, p_month, 1);
$$;
create function pg_temp.match(p_user uuid, p_purchase text, p_items jsonb, p_req int, p_rev int default 1) returns jsonb language plpgsql as $$
begin
  return pg_temp.as_json(p_user, format('select public.match_purchase_commitments_v1(%L, %L, %s, %L::jsonb, %L)',
    current_setting('t.a'), p_purchase, p_rev, p_items::text, pg_temp.rq(p_req)));
end;
$$;
create function pg_temp.item(p_occurrence uuid, p_line uuid, p_cents int) returns jsonb language sql as $$
  select jsonb_build_object('occurrence_id', p_occurrence, 'purchase_line_id', p_line, 'allocated_cents', p_cents);
$$;
create function pg_temp.page(p_user uuid) returns jsonb language plpgsql as $$
begin
  return pg_temp.as_json(p_user, format('select public.purchase_commitment_page_v1(%L, %L, null, 100)', current_setting('t.a'), current_setting('t.lease')));
end;
$$;
create function pg_temp.occ_json(p_user uuid, p_month int) returns jsonb language sql as $$
  select e from jsonb_array_elements(pg_temp.page(p_user) -> 'occurrences') e
   where e ->> 'due_on' = make_date(2026, p_month, 1)::text;
$$;
create function pg_temp.matched(p_month int) returns bigint language sql as $$
  select coalesce(sum(allocated_cents), 0) from public.purchase_commitment_matches where occurrence_id = pg_temp.occ(p_month);
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@commitments.test', '', now(), now(), now()
  from generate_series(1, 5) i;
-- 1 owner of A, 2 plain member, 4 admin (reads finances, links no bill), 5 owner of B.
select pg_temp.act_as(pg_temp.u(1));
select set_config('t.a', public.create_workspace('Commit A', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select pg_temp.act_as(pg_temp.u(5));
select set_config('t.b', public.create_workspace('Commit B', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces
   set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"supplyExpenses": true, "scheduledExpenses": true,
       "purchases": true, "premisesLease": true, "invoicing": true, "inputVat": true, "vatManagement": true}'
 where id in (current_setting('t.a')::uuid, current_setting('t.b')::uuid);
insert into public.members (workspace_id, user_id, is_owner, is_admin, status, subscription_pct, joined_at) values
 (current_setting('t.a')::uuid, pg_temp.u(2), false, false, 'active', 100, '2026-01-01'),
 (current_setting('t.a')::uuid, pg_temp.u(4), false, true, 'active', 100, '2026-01-01');
insert into public.suppliers (id, workspace_id, supplier_number, name, status) values
 ('00000000-0000-4000-8000-0000257500a1', current_setting('t.a')::uuid, '1', 'SCI Les Halles', 'active'),
 ('00000000-0000-4000-8000-0000257500a2', current_setting('t.a')::uuid, '2', 'Autre Bailleur', 'active');

-- the lease: rent 1 000.00 from 1 January 2026
select set_config('t.lease', (pg_temp.as_json(pg_temp.u(1), format('select public.save_premises_lease_v1(%L, null, 0, %L::jsonb, %L)',
  current_setting('t.a'), jsonb_build_object('supplier_id', '00000000-0000-4000-8000-0000257500a1', 'premises', '12 rue des Halles',
    'starts_on', '2026-01-01')::text, pg_temp.rq(1))) ->> 'id'), true);
select pg_temp.as_json(pg_temp.u(1), format('select public.add_lease_term_v1(%L, %L, 1, ''rent'', '''', 100000, 1, ''2026-01-01'', %L)',
  current_setting('t.a'), current_setting('t.lease'), pg_temp.rq(2)));
select pg_temp.as_json(pg_temp.u(1), format('select public.sweep_expense_schedules(%L)', current_setting('t.a')));
-- an ordinary member outlay, for the refusal
insert into public.expense_schedules (id, workspace_id, member_id, title, amount_cents, starts_on, unit, status, next_due)
values ('00000000-0000-4000-8000-0000257500e1', current_setting('t.a')::uuid, pg_temp.mem(2), 'Internet', 4900, '2026-01-01', 'month', 'active', '2026-01-01');
insert into public.expense_occurrences (id, schedule_id, workspace_id, member_id, due_on, amount_cents)
values ('00000000-0000-4000-8000-0000257500e2', '00000000-0000-4000-8000-0000257500e1', current_setting('t.a')::uuid, pg_temp.mem(2), '2026-01-01', 4900);
create temp table seed as select (select count(*) from public.ledger_entries) as ledger;

-- ── A: one bill, one month ─────────────────────────────────────────────
select set_config('t.b1', pg_temp.bill('R-JAN', array[100000]), true);
select is(pg_temp.occ_json(pg_temp.u(1), 1) ->> 'matched_cents', '0', 'A: before any bill the first months are expected and unmatched');
select ok((pg_temp.match(pg_temp.u(1), current_setting('t.b1'), jsonb_build_array(pg_temp.item(pg_temp.occ(1), pg_temp.line(current_setting('t.b1')), 100000)), 10)::text) like '%match_ids%',
  'A: the owner matches the January bill to January''s rent');
select is(pg_temp.matched(1), 100000::bigint, 'A: January is matched in full: 1 000.00');
select is(pg_temp.matched(2), 0::bigint, 'A: and February still expects its own 1 000.00');
select is((select count(*)::int from public.ledger_entries), (select ledger::int from seed), 'A: no member account was credited by matching a rent bill');
select is((select o.status from public.expense_occurrences o where o.id = pg_temp.occ(1)), 'awaiting_member', 'A: the occurrence is untouched: an expected obligation, not an outlay');

-- ── B: partial bills and an overmatch ──────────────────────────────────
select set_config('t.b2a', pg_temp.bill('R-FEB-1', array[60000]), true);
select set_config('t.b2b', pg_temp.bill('R-FEB-2', array[40000]), true);
select pg_temp.match(pg_temp.u(1), current_setting('t.b2a'), jsonb_build_array(pg_temp.item(pg_temp.occ(2), pg_temp.line(current_setting('t.b2a')), 60000)), 11);
select is(pg_temp.matched(2), 60000::bigint, 'B: a 600.00 bill covers part of February');
select ok((pg_temp.match(pg_temp.u(1), current_setting('t.b2b'), jsonb_build_array(pg_temp.item(pg_temp.occ(2), pg_temp.line(current_setting('t.b2b')), 40001)), 12)::text) like '%exceeds what the occurrence still expects%',
  'B: one cent more than the remainder is refused');
select is(pg_temp.matched(2), 60000::bigint, 'B: readback: the refusal matched nothing');
select pg_temp.match(pg_temp.u(1), current_setting('t.b2b'), jsonb_build_array(pg_temp.item(pg_temp.occ(2), pg_temp.line(current_setting('t.b2b')), 40000)), 13);
select is(pg_temp.matched(2), 100000::bigint, 'B: the 400.00 bill takes the exact remainder: February is whole');
select ok((pg_temp.match(pg_temp.u(1), current_setting('t.b2b'), jsonb_build_array(pg_temp.item(pg_temp.occ(2), pg_temp.line(current_setting('t.b2b')), 1)), 14)::text) like '%exceeds%',
  'B: nothing more can be matched to a whole month');

-- ── C: one bill for two months ─────────────────────────────────────────
select set_config('t.b3', pg_temp.bill('R-Q1', array[200000]), true);
select pg_temp.match(pg_temp.u(1), current_setting('t.b3'), jsonb_build_array(
  pg_temp.item(pg_temp.occ(3), pg_temp.line(current_setting('t.b3')), 100000),
  pg_temp.item(pg_temp.occ(4), pg_temp.line(current_setting('t.b3')), 100000)), 15);
select is(pg_temp.matched(3) + pg_temp.matched(4), 200000::bigint, 'C: one 2 000.00 bill settles March and April');
select ok((pg_temp.match(pg_temp.u(1), current_setting('t.b3'), jsonb_build_array(pg_temp.item(pg_temp.occ(5), pg_temp.line(current_setting('t.b3')), 100000)), 16)::text) like '%exceeds what is left of the line%',
  'C: the line is spent: it cannot cover a third month');

-- ── D: a bill above the expectation ────────────────────────────────────
select set_config('t.b4', pg_temp.bill('R-MAY', array[105000]), true);
select pg_temp.match(pg_temp.u(1), current_setting('t.b4'), jsonb_build_array(pg_temp.item(pg_temp.occ(5), pg_temp.line(current_setting('t.b4')), 100000)), 17);
select is(pg_temp.matched(5), 100000::bigint, 'D: 1 050.00 against 1 000.00 matches the 1 000.00 the lease expected');
select is(pg_temp.occ_json(pg_temp.u(1), 5) #>> '{matches,0,line_unallocated_cents}', '5000', 'D: and the page shows the 50.00 variance as the unallocated rest of the line');
select is(pg_temp.matched(6), 0::bigint, 'D: June''s expectation is unchanged by it');

-- ── E: refusals ────────────────────────────────────────────────────────
select set_config('t.b5', pg_temp.bill('OTHER', array[100000], '00000000-0000-4000-8000-0000257500a2'), true);
select ok((pg_temp.match(pg_temp.u(1), current_setting('t.b5'), jsonb_build_array(pg_temp.item(pg_temp.occ(6), pg_temp.line(current_setting('t.b5')), 100000)), 18)::text) like '%same lessor%',
  'E: another supplier''s bill does not settle this lease');
select set_config('t.b6', pg_temp.bill('DRAFT', array[100000], '00000000-0000-4000-8000-0000257500a1', false), true);
select ok((pg_temp.match(pg_temp.u(1), current_setting('t.b6'), jsonb_build_array(pg_temp.item(pg_temp.occ(6), pg_temp.line(current_setting('t.b6')), 100000)), 19)::text) like '%awaiting approval or approved%',
  'E: a draft is not matched');
select set_config('t.b7', pg_temp.bill('JUNE', array[100000]), true);
select ok((pg_temp.match(pg_temp.u(1), current_setting('t.b7'), jsonb_build_array(pg_temp.item('00000000-0000-4000-8000-0000257500e2', pg_temp.line(current_setting('t.b7')), 4900)), 20)::text) like '%expected obligations of a contract%',
  'E: a member''s own outlay schedule is not a contract');
select ok((pg_temp.match(pg_temp.u(2), current_setting('t.b7'), jsonb_build_array(pg_temp.item(pg_temp.occ(6), pg_temp.line(current_setting('t.b7')), 100000)), 21)::text) like '%may not link%',
  'E: a plain member cannot match');
select ok((pg_temp.match(pg_temp.u(4), current_setting('t.b7'), jsonb_build_array(pg_temp.item(pg_temp.occ(6), pg_temp.line(current_setting('t.b7')), 100000)), 22)::text) like '%may not link%',
  'E: nor an admin who only reads the finances');
select ok((pg_temp.match(pg_temp.u(5), current_setting('t.b7'), jsonb_build_array(pg_temp.item(pg_temp.occ(6), pg_temp.line(current_setting('t.b7')), 100000)), 23)::text) like '%not an active member%',
  'E: nor the owner of another space');
select ok((pg_temp.match(pg_temp.u(1), current_setting('t.b7'), jsonb_build_array(pg_temp.item(pg_temp.occ(6), pg_temp.line(current_setting('t.b7')), 100000)), 24, 9)::text) like '%stale revision%',
  'E: a stale revision is refused');
select ok((pg_temp.match(pg_temp.u(1), current_setting('t.b7'), '[]'::jsonb, 25)::text) like '%name between 1 and 50%', 'E: an empty match list is refused');
select is(pg_temp.matched(6), 0::bigint, 'E: readback: none of the refusals matched June');

-- ── F: reversal keeps history ──────────────────────────────────────────
select set_config('t.m5', (select id::text from public.purchase_commitment_matches where occurrence_id = pg_temp.occ(5) and kind = 'match'), true);
select ok((pg_temp.as_json(pg_temp.u(1), format('select public.reverse_commitment_match_v1(%L, %L, ''  '', %L)', current_setting('t.a'), current_setting('t.m5'), pg_temp.rq(26)))::text) like '%state why%', 'F: a reversal needs its reason');
select pg_temp.as_json(pg_temp.u(1), format('select public.reverse_commitment_match_v1(%L, %L, ''wrong month'', %L)', current_setting('t.a'), current_setting('t.m5'), pg_temp.rq(27)));
select is(pg_temp.matched(5), 0::bigint, 'F: after the reversal May expects its rent again');
select is((select count(*)::int from public.purchase_commitment_matches where occurrence_id = pg_temp.occ(5)), 2, 'F: and the history keeps both rows');
select ok((pg_temp.as_json(pg_temp.u(1), format('select public.reverse_commitment_match_v1(%L, %L, ''again'', %L)', current_setting('t.a'), current_setting('t.m5'), pg_temp.rq(28)))::text) like '%already reversed%', 'F: a match is reversed once');

-- the app names a line by its number
select set_config('t.b8', pg_temp.bill('R-JUN', array[100000]), true);
select ok((pg_temp.match(pg_temp.u(1), current_setting('t.b8'),
  jsonb_build_array(jsonb_build_object('occurrence_id', pg_temp.occ(6), 'line_no', 1, 'allocated_cents', 100000)), 29)::text) like '%match_ids%',
  'F: a line can be named by its number, as the app reads a bill');

-- ── G: replay and the append-only table ────────────────────────────────
select is(pg_temp.match(pg_temp.u(1), current_setting('t.b4'), jsonb_build_array(pg_temp.item(pg_temp.occ(5), pg_temp.line(current_setting('t.b4')), 100000)), 17)::text,
  pg_temp.match(pg_temp.u(1), current_setting('t.b4'), jsonb_build_array(pg_temp.item(pg_temp.occ(5), pg_temp.line(current_setting('t.b4')), 100000)), 17)::text,
  'G: the same request answers the same thing');
select ok((select count(*) from public.purchase_commitment_matches where occurrence_id = pg_temp.occ(5) and kind = 'match') = 1, 'G: and made no second match');

-- ── H: who reads ───────────────────────────────────────────────────────
select ok(jsonb_array_length(pg_temp.page(pg_temp.u(4)) -> 'occurrences') >= 10, 'H: an admin who reads the finances reads the occurrences');
select ok((pg_temp.page(pg_temp.u(2))::text) like '%may not read the commitments%', 'H: a plain member does not');
select ok((pg_temp.page(pg_temp.u(5))::text) like '%not an active member%', 'H: nor the owner of another space');
select is(jsonb_array_length(pg_temp.as_json(pg_temp.u(1), format('select public.purchase_commitment_page_v1(%L, %L, null, 3)', current_setting('t.a'), current_setting('t.lease'))) -> 'occurrences'), 3,
  'H: a page holds what it was asked for');

select * from finish();
rollback;
