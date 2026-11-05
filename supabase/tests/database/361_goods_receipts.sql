-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3307 / 0684: goods receipts and the bill that charges the order. An
-- order of 100 capsules and 12 rolls is sent; 60 capsules arrive (partly
-- received), then 40 capsules and 12 rolls (received). Nothing arrives
-- beyond what was ordered, nor in the future, nor for a draft; a finance
-- reader reads the deliveries and records none; a request id replays; a
-- draft bill of the same supplier names the order.
begin;
select plan(19);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000033072'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@receipts.test','',now(),now(),now()
  from unnest(array['a1','a2']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,role_permissions,feature_flags) values
 ('00000000-0000-4000-8000-0000033072b1','Receipts','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000033072a1','dev',
  '{"member":["viewFinances"]}',
  '{"moneyTab":true,"services":true,"purchases":true,"purchaseOrders":true}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000033072c1','00000000-0000-4000-8000-0000033072b1','00000000-0000-4000-8000-0000033072a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000033072c2','00000000-0000-4000-8000-0000033072b1','00000000-0000-4000-8000-0000033072a2',false,false,'active');
insert into public.suppliers (id, workspace_id, supplier_number, name, status) values
 ('00000000-0000-4000-8000-0000033072f1','00000000-0000-4000-8000-0000033072b1','1','Alpha','active'),
 ('00000000-0000-4000-8000-0000033072f2','00000000-0000-4000-8000-0000033072b1','2','Beta','active');

create function pg_temp.u(p text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000033072' || p)::uuid;
$$;
create function pg_temp.as_user(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.u(p_user), 'role', 'authenticated')::text, true);
  execute p_sql into v;
  return v;
end;
$$;
create function pg_temp.err(p_user text, p_sql text) returns text language plpgsql as $$
begin
  perform pg_temp.as_user(p_user, p_sql);
  return '';
exception when others then
  return sqlstate || ' ' || sqlerrm;
end;
$$;
create function pg_temp.order_of(p_supplier text) returns jsonb language sql as $$
  select pg_temp.as_user('a1', format('select public.save_purchase_order_v1(%L, %L, 0, %L::jsonb)',
    pg_temp.u('b1'), gen_random_uuid(), jsonb_build_object('supplier_id', pg_temp.u(p_supplier),
      'lines', jsonb_build_array(
        jsonb_build_object('description', 'Capsules', 'quantity', 100, 'unit_price_cents', 25),
        jsonb_build_object('description', 'Rolls', 'quantity', 12, 'unit_price_cents', 150)))));
$$;
create function pg_temp.receive(p_order jsonb, p_lines jsonb, p_day date default current_date - 1,
                                p_request uuid default gen_random_uuid()) returns text language sql as $$
  select format('select public.record_purchase_order_receipt_v1(%L, %L, %s, %L, %L::jsonb, %L, %L)',
    pg_temp.u('b1'), p_order ->> 'id', p_order ->> 'revision', p_day, p_lines, 'at the front desk', p_request);
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

set local role authenticated;
select set_config('t.draft', pg_temp.order_of('f1')::text, true);
select set_config('t.o', pg_temp.order_of('f1')::text, true);
select set_config('t.o', pg_temp.as_user('a1', format('select public.mark_purchase_order_sent_v1(%L, %L, 1, %L)',
  pg_temp.u('b1'), current_setting('t.o')::jsonb ->> 'id', gen_random_uuid()))::text, true);

-- ── receiving ─────────────────────────────────────────────────────────
select ok(pg_temp.err('a1', pg_temp.receive(current_setting('t.draft')::jsonb, '[{"line_no":1,"quantity":1}]')) like '%only a sent order%',
  'a draft order receives nothing');
select ok(pg_temp.err('a2', pg_temp.receive(current_setting('t.o')::jsonb, '[{"line_no":1,"quantity":1}]')) like '42501%',
  'a finance reader records no delivery');
select ok(pg_temp.err('a1', pg_temp.receive(current_setting('t.o')::jsonb, '[{"line_no":1,"quantity":1}]', current_date + 2)) like '%future%',
  'a delivery is not dated in the future');
select ok(pg_temp.err('a1', pg_temp.receive(current_setting('t.o')::jsonb, '[{"line_no":1,"quantity":101}]')) like '%more than was ordered%',
  'a line never receives more than was ordered');
select ok(pg_temp.err('a1', pg_temp.receive(current_setting('t.o')::jsonb, '[{"line_no":1,"quantity":0}]')) like '%above zero%',
  'a line is received in a quantity above zero');
select ok(pg_temp.err('a1', pg_temp.receive(jsonb_build_object('id', current_setting('t.o')::jsonb ->> 'id', 'revision', 0),
    '[{"line_no":1,"quantity":1}]')) like '40001%',
  'a delivery against a stale revision is refused');
