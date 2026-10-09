-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1285: execute the runbook preflight itself, including its intentional abort.
-- This is a privileged operator preflight with an owner identity for the
-- configuration export gate, not an RLS test. All fixtures roll back.
select plan(14);
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
 values ('00000000-0000-4000-8000-000000128501','00000000-0000-0000-0000-000000000000',
         'authenticated','authenticated','alignment@rehearsal.invalid','',now(),now(),now());
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000128501","role":"authenticated"}', true);
select set_config('alignment.workspace_id', public.create_workspace(
  'Alignment rehearsal', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select set_config('alignment.backend_system_id', (select system_identifier::text from pg_control_system()), true);
set local alignment.environment = 'dev';
set local alignment.twin_id = 'none';
set local alignment.template_key = 'association_fr';
set local alignment.groups = 'wording';
set local alignment.plan_ids = 'none';
set local alignment.package_ids = 'none';
set local alignment.desk_level_id = '00000000-0000-4000-8000-000000128512';
set local alignment.desk_ids = '00000000-0000-4000-8000-000000128532';
set local alignment.holiday_plan = 'skip';
-- The retired parameter is deliberately absent: an old packet must not
-- silently change a level instead of a table.
insert into public.levels(id,workspace_id,name,sort_order,bookable_as_whole)
 select ('00000000-0000-4000-8000-00000012851' || n)::uuid,
        current_setting('alignment.workspace_id')::uuid, 'Floor ' || n, n, true
 from generate_series(1,2) n;
insert into public.offices(id,workspace_id,level_id,name,bookable_as_whole,x,y,w,h)
 select ('00000000-0000-4000-8000-00000012852' || n)::uuid,
        current_setting('alignment.workspace_id')::uuid,
        ('00000000-0000-4000-8000-00000012851' || n)::uuid, 'Room ' || n, true, 0,0,30,30
 from generate_series(1,2) n;
insert into public.desks(id,workspace_id,office_id,name,bookable_as_whole,x,y,w,h)
 select ('00000000-0000-4000-8000-00000012853' || n)::uuid,
        current_setting('alignment.workspace_id')::uuid,
        ('00000000-0000-4000-8000-00000012852' || n)::uuid, 'Table ' || n, true, 0,0,10,10
 from generate_series(1,2) n;
insert into public.reservations(workspace_id,member_id,level_id,starts_at,ends_at,status,space_label)
 select workspace_id,id,'00000000-0000-4000-8000-000000128512',
        '2026-09-07 09:00+02','2026-09-07 12:00+02','completed','Synthetic table'
 from public.members where workspace_id = current_setting('alignment.workspace_id')::uuid;
insert into public.ledger_entries(workspace_id,member_id,kind,category,amount_cents,description,period)
 select workspace_id,id,'credit','payment',1000,'Synthetic payment','2026-09'
 from public.members where workspace_id = current_setting('alignment.workspace_id')::uuid;
insert into public.invoices(workspace_id,member_id,issuer_member_id,number,title,lines,total_cents,
 currency,member_name,workspace_name,issuer_name,signature,period)
 select workspace_id,id,id,'REHEARSAL-1','Synthetic invoice','[]',0,'EUR',
        'Synthetic member','Synthetic workspace','Synthetic issuer','rehearsal','2026-09'
 from public.members where workspace_id = current_setting('alignment.workspace_id')::uuid;
create temp table alignment_before as select pg_temp.alignment_report() as report;
select ok(not (report ? 'error'), 'the corrected desk packet is reviewable') from alignment_before;
select ok((report#>>'{protected,members,rows}')::int > 0
 and (report#>>'{protected,reservations,rows}')::int > 0
 and (report#>>'{protected,invoices,rows}')::int > 0
 and (report#>>'{protected,ledger_entries,rows}')::int > 0,
 'protected-content comparisons have populated fixtures') from alignment_before;
select is((select d->>'action' from alignment_before, jsonb_array_elements(report->'desks') d
 where d->>'id' = '00000000-0000-4000-8000-000000128532'), 'set false', 'the exact table is proposed');
select is((select d->>'action' from alignment_before, jsonb_array_elements(report->'desks') d
 where d->>'id' = '00000000-0000-4000-8000-000000128531'), 'preserved', 'the other floor table stays unchanged');
select ok((select bool_and(l->>'action' = 'preserved') from alignment_before,
 jsonb_array_elements(report->'levels') l), 'every whole-level policy stays unchanged');
set local alignment.desk_ids = '00000000-0000-4000-8000-000000128531';
select ok(pg_temp.alignment_report()->>'error' like 'PREFLIGHT STOP%', 'a table on the wrong floor is refused');
set local alignment.desk_ids = '00000000-0000-4000-8000-000000128599';
select ok(pg_temp.alignment_report()->>'error' like 'PREFLIGHT STOP%', 'an unknown table is refused');
-- A real foreign desk, not merely an absent UUID.
select set_config('alignment.foreign_ws', public.create_workspace(
 'Other rehearsal', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select public.apply_workspace_template(current_setting('alignment.foreign_ws')::uuid,
 (select id from public.workspace_templates where key = 'tiny'));
select set_config('alignment.desk_ids', (select id::text from public.desks
 where workspace_id = current_setting('alignment.foreign_ws')::uuid order by id limit 1), true);
select ok(pg_temp.alignment_report()->>'error' like 'PREFLIGHT STOP%', 'a real foreign table is refused');
set local alignment.desk_ids = '00000000-0000-4000-8000-000000128532';
set local alignment.environment = 'prod';
select ok(pg_temp.alignment_report()->>'error' like 'PREFLIGHT STOP%', 'the environment check remains enforced');
set local alignment.environment = 'dev';
set local alignment.level_ids = '00000000-0000-4000-8000-000000128512';
select ok(pg_temp.alignment_report()->>'error' like '%level_ids is retired%', 'an old whole-level packet is refused');
set local alignment.level_ids = '';
set local alignment.desk_ids = '';
select ok(pg_temp.alignment_report()->>'error' like '%parameters not set: desk_ids%', 'a missing desk decision stops');
set local alignment.desk_ids = '00000000-0000-4000-8000-000000128532';
-- The reviewed operation: the workspace and floor are both explicit.
update public.desks d set bookable_as_whole = false
 where d.workspace_id = current_setting('alignment.workspace_id')::uuid
   and d.id = any (string_to_array(current_setting('alignment.desk_ids'), ',')::uuid[])
   and exists (select 1 from public.offices o where o.id = d.office_id
     and o.workspace_id = d.workspace_id
     and o.level_id = current_setting('alignment.desk_level_id')::uuid)
   and d.bookable_as_whole;
select ok(not (pg_temp.alignment_report() ? 'error'), 'readback accepts the already-disabled table');
select is(pg_temp.alignment_report()->'protected', (select report->'protected' from alignment_before),
 'protected contents and relationships are unchanged');
select ok((select bool_and(bookable_as_whole) from public.levels
 where workspace_id = current_setting('alignment.workspace_id')::uuid)
 and (select bool_and(bookable_as_whole) from public.offices
 where workspace_id = current_setting('alignment.workspace_id')::uuid)
 and (select bookable_as_whole from public.desks where id = '00000000-0000-4000-8000-000000128531'),
 'the operation preserves floor, room and unrelated table policies');
