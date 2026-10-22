-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2582 C2 / 0531: a shared operating cost spread over resources by weights a
-- person entered, worked from the issue's figures (in cents): cleaning
-- 100.01 over three offices 1:1:1 is 33.34 / 33.34 / 33.33; rent 5.00 with
-- no rule stays unallocated, then goes direct to one office by a line rule;
-- direct + shared + unallocated is always the operating costs. A revision
-- effective in April leaves March as it was; a retired rule allocates
-- nothing; two rules claiming one line allocate nothing; weights of 0
-- allocate nothing. Only manageBilling may edit, a stale revision is
-- refused, a request id replays, and no edit touches a member's ledger.
begin;
select plan(17);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000025821'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@alloc.test','',now(),now(),now()
  from unnest(array['a1','a2','a3']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags) values
 ('00000000-0000-4000-8000-0000025821b1','Alloc','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000025821a1','dev',
  '{"moneyTab":true,"invoicing":true,"purchases":true,"purchaseAnalytics":true,"supplyExpenses":true,"inputVat":true}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000025821c1','00000000-0000-4000-8000-0000025821b1','00000000-0000-4000-8000-0000025821a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000025821c2','00000000-0000-4000-8000-0000025821b1','00000000-0000-4000-8000-0000025821a2',false,false,'active'),
 ('00000000-0000-4000-8000-0000025821c3','00000000-0000-4000-8000-0000025821b1','00000000-0000-4000-8000-0000025821a3',false,true,'active');
insert into public.suppliers (id, workspace_id, supplier_number, name, status) values
 ('00000000-0000-4000-8000-0000025821f1','00000000-0000-4000-8000-0000025821b1','1','Nettoyage SA','active');
insert into public.levels (id, workspace_id, name) values
 ('00000000-0000-4000-8000-0000025821d0','00000000-0000-4000-8000-0000025821b1','Ground');
insert into public.offices (id, workspace_id, level_id, name, x, y, w, h)
select ('00000000-0000-4000-8000-00000258210' || n)::uuid, '00000000-0000-4000-8000-0000025821b1',
       '00000000-0000-4000-8000-0000025821d0', 'Office ' || n, 0, 0, 1, 1
  from unnest(array['1','2','3']) n;

