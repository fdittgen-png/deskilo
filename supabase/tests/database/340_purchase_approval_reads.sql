-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3070: approver-only reads match the supplier decision eligibility and
-- never grant blanket purchase visibility; count and page share a predicate.
begin;
select plan(31);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
('00000000-0000-4000-8000-0000000034a1','00000000-0000-0000-0000-000000000000','authenticated','authenticated','repro34a1@deskilo.test','',now(),now(),now()),
('00000000-0000-4000-8000-0000000034a2','00000000-0000-0000-0000-000000000000','authenticated','authenticated','repro34a2@deskilo.test','',now(),now(),now());
insert into public.workspaces (id,name,country_code,currency_code,timezone,created_by,feature_flags,role_permissions) values
('00000000-0000-4000-8000-0000000034a3','Approval repro','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000000034a1','{"moneyTab":true,"purchases":true,"configurableSettings":true}','{"member":["approveExpenses"]}');
insert into public.members (id,workspace_id,user_id,is_owner,is_admin,status,joined_at) values
('00000000-0000-4000-8000-0000000034a4','00000000-0000-4000-8000-0000000034a3','00000000-0000-4000-8000-0000000034a1',true,true,'active',now()),
('00000000-0000-4000-8000-0000000034a5','00000000-0000-4000-8000-0000000034a3','00000000-0000-4000-8000-0000000034a2',false,false,'active',now());
insert into public.suppliers (id,workspace_id,supplier_number,name) values ('00000000-0000-4000-8000-0000000034a6','00000000-0000-4000-8000-0000000034a3','1','Repro supplier');
insert into public.purchase_documents (id,workspace_id,kind,state,currency,supplier_id,submitter_member_id,submitted_by_member_id,payer_kind) values
('00000000-0000-4000-8000-0000000034a7','00000000-0000-4000-8000-0000000034a3','bill','pending','EUR','00000000-0000-4000-8000-0000000034a6','00000000-0000-4000-8000-0000000034a4','00000000-0000-4000-8000-0000000034a4','unpaid');

