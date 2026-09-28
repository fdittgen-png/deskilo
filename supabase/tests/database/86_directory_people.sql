-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1791: directory identity is not a credential or a workspace membership.
-- Exercise existing signup, invitation and membership paths with real RLS.
begin;
select plan(41);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at)
select ('00000000-0000-4000-8000-0000001791' || suffix)::uuid,
  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  suffix || '@directory.deskilo.test', '', now(), now(), now()
from unnest(array['a1','a2','a3']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment)
select ('00000000-0000-4000-8000-0000001791' || suffix)::uuid,
  'Directory fixture','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001791a1','dev'
from unnest(array['b1','b2']) suffix;
insert into public.members(id,workspace_id,user_id,is_owner,is_admin)
values ('00000000-0000-4000-8000-0000001791c1','00000000-0000-4000-8000-0000001791b1','00000000-0000-4000-8000-0000001791a1',true,true),
('00000000-0000-4000-8000-0000001791c2','00000000-0000-4000-8000-0000001791b1','00000000-0000-4000-8000-0000001791a2',false,false),
('00000000-0000-4000-8000-0000001791c3','00000000-0000-4000-8000-0000001791b2','00000000-0000-4000-8000-0000001791a2',false,false);
select is((select count(*)::int from public.profiles where id::text like '%1791a%' and person_id is not null),3,'signup automatically creates a directory person');
select ok((select person_id <> id from public.profiles where id='00000000-0000-4000-8000-0000001791a2'),'person ID is independent of account ID');
select is((select count(*)::int from public.members where user_id='00000000-0000-4000-8000-0000001791a3'),0,'directory inclusion grants no membership');
select is((select count(distinct person_id)::int from public.members where user_id='00000000-0000-4000-8000-0000001791a2'),1,'one person holds two workspace memberships');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001791a1","role":"authenticated"}',true);
set local role authenticated;
select is(public.my_directory_person(),(select person_id from public.profiles where id=auth.uid()),'caller resolves own directory identity');
select throws_ok($$select * from public.directory_people$$,'42501',null,'directory cannot be enumerated even by a workspace owner');
select throws_ok($$update public.profiles set person_id=gen_random_uuid() where id=auth.uid()$$,'P0001','person identity is immutable','profile cannot change directory identity');
select throws_ok($$update public.members set person_id=gen_random_uuid() where id='00000000-0000-4000-8000-0000001791c2'$$,'P0001','person identity is server managed','workspace owner cannot substitute a person');
select throws_ok($$update public.members set user_id='00000000-0000-4000-8000-0000001791a3' where id='00000000-0000-4000-8000-0000001791c2'$$,'P0001','membership account cannot be reassigned','workspace owner cannot substitute login credentials');
select set_config('deskilo.directory.managed',public.create_managed_member('00000000-0000-4000-8000-0000001791b1','{"first_name":"Managed","email":"private@example.test"}')::text,true);
select ok((select person_id is not null and user_id is null from public.members where id=current_setting('deskilo.directory.managed')::uuid),'unclaimed member has a person without an account');
select set_config('deskilo.directory.old_person',(select person_id::text from public.members where id=current_setting('deskilo.directory.managed')::uuid),true);
select set_config('deskilo.directory.invite',public.create_invitation('00000000-0000-4000-8000-0000001791b1',false,'','',current_setting('deskilo.directory.managed')::uuid),true);
reset role;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001791a3","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($$select public.join_workspace(current_setting('deskilo.directory.invite'))$$,'existing invitation claims the person without a new flow');
reset role;
select is((select person_id from public.members where id=current_setting('deskilo.directory.managed')::uuid),(select person_id from public.profiles where id='00000000-0000-4000-8000-0000001791a3'),'claim links the existing membership to the account person');
select is((select merged_into from public.directory_people where id=current_setting('deskilo.directory.old_person')::uuid),(select person_id from public.profiles where id='00000000-0000-4000-8000-0000001791a3'),'prior directory ID remains a resolvable alias');
set local role anon;
select throws_ok($$select public.my_directory_person()$$,'42501',null,'anonymous requests cannot resolve directory entries');
reset role;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001791a2","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($$select public.set_personal_preferences('{"clock":"24h","theme":"dark"}')$$,'personal defaults save without changing roles');
select is(public.my_personal_preferences('00000000-0000-4000-8000-0000001791b1')->'defaults'->>'clock','24h','workspace starts with personal default');
select lives_ok($$select public.set_personal_preferences('{"clock":"12h"}','00000000-0000-4000-8000-0000001791b1')$$,'member saves a workspace override');
select is(public.my_personal_preferences('00000000-0000-4000-8000-0000001791b1')->'overrides'->>'clock','12h','override is separate from default');
select public.set_personal_preferences('{"preferred_locale":"fr"}','00000000-0000-4000-8000-0000001791b1');
select is((select preferred_locale_override from public.members where id='00000000-0000-4000-8000-0000001791c2'),'fr','document locale follows the member workspace override');
select public.set_personal_preferences('{"preferred_locale":null}','00000000-0000-4000-8000-0000001791b1');
select is((select preferred_locale_override from public.members where id='00000000-0000-4000-8000-0000001791c2'),null::text,'reset document language restores profile inheritance');
select is(public.export_my_data('00000000-0000-4000-8000-0000001791b1')->'personal_preferences'->>'theme','dark','subject export includes personal defaults');
select is(public.export_my_data('00000000-0000-4000-8000-0000001791b1')->'workspace_preferences'->>'clock','12h','subject export includes own workspace override');
select throws_ok($$select public.set_personal_preferences('{"clock":"24h"}',null,'00000000-0000-4000-8000-0000001791a1')$$,'P0001','account changed','a delayed save cannot apply under another account');
select is(public.my_personal_preferences('00000000-0000-4000-8000-0000001791b2')->'overrides','{}'::jsonb,'another workspace keeps inheriting');
select public.set_personal_preferences('{"clock":"auto"}');
select is(public.my_personal_preferences('00000000-0000-4000-8000-0000001791b1')->'overrides'->>'clock','12h','new default does not overwrite explicit choice');
select public.set_personal_preferences('{"clock":null}','00000000-0000-4000-8000-0000001791b1');
select is(public.my_personal_preferences('00000000-0000-4000-8000-0000001791b1')->'overrides','{}'::jsonb,'reset removes override instead of copying a stale default');
select throws_ok($$select public.set_personal_preferences('{"is_owner":true}')$$,'P0001','unknown preference','settings cannot grant workspace authority');
select throws_ok($$select public.set_personal_preferences('{"clock":"bad"}')$$,'P0001','invalid preference value','invalid settings rejected');
select throws_ok($$select public.set_personal_preferences('{"theme":"light"}','00000000-0000-4000-8000-0000001791ff')$$,'P0001','membership unavailable','a person cannot write another workspace');
select throws_ok($$select * from public.member_preference_overrides$$,'42501',null,'workspace members cannot read each other private preferences');
update public.profiles set clock='24h' where id=auth.uid();
select is(public.my_personal_preferences()->'defaults'->>'clock','24h','old client edits still update personal defaults');
reset role;
select set_config('deskilo.directory.deleted_person',(select person_id::text from public.profiles where id='00000000-0000-4000-8000-0000001791a2'),true);
delete from auth.users where id='00000000-0000-4000-8000-0000001791a2';
select is((select count(*)::int from public.members where id in ('00000000-0000-4000-8000-0000001791c2','00000000-0000-4000-8000-0000001791c3') and user_id is null),2,'credential deletion preserves both membership IDs');
select ok(exists(select 1 from public.directory_people where id=current_setting('deskilo.directory.deleted_person')::uuid),'person survives credential deletion');
select is((select count(*)::int from public.profiles where id='00000000-0000-4000-8000-0000001791a2'),0,'credential deletion still removes its private account profile');
delete from public.identity_authority;
select set_config('request.jwt.claims','{"role":"anon"}',true);
set local role anon;
select is(public.public_identity_authority(),null::jsonb,'standalone installation does not advertise federation');
select throws_ok($$select * from public.identity_authority$$,'42501',null,'public discovery does not expose the protected configuration table');
reset role;
insert into public.identity_authority(kind,issuer,oidc_provider)
values ('oidc','https://identity.deskilo.test/auth/v1','custom:deskilo');
set local role anon;
select is(public.public_identity_authority() - 'installation_id',
  '{"kind":"oidc","issuer":"https://identity.deskilo.test/auth/v1","provider":"custom:deskilo"}'::jsonb,
  'signed-out discovery exposes only the configured identity routing metadata');
reset role;
select set_config('request.jwt.claims','{"role":"authenticated","client_id":"delegated"}',true);
set local role authenticated;
select throws_ok($$select public.public_identity_authority()$$,'P0001','native client required','delegated tokens cannot use the native discovery RPC');
reset role;
insert into auth.identities(id,provider_id,user_id,identity_data,provider,created_at,updated_at)
values(gen_random_uuid(),'directory-canonical-person','00000000-0000-4000-8000-0000001791a1',
  '{"sub":"directory-canonical-person","iss":"https://identity.deskilo.test/auth/v1"}',
  'custom:deskilo',now(),now());
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001791a1","role":"authenticated"}',true);
set local role authenticated;
select is(public.finalize_identity_binding()->>'status','verified','a linked provider proves the existing native account');
reset role;
delete from auth.identities where provider='custom:deskilo' and user_id='00000000-0000-4000-8000-0000001791a1';
set local role authenticated;
select is(public.my_identity_status()->>'status','unlinked','provider removal revokes its canonical binding');
select is((select count(*)::int from public.members where user_id=auth.uid()),1,'unlink retains the existing workspace membership');
reset role;
select * from finish();
rollback;
