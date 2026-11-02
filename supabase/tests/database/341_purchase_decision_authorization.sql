-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3070: the decision write refuses stale authorization without side effects.
begin;
select plan(29);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
('00000000-0000-4000-8000-0000000035a1','00000000-0000-0000-0000-000000000000','authenticated','authenticated','repro35a1@deskilo.test','',now(),now(),now()),
('00000000-0000-4000-8000-0000000035a2','00000000-0000-0000-0000-000000000000','authenticated','authenticated','repro35a2@deskilo.test','',now(),now(),now());
insert into public.workspaces (id,name,country_code,currency_code,timezone,created_by,feature_flags,role_permissions) values
('00000000-0000-4000-8000-0000000035a3','Approval repro','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000000035a1','{"moneyTab":true,"purchases":true,"configurableSettings":true}','{"member":["approveExpenses"]}');
insert into public.members (id,workspace_id,user_id,is_owner,is_admin,status,joined_at) values
('00000000-0000-4000-8000-0000000035a4','00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035a1',true,true,'active',now()),
('00000000-0000-4000-8000-0000000035a5','00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035a2',false,false,'active',now());
-- A custom role supplies the actor's permission in the role-race cases.
insert into public.workspace_roles (id,workspace_id,key,permissions)
values ('00000000-0000-4000-8000-0000000035f1','00000000-0000-4000-8000-0000000035a3','decision_reviewer',array['approveExpenses']);
insert into public.workspace_role_members (workspace_id,role_id,member_id)
values ('00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035f1','00000000-0000-4000-8000-0000000035a5');
insert into public.suppliers (id,workspace_id,supplier_number,name) values ('00000000-0000-4000-8000-0000000035a6','00000000-0000-4000-8000-0000000035a3','1','Repro supplier');
insert into public.purchase_documents (id,workspace_id,kind,state,currency,supplier_id,submitter_member_id,submitted_by_member_id,payer_kind) values
('00000000-0000-4000-8000-0000000035a7','00000000-0000-4000-8000-0000000035a3','bill','draft','EUR','00000000-0000-4000-8000-0000000035a6','00000000-0000-4000-8000-0000000035a4','00000000-0000-4000-8000-0000000035a4','unpaid');

insert into public.purchase_lines (workspace_id,purchase_id,line_no,description,gross_cents) values
('00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035a7',1,'Synthetic goods',120);
update public.purchase_documents set state='pending' where id='00000000-0000-4000-8000-0000000035a7';

-- Source metadata exists but is not part of the scoped approval read.
insert into public.purchase_sources (workspace_id,purchase_id,source_kind,source_id,original_hash,original_reference)
values ('00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035a7','manual',
        '00000000-0000-4000-8000-0000000035b2',repeat('a',64),'synthetic evidence');

