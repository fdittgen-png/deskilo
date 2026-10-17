-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- accounting_source_snapshot_v1 under the real `authenticated` role: the
-- fiscal source of one workspace and period leaves the database in one
-- response that names its workspace, period, principal and snapshot, and
-- whose control totals equal figures worked out by hand from the seeded
-- rows (not computed by the function under test). The boundary rows decide
-- the workspace's own calendar (Europe/Paris), not UTC. A caller without
-- viewFinances, a member of another workspace, a caller with no identity,
-- an over-long period and an over-budget scope are all refused, and the
-- reads change no row of the four source tables.
begin;
select plan(30);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  uo uuid := '00000000-0000-4000-8000-000000236501';
  up uuid := '00000000-0000-4000-8000-000000236502';
  ux uuid := '00000000-0000-4000-8000-000000236503';
  ws uuid; wx uuid; mo uuid; mp uuid; mxo uuid;
  ia uuid; ib uuid; ic uuid; id_ uuid; ix uuid;
begin
  insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
   values (uo,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner@src2365.test','',now(),now(),now()),
          (up,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','plain@src2365.test','',now(),now(),now()),
          (ux,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','other@src2365.test','',now(),now(),now());
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by)
   values ('Source 2365','FR','EUR','Europe/Paris',uo) returning id into ws;
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by)
   values ('Source 2365 other','FR','EUR','Europe/Paris',ux) returning id into wx;
  insert into public.members(workspace_id,user_id,is_owner,is_admin) values (ws,uo,true,true) returning id into mo;
  insert into public.members(workspace_id,user_id) values (ws,up) returning id into mp;
  insert into public.members(workspace_id,user_id,is_owner,is_admin) values (wx,ux,true,true) returning id into mxo;

  -- 2026 in Paris: A (March), C (31 Dec 2025 23:30 UTC = 1 Jan 2026 Paris).
  -- Out: B (31 Dec 2026 23:30 UTC = 1 Jan 2027 Paris), D (2025), X (other workspace).
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency, member_name, workspace_name, issuer_name, signature, issued_at)
   values (ws, mp, mo, 'A', 'A', '[]'::jsonb, 12000, 'EUR', 'M', 'W', 'O', 's', '2026-03-10 10:00+00') returning id into ia;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency, member_name, workspace_name, issuer_name, signature, issued_at)
   values (ws, mp, mo, 'B', 'B', '[]'::jsonb, 5000, 'EUR', 'M', 'W', 'O', 's', '2026-12-31 23:30+00') returning id into ib;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency, member_name, workspace_name, issuer_name, signature, issued_at)
   values (ws, mp, mo, 'C', 'C', '[]'::jsonb, 7000, 'EUR', 'M', 'W', 'O', 's', '2025-12-31 23:30+00') returning id into ic;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency, member_name, workspace_name, issuer_name, signature, issued_at)
   values (ws, mp, mo, 'D', 'D', '[]'::jsonb, 900, 'EUR', 'M', 'W', 'O', 's', '2025-06-10 10:00+00') returning id into id_;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency, member_name, workspace_name, issuer_name, signature, issued_at)
   values (wx, mxo, mxo, 'X', 'X', '[]'::jsonb, 4242, 'EUR', 'M', 'WX', 'O', 's', '2026-03-10 10:00+00') returning id into ix;

  insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution)
   values (ws, ia, 12000, 'exact'), (ws, id_, 900, 'exact');

  insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, occurred_on, created_at)
   values (ws, mp, 'credit', 'payment', 12000, 'transfer', '2026-03', '2026-03-12', '2026-03-13 08:00+00'),
          (ws, mp, 'charge', 'service', 3000, 'service', '2026-05', null, '2026-05-02 08:00+00'),
          (ws, mp, 'credit', 'expense', 3000, 'taxi', '2026-12', '2026-12-31', '2027-01-05 08:00+00'),
          (ws, mp, 'charge', 'service', 500, 'last year', '2025-12', '2025-12-31', '2025-12-31 08:00+00'),
          (wx, mxo, 'credit', 'payment', 777, 'foreign', '2026-03', '2026-03-12', '2026-03-12 08:00+00');

  insert into public.expense_repartitions (workspace_id, title, amount_cents, method, period, shares, status, created_at, applied_at)
   values (ws, 'rent', 6000, 'equal', '2026-04', '[]'::jsonb, 'confirmed', '2026-03-30 08:00+00', '2026-04-01 08:00+00'),
          (ws, 'old', 111, 'equal', '2025-03', '[]'::jsonb, 'confirmed', '2025-03-01 08:00+00', '2025-03-01 08:00+00');

  perform set_config('sn.ws', ws::text, false);
  perform set_config('sn.wx', wx::text, false);
  perform set_config('sn.uo', uo::text, false);
  perform set_config('sn.up', up::text, false);
  perform set_config('sn.ux', ux::text, false);
end;
$seed$;

create or replace function pg_temp.g(k text) returns uuid language sql as $$
  select current_setting('sn.' || k)::uuid;
$$;
create or replace function pg_temp.act_as(who text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('sn.' || who), 'role', 'authenticated')::text, false);
end;
$$;
create or replace function pg_temp.snap(w text) returns jsonb language sql as $$
  select public.accounting_source_snapshot_v1(pg_temp.g(w), date '2026-01-01', date '2026-12-31');
