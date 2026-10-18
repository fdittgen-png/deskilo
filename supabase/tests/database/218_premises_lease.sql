-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2569 / 0473-0474: the premises lease the space holds as tenant -- its
-- terms with their history, the scheduled expenses they generate, and its
-- termination. Real roles; every refusal is followed by a readback.
-- Expected values are written by hand (rent 1 000.00 from 1 March 2026 and
-- 1 050.00 from 1 September: six occurrences at 1 000.00 and the rest at
-- 1 050.00; a second lease ended on 30 April: four occurrences, none after).
--   A the flag and the rights   B the lease   C terms and their history
--   D the occurrences   E termination   F history is never edited
-- NOT RUN here: two sessions adding a term to one lease at once.
begin;
select plan(54);

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
create function pg_temp.owner_err(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return '';
exception when others then
  return sqlerrm;
end;
$$;
create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00002569' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.mem(n int) returns uuid language sql as $$
  select id from public.members where user_id = pg_temp.u(n) and workspace_id = current_setting('t.a')::uuid;
$$;
create function pg_temp.rq(n int) returns uuid language sql as $$
  select ('c0000000-0000-4000-8000-00000000' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.save(p_user uuid, p_lease text, p_rev int, p_payload jsonb, p_req int) returns jsonb language plpgsql as $$
begin
  return pg_temp.as_json(p_user, format('select public.save_premises_lease_v1(%L, %L, %s, %L::jsonb, %L)',
    current_setting('t.a'), p_lease, p_rev, p_payload::text, pg_temp.rq(p_req)));
end;
$$;
create function pg_temp.term(p_user uuid, p_lease text, p_rev int, p_kind text, p_label text, p_amount int, p_every int, p_from date, p_req int) returns jsonb
language plpgsql as $$
begin
  return pg_temp.as_json(p_user, format('select public.add_lease_term_v1(%L, %L, %s, %L, %L, %s, %s, %L, %L)',
    current_setting('t.a'), p_lease, p_rev, p_kind, p_label, p_amount, p_every, p_from, pg_temp.rq(p_req)));
end;
$$;
create function pg_temp.notice(p_user uuid, p_lease text, p_rev int, p_given date, p_end date, p_reason text, p_req int) returns jsonb
language plpgsql as $$
begin
  return pg_temp.as_json(p_user, format('select public.give_lease_notice_v1(%L, %L, %s, %L, %L, %L, %L)',
    current_setting('t.a'), p_lease, p_rev, p_given, p_end, p_reason, pg_temp.rq(p_req)));
end;
$$;
create function pg_temp.sweep() returns int language plpgsql as $$
declare v int;
begin
  perform pg_temp.act_as(pg_temp.u(1));
  select public.sweep_expense_schedules(current_setting('t.a')::uuid) into v;
  reset role;
  return v;
end;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@lease.test', '', now(), now(), now()
  from generate_series(1, 5) i;
-- 1 owner of A, 2 plain member, 4 admin (reads the finances, no lease right),
-- 5 owner of B.
select pg_temp.act_as(pg_temp.u(1));
select set_config('t.a', public.create_workspace('Lease A', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select pg_temp.act_as(pg_temp.u(5));
select set_config('t.b', public.create_workspace('Lease B', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"supplyExpenses": true, "scheduledExpenses": true}'
 where id in (current_setting('t.a')::uuid, current_setting('t.b')::uuid);
insert into public.members (workspace_id, user_id, is_owner, is_admin, status, subscription_pct, joined_at) values
 (current_setting('t.a')::uuid, pg_temp.u(2), false, false, 'active', 100, '2026-01-01'),
 (current_setting('t.a')::uuid, pg_temp.u(4), false, true, 'active', 100, '2026-01-01');
insert into public.suppliers (id, workspace_id, supplier_number, name, status) values
 ('00000000-0000-4000-8000-0000256900a1', current_setting('t.a')::uuid, '1', 'SCI Les Halles', 'active'),
 ('00000000-0000-4000-8000-0000256900a2', current_setting('t.a')::uuid, '2', 'Ancienne Agence', 'archived'),
 ('00000000-0000-4000-8000-0000256900b1', current_setting('t.b')::uuid, '1', 'Other Landlord', 'active');
insert into public.workspace_documents (id, workspace_id, title, category, provider, url)
values ('00000000-0000-4000-8000-0000256900d1', current_setting('t.a')::uuid, 'Lease contract', 'other', 'link', 'https://example.test/lease.pdf'),
       ('00000000-0000-4000-8000-0000256900d2', current_setting('t.b')::uuid, 'Foreign contract', 'other', 'link', 'https://example.test/foreign.pdf');

create function pg_temp.lease_payload(p_extra jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('supplier_id', '00000000-0000-4000-8000-0000256900a1', 'premises', '12 rue des Halles, 34120 Pézenas',
    'area_m2', 85.5, 'covered_levels', 'Ground floor', 'starts_on', '2026-03-01', 'fixed_until', '2027-02-28',
    'notice_months', 3, 'indexation_note', 'ILC, each 1 March', 'deposit_cents', 200000,
    'contract_document_id', '00000000-0000-4000-8000-0000256900d1') || p_extra;
$$;

-- ── A: the flag and the rights ─────────────────────────────────────────
select ok((pg_temp.save(pg_temp.u(1), null, 0, pg_temp.lease_payload(), 1)::text) like '%switched off%',
  'A: with the flag off the lease cannot be saved');
update public.workspaces set feature_flags = feature_flags || '{"premisesLease": true}' where id = current_setting('t.a')::uuid;
select ok((pg_temp.save(pg_temp.u(2), null, 0, pg_temp.lease_payload(), 2)::text) like '%may not manage the lease%',
  'A: a plain member cannot save it');
select ok((pg_temp.save(pg_temp.u(4), null, 0, pg_temp.lease_payload(), 3)::text) like '%may not manage the lease%',
  'A: nor an admin who only reads the finances');
select ok((pg_temp.save(pg_temp.u(5), null, 0, pg_temp.lease_payload(), 4)::text) like '%not an active member%',
  'A: nor a foreign owner');
select is((select count(*)::int from public.premises_leases), 0, 'A: readback: no refusal left a lease');

-- ── B: the lease ───────────────────────────────────────────────────────
select ok((pg_temp.save(pg_temp.u(1), null, 0, pg_temp.lease_payload('{"supplier_id": "00000000-0000-4000-8000-0000256900b1"}'), 5)::text) like '%active supplier of this space%',
  'B: a foreign supplier is not the lessor');
select ok((pg_temp.save(pg_temp.u(1), null, 0, pg_temp.lease_payload('{"supplier_id": "00000000-0000-4000-8000-0000256900a2"}'), 6)::text) like '%active supplier of this space%',
  'B: nor an archived one');
select ok((pg_temp.save(pg_temp.u(1), null, 0, pg_temp.lease_payload('{"contract_document_id": "00000000-0000-4000-8000-0000256900d2"}'), 7)::text) like '%unknown contract document%',
  'B: nor another space''s contract');
select set_config('t.l1', pg_temp.save(pg_temp.u(1), null, 0, pg_temp.lease_payload(), 8)::text, true);
select is(current_setting('t.l1')::jsonb ->> 'status', 'draft', 'B: the owner records the lease as a draft');
select is(current_setting('t.l1')::jsonb ->> 'notice_deadline', '2026-11-28', 'B: golden: fixed until 28 Feb 2027 with 3 months notice: the deadline is 28 Nov 2026');
select is(current_setting('t.l1')::jsonb ->> 'supplier_name', 'SCI Les Halles', 'B: and names its lessor');
select is(pg_temp.save(pg_temp.u(1), null, 0, pg_temp.lease_payload(), 8), current_setting('t.l1')::jsonb, 'B: the same request answers the original');
select is((select count(*)::int from public.premises_leases), 1, 'B: and files no second lease');
select ok((pg_temp.save(pg_temp.u(1), current_setting('t.l1')::jsonb ->> 'id', 9, '{"notice_months": 6}'::jsonb, 9)::text) like '%stale revision%',
  'B: a stale revision is refused');
select set_config('t.l1', pg_temp.save(pg_temp.u(1), current_setting('t.l1')::jsonb ->> 'id', 1, '{"notice_months": 6}'::jsonb, 10)::text, true);
select is(current_setting('t.l1')::jsonb ->> 'notice_deadline', '2026-08-28', 'B: a draft is amended: 6 months notice moves the deadline');

-- ── C: terms and their history ─────────────────────────────────────────
select set_config('t.id', current_setting('t.l1')::jsonb ->> 'id', true);
select ok((pg_temp.term(pg_temp.u(2), current_setting('t.id'), 2, 'rent', '', 100000, 1, '2026-03-01', 11)::text) like '%may not manage the lease%',
  'C: a plain member adds no term');
select ok((pg_temp.term(pg_temp.u(1), current_setting('t.id'), 2, 'rent', '', 100000, 1, '2026-02-01', 12)::text) like '%before the lease%',
  'C: a term cannot start before the lease');
select ok((pg_temp.term(pg_temp.u(1), current_setting('t.id'), 2, 'rent', '', 0, 1, '2026-03-01', 13)::text) like '%must be positive%', 'C: the amount is positive');
select ok((pg_temp.term(pg_temp.u(1), current_setting('t.id'), 2, 'rent', '', 100000, 2, '2026-03-01', 14)::text) like '%every 1, 3, 6 or 12%', 'C: and paid monthly, quarterly, half-yearly or yearly');
select ok((pg_temp.term(pg_temp.u(1), current_setting('t.id'), 2, 'other', '', 5000, 1, '2026-03-01', 15)::text) like '%name the other charge%', 'C: another charge is named');
select ok((pg_temp.term(pg_temp.u(1), current_setting('t.id'), 2, 'parking', '', 5000, 1, '2026-03-01', 16)::text) like '%unknown term kind%', 'C: the kind is one of the three');
select is((select count(*)::int from public.expense_schedules where workspace_id = current_setting('t.a')::uuid), 0, 'C: readback: no refusal made a scheduled expense');
select set_config('t.t1', pg_temp.term(pg_temp.u(1), current_setting('t.id'), 2, 'rent', '', 100000, 1, '2026-03-01', 17)::text, true);
select is(current_setting('t.t1')::jsonb ->> 'status', 'active', 'C: the first term activates the lease');
select is((select concat_ws('/', es.status, es.amount_cents, es.next_due, es.every, es.unit, (es.supplier_id = '00000000-0000-4000-8000-0000256900a1')::text,
                            (es.member_id = pg_temp.mem(1))::text)
             from public.expense_schedules es where es.workspace_id = current_setting('t.a')::uuid),
  'active/100000/2026-03-01/1/month/true/true', 'C: it owns one active monthly schedule, with the lessor, answered by the responsible member');
select is(pg_temp.term(pg_temp.u(1), current_setting('t.id'), 2, 'rent', '', 100000, 1, '2026-03-01', 17), current_setting('t.t1')::jsonb, 'C: the same request answers the original');
select ok((pg_temp.term(pg_temp.u(1), current_setting('t.id'), 3, 'rent', '', 105000, 1, '2026-03-01', 18)::text) like '%starts after the one in force%',
  'C: a new term starts after the one in force');
select set_config('t.t2', pg_temp.term(pg_temp.u(1), current_setting('t.id'), 3, 'rent', '', 105000, 1, '2026-09-01', 19)::text, true);
select is((select string_agg(t.amount_cents || ':' || t.effective_from || ':' || coalesce(t.effective_to::text, 'open'), ' | ' order by t.effective_from)
             from public.lease_terms t where t.lease_id = current_setting('t.id')::uuid),
  '100000:2026-03-01:2026-08-31 | 105000:2026-09-01:open', 'C: history keeps both terms; the first closed the day before the second');
select is((select string_agg(coalesce(es.ends_on::text, 'open'), ' | ' order by es.starts_on) from public.expense_schedules es
            where es.workspace_id = current_setting('t.a')::uuid), '2026-08-31 | open', 'C: and so do their schedules');
select is(jsonb_array_length(current_setting('t.t2')::jsonb -> 'terms'), 2, 'C: the lease reads back with both terms');

-- ── D: the occurrences ─────────────────────────────────────────────────
select ok(pg_temp.sweep() >= 8, 'D: the sweep materialises the occurrences up to today');
select is((select count(*)::int from public.expense_occurrences where workspace_id = current_setting('t.a')::uuid and amount_cents = 100000), 6,
  'D: golden: six occurrences at 1 000.00 (March to August)');
select is((select count(*)::int from public.expense_occurrences where workspace_id = current_setting('t.a')::uuid and amount_cents = 105000
              and due_on < '2026-09-01'), 0, 'D: and none at 1 050.00 before 1 September');
select is((select (count(*) - count(distinct date_trunc('month', due_on)))::int from public.expense_occurrences where workspace_id = current_setting('t.a')::uuid), 0,
  'D: no month has two occurrences: the superseded schedule stopped where the new one began');

select is((select concat_ws('/', es.origin, (es.contract_id = current_setting('t.id')::uuid)::text) from public.expense_schedules es
            where es.workspace_id = current_setting('t.a')::uuid and es.starts_on = '2026-03-01'), 'workspace_contract/true',
  'D: the schedule of a term is a workspace contract of the lease, not a member''s outlay');
create temp table seed_ledger as select count(*) as n from public.ledger_entries;
select ok((pg_temp.as_json(pg_temp.u(1), format('select public.confirm_expense_occurrence(%L, 100000, '''', null)::text',
  (select o.id from public.expense_occurrences o where o.workspace_id = current_setting('t.a')::uuid and o.amount_cents = 100000 limit 1)))::text)
  like '%matched to the supplier invoice%', 'D: the responsible member cannot confirm a rent occurrence as an outlay');
select is((select count(*)::int from public.ledger_entries), (select n::int from seed_ledger), 'D: and no member account was credited with the rent');

-- ── E: termination ─────────────────────────────────────────────────────
select ok((pg_temp.notice(pg_temp.u(2), current_setting('t.id'), 4, current_date, current_date + 60, 'move out', 20)::text) like '%may not manage the lease%',
  'E: a plain member cannot end the lease');
select ok((pg_temp.notice(pg_temp.u(1), current_setting('t.id'), 4, current_date, current_date - 1, 'x', 21)::text) like '%cannot end before notice%', 'E: it cannot end before notice is given');
select ok((pg_temp.notice(pg_temp.u(1), current_setting('t.id'), 4, current_date, current_date + 60, '  ', 22)::text) like '%state why%', 'E: it needs its reason');
select set_config('t.n1', pg_temp.notice(pg_temp.u(1), current_setting('t.id'), 4, current_date, current_date + 60, 'moving to a larger place', 23)::text, true);
select is(current_setting('t.n1')::jsonb ->> 'status', 'notice_given', 'E: notice with an end in the future leaves the lease in notice');
select is(current_setting('t.n1')::jsonb ->> 'deposit_due_back_cents', '200000', 'E: and lists the deposit due back (2 000.00)');
select is((select concat_ws('/', l.terminated_by_member_id = pg_temp.mem(1), l.termination_reason) from public.premises_leases l where l.id = current_setting('t.id')::uuid),
  't/moving to a larger place', 'E: who, and why, are recorded');
select is((select string_agg(distinct coalesce(es.ends_on::text, 'open'), ',') from public.expense_schedules es
            where es.workspace_id = current_setting('t.a')::uuid and es.starts_on = '2026-09-01'), (current_date + 60)::text,
  'E: the schedule in force now stops at the end date');
select ok((pg_temp.term(pg_temp.u(1), current_setting('t.id'), 5, 'rent', '', 110000, 1, current_date + 90, 24)::text) like '%no new term%', 'E: a terminated lease takes no new term');
select ok((pg_temp.notice(pg_temp.u(1), current_setting('t.id'), 5, current_date, current_date + 30, 'again', 25)::text) like '%only an active lease%', 'E: and is not ended twice');

-- a lease whose end is already past: four occurrences, none after
select set_config('t.l2', pg_temp.save(pg_temp.u(1), null, 0, pg_temp.lease_payload('{"starts_on": "2026-01-01", "fixed_until": null, "premises": "Storage unit"}'), 26)::text, true);
select pg_temp.term(pg_temp.u(1), current_setting('t.l2')::jsonb ->> 'id', 1, 'service_charge_advance', '', 20000, 1, '2026-01-01', 27);
select set_config('t.n2', pg_temp.notice(pg_temp.u(1), current_setting('t.l2')::jsonb ->> 'id', 2, '2026-02-10', '2026-04-30', 'lease expired', 28)::text, true);
select is(current_setting('t.n2')::jsonb ->> 'status', 'ended', 'E: an end already past ends the lease at once');
select pg_temp.sweep();
select is((select count(*)::int from public.expense_occurrences o join public.lease_terms t on t.schedule_id = o.schedule_id
            where t.lease_id = (current_setting('t.l2')::jsonb ->> 'id')::uuid and o.due_on <= '2026-04-30'), 4, 'E: golden: January to April, four occurrences');
select is((select count(*)::int from public.expense_occurrences o join public.lease_terms t on t.schedule_id = o.schedule_id
            where t.lease_id = (current_setting('t.l2')::jsonb ->> 'id')::uuid and o.due_on > '2026-04-30'), 0, 'E: and none after the end');
select is((select count(*)::int from public.expense_occurrences where workspace_id = current_setting('t.a')::uuid and amount_cents = 100000), 6,
  'E: every past occurrence of the first lease is intact');

-- ── F: history is never edited, and who reads ──────────────────────────
select ok(pg_temp.owner_err(format('update public.lease_terms set amount_cents = 1 where lease_id = %L', current_setting('t.id'))) like '%superseded, never edited%',
  'F: a term is not edited, even by an owner of the table');
select ok(pg_temp.owner_err(format('delete from public.lease_terms where lease_id = %L', current_setting('t.id'))) like '%never deleted%', 'F: nor deleted');
select is(jsonb_array_length(pg_temp.as_json(pg_temp.u(4), format('select public.premises_leases_v1(%L) -> ''leases''', current_setting('t.a')))), 2,
  'F: an admin who reads the finances reads the leases');
select ok((pg_temp.as_json(pg_temp.u(2), format('select public.premises_leases_v1(%L)', current_setting('t.a')))::text) like '%may not read the lease%',
  'F: a plain member does not');
select pg_temp.act_as(pg_temp.u(2));
select is((select count(*)::int from public.premises_leases) + (select count(*)::int from public.lease_terms), 0, 'F: nor does a table read show them');
reset role;

select * from finish();
rollback;
