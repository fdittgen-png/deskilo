-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2552 XPRIV-01: the private-values mask is a personal account default.
-- 'masked' and 'shown' save and read back; anything else is refused; a
-- workspace cannot override it, yet the workspace reset still passes; an
-- account that never chose carries no key, and another key's save keeps an
-- explicit choice. The writer is security definer: the claims name the caller.
begin;
select plan(14);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at)
select ('00000000-0000-4000-8000-0000002552' || suffix)::uuid,
  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  suffix || '@mask.deskilo.test', '', now(), now(), now()
from unnest(array['a1','a2']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment)
values ('00000000-0000-4000-8000-0000002552b1','Mask fixture','FR','EUR','Europe/Paris',
  '00000000-0000-4000-8000-0000002552a1','dev');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin)
values ('00000000-0000-4000-8000-0000002552c1','00000000-0000-4000-8000-0000002552b1',
  '00000000-0000-4000-8000-0000002552a1',true,true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002552a1","role":"authenticated"}',true);
select ok(not (public.my_personal_preferences()->'defaults' ? 'private_values'),
  'an account that never chose carries no mask key (the client masks)');
select lives_ok($$select public.set_personal_preferences('{"private_values":"shown"}')$$,
  'the personal default accepts shown');
select is(public.my_personal_preferences()->'defaults'->>'private_values','shown',
  'shown reads back as the personal default');
select lives_ok($$select public.set_personal_preferences('{"private_values":"masked"}')$$,
  'the personal default accepts masked');
select is(public.my_personal_preferences()->'defaults'->>'private_values','masked',
  'masked reads back as the personal default');
select throws_ok($$select public.set_personal_preferences('{"private_values":"hidden"}')$$,
  'P0001','invalid preference value','an unknown mask value is refused');
select throws_ok($$select public.set_personal_preferences('{"private_values":true}')$$,
  'P0001','invalid preference value','a non-text mask value is refused');
select throws_ok($$select public.set_personal_preferences('{"private_values":"shown"}','00000000-0000-4000-8000-0000002552b1')$$,
  'P0001','personal preference only','a workspace cannot override the mask');
select lives_ok($$select public.set_personal_preferences('{"private_values":null,"theme":null}','00000000-0000-4000-8000-0000002552b1')$$,
  'the workspace reset of every key still passes');
select public.set_personal_preferences('{"clock":"24h"}');
select is(public.my_personal_preferences()->'defaults'->>'private_values','masked',
  'saving another key keeps the explicit mask choice');
select lives_ok($$select public.set_personal_preferences('{"payment_provider":"stripe"}')$$,
  'the 0304 payment provider key is still accepted');
select throws_ok($$select public.set_personal_preferences('{"is_owner":true}')$$,
  'P0001','unknown preference','an unknown key is still refused');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002552a2","role":"authenticated"}',true);
select ok(not (public.my_personal_preferences()->'defaults' ? 'private_values'),
  'another account does not inherit the first one''s choice');
select ok(not has_function_privilege('anon','public.set_personal_preferences(jsonb,uuid,uuid)','execute'),
  'anonymous callers cannot write preferences');
select * from finish();
rollback;
