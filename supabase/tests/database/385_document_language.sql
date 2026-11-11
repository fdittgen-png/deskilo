-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3647: the language of letters and notifications is its own preference.
-- 'follows' and 'chosen' save and read back; anything else is refused; a
-- workspace cannot override the mode, yet the workspace reset still passes;
-- an account that never chose carries no key and keeps its stored
-- preferred_locale; a chosen language survives a later interface-language
-- save that leaves preferred_locale out. The writer is security definer: the
-- claims name the caller.
begin;
select plan(14);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at)
select ('00000000-0000-4000-8000-0000003647' || suffix)::uuid,
  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  suffix || '@doclang.deskilo.test', '', now(), now(), now()
from unnest(array['a1','a2']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment)
values ('00000000-0000-4000-8000-0000003647b1','Document language fixture','FR','EUR','Europe/Paris',
  '00000000-0000-4000-8000-0000003647a1','dev');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin)
values ('00000000-0000-4000-8000-0000003647c1','00000000-0000-4000-8000-0000003647b1',
  '00000000-0000-4000-8000-0000003647a1',true,true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000003647a1","role":"authenticated"}',true);
select public.set_personal_preferences('{"preferred_locale":"de"}');
select ok(not (public.my_personal_preferences()->'defaults' ? 'document_locale_mode'),
  'an account that never chose carries no mode key (it follows)');
select is((select preferred_locale from public.profiles where id='00000000-0000-4000-8000-0000003647a1'),
  'de', 'the stored document language of an account that never chose stays');
select lives_ok($$select public.set_personal_preferences('{"document_locale_mode":"chosen","preferred_locale":"it"}')$$,
  'choosing a document language saves');
select is(public.my_personal_preferences()->'defaults'->>'document_locale_mode','chosen',
  'chosen reads back as the personal default');
select is((select preferred_locale from public.profiles where id='00000000-0000-4000-8000-0000003647a1'),
  'it', 'the chosen language reaches the projection reminders and pushes read');
select public.set_personal_preferences('{"ui_locale":"fr"}');
select is((select preferred_locale from public.profiles where id='00000000-0000-4000-8000-0000003647a1'),
  'it', 'an interface-language save without the document key leaves the chosen language');
select lives_ok($$select public.set_personal_preferences('{"document_locale_mode":"follows","preferred_locale":"fr"}')$$,
  'following the app again saves');
select is(public.my_personal_preferences()->'defaults'->>'document_locale_mode','follows',
  'follows reads back as the personal default');
select throws_ok($$select public.set_personal_preferences('{"document_locale_mode":"always"}')$$,
  'P0001','invalid preference value','an unknown mode is refused');
select throws_ok($$select public.set_personal_preferences('{"document_locale_mode":true}')$$,
  'P0001','invalid preference value','a non-text mode is refused');
select throws_ok($$select public.set_personal_preferences('{"document_locale_mode":"chosen"}','00000000-0000-4000-8000-0000003647b1')$$,
  'P0001','personal preference only','a workspace cannot override the mode');
select lives_ok($$select public.set_personal_preferences('{"document_locale_mode":null,"private_values":null,"theme":null}','00000000-0000-4000-8000-0000003647b1')$$,
  'the workspace reset of every key still passes');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000003647a2","role":"authenticated"}',true);
select ok(not (public.my_personal_preferences()->'defaults' ? 'document_locale_mode'),
  'another account does not inherit the first one''s mode');
select throws_ok($$select public.set_personal_preferences('{"is_owner":true}')$$,
  'P0001','unknown preference','an unknown key is still refused');
select * from finish();
rollback;