insert into public.purchase_documents (id,workspace_id,kind,state,currency,supplier_id,submitter_member_id,submitted_by_member_id,payer_kind) values
('00000000-0000-4000-8000-0000000035a9','00000000-0000-4000-8000-0000000035a3','bill','draft','EUR','00000000-0000-4000-8000-0000000035a6','00000000-0000-4000-8000-0000000035a5','00000000-0000-4000-8000-0000000035a5','unpaid');
insert into public.purchase_lines (workspace_id,purchase_id,line_no,gross_cents) values
('00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035a9',1,50);
update public.purchase_documents set state='pending' where id='00000000-0000-4000-8000-0000000035a9';
insert into public.purchase_documents (id,workspace_id,kind,state,currency,supplier_id,submitter_member_id,submitted_by_member_id,payer_kind) values
('00000000-0000-4000-8000-0000000035af','00000000-0000-4000-8000-0000000035a3','bill','draft','EUR','00000000-0000-4000-8000-0000000035a6','00000000-0000-4000-8000-0000000035a4','00000000-0000-4000-8000-0000000035a5','unpaid');
insert into public.purchase_lines (workspace_id,purchase_id,line_no,gross_cents) values
('00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035af',1,100);
update public.purchase_documents set state='pending' where id='00000000-0000-4000-8000-0000000035af';
insert into public.purchase_documents (id,workspace_id,kind,state,currency,supplier_id,submitter_member_id,submitted_by_member_id,payer_kind) values
('00000000-0000-4000-8000-0000000035b1','00000000-0000-4000-8000-0000000035a3','bill','draft','EUR','00000000-0000-4000-8000-0000000035a6','00000000-0000-4000-8000-0000000035a5','00000000-0000-4000-8000-0000000035a4','unpaid');
insert into public.purchase_lines (workspace_id,purchase_id,line_no,gross_cents) values
('00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035b1',1,150);
update public.purchase_documents set state='pending' where id='00000000-0000-4000-8000-0000000035b1';
insert into public.purchase_documents (id,workspace_id,kind,state,currency,supplier_id,submitter_member_id,submitted_by_member_id,payer_kind) values
('00000000-0000-4000-8000-0000000035ab','00000000-0000-4000-8000-0000000035a3','bill','draft','EUR','00000000-0000-4000-8000-0000000035a6','00000000-0000-4000-8000-0000000035a5','00000000-0000-4000-8000-0000000035a5','unpaid');
insert into public.purchase_lines (workspace_id,purchase_id,line_no,gross_cents) values
('00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035ab',1,100);
update public.purchase_documents set state='pending' where id='00000000-0000-4000-8000-0000000035ab';
insert into public.purchase_documents (id,workspace_id,kind,state,currency,submitter_member_id,payer_kind,payer_member_id) values
('00000000-0000-4000-8000-0000000035ac','00000000-0000-4000-8000-0000000035a3','member_receipt','pending','EUR','00000000-0000-4000-8000-0000000035a4','member','00000000-0000-4000-8000-0000000035a4');
-- Separate pending bills for the isolated two-session ordering proof.
insert into public.purchase_documents (id,workspace_id,kind,state,currency,supplier_id,submitter_member_id,submitted_by_member_id,payer_kind)
select id,'00000000-0000-4000-8000-0000000035a3','bill','draft','EUR','00000000-0000-4000-8000-0000000035a6',
       '00000000-0000-4000-8000-0000000035a4','00000000-0000-4000-8000-0000000035a4','unpaid'
from unnest(array['00000000-0000-4000-8000-0000000035d1'::uuid,
                  '00000000-0000-4000-8000-0000000035d2'::uuid,
                  '00000000-0000-4000-8000-0000000035d4'::uuid,
                  '00000000-0000-4000-8000-0000000035d5'::uuid,
                  '00000000-0000-4000-8000-0000000035d6'::uuid,
                  '00000000-0000-4000-8000-0000000035d7'::uuid,
                  '00000000-0000-4000-8000-0000000035d8'::uuid]) id;
insert into public.purchase_lines (workspace_id,purchase_id,line_no,gross_cents)
select '00000000-0000-4000-8000-0000000035a3',id,1,120 from public.purchase_documents
where id in ('00000000-0000-4000-8000-0000000035d1','00000000-0000-4000-8000-0000000035d2','00000000-0000-4000-8000-0000000035d4',
             '00000000-0000-4000-8000-0000000035d5','00000000-0000-4000-8000-0000000035d6',
             '00000000-0000-4000-8000-0000000035d7','00000000-0000-4000-8000-0000000035d8');
update public.purchase_documents set state='pending'
where id in ('00000000-0000-4000-8000-0000000035d1','00000000-0000-4000-8000-0000000035d2','00000000-0000-4000-8000-0000000035d4',
             '00000000-0000-4000-8000-0000000035d5','00000000-0000-4000-8000-0000000035d6',
             '00000000-0000-4000-8000-0000000035d7','00000000-0000-4000-8000-0000000035d8');

