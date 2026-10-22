-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2582 C1 / 0527: the purchase figures of the analytics page, worked by hand.
-- A supplier bill of 10.00 dated 10 March, 6.00 paid on 2 April; a member's
-- approved claim of 1.20 (5 March), 0.50 paid back on 20 March; a second bill
-- of 5.00 waiting for a decision. Owed at the end of March 10.00 and at the
-- end of April 4.00; due to the member 0.70; paid out 0.50 in March and 6.00
-- in April. A plain member and a space without the flag read nothing.
begin;
select plan(12);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000002582'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@kpi.test','',now(),now(),now()
  from unnest(array['a1','a2','a3']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags) values
 ('00000000-0000-4000-8000-0000002582b1','Figures','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000002582a1','dev',
  '{"moneyTab":true,"purchases":true,"purchaseAnalytics":true,"supplyExpenses":true,"inputVat":true}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000002582c1','00000000-0000-4000-8000-0000002582b1','00000000-0000-4000-8000-0000002582a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000002582c2','00000000-0000-4000-8000-0000002582b1','00000000-0000-4000-8000-0000002582a2',false,false,'active'),
 ('00000000-0000-4000-8000-0000002582c3','00000000-0000-4000-8000-0000002582b1','00000000-0000-4000-8000-0000002582a3',false,true,'active');
insert into public.suppliers (id, workspace_id, supplier_number, name, status) values
 ('00000000-0000-4000-8000-0000002582f1','00000000-0000-4000-8000-0000002582b1','1','Fournitures SA','active');

-- The member's approved claim: the bridge files the receipt and its claim,
-- the approval's credit completes it.
insert into public.events (id, workspace_id, type, action, actor_member_id, subject_member_id, payload, status,
                           decided_at, created_at) values
 ('00000000-0000-4000-8000-0000002582e1','00000000-0000-4000-8000-0000002582b1','expense','submitted',
  '00000000-0000-4000-8000-0000002582c2','00000000-0000-4000-8000-0000002582c2',
  '{"amount_cents": 120, "category": "coffee", "note": "Coffee"}', 'confirmed',
  '2026-03-06 10:00+00', '2026-03-05 10:00+00');
insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, event_id)
values ('00000000-0000-4000-8000-0000002582b1','00000000-0000-4000-8000-0000002582c2','credit','expense',120,
        'Coffee','2026-03','00000000-0000-4000-8000-0000002582e1');

