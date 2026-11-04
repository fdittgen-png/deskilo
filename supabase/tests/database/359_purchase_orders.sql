-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3307 / 0679-0681: the space's purchase orders. A buyer (managePurchases)
-- drafts, edits, prints and cancels; a finance reader (viewFinances) reads;
-- a plain member reads and writes nothing; the series counts per space and
-- year; a sent order and its lines are frozen; a request id replays.
begin;
select plan(24);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000033070'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@orders.test','',now(),now(),now()
  from unnest(array['a1','a2','a3','a4']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,role_permissions,feature_flags) values
 ('00000000-0000-4000-8000-0000033070b1','Orders','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000033070a1','dev',
  '{"member":["viewFinances"]}',
  '{"moneyTab":true,"services":true,"purchases":true,"purchaseOrders":true}'),
 ('00000000-0000-4000-8000-0000033070b2','Other','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000033070a1','dev','{}','{}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000033070c1','00000000-0000-4000-8000-0000033070b1','00000000-0000-4000-8000-0000033070a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000033070c2','00000000-0000-4000-8000-0000033070b1','00000000-0000-4000-8000-0000033070a2',false,false,'active'),
 ('00000000-0000-4000-8000-0000033070c4','00000000-0000-4000-8000-0000033070b2','00000000-0000-4000-8000-0000033070a4',true,true,'active');
-- a3 is not a member of the space at all.
insert into public.suppliers (id, workspace_id, supplier_number, name, status) values
 ('00000000-0000-4000-8000-0000033070f1','00000000-0000-4000-8000-0000033070b1','1','Alpha','active'),
 ('00000000-0000-4000-8000-0000033070f9','00000000-0000-4000-8000-0000033070b2','1','Elsewhere','active');
insert into public.services (id, workspace_id, name, price_cents, active, stock) values
 ('00000000-0000-4000-8000-0000033070d1','00000000-0000-4000-8000-0000033070b1','Coffee capsules',200,true,10);