insert into public.purchase_documents (id,workspace_id,kind,state,currency,supplier_id,submitter_member_id,submitted_by_member_id,payer_kind)
values ('00000000-0000-4000-8000-0000000035d3','00000000-0000-4000-8000-0000000035a3','bill','draft','EUR','00000000-0000-4000-8000-0000000035a6','00000000-0000-4000-8000-0000000035a5','00000000-0000-4000-8000-0000000035a5','unpaid');
insert into public.purchase_lines (workspace_id,purchase_id,line_no,gross_cents)
values ('00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035d3',1,120);
update public.purchase_documents set state='pending' where id='00000000-0000-4000-8000-0000000035d3';

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000035a2","role":"authenticated"}',true);
set local role authenticated;
select is(public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035a7')->>'can_reject','true','stale client initially reads an eligible action');
reset role;
update public.workspaces set feature_flags=feature_flags || '{"purchases":false}' where id='00000000-0000-4000-8000-0000000035a3';
set local role authenticated;
select throws_ok($$select public.decide_purchase_v1('00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035a7',1,false,'No','00000000-0000-4000-8000-0000000035c1')$$,'42501','purchase decision is not available','feature off refuses stale decision');
reset role;
select is((select state::text from public.purchase_documents where id='00000000-0000-4000-8000-0000000035a7'),'pending','feature refusal leaves bill pending');
select is((select count(*)::int from public.purchase_requests where workspace_id='00000000-0000-4000-8000-0000000035a3'),0,'feature refusal leaves no request');
select is((select count(*)::int from public.purchase_obligations where workspace_id='00000000-0000-4000-8000-0000000035a3'),0,'feature refusal leaves no obligation');
update public.workspaces set feature_flags=feature_flags || '{"purchases":true,"moneyTab":false}' where id='00000000-0000-4000-8000-0000000035a3';
set local role authenticated;
select throws_ok($$select public.decide_purchase_v1('00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035a7',1,false,'No','00000000-0000-4000-8000-0000000035ce')$$,'42501','purchase decision is not available','disabled moneyTab parent refuses decision');
reset role;

update public.workspaces set feature_flags=feature_flags || '{"purchases":true,"moneyTab":true}', role_permissions='{"member":[]}' where id='00000000-0000-4000-8000-0000000035a3';
set local role authenticated;
select throws_ok($$select public.decide_purchase_v1('00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035a7',1,false,'No','00000000-0000-4000-8000-0000000035c2')$$,'42501','purchase decision is not available','permission removal refuses stale decision');
reset role;
update public.workspaces set role_permissions='{"member":["approveExpenses"]}' where id='00000000-0000-4000-8000-0000000035a3';
update public.members set status='paused' where id='00000000-0000-4000-8000-0000000035a5';
set local role authenticated;
select throws_ok($$select public.decide_purchase_v1('00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035a7',1,false,'No','00000000-0000-4000-8000-0000000035c3')$$,'42501','purchase decision is not available','inactive member refused');
reset role;
update public.members set status='active' where id='00000000-0000-4000-8000-0000000035a5';
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000035a2","role":"authenticated","client_id":"delegated"}',true);
set local role authenticated;
select throws_ok($$select public.decide_purchase_v1('00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035a7',1,false,'No','00000000-0000-4000-8000-0000000035c4')$$,'42501','purchase decision is not available','delegated actor refused');
reset role;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000035a2","role":"authenticated"}',true);
set local role authenticated;
select throws_ok($$select public.decide_purchase_v1('00000000-0000-4000-8000-0000000035aa','00000000-0000-4000-8000-0000000035a7',1,false,'No','00000000-0000-4000-8000-0000000035c5')$$,'42501','purchase decision is not available','other tenant refused');
select throws_ok($$select public.decide_purchase_v1('00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035a9',1,true,'','00000000-0000-4000-8000-0000000035c6')$$,'P0001','another person must decide a purchase you submitted','default zero still refuses own approval');
select throws_ok($$select public.decide_purchase_v1('00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035a7',2,false,'No','00000000-0000-4000-8000-0000000035cd')$$,'P0001','stale revision','stale revision is still refused');
select throws_ok($$select public.decide_purchase_v1('00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035ac',1,true,'','00000000-0000-4000-8000-0000000035cc')$$,'P0001','only a supplier bill is decided here','receipt decision remains on event path');

reset role;
select is((select state::text from public.purchase_documents where id='00000000-0000-4000-8000-0000000035a7'),'pending','all denied attempts preserve the pending bill');
select is((select count(*)::int from public.purchase_requests where workspace_id='00000000-0000-4000-8000-0000000035a3'),0,'denied attempts create no request receipts');
select is((select count(*)::int from public.purchase_obligations where workspace_id='00000000-0000-4000-8000-0000000035a3'),0,'denied attempts create no obligations');
insert into public.setting_values (scope,workspace_id,key,value) values ('workspace','00000000-0000-4000-8000-0000000035a3','purchase.single_approval_below_units','1');
set local role authenticated;
select throws_ok($$select public.decide_purchase_v1('00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035af',1,true,'','00000000-0000-4000-8000-0000000035c7')$$,'P0001','another person must decide a purchase you submitted','sender at threshold refused');
select throws_ok($$select public.decide_purchase_v1('00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035b1',1,true,'','00000000-0000-4000-8000-0000000035c8')$$,'P0001','another person must decide a purchase you submitted','drafter above threshold refused');
select throws_ok($$select public.decide_purchase_v1('00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035a9',1,false,'No','00000000-0000-4000-8000-0000000035c9')$$,'P0001','another person must decide a purchase you submitted','own rejection still refused');
select is(public.decide_purchase_v1('00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035a9',1,true,'','00000000-0000-4000-8000-0000000035ca')->>'state','approved','below threshold own approval preserved');
select is(public.decide_purchase_v1('00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035a7',1,false,'No','00000000-0000-4000-8000-0000000035cb')->>'state','rejected','other-maker decision succeeds after recovery');
select is(public.decide_purchase_v1('00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035a7',1,false,'No','00000000-0000-4000-8000-0000000035cb')->>'state','rejected','same request replay remains idempotent');
reset role;
update public.workspaces set feature_flags=feature_flags || '{"purchases":false}' where id='00000000-0000-4000-8000-0000000035a3';
set local role authenticated;
select throws_ok($$select public.decide_purchase_v1('00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035a7',1,false,'No','00000000-0000-4000-8000-0000000035cb')$$,'42501','purchase decision is not available','replay is refused after authorization is revoked');
reset role;
update public.workspaces set feature_flags=feature_flags || '{"purchases":true}' where id='00000000-0000-4000-8000-0000000035a3';
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000035a1","role":"authenticated"}',true);
set local role authenticated;
select is(public.decide_purchase_v1('00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035d3',1,true,'','00000000-0000-4000-8000-0000000035cf')->>'state','approved','owner wide permission retains non-maker approval');
reset role;
update public.workspaces set feature_flags=feature_flags || '{"customRoles":true}', role_permissions='{"member":[]}' where id='00000000-0000-4000-8000-0000000035a3';
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000035a2","role":"authenticated"}',true);
set local role authenticated;
select is(public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035d5')->>'can_reject','true','custom role grants a decision');
reset role;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000035a1","role":"authenticated"}',true);
set local role authenticated;
select public.assign_workspace_role('00000000-0000-4000-8000-0000000035a5','00000000-0000-4000-8000-0000000035f1',false);
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000035a2","role":"authenticated"}',true);
select throws_ok($$select public.decide_purchase_v1('00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035d5',1,false,'No','00000000-0000-4000-8000-0000000035d5')$$,'42501','purchase decision is not available','removed custom assignment refuses decision');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000035a1","role":"authenticated"}',true);
select public.assign_workspace_role('00000000-0000-4000-8000-0000000035a5','00000000-0000-4000-8000-0000000035f1',true);
select public.set_workspace_role('00000000-0000-4000-8000-0000000035a3','decision_reviewer',array[]::text[],'{}'::jsonb,0,true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000035a2","role":"authenticated"}',true);
select throws_ok($$select public.decide_purchase_v1('00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035d5',1,false,'No','00000000-0000-4000-8000-0000000035d5')$$,'42501','purchase decision is not available','removed role permission refuses decision');
reset role;
select is((select state::text from public.purchase_documents where id='00000000-0000-4000-8000-0000000035d5'),'pending','custom role refusals preserve bill');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000035a1","role":"authenticated"}',true);
set local role authenticated;
select public.set_workspace_role('00000000-0000-4000-8000-0000000035a3','decision_reviewer',array['approveExpenses']::text[],'{}'::jsonb,0,true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000035a2","role":"authenticated"}',true);
select is(public.decide_purchase_v1('00000000-0000-4000-8000-0000000035a3','00000000-0000-4000-8000-0000000035d5',1,false,'No','00000000-0000-4000-8000-0000000035d5')->>'state','rejected','restored custom role allows decision');
select * from finish();
rollback;
