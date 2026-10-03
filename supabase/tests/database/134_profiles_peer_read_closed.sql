-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1833 (checkpoint B): a space mate reads nobody's `profiles` row but
-- their own; other people come through member_profiles (0319). The
-- operational audience (viewPersonalData / issueInvoices in a shared
-- space) still reads the row, an administrator without those does not,
-- revoking the role takes it away, strangers and exited members read
-- nothing. A released client's DIRECT read of a space mate's row
-- (GET /profiles) is refused with PT426 (HTTP 426), while its own row,
-- its own update and a stranger's absent row stay quiet. Outside a
-- PostgREST table read -- Realtime, other policies -- the row is simply
-- not visible. Avatars keep the community audience: space mates read
-- the photo object, strangers and exited members do not.
begin;
select plan(22);

-- a1 owner of b1 · a2 subject · a3 peer · a4 admin without billing
-- permissions · a5 billing clerk (co-owner holding issueInvoices only)
-- · a6 stranger (owner of b3) · a8 exited from b1.
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000001834'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@closed.test','',now(),now(),now()
  from unnest(array['a1','a2','a3','a4','a5','a6','a8']) suffix;
update public.profiles set display_name = 'Closed '||right(id::text,2)
 where id::text like '00000000-0000-4000-8000-0000001834%';