create function pg_temp.call(p_user uuid, p_sql text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  execute p_sql into v;
  return v;
end;
$$;
create function pg_temp.u(p text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000025821' || p)::uuid;
$$;
-- One approved bill of 10 March with one operating line of p_net, untaxed.
create function pg_temp.bill(p_category text, p_ref text, p_net int) returns uuid language plpgsql as $$
declare v uuid;
begin
  v := (pg_temp.call(pg_temp.u('a1'),
    format('select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)', pg_temp.u('b1'), gen_random_uuid(),
      jsonb_build_object('kind', 'bill', 'supplier_id', pg_temp.u('f1'), 'category', p_category,
        'original_reference', p_ref, 'original_date', '2026-03-10', 'due_on', '2026-04-30', 'payer_kind', 'unpaid',
        'lines', jsonb_build_array(jsonb_build_object('description', p_category, 'gross_cents', p_net,
          'net_cents', p_net, 'tax_cents', 0, 'tax_rate_percent', 0, 'recoverable_tax_cents', 0,
          'nonrecoverable_tax_cents', 0, 'recognition_kind', 'operating')))::text)) ->> 'purchase_id')::uuid;
  perform pg_temp.call(pg_temp.u('a1'),
    format('select public.submit_purchase_v1(%L, %L, 1, %L)', pg_temp.u('b1'), v, gen_random_uuid()));
  perform pg_temp.call(pg_temp.u('a3'),
    format('select public.decide_purchase_v1(%L, %L, %s, true, %L, %L)', pg_temp.u('b1'), v,
      (select revision from public.purchase_documents where id = v), '', gen_random_uuid()));
  return v;
end;
$$;
create function pg_temp.save(p_user text, p_rule uuid, p_expected int, p_body jsonb, p_request uuid default null)
returns jsonb language sql as $$
  select pg_temp.call(pg_temp.u(p_user),
    format('select public.save_cost_allocation_rule_v1(%L, %L, %s, %L::jsonb, %L)', pg_temp.u('b1'), p_rule,
      coalesce(p_expected, 0), p_body, coalesce(p_request, gen_random_uuid())));
$$;
create function pg_temp.offices(p_w1 int, p_w2 int, p_w3 int) returns jsonb language sql as $$
  select jsonb_build_array(
    jsonb_build_object('resource_kind', 'office', 'resource_id', '00000000-0000-4000-8000-000002582103', 'weight', p_w3),
    jsonb_build_object('resource_kind', 'office', 'resource_id', '00000000-0000-4000-8000-000002582101', 'weight', p_w1),
    jsonb_build_object('resource_kind', 'office', 'resource_id', '00000000-0000-4000-8000-000002582102', 'weight', p_w2));
$$;
create function pg_temp.march() returns jsonb language sql as $$
  select pg_temp.call(pg_temp.u('a1'),
    format('select public.kpi_cost_allocation(%L, %L, %L)', pg_temp.u('b1'), '2026-03', '2026-03'));
$$;
create function pg_temp.shares(p jsonb) returns text language sql as $$
  select string_agg(r ->> 'allocated_minor', '/' order by r ->> 'resource_id')
    from jsonb_array_elements(p -> 'resources') r;
$$;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000025821a1","role":"authenticated"}',true);
set local role authenticated;

select set_config('t.cleaning', pg_temp.bill('Cleaning', 'N-1', 10001)::text, true);
select set_config('t.rent', pg_temp.bill('Rent', 'L-1', 500)::text, true);
select set_config('t.ledger', (select count(*) from public.ledger_entries
                                 where workspace_id = pg_temp.u('b1'))::text, true);

-- The shared cleaning, 1:1:1 from January.
select set_config('t.rule', pg_temp.save('a1', null, 0, jsonb_build_object(
  'category', 'Cleaning', 'effective_from', '2026-01-01', 'basis', 'Floor area, equal offices',
  'weights', pg_temp.offices(1, 1, 1)), pg_temp.u('e1')) ->> 'rule_id', true);
select set_config('t.m', pg_temp.march()::text, true);
select is(pg_temp.shares(current_setting('t.m')::jsonb), '3334/3334/3333',
  '100.01 over 1:1:1: 33.34 / 33.34 / 33.33, the extra cents in office order');
select is(current_setting('t.m')::jsonb ->> 'shared_minor', '10001', 'all of it shared');
select is(current_setting('t.m')::jsonb ->> 'unallocated_minor', '500', 'the rent with no rule stays unallocated');
select is((current_setting('t.m')::jsonb ->> 'direct_minor')::bigint + (current_setting('t.m')::jsonb ->> 'shared_minor')::bigint
          + (current_setting('t.m')::jsonb ->> 'unallocated_minor')::bigint,
          (current_setting('t.m')::jsonb ->> 'operating_costs_minor')::bigint,
  'direct + shared + unallocated = the operating costs');
select is(pg_temp.save('a1', null, 0, jsonb_build_object(
  'category', 'Cleaning', 'effective_from', '2026-01-01', 'basis', 'Floor area, equal offices',
  'weights', pg_temp.offices(1, 1, 1)), pg_temp.u('e1')) ->> 'rule_id', current_setting('t.rule'),
  'the same request id replays the same revision');

-- The rent goes to office 1 alone: direct.
select pg_temp.save('a1', null, 0, jsonb_build_object(
  'purchase_line_id', (select id from public.purchase_lines where purchase_id = current_setting('t.rent')::uuid),
  'effective_from', '2026-03-01', 'basis', 'Office 1 holds the lease',
  'weights', jsonb_build_array(jsonb_build_object('resource_kind', 'office',
    'resource_id', '00000000-0000-4000-8000-000002582101', 'weight', 1))));
select is(pg_temp.march() ->> 'direct_minor', '500', 'a rule with one resource is direct');
select is(pg_temp.march() ->> 'unallocated_minor', '0', 'and nothing is left unallocated');

-- A revision effective in April leaves March on revision 1.
select pg_temp.save('a1', current_setting('t.rule')::uuid, 1, jsonb_build_object(
  'category', 'Cleaning', 'effective_from', '2026-04-01', 'basis', 'Only office 1 from April',
  'weights', pg_temp.offices(1, 0, 0)));
select is(pg_temp.shares(pg_temp.march()), '3834/3334/3333',
  'March still 1:1:1 (office 1 also holds the rent), the April revision does not rewrite it');
select ok(pg_temp.march() -> 'rules' @> jsonb_build_array(jsonb_build_object(
  'rule_id', current_setting('t.rule'), 'revision', 1)), 'and March states revision 1');

select throws_ok(format($q$select pg_temp.save('a1', %L, 1, '{"category":"Cleaning","effective_from":"2026-01-01","basis":"x","weights":[]}'::jsonb)$q$,
  current_setting('t.rule')), '40001', null, 'a stale revision is refused');
select throws_ok($q$select pg_temp.save('a2', null, 0, jsonb_build_object('category', 'Cleaning',
  'effective_from', '2026-01-01', 'basis', 'x', 'weights', pg_temp.offices(1, 1, 1)))$q$,
  '42501', null, 'a member without manageBilling may not edit');
select throws_ok($q$select pg_temp.save('a1', null, 0, jsonb_build_object('category', 'Cleaning',
  'effective_from', '2026-01-01', 'basis', 'x', 'weights', jsonb_build_array(jsonb_build_object(
  'resource_kind', 'office', 'resource_id', gen_random_uuid(), 'weight', 1))))$q$,
  '22023', null, 'a resource of no office of this workspace is refused');

-- Retired from March: the cleaning is unallocated again.
select pg_temp.save('a1', current_setting('t.rule')::uuid, 2, jsonb_build_object(
  'category', 'Cleaning', 'effective_from', '2026-03-01', 'basis', 'Stopped', 'retired', true, 'weights', '[]'::jsonb));
select is(pg_temp.march() ->> 'unallocated_minor', '10001', 'a retired rule allocates nothing');

-- Weights of 0: unallocated, never an even split.
select set_config('t.zero', pg_temp.save('a1', null, 0, jsonb_build_object(
  'category', 'Cleaning', 'effective_from', '2026-03-01', 'basis', 'Not measured yet',
  'weights', pg_temp.offices(0, 0, 0))) ->> 'rule_id', true);
select is(pg_temp.march() ->> 'unallocated_minor', '10001', 'weights of 0 allocate nothing');

-- Two live rules for the same category: the line is claimed twice.
select pg_temp.save('a1', null, 0, jsonb_build_object(
  'category', 'Cleaning', 'effective_from', '2026-03-01', 'basis', 'A second opinion',
  'weights', pg_temp.offices(1, 1, 1)));
select is((pg_temp.march() ->> 'conflicting_lines')::int, 1, 'two rules claiming one line conflict');
select is(pg_temp.march() ->> 'unallocated_minor', '10001', 'and allocate nothing');

select is((select count(*) from public.ledger_entries where workspace_id = pg_temp.u('b1'))::text,
  current_setting('t.ledger'), 'no rule edit wrote to a member''s ledger');

select * from finish();
rollback;