create function pg_temp.u(p text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000033070' || p)::uuid;
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
create function pg_temp.order_payload(p_supplier text, p_extra jsonb default '{}') returns jsonb language sql as $$
  select jsonb_build_object('supplier_id', pg_temp.u(p_supplier), 'expected_on', '2026-12-01',
    'note', 'Leave at the front desk', 'recipient_email', 'orders@alpha.test',
    'lines', jsonb_build_array(
      jsonb_build_object('service_id', pg_temp.u('d1'), 'quantity', 100, 'unit', 'capsule', 'unit_price_cents', 25, 'vat_rate_percent', 20),
      jsonb_build_object('description', 'Paper towels', 'quantity', 12, 'unit', 'roll', 'unit_price_cents', 150))) || p_extra;
$$;
create function pg_temp.save(p_user text, p_request uuid, p_revision int, p_payload jsonb) returns text language sql as $$
  select format('select public.save_purchase_order_v1(%L, %L, %s, %L::jsonb)', pg_temp.u('b1'), p_request, p_revision, p_payload);
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

set local role authenticated;
select set_config('t.req', gen_random_uuid()::text, true);
select set_config('t.o1', pg_temp.as_user('a1', pg_temp.save('a1', current_setting('t.req')::uuid, 0, pg_temp.order_payload('f1')))::text, true);

-- ── creating ──────────────────────────────────────────────────────────
select is(current_setting('t.o1')::jsonb ->> 'state', 'draft', 'a new order is a draft');
select is(current_setting('t.o1')::jsonb ->> 'number', '1', 'the first order of the year is number 1');
select ok(current_setting('t.o1')::jsonb ->> 'reference' ~ '^[0-9]{4}-0001$', 'its reference is the year and the number');
select is(current_setting('t.o1')::jsonb -> 'lines' -> 0 ->> 'description', 'Coffee capsules',
  'a line naming an item takes the item''s name');
select is((current_setting('t.o1')::jsonb -> 'lines' -> 1 ->> 'unit_price_cents', current_setting('t.o1')::jsonb ->> 'currency'),
  ('150'::text, 'EUR'::text), 'a free-text line keeps its price, the order the space''s currency');
select is(pg_temp.as_user('a1', pg_temp.save('a1', current_setting('t.req')::uuid, 0, pg_temp.order_payload('f1'))) ->> 'id',
  current_setting('t.o1')::jsonb ->> 'id', 'the same request id replays the same order, never a second one');
select is(pg_temp.as_user('a1', pg_temp.save('a1', gen_random_uuid(), 0, pg_temp.order_payload('f1'))) ->> 'number', '2',
  'the next order takes the next number');

-- ── refused ───────────────────────────────────────────────────────────
select ok(pg_temp.err('a2', pg_temp.save('a2', gen_random_uuid(), 0, pg_temp.order_payload('f1'))) like '42501%',
  'a finance reader does not order');
select ok(pg_temp.err('a3', pg_temp.save('a3', gen_random_uuid(), 0, pg_temp.order_payload('f1'))) like '42501%',
  'a stranger does not order');
select ok(pg_temp.err('a1', pg_temp.save('a1', gen_random_uuid(), 0, pg_temp.order_payload('f9'))) like '%active supplier of the space%',
  'another space''s supplier is refused');
select ok(pg_temp.err('a1', pg_temp.save('a1', gen_random_uuid(), 0,
    pg_temp.order_payload('f1', jsonb_build_object('lines', jsonb_build_array(jsonb_build_object('description', 'x', 'quantity', 0, 'unit_price_cents', 1))))))
  like '%quantity above zero%', 'a line in no quantity is refused');
select ok(pg_temp.err('a1', pg_temp.save('a1', gen_random_uuid(), 0,
    pg_temp.order_payload('f1', '{"recipient_email": "not an address"}'))) like '%not an e-mail address%',
  'a recipient that is not an e-mail address is refused');

-- ── editing a draft ───────────────────────────────────────────────────
select is(pg_temp.as_user('a1', pg_temp.save('a1', gen_random_uuid(), 1,
    pg_temp.order_payload('f1', jsonb_build_object('order_id', current_setting('t.o1')::jsonb ->> 'id', 'note', 'Ring twice')))) ->> 'note',
  'Ring twice', 'a draft is edited at its revision');
select ok(pg_temp.err('a1', pg_temp.save('a1', gen_random_uuid(), 1,
    pg_temp.order_payload('f1', jsonb_build_object('order_id', current_setting('t.o1')::jsonb ->> 'id')))) like '40001%',
  'a stale revision is refused');

-- ── reading ───────────────────────────────────────────────────────────
select is(pg_temp.as_user('a2', $q$select to_jsonb(count(*)) from public.purchase_orders$q$)::text, '2',
  'a finance reader reads the space''s orders');
select is(pg_temp.as_user('a3', $q$select to_jsonb(count(*)) from public.purchase_orders$q$)::text, '0',
  'a stranger reads none');
select is(pg_temp.as_user('a4', $q$select to_jsonb(count(*)) from public.purchase_order_lines$q$)::text, '0',
  'another space''s owner reads none of its lines');

-- ── sending by print, then frozen ─────────────────────────────────────
select is(pg_temp.as_user('a1', format('select public.mark_purchase_order_sent_v1(%L, %L, 2, %L)',
    pg_temp.u('b1'), current_setting('t.o1')::jsonb ->> 'id', gen_random_uuid())) ->> 'sent_via',
  'print', 'a printed draft is sent, and says how');
select ok(pg_temp.err('a1', pg_temp.save('a1', gen_random_uuid(), 3,
    pg_temp.order_payload('f1', jsonb_build_object('order_id', current_setting('t.o1')::jsonb ->> 'id')))) like '%only a draft%',
  'a sent order is not edited');
reset role;
select throws_ok(format($q$update public.purchase_order_lines set quantity = 1 where order_id = %L$q$,
    current_setting('t.o1')::jsonb ->> 'id'), 'P0001', 'the lines of a sent purchase order are frozen',
  'its lines are frozen, whoever writes');
set local role authenticated;

-- ── cancelling ────────────────────────────────────────────────────────
select ok(pg_temp.err('a1', format('select public.cancel_purchase_order_v1(%L, %L, 3, %L, %L)',
    pg_temp.u('b1'), current_setting('t.o1')::jsonb ->> 'id', '', gen_random_uuid())) like '%says why%',
  'a cancellation says why');
select is(pg_temp.as_user('a1', format('select public.cancel_purchase_order_v1(%L, %L, 3, %L, %L)',
    pg_temp.u('b1'), current_setting('t.o1')::jsonb ->> 'id', 'ordered twice', gen_random_uuid())) ->> 'state',
  'cancelled', 'a sent order is cancelled with its reason');
select ok(pg_temp.err('a1', format('select public.mark_purchase_order_sent_v1(%L, %L, 4, %L)',
    pg_temp.u('b1'), current_setting('t.o1')::jsonb ->> 'id', gen_random_uuid())) like '%only a draft%',
  'a cancelled order is final');

reset role;
update public.workspaces set feature_flags = feature_flags || '{"purchaseOrders": false}' where id = pg_temp.u('b1');
set local role authenticated;
select ok(pg_temp.err('a1', pg_temp.save('a1', gen_random_uuid(), 0, pg_temp.order_payload('f1'))) like '%switched off%',
  'with purchase orders off, nothing is ordered');

select * from finish();
rollback;
