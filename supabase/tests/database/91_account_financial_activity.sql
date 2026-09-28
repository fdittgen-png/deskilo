-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1791: account history spans own workspaces without granting co-member
-- finances; settled payments are shown once and currencies remain explicit.
begin;
select plan(12);
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000000301'||suffix)::uuid,
 '00000000-0000-0000-0000-000000000000','authenticated','authenticated',suffix||'@activity.test','',now(),now(),now()
from unnest(array['a1','a2']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment)
values('00000000-0000-4000-8000-0000000301b1','Euro office','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000000301a2','dev'),
('00000000-0000-4000-8000-0000000301b2','Dollar office','US','USD','America/New_York','00000000-0000-4000-8000-0000000301a2','dev');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status)
values('00000000-0000-4000-8000-0000000301c1','00000000-0000-4000-8000-0000000301b1','00000000-0000-4000-8000-0000000301a1',false,true,'active'),
('00000000-0000-4000-8000-0000000301c2','00000000-0000-4000-8000-0000000301b2','00000000-0000-4000-8000-0000000301a1',false,false,'exited'),
('00000000-0000-4000-8000-0000000301c3','00000000-0000-4000-8000-0000000301b1','00000000-0000-4000-8000-0000000301a2',true,true,'active');
insert into public.payment_intents(workspace_id,member_id,provider,order_id,period,amount_cents,currency,status)
values('00000000-0000-4000-8000-0000000301b1','00000000-0000-4000-8000-0000000301c1','stripe','activity-pending','2026-09',1200,'EUR','created'),
('00000000-0000-4000-8000-0000000301b2','00000000-0000-4000-8000-0000000301c2','stripe','activity-captured','2026-09',1800,'USD','captured'),
('00000000-0000-4000-8000-0000000301b1','00000000-0000-4000-8000-0000000301c3','stripe','activity-other','2026-09',9900,'EUR','created');
insert into public.ledger_entries(workspace_id,member_id,kind,category,amount_cents,period)
values('00000000-0000-4000-8000-0000000301b2','00000000-0000-4000-8000-0000000301c2','credit','payment',1800,'2026-09');
insert into public.usage_records(workspace_id,member_id,period,reserved_from,reserved_to,counted_minutes,reserved_minutes,space_label)
values('00000000-0000-4000-8000-0000000301b2','00000000-0000-4000-8000-0000000301c2','2026-09','2026-09-20 09:00Z','2026-09-20 10:00Z',60,60,'Quiet desk');
insert into public.invoices(workspace_id,member_id,issuer_member_id,number,title,lines,total_cents,currency,member_name,workspace_name,issuer_name,signature)
values('00000000-0000-4000-8000-0000000301b1','00000000-0000-4000-8000-0000000301c1','00000000-0000-4000-8000-0000000301c3',
 'ACT-OWN','Desk use','[{"label":"Desk","amount_cents":1200}]',1200,'EUR','Me','Euro office','Owner','fixture'),
('00000000-0000-4000-8000-0000000301b1','00000000-0000-4000-8000-0000000301c3','00000000-0000-4000-8000-0000000301c3',
 'ACT-OTHER','Private use','[{"label":"Desk","amount_cents":9900}]',9900,'EUR','Other','Euro office','Owner','fixture');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000301a1","role":"authenticated"}',true);
set local role authenticated;
select is(jsonb_array_length(public.my_financial_activity('payments')),2,'own pending and settled payments; no double-counted capture or co-member payment');
select is((select count(distinct row->>'workspace_id') from jsonb_array_elements(public.my_financial_activity('payments')) row),2::bigint,'account overview spans own workspaces');
select is((select count(distinct row->>'currency') from jsonb_array_elements(public.my_financial_activity('payments')) row),2::bigint,'currencies are not mixed');
select is(public.my_financial_activity('usage')->0->>'minutes','60','departed member retains billable consumption');
select is(public.my_financial_activity('invoices')->0->>'reference','ACT-OWN','own invoice visible even to an admin; other account invoices excluded');
select throws_ok($$select public.my_financial_activity('anything')$$,'P0001','invalid activity kind','unknown views rejected');
select throws_ok($$select public.my_financial_activity('payments',now(),null)$$,'P0001','invalid cursor','partial cursor rejected');
select lives_ok($$select public.set_personal_preferences('{"payment_provider":"stripe"}')$$,'user configures preferred checkout');
select is(public.my_personal_preferences()->'defaults'->>'payment_provider','stripe','saved preference is returned');
select throws_ok($$select public.set_personal_preferences('{"payment_provider":"invented"}')$$,'P0001','invalid preference value','unknown payment provider rejected');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000301a1","role":"authenticated","client_id":"delegated"}',true);
select throws_ok($$select public.my_financial_activity('payments')$$,'P0001',null,'delegated token cannot read personal overview');
reset role;
select set_config('request.jwt.claims','{}',true);
set local role anon;
select throws_ok($$select public.my_financial_activity('payments')$$,'42501',null,'anonymous enumeration denied');
reset role;
select * from finish();
rollback;