$$;
create or replace function pg_temp.state() returns text language sql as $$
  select (select count(*) from public.invoices) || '/' || (select count(*) from public.invoice_matches)
      || '/' || (select count(*) from public.ledger_entries) || '/' || (select count(*) from public.expense_repartitions);
$$;

select pg_temp.seed();
select set_config('sn.before', pg_temp.state(), false);
set local role authenticated;
select pg_temp.act_as('uo');
create temp table sn_got as select pg_temp.snap('ws') as j;

select is((select j->>'status' from sn_got), 'ok', 'the owner is answered');
select is((select (j->>'version')::int from sn_got), 1, 'the answer names its version');
select is((select (j->>'workspace_id')::uuid from sn_got), pg_temp.g('ws'), 'the answer names its workspace');
select is((select (j->>'from') || '..' || (j->>'to') from sn_got), '2026-01-01..2026-12-31', 'the answer names its period');
select is((select (j->>'principal')::uuid from sn_got), pg_temp.g('uo'), 'the answer names the principal');
select ok((select length(j->>'cutoff') > 0 from sn_got), 'the answer names the snapshot it was read at');
select is((select j->>'timezone' from sn_got), 'Europe/Paris', 'the answer names the calendar it cut on');

-- invoices: A and C in, B (1 Jan 2027 in Paris), D and the foreign X out
select is((select jsonb_array_length(j->'invoices') from sn_got), 2, 'two invoices are in the 2026 Paris year');
select is((select string_agg(e->>'number', ',' order by e->>'number') from sn_got, jsonb_array_elements(j->'invoices') e), 'A,C',
  'A and the 1 January 2026 Paris invoice C are in; B, D and the foreign X are not');
select is((select (j#>>'{totals,invoices,total_cents}')::int from sn_got), 19000, 'invoice total is 12000 + 7000 worked by hand');
-- matches
select is((select (j#>>'{totals,matches,count}')::int from sn_got), 1, 'one match belongs to an in-scope invoice');
select is((select (j#>>'{totals,matches,paid_cents}')::int from sn_got), 12000, 'match paid total is 12000');
-- ledger: payment, undated service booked 2 May, the 31 Dec expense booked in January 2027
select is((select (j#>>'{totals,ledger,count}')::int from sn_got), 3, 'three ledger rows are in the year (occurred_on beats created_at)');
select is((select (j#>>'{totals,ledger,sum_cents}')::int from sn_got), 18000, 'ledger sum is 12000 + 3000 + 3000');
select is((select (j#>>'{totals,ledger,credit_cents}')::int from sn_got), 15000, 'credit side is 12000 + 3000');
select is((select (j#>>'{totals,ledger,charge_cents}')::int from sn_got), 3000, 'charge side is 3000');
select is((select jsonb_array_length(j->'ledger') from sn_got), 3, 'the delivered rows are the counted rows');
-- repartitions
select is((select (j#>>'{totals,repartitions,count}')::int from sn_got), 1, 'one repartition is applied in the year');
select is((select (j#>>'{totals,repartitions,amount_cents}')::int from sn_got), 6000, 'repartition total is 6000');

-- a repeated read is the same answer
select is((pg_temp.snap('ws')#>>'{totals,ledger,sum_cents}')::int, 18000, 'a retry reads the same totals');

-- refusals
select throws_ok($$ select pg_temp.snap('wx') $$, '42501', 'accounting_source_snapshot_v1: not allowed',
  'the owner of W may not read the source of another workspace');
select pg_temp.act_as('up');
select throws_ok($$ select pg_temp.snap('ws') $$, '42501', 'accounting_source_snapshot_v1: not allowed',
  'a plain member without viewFinances is refused');
select pg_temp.act_as('ux');
select throws_ok($$ select pg_temp.snap('ws') $$, '42501', 'accounting_source_snapshot_v1: not allowed',
  'a member of another workspace is refused');
select lives_ok($$ select pg_temp.snap('wx') $$, 'the other workspace owner reads their own source');
select is((pg_temp.snap('wx')#>>'{totals,ledger,sum_cents}')::int, 777, 'and only their own ledger is in it');
select pg_temp.act_as('uo');
select throws_ok($$ select public.accounting_source_snapshot_v1(pg_temp.g('ws'), date '2025-01-01', date '2026-12-31') $$,
  '22023', 'accounting_source_snapshot_v1: the period must be at most one year', 'a period over one year is refused');
reset role;
set local role anon;
select throws_ok($$ select public.accounting_source_snapshot_v1('00000000-0000-4000-8000-000000000000'::uuid, date '2026-01-01', date '2026-12-31') $$,
  '42501', null, 'anon may not execute it');
reset role;

select is(pg_temp.state(), current_setting('sn.before'), 'the reads and refusals changed no source row');

-- over budget: refused with the narrower-period action, no truncated rows
insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, occurred_on)
  select pg_temp.g('wx'), m.id, 'charge', 'service', 1, 'bulk', '2026-02', '2026-02-02'
    from public.members m, generate_series(1, 20001)
   where m.workspace_id = pg_temp.g('wx');
set local role authenticated;
select pg_temp.act_as('ux');
select is(pg_temp.snap('wx')->>'status', 'refused', 'a scope over the row budget is refused');
select ok(not (pg_temp.snap('wx') ? 'ledger') and pg_temp.snap('wx')->>'action' = 'narrow_period',
  'the refusal carries no rows and names the narrower-period action');
reset role;

select * from finish();
rollback;