create function pg_temp.call(p_user uuid, p_sql text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  execute p_sql into v;
  return v;
end;
$$;
create function pg_temp.bill(p_ref text, p_day text, p_gross int) returns text language sql as $$
  select pg_temp.call('00000000-0000-4000-8000-0000002582a1',
    format('select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)', '00000000-0000-4000-8000-0000002582b1',
      gen_random_uuid(), jsonb_build_object('kind', 'bill', 'supplier_id', '00000000-0000-4000-8000-0000002582f1',
        'original_reference', p_ref, 'original_date', p_day, 'due_on', '2026-06-30', 'payer_kind', 'unpaid',
        'lines', jsonb_build_array(jsonb_build_object('description', p_ref, 'gross_cents', p_gross,
          'net_cents', p_gross, 'tax_cents', 0)))::text)) ->> 'purchase_id';
$$;
create function pg_temp.kpi(p_user text, p_from text, p_to text) returns jsonb language sql as $$
  select pg_temp.call(('00000000-0000-4000-8000-0000002582' || p_user)::uuid,
    format('select public.kpi_purchases_summary(%L, %L, %L)', '00000000-0000-4000-8000-0000002582b1', p_from, p_to));
$$;
create function pg_temp.err(p_user text, p_from text, p_to text) returns text language plpgsql as $$
begin
  perform pg_temp.kpi(p_user, p_from, p_to);
  return '';
exception when others then
  return sqlstate;
end;
$$;

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002582a1","role":"authenticated"}',true);
set local role authenticated;

-- The bill: drafted, submitted, decided by a second admin, 6.00 paid on 2 April.
select set_config('t.bill', pg_temp.bill('F-1', '2026-03-10', 1000), true);
select pg_temp.call('00000000-0000-4000-8000-0000002582a1',
  format('select public.submit_purchase_v1(%L, %L, 1, %L)', '00000000-0000-4000-8000-0000002582b1',
    current_setting('t.bill'), gen_random_uuid()));
select pg_temp.call('00000000-0000-4000-8000-0000002582a3',
  format('select public.decide_purchase_v1(%L, %L, %s, true, %L, %L)', '00000000-0000-4000-8000-0000002582b1',
    current_setting('t.bill'), (select revision from public.purchase_documents where id = current_setting('t.bill')::uuid),
    '', gen_random_uuid()));
select pg_temp.call('00000000-0000-4000-8000-0000002582a1',
  format('select public.record_supplier_payment_v1(%L, %L, 600, %s, %L, %L, ''bank_transfer'', ''wire'')',
    '00000000-0000-4000-8000-0000002582b1',
    (select id from public.purchase_obligations where purchase_id = current_setting('t.bill')::uuid),
    (select revision from public.purchase_obligations where purchase_id = current_setting('t.bill')::uuid),
    gen_random_uuid(), '2026-04-02'));
-- The member's claim: 0.50 paid back on 20 March by the owner.
select pg_temp.call('00000000-0000-4000-8000-0000002582a1',
  format('select public.record_member_reimbursement_v1(%L, %L, 50, %s, %L, %L)',
    '00000000-0000-4000-8000-0000002582b1',
    (select id from public.purchase_obligations where creditor_member_id = '00000000-0000-4000-8000-0000002582c2'),
    (select revision from public.purchase_obligations where creditor_member_id = '00000000-0000-4000-8000-0000002582c2'),
    gen_random_uuid(), '2026-03-20'));
-- A second bill waits for a decision.
select set_config('t.pending', pg_temp.bill('F-2', '2026-04-15', 500), true);
select pg_temp.call('00000000-0000-4000-8000-0000002582a1',
  format('select public.submit_purchase_v1(%L, %L, 1, %L)', '00000000-0000-4000-8000-0000002582b1',
    current_setting('t.pending'), gen_random_uuid()));

select set_config('t.march', pg_temp.kpi('a1', '2026-03', '2026-03')::text, true);
select set_config('t.april', pg_temp.kpi('a1', '2026-04', '2026-04')::text, true);
select set_config('t.spring', pg_temp.kpi('a1', '2026-03', '2026-04')::text, true);

select is(current_setting('t.march')::jsonb ->> 'ap_outstanding_minor', '1000',
  'owed to suppliers at the end of March: the bill, nothing paid yet');
select is(current_setting('t.april')::jsonb ->> 'ap_outstanding_minor', '400',
  'at the end of April: 6.00 of it paid on 2 April');
select is(current_setting('t.march')::jsonb ->> 'member_due_minor', '70',
  'due to the member: 1.20 claimed, 0.50 paid back');
select is(current_setting('t.march')::jsonb ->> 'outflows_minor', '50', 'paid out in March: the 0.50');
select is(current_setting('t.april')::jsonb ->> 'outflows_minor', '600', 'paid out in April: the 6.00');
select is((current_setting('t.spring')::jsonb ->> 'outflows_minor', current_setting('t.spring')::jsonb ->> 'ap_outstanding_minor'),
  ('650'::text, '400'::text), 'two months: the payments summed, the payable read at the end of April, never summed');
select is((current_setting('t.march')::jsonb ->> 'pending_count')::int, 1, 'one bill waits for a decision');
select is(current_setting('t.march')::jsonb ->> 'pending_minor', '500', 'worth 5.00');
select ok(current_setting('t.march')::jsonb -> 'reasons' ? 'current_queue',
  'a past period says the queue is the current one');
select is(current_setting('t.march')::jsonb ->> 'currency', 'EUR', 'in the workspace currency');
select is(pg_temp.err('a2', '2026-03', '2026-03'), '42501', 'a plain member reads no figure');
reset role;
update public.workspaces set feature_flags = feature_flags || '{"purchaseAnalytics": false}'
 where id = '00000000-0000-4000-8000-0000002582b1';
set local role authenticated;
select is(pg_temp.err('a1', '2026-03', '2026-03'), '42501', 'without the flag nobody does');

select * from finish();
rollback;
