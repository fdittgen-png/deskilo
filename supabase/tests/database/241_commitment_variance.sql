-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2575 / 0516: a bill above the rent a contract expects is a decision.
-- Real roles; every refusal is followed by a readback. Rent 1 000.00 a month
-- from 1 January 2026 (the 222 fixture).
--   A the difference accepted without a policy   B refusals   C held by a
--   policy, applied as the requester on confirmation   D reversal   E replay
begin;
select plan(18);

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
  select ('00000000-0000-4000-8000-00002576' || lpad(n::text, 4, '1'))::uuid;
$$;
create function pg_temp.rq(n int) returns uuid language sql as $$
  select ('c1000000-0000-4000-8000-00000000' || lpad(n::text, 4, '0'))::uuid;
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
       'u' || i || '@variance.test', '', now(), now(), now()
  from generate_series(1, 5) i;
-- 1 owner of A, 2 plain member, 4 admin (reads finances, links no bill), 5 owner of B.
select pg_temp.act_as(pg_temp.u(1));
select set_config('t.a', public.create_workspace('Variance A', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select pg_temp.act_as(pg_temp.u(5));
select set_config('t.b', public.create_workspace('Variance B', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
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

create function pg_temp.variance(p_user uuid, p_occ uuid, p_purchase text, p_cents int, p_reason text, p_req int)
returns jsonb language plpgsql as $$
begin
  return pg_temp.as_json(p_user, format('select public.accept_commitment_variance_v1(%L, %L, %L, 1, %s, %L, %L)',
    current_setting('t.a'), p_occ, p_purchase, p_cents, p_reason, pg_temp.rq(p_req)));
end;
$$;
create function pg_temp.variances(p_month int) returns bigint language sql as $$
  select coalesce(sum(allocated_cents), 0) from public.purchase_commitment_matches
   where occurrence_id = pg_temp.occ(p_month) and kind = 'variance';
$$;

-- ── A: 1 050.00 billed for January; 1 000.00 matched, 50.00 accepted ───
select set_config('t.b1', pg_temp.bill('R-JAN', array[105000]), true);
select pg_temp.match(pg_temp.u(1), current_setting('t.b1'), jsonb_build_array(pg_temp.item(pg_temp.occ(1), pg_temp.line(current_setting('t.b1')), 100000)), 10);
select is(pg_temp.matched(1), 100000::bigint, 'A: January is matched up to what it expects; 50.00 of the line is left');
select ok((pg_temp.variance(pg_temp.u(1), pg_temp.occ(1), current_setting('t.b1'), 5000, 'indexation applied by the lessor', 20)::text) like '%variance_id%',
  'A: the owner accepts the 50.00 difference with a reason');
select is(pg_temp.variances(1), 5000::bigint, 'A: the difference is written beside the match');
select is(pg_temp.matched(2), 0::bigint, 'A: February still expects 1 000.00: the lease is not changed');
select is((select e ->> 'kind' from jsonb_array_elements(pg_temp.occ_json(pg_temp.u(1), 1) -> 'matches') e where e ->> 'kind' = 'variance'),
  'variance', 'A: the page lists the accepted difference with its kind');

-- ── B: refusals ────────────────────────────────────────────────────────
-- line 1: 1 000.00 of rent; line 2: a 100.00 catch-up
select set_config('t.b2', pg_temp.bill('R-FEB', array[100000, 10000]), true);
select pg_temp.match(pg_temp.u(1), current_setting('t.b2'), jsonb_build_array(pg_temp.item(pg_temp.occ(2), pg_temp.line(current_setting('t.b2')), 90000)), 11);
select ok((pg_temp.variance(pg_temp.u(1), pg_temp.occ(2), current_setting('t.b2'), 5000, 'x', 21)::text) like '%match the occurrence in full%',
  'B: no difference is accepted on a month that is not matched in full');
select pg_temp.match(pg_temp.u(1), current_setting('t.b2'), jsonb_build_array(pg_temp.item(pg_temp.occ(2), pg_temp.line(current_setting('t.b2'), 2), 10000)), 12);
select ok((pg_temp.variance(pg_temp.u(1), pg_temp.occ(2), current_setting('t.b2'), 10001, 'x', 22)::text) like '%exceeds what is left of the line%',
  'B: never more than what is left of the line');
select ok((pg_temp.variance(pg_temp.u(1), pg_temp.occ(2), current_setting('t.b2'), 5000, '  ', 23)::text) like '%state why%',
  'B: a reason is required');
select ok((pg_temp.variance(pg_temp.u(2), pg_temp.occ(2), current_setting('t.b2'), 5000, 'x', 24)::text) like '%may not link supplier bills%',
  'B: a plain member may not accept a difference');
select is(pg_temp.variances(2), 0::bigint, 'B: and nothing was written by any refusal');

-- ── C: held by a policy, applied as the requester ──────────────────────
insert into public.validation_policies (workspace_id, event_type, required_count, admins_may_validate, min_amount_cents)
values (current_setting('t.a')::uuid, 'commitment_variance', 1, true, 0);
select set_config('t.c', pg_temp.variance(pg_temp.u(1), pg_temp.occ(2), current_setting('t.b2'), 10000, 'service charge catch-up', 25) ->> 'event_id', true);
select isnt(current_setting('t.c'), null, 'C: under a policy the difference is a pending decision');
select is(pg_temp.variances(2), 0::bigint, 'C: nothing is written while it is pending');
select is(pg_temp.as_json(pg_temp.u(4), format('select ''{}''::jsonb from public.respond_to_event(%L, true)', current_setting('t.c'))) ->> 'error',
  null, 'C: the admin confirms it');
select is(pg_temp.variances(2), 10000::bigint, 'C: the confirmation writes the 100.00 difference');
select is((select actor_member_id from public.purchase_commitment_matches where occurrence_id = pg_temp.occ(2) and kind = 'variance'),
  pg_temp.mem(1), 'C: as the member who asked for it');

-- ── D: a difference is reversed like a match ───────────────────────────
select ok((pg_temp.as_json(pg_temp.u(1), format('select public.reverse_commitment_match_v1(%L, %L, %L, %L)', current_setting('t.a'),
  (select id from public.purchase_commitment_matches where occurrence_id = pg_temp.occ(1) and kind = 'variance'),
  'wrong indexation', pg_temp.rq(30)))::text) like '%reversal_id%', 'D: the January difference is reversed with a reason');
select is((select coalesce(sum(allocated_cents), 0)::bigint from public.purchase_commitment_matches where occurrence_id = pg_temp.occ(1)),
  100000::bigint, 'D: January is back to its matched 1 000.00');

-- ── E: replay ──────────────────────────────────────────────────────────
select is(pg_temp.variance(pg_temp.u(1), pg_temp.occ(2), current_setting('t.b2'), 10000, 'service charge catch-up', 25) ->> 'event_id',
  current_setting('t.c'), 'E: the same request id answers the same decision, nothing twice');

select * from finish();
rollback;