update public.profiles set display_name = 'Subject Person', vat_id = 'VAT-CANARY-1834',
       address = 'ADDRESS-CANARY', phone = 'PHONE-CANARY', email = 'mail-canary@closed.test'
 where id = '00000000-0000-4000-8000-0000001834a2';
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,role_permissions,feature_flags) values
 ('00000000-0000-4000-8000-0000001834b1','Closed one','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001834a1','dev',
  '{"admin":["manageMembers"],"co_owner":["issueInvoices"]}','{"adminInvoicing":false}'),
 ('00000000-0000-4000-8000-0000001834b3','Closed three','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001834a6','dev','{}','{}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,co_owner,status) values
 ('00000000-0000-4000-8000-0000001834c1','00000000-0000-4000-8000-0000001834b1','00000000-0000-4000-8000-0000001834a1',true,true,'none','active'),
 ('00000000-0000-4000-8000-0000001834c2','00000000-0000-4000-8000-0000001834b1','00000000-0000-4000-8000-0000001834a2',false,false,'none','active'),
 ('00000000-0000-4000-8000-0000001834c3','00000000-0000-4000-8000-0000001834b1','00000000-0000-4000-8000-0000001834a3',false,false,'none','active'),
 ('00000000-0000-4000-8000-0000001834c4','00000000-0000-4000-8000-0000001834b1','00000000-0000-4000-8000-0000001834a4',false,true,'none','active'),
 ('00000000-0000-4000-8000-0000001834c5','00000000-0000-4000-8000-0000001834b1','00000000-0000-4000-8000-0000001834a5',false,false,'active','active'),
 ('00000000-0000-4000-8000-0000001834c6','00000000-0000-4000-8000-0000001834b3','00000000-0000-4000-8000-0000001834a6',true,true,'none','active'),
 ('00000000-0000-4000-8000-0000001834c8','00000000-0000-4000-8000-0000001834b1','00000000-0000-4000-8000-0000001834a8',false,false,'none','exited');
insert into storage.objects(bucket_id, name) values ('avatars', '00000000-0000-4000-8000-0000001834a2/avatar');

-- ── the peer a3 ─────────────────────────────────────────────────────
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001834a3","role":"authenticated"}',true);
set local role authenticated;
select is((select count(*)::int from public.profiles where id = '00000000-0000-4000-8000-0000001834a2'),0,'a space mate does not see the subject''s row');
select is((select display_name from public.profiles where id = '00000000-0000-4000-8000-0000001834a3'),'Closed a3','the peer still reads their own row');
select is(public.member_profiles('00000000-0000-4000-8000-0000001834b1',array['00000000-0000-4000-8000-0000001834a2'::uuid])->0->'community'->>'display_name','Subject Person','the space mate still reads the name through the projection');
select is((select count(*)::int from storage.objects where bucket_id = 'avatars' and name = '00000000-0000-4000-8000-0000001834a2/avatar'),1,'and still sees the photo');

-- a released client reading the table directly
select set_config('request.path','/profiles',true);
select set_config('request.method','GET',true);
select throws_ok($$select * from public.profiles where id = '00000000-0000-4000-8000-0000001834a2'$$,'PT426',null,'a direct read of a space mate is refused as Upgrade Required');
select throws_ok($$select id from public.profiles$$,'PT426',null,'so is a read of every row');
select is((select display_name from public.profiles where id = '00000000-0000-4000-8000-0000001834a3'),'Closed a3','the released client''s own profile read still works');
select is((select count(*)::int from public.profiles where id = '00000000-0000-4000-8000-0000001834a6'),0,'a stranger''s row is absent, not refused');
select set_config('request.method','PATCH',true);
select lives_ok($$update public.profiles set status_text = 'Busy' where id = '00000000-0000-4000-8000-0000001834a3'$$,'its own update still works');
select is((select status_text from public.profiles where id = '00000000-0000-4000-8000-0000001834a3'),'Busy','and lands');
select set_config('request.path','',true);
select set_config('request.method','',true);

-- ── the administrator a4 without viewPersonalData / issueInvoices ───
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001834a4","role":"authenticated"}',true);
select is((select count(*)::int from public.profiles where id = '00000000-0000-4000-8000-0000001834a2'),0,'an administrator without the permissions does not see the row');

-- ── the billing clerk a5, the owner a1 ──────────────────────────────
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001834a5","role":"authenticated"}',true);
select is((select vat_id from public.profiles where id = '00000000-0000-4000-8000-0000001834a2'),'VAT-CANARY-1834','the billing clerk still reads the row a released invoice preview needs');
select set_config('request.path','/profiles',true);
select set_config('request.method','GET',true);
select is((select count(*)::int from public.profiles where id = '00000000-0000-4000-8000-0000001834a2'),1,'and is not refused on the direct route');
select set_config('request.path','',true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001834a1","role":"authenticated"}',true);
select is((select address from public.profiles where id = '00000000-0000-4000-8000-0000001834a2'),'ADDRESS-CANARY','the owner reads the row');

-- ── the stranger a6, the exited a8 ──────────────────────────────────
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001834a6","role":"authenticated"}',true);
select is((select count(*)::int from public.profiles where id = '00000000-0000-4000-8000-0000001834a2'),0,'a stranger sees nothing');
select is((select count(*)::int from storage.objects where bucket_id = 'avatars' and name = '00000000-0000-4000-8000-0000001834a2/avatar'),0,'nor the photo');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001834a8","role":"authenticated"}',true);
select is((select count(*)::int from public.profiles where id = '00000000-0000-4000-8000-0000001834a2'),0,'an exited member sees nothing');
select is((select count(*)::int from storage.objects where bucket_id = 'avatars' and name = '00000000-0000-4000-8000-0000001834a2/avatar'),0,'nor the photo');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001834a2","role":"authenticated"}',true);
select is((select count(*)::int from storage.objects where bucket_id = 'avatars' and name = '00000000-0000-4000-8000-0000001834a2/avatar'),1,'the subject sees their own photo');

-- ── revoking the clerk's role takes the row away ────────────────────
reset role;
update public.members set co_owner = 'none' where id = '00000000-0000-4000-8000-0000001834c5';
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001834a5","role":"authenticated"}',true);
set local role authenticated;
select is((select count(*)::int from public.profiles where id = '00000000-0000-4000-8000-0000001834a2'),0,'the clerk whose role was withdrawn no longer sees the row');

reset role;
select is((select vat_id from public.profiles where id = '00000000-0000-4000-8000-0000001834a2'),'VAT-CANARY-1834','the row itself is unchanged');
select ok(not has_function_privilege('anon','public.profile_row_readable(uuid)','execute'),'anonymous callers cannot call the reading rule');

select * from finish();
rollback;