select ok(pg_temp.err('a1', format('select public.record_purchase_order_receipt_v1(%L, %L, %s, %L, null, %L, %L)',
    pg_temp.u('b1'), current_setting('t.o')::jsonb ->> 'id', current_setting('t.o')::jsonb ->> 'revision',
    current_date - 1, '', gen_random_uuid())) like '%at least one line%',
  'a delivery without its lines is refused');
select set_config('t.req', gen_random_uuid()::text, true);
select set_config('t.o', pg_temp.as_user('a1', pg_temp.receive(current_setting('t.o')::jsonb, '[{"line_no":1,"quantity":60}]',
  current_date - 3, current_setting('t.req')::uuid))::text, true);
select is(current_setting('t.o')::jsonb ->> 'state', 'partly_received', 'a first delivery leaves the order partly received');
select is(current_setting('t.o')::jsonb -> 'lines' -> 0 ->> 'received_quantity', '60', 'the line carries what arrived');
select is(pg_temp.as_user('a1', pg_temp.receive(
    jsonb_build_object('id', current_setting('t.o')::jsonb ->> 'id', 'revision', 2),
    '[{"line_no":1,"quantity":60}]', current_date - 3, current_setting('t.req')::uuid)) ->> 'receipt_id',
  current_setting('t.o')::jsonb ->> 'receipt_id', 'the same request id replays the same delivery');
select ok(pg_temp.err('a1', pg_temp.receive(current_setting('t.o')::jsonb, '[{"line_no":1,"quantity":41}]')) like '%more than was ordered%',
  'what arrived before counts against what was ordered');
select set_config('t.o', pg_temp.as_user('a1', pg_temp.receive(current_setting('t.o')::jsonb,
  '[{"line_no":1,"quantity":40},{"line_no":2,"quantity":12}]'))::text, true);
select is(current_setting('t.o')::jsonb ->> 'state', 'received', 'every line complete: the order is received');
select ok(pg_temp.err('a1', pg_temp.receive(current_setting('t.o')::jsonb, '[{"line_no":1,"quantity":1}]')) like '%only a sent order%',
  'a received order receives nothing more');
select is(pg_temp.as_user('a2', $q$select to_jsonb(count(*)) from public.purchase_order_receipt_lines$q$)::text, '3',
  'a finance reader reads the deliveries');

-- ── the bill that charges the order ───────────────────────────────────
select set_config('t.bill', (pg_temp.as_user('a1', format('select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)',
  pg_temp.u('b1'), gen_random_uuid(), jsonb_build_object('kind', 'bill', 'supplier_id', pg_temp.u('f1'),
    'payer_kind', 'unpaid', 'lines', jsonb_build_array(jsonb_build_object('gross_cents', 4300)))))) ->> 'purchase_id', true);
select set_config('t.other', (pg_temp.as_user('a1', format('select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)',
  pg_temp.u('b1'), gen_random_uuid(), jsonb_build_object('kind', 'bill', 'supplier_id', pg_temp.u('f2'),
    'payer_kind', 'unpaid', 'lines', jsonb_build_array(jsonb_build_object('gross_cents', 100)))))) ->> 'purchase_id', true);
select is(pg_temp.as_user('a1', format('select public.link_purchase_to_order_v1(%L, %L, %L)',
    pg_temp.u('b1'), current_setting('t.bill'), current_setting('t.o')::jsonb ->> 'id')) ->> 'purchase_order_id',
  current_setting('t.o')::jsonb ->> 'id', 'a draft bill of the supplier names the order');
select ok(pg_temp.err('a1', format('select public.link_purchase_to_order_v1(%L, %L, %L)',
    pg_temp.u('b1'), current_setting('t.other'), current_setting('t.o')::jsonb ->> 'id')) like '%another supplier%',
  'a bill of another supplier does not');
select ok(pg_temp.err('a1', format('select public.link_purchase_to_order_v1(%L, %L, %L)',
    pg_temp.u('b1'), current_setting('t.bill'), current_setting('t.draft')::jsonb ->> 'id')) like '%was sent%',
  'a draft order is not charged');
select ok(pg_temp.err('a2', format('select public.link_purchase_to_order_v1(%L, %L, %L)',
    pg_temp.u('b1'), current_setting('t.bill'), current_setting('t.o')::jsonb ->> 'id')) like '42501%',
  'a finance reader links nothing');
reset role;
select is((select purchase_order_id from public.purchase_documents where id = current_setting('t.bill')::uuid)::text,
  current_setting('t.o')::jsonb ->> 'id', 'the bill keeps its order');

select * from finish();
rollback;
