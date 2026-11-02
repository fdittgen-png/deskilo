-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3070: only an eligible approver reads the exact recorded rate.
begin;
select plan(24);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
('00000000-0000-4000-8000-0000000036a1','00000000-0000-0000-0000-000000000000','authenticated','authenticated','repro36a1@deskilo.test','',now(),now(),now()),
('00000000-0000-4000-8000-0000000036a2','00000000-0000-0000-0000-000000000000','authenticated','authenticated','repro36a2@deskilo.test','',now(),now(),now());
insert into public.workspaces (id,name,country_code,currency_code,timezone,created_by,feature_flags,role_permissions) values
('00000000-0000-4000-8000-0000000036a3','Approval repro','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000000036a1','{"moneyTab":true,"purchases":true,"configurableSettings":true}','{"member":["approveExpenses"]}');
insert into public.members (id,workspace_id,user_id,is_owner,is_admin,status,joined_at) values
('00000000-0000-4000-8000-0000000036a4','00000000-0000-4000-8000-0000000036a3','00000000-0000-4000-8000-0000000036a1',true,true,'active',now()),
('00000000-0000-4000-8000-0000000036a5','00000000-0000-4000-8000-0000000036a3','00000000-0000-4000-8000-0000000036a2',false,false,'active',now());
insert into public.suppliers (id,workspace_id,supplier_number,name) values ('00000000-0000-4000-8000-0000000036a6','00000000-0000-4000-8000-0000000036a3','1','Repro supplier');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values ('00000000-0000-4000-8000-0000000036a8','00000000-0000-0000-0000-000000000000','authenticated','authenticated','repro36a8@deskilo.test','',now(),now(),now());
update public.workspaces set role_permissions='{"member":["approveExpenses"],"admin":[]}' where id='00000000-0000-4000-8000-0000000036a3';
insert into public.members (id,workspace_id,user_id,is_owner,is_admin,status,joined_at)
values ('00000000-0000-4000-8000-0000000036a9','00000000-0000-4000-8000-0000000036a3','00000000-0000-4000-8000-0000000036a8',false,true,'active',now());
insert into public.purchase_documents (id,workspace_id,kind,state,currency,supplier_id,submitter_member_id,submitted_by_member_id,payer_kind) values
('00000000-0000-4000-8000-0000000036b1','00000000-0000-4000-8000-0000000036a3','bill','draft','CHF','00000000-0000-4000-8000-0000000036a6','00000000-0000-4000-8000-0000000036a4','00000000-0000-4000-8000-0000000036a4','unpaid'),
('00000000-0000-4000-8000-0000000036b2','00000000-0000-4000-8000-0000000036a3','bill','draft','CHF','00000000-0000-4000-8000-0000000036a6','00000000-0000-4000-8000-0000000036a4','00000000-0000-4000-8000-0000000036a4','unpaid'),
('00000000-0000-4000-8000-0000000036b3','00000000-0000-4000-8000-0000000036a3','bill','draft','EUR','00000000-0000-4000-8000-0000000036a6','00000000-0000-4000-8000-0000000036a4','00000000-0000-4000-8000-0000000036a4','unpaid'),
('00000000-0000-4000-8000-0000000036b4','00000000-0000-4000-8000-0000000036a3','bill','draft','CHF','00000000-0000-4000-8000-0000000036a6','00000000-0000-4000-8000-0000000036a5','00000000-0000-4000-8000-0000000036a5','unpaid');
insert into public.purchase_lines (workspace_id,purchase_id,line_no,gross_cents)
select '00000000-0000-4000-8000-0000000036a3',id,1,50 from public.purchase_documents where id in ('00000000-0000-4000-8000-0000000036b1','00000000-0000-4000-8000-0000000036b2','00000000-0000-4000-8000-0000000036b3','00000000-0000-4000-8000-0000000036b4');
insert into public.document_exchange_rates (workspace_id,document_kind,document_id,currency,functional_currency,rate,rate_date,source)
values ('00000000-0000-4000-8000-0000000036a3','purchase','00000000-0000-4000-8000-0000000036b1','CHF','EUR',1.0456789012,'2026-11-02','bank');
update public.purchase_documents set state='pending' where id in ('00000000-0000-4000-8000-0000000036b1','00000000-0000-4000-8000-0000000036b2','00000000-0000-4000-8000-0000000036b3','00000000-0000-4000-8000-0000000036b4');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000036a2","role":"authenticated"}',true);
set local role authenticated;
select is(public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000036a3','00000000-0000-4000-8000-0000000036b1')#>>'{fx,status}','recorded','eligible approver sees recorded FX');
select is((select array_agg(k order by k) from jsonb_object_keys(public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000036a3','00000000-0000-4000-8000-0000000036b1')) k),array['can_approve','can_reject','detail','fx']::text[],'response has exact top-level allowlist');
select is(public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000036a3','00000000-0000-4000-8000-0000000036b1')#>>'{fx,rate}','1.0456789012','exact decimal text is preserved');
select is((select array_agg(k order by k) from jsonb_object_keys(public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000036a3','00000000-0000-4000-8000-0000000036b1')->'fx') k),array['currency','functional_currency','rate','rate_date','source','status']::text[],'recorded fields are exactly allowlisted');
select is(public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000036a3','00000000-0000-4000-8000-0000000036b1')#>>'{fx,currency}','CHF','original currency');
select is(public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000036a3','00000000-0000-4000-8000-0000000036b1')#>>'{fx,functional_currency}','EUR','recorded functional currency');
select is(public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000036a3','00000000-0000-4000-8000-0000000036b1')#>>'{fx,source}','bank','recorded source');
select is(public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000036a3','00000000-0000-4000-8000-0000000036b1')#>>'{fx,rate_date}','2026-11-02','recorded date');
select is(public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000036a3','00000000-0000-4000-8000-0000000036b2')#>>'{fx,status}','missing','foreign bill with no record is missing');
select is(public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000036a3','00000000-0000-4000-8000-0000000036b3')#>>'{fx,status}','same_currency','same currency is explicitly established');
select is((select array_agg(k order by k) from jsonb_object_keys(public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000036a3','00000000-0000-4000-8000-0000000036b2')->'fx') k),array['currency','functional_currency','status']::text[],'missing fields are exactly allowlisted');
select is((select array_agg(k order by k) from jsonb_object_keys(public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000036a3','00000000-0000-4000-8000-0000000036b3')->'fx') k),array['currency','functional_currency','status']::text[],'same-currency fields are exactly allowlisted');
select is((select count(*)::int from public.document_exchange_rates where document_id='00000000-0000-4000-8000-0000000036b1'),0,'approver gains no broad rate table access');
select throws_ok($$select public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000036a3','00000000-0000-4000-8000-0000000036b4')$$,'42501','purchase approval is not available','own bill at default threshold denied');
select throws_ok($$select public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000036aa','00000000-0000-4000-8000-0000000036b1')$$,'42501','purchase approvals are not available','other workspace denied');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000036a8","role":"authenticated"}',true);
select throws_ok($$select public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000036a3','00000000-0000-4000-8000-0000000036b1')$$,'42501','purchase approvals are not available','different active actor without permission denied');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000036a2","role":"authenticated"}',true);
reset role;
update public.workspaces set role_permissions='{"member":[]}' where id='00000000-0000-4000-8000-0000000036a3';
set local role authenticated;
select throws_ok($$select public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000036a3','00000000-0000-4000-8000-0000000036b1')$$,'42501','purchase approvals are not available','revoked permission denied');
reset role;
update public.workspaces set role_permissions='{"member":["approveExpenses"]}' where id='00000000-0000-4000-8000-0000000036a3';
update public.members set status='paused' where id='00000000-0000-4000-8000-0000000036a5';
set local role authenticated;
select throws_ok($$select public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000036a3','00000000-0000-4000-8000-0000000036b1')$$,'42501','purchase approvals are not available','inactive member denied');
reset role;
update public.members set status='active' where id='00000000-0000-4000-8000-0000000036a5';
update public.workspaces set feature_flags=feature_flags || '{"purchases":false}' where id='00000000-0000-4000-8000-0000000036a3';
set local role authenticated;
select throws_ok($$select public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000036a3','00000000-0000-4000-8000-0000000036b1')$$,'42501','purchase approvals are not available','feature off denied');
reset role;
update public.workspaces set feature_flags=feature_flags || '{"purchases":true}' where id='00000000-0000-4000-8000-0000000036a3';
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000036a2","role":"authenticated","client_id":"delegated"}',true);
set local role authenticated;
select throws_ok($$select public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000036a3','00000000-0000-4000-8000-0000000036b1')$$,'42501','purchase approvals are not available','delegated actor denied');
reset role;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000036a2","role":"authenticated"}',true);
insert into public.setting_values (scope,workspace_id,key,value) values ('workspace','00000000-0000-4000-8000-0000000036a3','purchase.single_approval_below_units','1');
set local role authenticated;
select is(public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000036a3','00000000-0000-4000-8000-0000000036b4')#>>'{fx,status}','missing','own approval below threshold remains eligible');
reset role;
update public.purchase_documents set state='rejected' where id='00000000-0000-4000-8000-0000000036b2';
set local role authenticated;
select throws_ok($$select public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000036a3','00000000-0000-4000-8000-0000000036b2')$$,'42501','purchase approval is not available','nonpending bill refused');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000036a1","role":"authenticated"}',true);
select is((select count(*)::int from public.document_exchange_rates where document_id='00000000-0000-4000-8000-0000000036b1'),1,'broad reader retains direct FX access');
select is(public.purchase_detail_v1('00000000-0000-4000-8000-0000000036a3','00000000-0000-4000-8000-0000000036b1')->>'currency','CHF','broad purchase detail remains readable');
select * from finish();
rollback;