insert into public.purchase_documents (id,workspace_id,kind,state,currency,supplier_id,submitter_member_id,submitted_by_member_id,payer_kind) values
('00000000-0000-4000-8000-0000000034a9','00000000-0000-4000-8000-0000000034a3','bill','draft','EUR','00000000-0000-4000-8000-0000000034a6','00000000-0000-4000-8000-0000000034a5','00000000-0000-4000-8000-0000000034a5','unpaid');
insert into public.purchase_lines (workspace_id,purchase_id,line_no,gross_cents) values
('00000000-0000-4000-8000-0000000034a3','00000000-0000-4000-8000-0000000034a9',1,50);
update public.purchase_documents set state='pending' where id='00000000-0000-4000-8000-0000000034a9';
insert into public.purchase_documents (id,workspace_id,kind,state,currency,supplier_id,submitter_member_id,submitted_by_member_id,payer_kind) values
('00000000-0000-4000-8000-0000000034af','00000000-0000-4000-8000-0000000034a3','bill','draft','EUR','00000000-0000-4000-8000-0000000034a6','00000000-0000-4000-8000-0000000034a4','00000000-0000-4000-8000-0000000034a5','unpaid');
insert into public.purchase_lines (workspace_id,purchase_id,line_no,gross_cents) values
('00000000-0000-4000-8000-0000000034a3','00000000-0000-4000-8000-0000000034af',1,100);
update public.purchase_documents set state='pending' where id='00000000-0000-4000-8000-0000000034af';
insert into public.purchase_documents (id,workspace_id,kind,state,currency,supplier_id,submitter_member_id,submitted_by_member_id,payer_kind) values
('00000000-0000-4000-8000-0000000034b1','00000000-0000-4000-8000-0000000034a3','bill','draft','EUR','00000000-0000-4000-8000-0000000034a6','00000000-0000-4000-8000-0000000034a5','00000000-0000-4000-8000-0000000034a4','unpaid');
insert into public.purchase_lines (workspace_id,purchase_id,line_no,gross_cents) values
('00000000-0000-4000-8000-0000000034a3','00000000-0000-4000-8000-0000000034b1',1,150);
update public.purchase_documents set state='pending' where id='00000000-0000-4000-8000-0000000034b1';
insert into public.purchase_documents (id,workspace_id,kind,state,currency,supplier_id,submitter_member_id,submitted_by_member_id,payer_kind) values
('00000000-0000-4000-8000-0000000034ab','00000000-0000-4000-8000-0000000034a3','bill','draft','EUR','00000000-0000-4000-8000-0000000034a6','00000000-0000-4000-8000-0000000034a5','00000000-0000-4000-8000-0000000034a5','unpaid');
insert into public.purchase_lines (workspace_id,purchase_id,line_no,gross_cents) values
('00000000-0000-4000-8000-0000000034a3','00000000-0000-4000-8000-0000000034ab',1,100);
update public.purchase_documents set state='pending' where id='00000000-0000-4000-8000-0000000034ab';
insert into public.purchase_documents (id,workspace_id,kind,state,currency,submitter_member_id,payer_kind,payer_member_id) values
('00000000-0000-4000-8000-0000000034ac','00000000-0000-4000-8000-0000000034a3','member_receipt','pending','EUR','00000000-0000-4000-8000-0000000034a4','member','00000000-0000-4000-8000-0000000034a4');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000034a2","role":"authenticated"}',true);
set local role authenticated;
select is((select count(*)::int from public.purchase_documents where id='00000000-0000-4000-8000-0000000034a7'),0,'approver-only retains no wide table access');
select throws_ok($$select public.purchase_detail_v1('00000000-0000-4000-8000-0000000034a3','00000000-0000-4000-8000-0000000034a7')$$,'P0001','unknown purchase','ordinary detail remains restricted');
select is((public.purchase_approval_page_v1('00000000-0000-4000-8000-0000000034a3')->>'count')::int,1,'only other person bill actionable with default threshold');
select is(public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000034a3','00000000-0000-4000-8000-0000000034a7')->>'can_reject','true','other person bill can be rejected');
select throws_ok($$select public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000034a3','00000000-0000-4000-8000-0000000034a9')$$,'42501','purchase approval is not available','own bill at zero threshold is excluded');
select throws_ok($$select public.purchase_approval_page_v1('00000000-0000-4000-8000-0000000034a3',now(),null)$$,'22023','both cursor fields are required','partial cursor rejected');
select throws_ok($$select public.purchase_approval_page_v1('00000000-0000-4000-8000-0000000034aa')$$,'42501','purchase approvals are not available','other workspace rejected');
reset role;
insert into public.setting_values (scope,workspace_id,key,value) values ('workspace','00000000-0000-4000-8000-0000000034a3','purchase.single_approval_below_units','1');
set local role authenticated;
select is((public.purchase_approval_page_v1('00000000-0000-4000-8000-0000000034a3')->>'count')::int,2,'own bill below threshold is eligible');
select is(public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000034a3','00000000-0000-4000-8000-0000000034a9')->>'can_approve','true','own bill below threshold can be approved');
select is(public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000034a3','00000000-0000-4000-8000-0000000034a9')->>'can_reject','false','own bill cannot be rejected');
select throws_ok($$select public.decide_purchase_v1('00000000-0000-4000-8000-0000000034a3','00000000-0000-4000-8000-0000000034a9',1,false,'No','00000000-0000-4000-8000-0000000034ad')$$,'P0001','another person must decide a purchase you submitted','existing write rejects self rejection');
select throws_ok($$select public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000034a3','00000000-0000-4000-8000-0000000034ab')$$,'42501','purchase approval is not available','own bill equal to threshold excluded');
select throws_ok($$select public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000034a3','00000000-0000-4000-8000-0000000034af')$$,'42501','purchase approval is not available','own sender is excluded at equal threshold even when drafter differs');
select throws_ok($$select public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000034a3','00000000-0000-4000-8000-0000000034b1')$$,'42501','purchase approval is not available','own drafter above threshold is excluded even when sender differs');
select throws_ok($$select public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000034a3','00000000-0000-4000-8000-0000000034ac')$$,'42501','purchase approval is not available','member receipt belongs to validation flow');
select is(public.decide_purchase_v1('00000000-0000-4000-8000-0000000034a3','00000000-0000-4000-8000-0000000034a7',1,false,'Repro','00000000-0000-4000-8000-0000000034a8')->>'state','rejected','existing decision succeeds');
select is((public.purchase_approval_page_v1('00000000-0000-4000-8000-0000000034a3')->>'count')::int,1,'decided bill is no longer counted');
select throws_ok($$select public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000034a3','00000000-0000-4000-8000-0000000034a7')$$,'42501','purchase approval is not available','decided bill no longer exposed');
reset role;
-- Identical timestamps exercise the id tie-breaker and an explicit continuation.
insert into public.purchase_documents (id,workspace_id,kind,state,currency,supplier_id,submitter_member_id,submitted_by_member_id,payer_kind)
select gen_random_uuid(),'00000000-0000-4000-8000-0000000034a3','bill','pending','EUR',
 '00000000-0000-4000-8000-0000000034a6','00000000-0000-4000-8000-0000000034a4',
 '00000000-0000-4000-8000-0000000034a4','unpaid' from generate_series(1,205);
create function pg_temp.approvals_walk() returns int language plpgsql as $$
declare p jsonb; c timestamptz; i uuid; seen uuid[] := '{}'; x jsonb; n int := 0;
begin
 loop
  p := public.purchase_approval_page_v1('00000000-0000-4000-8000-0000000034a3',c,i,50);
  for x in select * from jsonb_array_elements(p->'rows') loop
   if (x->>'id')::uuid = any(seen) then raise exception 'duplicate row'; end if;
   seen := array_append(seen,(x->>'id')::uuid); n := n + 1;
  end loop;
  exit when p->'next' = 'null'::jsonb;
  if n > 500 then raise exception 'cursor did not end'; end if;
  c := (p#>>'{next,created}')::timestamptz; i := (p#>>'{next,id}')::uuid;
 end loop;
 return n;
end $$;
grant execute on function pg_temp.approvals_walk() to authenticated;
set local role authenticated;
select is((public.purchase_approval_page_v1('00000000-0000-4000-8000-0000000034a3',null,null,50)->>'count')::int,206,'count covers all pages');
select isnt(public.purchase_approval_page_v1('00000000-0000-4000-8000-0000000034a3',null,null,50)->'next','null'::jsonb,'first page has continuation');
select is(pg_temp.approvals_walk(),206,'keyset traversal reaches every unique eligible row');
select set_config('t.approval_version',public.purchase_approval_page_v1('00000000-0000-4000-8000-0000000034a3')->>'version',true);
reset role;
update public.purchase_documents set state='rejected' where id=(select id from public.purchase_documents
 where workspace_id='00000000-0000-4000-8000-0000000034a3' and kind='bill' and state='pending'
 and submitter_member_id='00000000-0000-4000-8000-0000000034a4' order by id limit 1);
insert into public.purchase_documents (id,workspace_id,kind,state,currency,supplier_id,submitter_member_id,submitted_by_member_id,payer_kind) values
('00000000-0000-4000-8000-0000000034ae','00000000-0000-4000-8000-0000000034a3','bill','pending','EUR','00000000-0000-4000-8000-0000000034a6','00000000-0000-4000-8000-0000000034a4','00000000-0000-4000-8000-0000000034a4','unpaid');
set local role authenticated;
select is((public.purchase_approval_page_v1('00000000-0000-4000-8000-0000000034a3')->>'count')::int,206,'replacement can preserve the count');
select isnt(public.purchase_approval_page_v1('00000000-0000-4000-8000-0000000034a3')->>'version',current_setting('t.approval_version'),'replacement changes the page version');
select is(public.decide_purchase_v1('00000000-0000-4000-8000-0000000034a3','00000000-0000-4000-8000-0000000034a9',1,true,'','00000000-0000-4000-8000-0000000034b0')->>'state','approved','existing write permits own positive bill strictly below threshold');
reset role;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000034a2","role":"authenticated","client_id":"delegated"}',true);
set local role authenticated;
select throws_ok($$select public.purchase_approval_page_v1('00000000-0000-4000-8000-0000000034a3')$$,'42501','purchase approvals are not available','delegated caller refused');
reset role;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000034a2","role":"authenticated"}',true);
update public.workspaces set role_permissions='{"member":[]}' where id='00000000-0000-4000-8000-0000000034a3';
set local role authenticated;
select throws_ok($$select public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000034a3','00000000-0000-4000-8000-0000000034a9')$$,'42501','purchase approvals are not available','removed permission refuses detail');
reset role;
update public.workspaces set role_permissions='{"member":["approveExpenses"]}' where id='00000000-0000-4000-8000-0000000034a3';
update public.members set status='paused' where id='00000000-0000-4000-8000-0000000034a5';
set local role authenticated;
select throws_ok($$select public.purchase_approval_page_v1('00000000-0000-4000-8000-0000000034a3')$$,'42501','purchase approvals are not available','inactive member cannot read approvals');
reset role;
update public.members set status='active' where id='00000000-0000-4000-8000-0000000034a5';
update public.workspaces set feature_flags=feature_flags || '{"purchases":false}'  where id='00000000-0000-4000-8000-0000000034a3';
set local role authenticated;
select throws_ok($$select public.purchase_approval_page_v1('00000000-0000-4000-8000-0000000034a3')$$,'42501','purchase approvals are not available','feature off refuses page');
select throws_ok($$select public.purchase_approval_detail_v1('00000000-0000-4000-8000-0000000034a3','00000000-0000-4000-8000-0000000034a9')$$,'42501','purchase approvals are not available','feature off refuses detail');
reset role;
select ok(not has_function_privilege('anon','public.purchase_approval_page_v1(uuid,timestamptz,uuid,integer)','execute'),'anonymous cannot execute page');
select ok(not has_function_privilege('anon','public.purchase_approval_detail_v1(uuid,uuid)','execute'),'anonymous cannot execute detail');
select * from finish();
rollback;
