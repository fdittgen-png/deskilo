-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3294 step 5 / 0699: the vendor delivery figure, proven from a hand-built
-- March 2025 (Paris, EUR). Purchase orders (sent, expected, received):
--   o1 Alpha   5th, 20th, received the 18th      -> on time, lead 13, -2 days
--   o2 Alpha   6th, 15th, received the 25th      -> late, lead 19, +10 days
--   o3 Beta    7th, 20th, part received the 12th -> partial
--   o4 Beta    8th, 10th, nothing                -> overdue
--   o5 Gamma   9th, 2099, nothing                -> open
--   o6 Gamma  10th, none, received the 15th      -> unknown expected, lead 5
--   o7 Gamma  11th, cancelled; o8 Alpha a draft; o9 Alpha sent 2 April
--                                                -> not in the months
-- On time 1 of 2 with a date; lead median 13, P90 19; delay median -2, P90 10.
-- A plain member reads nothing; with `purchaseOrders` off the reason says so;
-- the figures of 0673 are unchanged. Rolled back.
begin;
select plan(13);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000032943'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@delivery.test','',now(),now(),now()
  from unnest(array['a1','a2']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags) values
 ('00000000-0000-4000-8000-0000032943b1','Delivery','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000032943a1','dev',
  '{"moneyTab":true,"purchases":true,"purchaseAnalytics":true,"purchaseOrders":true}'),
 ('00000000-0000-4000-8000-0000032943b2','Empty','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000032943a1','dev',
  '{"moneyTab":true,"purchases":true,"purchaseAnalytics":true,"purchaseOrders":true}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000032943c1','00000000-0000-4000-8000-0000032943b1','00000000-0000-4000-8000-0000032943a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000032943c2','00000000-0000-4000-8000-0000032943b1','00000000-0000-4000-8000-0000032943a2',false,false,'active'),
 ('00000000-0000-4000-8000-0000032943c3','00000000-0000-4000-8000-0000032943b2','00000000-0000-4000-8000-0000032943a1',true,true,'active');
insert into public.suppliers (id, workspace_id, supplier_number, name, status) values
 ('00000000-0000-4000-8000-0000032943f1','00000000-0000-4000-8000-0000032943b1','1','Alpha','active'),
 ('00000000-0000-4000-8000-0000032943f2','00000000-0000-4000-8000-0000032943b1','2','Beta','active'),
 ('00000000-0000-4000-8000-0000032943f3','00000000-0000-4000-8000-0000032943b1','3','Gamma','active');

create function pg_temp.o(n int, supplier int, state text, sent date, expected date) returns void language sql as $$
  insert into public.purchase_orders (id, workspace_id, year, number, supplier_id, state, currency, expected_on,
                                      created_by_member_id, sent_at, sent_via, cancelled_at)
  values (('00000000-0000-4000-8000-00000329430'||n)::uuid, '00000000-0000-4000-8000-0000032943b1', 2025, n,
          ('00000000-0000-4000-8000-0000032943f'||supplier)::uuid, state, 'EUR', expected,
          '00000000-0000-4000-8000-0000032943c1',
          case when sent is null then null else (sent::timestamp + interval '10 hours') at time zone 'Europe/Paris' end,
          case when sent is null then null else 'print' end,
          case when state = 'cancelled' then now() end);
$$;
select pg_temp.o(1, 1, 'received', date '2025-03-05', date '2025-03-20');
select pg_temp.o(2, 1, 'received', date '2025-03-06', date '2025-03-15');
select pg_temp.o(3, 2, 'partly_received', date '2025-03-07', date '2025-03-20');
select pg_temp.o(4, 2, 'sent', date '2025-03-08', date '2025-03-10');
select pg_temp.o(5, 3, 'sent', date '2025-03-09', date '2099-01-01');
select pg_temp.o(6, 3, 'received', date '2025-03-10', null);
select pg_temp.o(7, 3, 'cancelled', date '2025-03-11', date '2025-03-30');
select pg_temp.o(8, 1, 'draft', null, date '2025-03-30');
select pg_temp.o(9, 1, 'sent', date '2025-04-02', date '2025-04-20');
insert into public.purchase_order_receipts (workspace_id, order_id, received_on, actor_member_id)
select '00000000-0000-4000-8000-0000032943b1', ('00000000-0000-4000-8000-00000329430'||r.o)::uuid, r.d,
       '00000000-0000-4000-8000-0000032943c1'
  from (values (1, date '2025-03-18'), (2, date '2025-03-25'), (3, date '2025-03-12'), (6, date '2025-03-15')) r(o, d);

create function pg_temp.read(p_user text, p_ws text) returns jsonb language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', ('00000000-0000-4000-8000-0000032943' || p_user)::uuid, 'role', 'authenticated')::text, true);
  return public.kpi_vendor_quality(('00000000-0000-4000-8000-0000032943' || p_ws)::uuid, '2025-03', '2025-03');
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

set local role authenticated;
select set_config('t.r', pg_temp.read('a1', 'b1')::text, true);
create function pg_temp.d() returns jsonb language sql as $$ select current_setting('t.r')::jsonb -> 'delivery' $$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select is(pg_temp.d() ->> 'orders', '6', 'six orders were sent in the month: a cancelled one, a draft and an April one are not among them');
select is(pg_temp.d() -> 'cohorts',
          '{"on_time": 1, "late": 1, "unknown_expected": 1, "partial": 1, "overdue": 1, "open": 1}'::jsonb,
          'each order lands in exactly one cohort');
select is(pg_temp.d() ->> 'median_lead_days', '13', 'the median days from sending to the last receipt');
select is(pg_temp.d() ->> 'p90_lead_days', '19', 'the 90th percentile of the lead time');
select is(pg_temp.d() ->> 'median_delay_days', '-2', 'the median delay against the expected date (negative = early)');
select is(pg_temp.d() ->> 'p90_delay_days', '10', 'the 90th percentile of the delay');
select is((select string_agg((r ->> 'name') || ':' || (r ->> 'orders') || '/' || (r ->> 'on_time') || '/' || (r ->> 'late') || '/' || coalesce(r ->> 'median_lead_days', '-'), ', ' order by n)
             from jsonb_array_elements(pg_temp.d() -> 'rows') with ordinality t(r, n)),
          'Alpha:2/1/1/13, Beta:2/0/0/-, Gamma:2/0/0/5', 'by supplier: orders, on time, late, the median lead time');
select ok(not (current_setting('t.r')::jsonb -> 'reasons') ? 'purchase_orders_off', 'with purchaseOrders on, no reason says it is off');
select ok(current_setting('t.r')::jsonb ? 'billing_lag' and current_setting('t.r')::jsonb ? 'payment' and current_setting('t.r')::jsonb ? 'spend',
          'the figures of 0673 are still in the answer');
select is(pg_temp.read('a1', 'b2') -> 'delivery' -> 'cohorts' ->> 'on_time', '0', 'a space with no orders has zero in every cohort');
select throws_ok($$select pg_temp.read('a2', 'b1')$$, '42501', null, 'a plain member reads nothing');
reset role;
update public.workspaces set feature_flags = feature_flags || '{"purchaseOrders": false}'::jsonb
 where id = '00000000-0000-4000-8000-0000032943b1';
set local role authenticated;
select ok((pg_temp.read('a1', 'b1') -> 'reasons') ? 'purchase_orders_off', 'with purchaseOrders off the reason says so');
select ok((select (public.kpi_registry() -> 'vendors.delivery' ->> 'unit') = 'percent'), 'the registry carries the figure');

select * from finish();
rollback;
