-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1823: each field of an account has its own audience, and so does the
-- right to START a conversation. The defaults hold (name for my spaces,
-- the rest for nobody, reachable by my spaces); a chosen space reaches
-- only its own members; a signed-in stranger sees what is shared with
-- anyone signed in; the account search, the first message and the
-- preview answer to the same audiences; the legacy availability switch
-- still reads and writes reachability; nothing is readable directly.
begin;
select plan(36);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000001823'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@visibility.test','',now(),now(),now()
  from unnest(array['a1','a2','a3','a4','a5']) suffix;
update public.profiles set display_name = 'Vis'||right(id::text,2), whatsapp = '+33600000001',
       email = right(id::text,2)||'@contact.test', status_text = 'Here'
 where id::text like '%0000001823a%';
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment) values
 ('00000000-0000-4000-8000-0000001823b1','Visible one','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001823a1','dev'),
 ('00000000-0000-4000-8000-0000001823b2','Visible two','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001823a1','dev'),
 ('00000000-0000-4000-8000-0000001823b3','Not mine','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001823a3','dev');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000001823c1','00000000-0000-4000-8000-0000001823b1','00000000-0000-4000-8000-0000001823a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000001823c2','00000000-0000-4000-8000-0000001823b1','00000000-0000-4000-8000-0000001823a2',false,false,'active'),
 ('00000000-0000-4000-8000-0000001823c3','00000000-0000-4000-8000-0000001823b2','00000000-0000-4000-8000-0000001823a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000001823c4','00000000-0000-4000-8000-0000001823b2','00000000-0000-4000-8000-0000001823a4',false,false,'active'),
 ('00000000-0000-4000-8000-0000001823c5','00000000-0000-4000-8000-0000001823b3','00000000-0000-4000-8000-0000001823a3',true,true,'active');
-- a5 switched the legacy 0305 availability on, a4 switched it off; neither
-- ever chose an audience.
insert into public.account_contact_settings(user_id,available) values
 ('00000000-0000-4000-8000-0000001823a5',true),
 ('00000000-0000-4000-8000-0000001823a4',false);

-- a1 reads and shapes their own visibility.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001823a1","role":"authenticated"}',true);
set local role authenticated;
select is(public.my_visibility()->'fields'->'identity'->>'audience','my_spaces','identity defaults to my spaces');
select is(public.my_visibility()->'fields'->'about'->>'audience','nobody','about defaults to nobody');
select is(public.my_visibility()->'fields'->'contact_channels'->>'audience','nobody','contact channels default to nobody');
select is(public.my_visibility()->'fields'->'presence'->>'audience','nobody','presence defaults to nobody');
select is(public.my_visibility()->'reachability'->>'audience','my_spaces','reachability defaults to my spaces');
select is(jsonb_array_length(public.search_available_accounts('Visa4')),0,'a legacy "not available" is not widened to my spaces');
select lives_ok($$select public.set_my_about('Architect','Drawing things')$$,'the owner writes their profession and bio');
select is(public.my_visibility()->'about'->>'profession','Architect','my_visibility returns my own about text');

-- a2 shares a space with a1.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001823a2","role":"authenticated"}',true);
select is(public.visible_account('00000000-0000-4000-8000-0000001823a1')->'identity'->>'name','Visa1','a space mate sees the name');
select ok(not (public.visible_account('00000000-0000-4000-8000-0000001823a1') ? 'about'),'a space mate does not see an about kept for nobody');
select ok(not (public.visible_account('00000000-0000-4000-8000-0000001823a1') ? 'contact_channels'),'nor the contact channels');
select ok((public.visible_account('00000000-0000-4000-8000-0000001823a1')->>'can_message')::boolean,'a space mate may start a conversation');
select is(jsonb_array_length(public.search_available_accounts('Visa1')),1,'a space mate finds the account');
select lives_ok($$select public.send_account_message('00000000-0000-4000-8000-0000001823a1','Hello neighbour','00000000-0000-4000-8000-0000001823a2')$$,'a space mate starts a conversation');
select throws_ok($$select * from public.account_about$$,'42501',null,'nobody reads the about table directly');
select throws_ok($$select * from public.account_field_audience$$,'42501',null,'nobody reads the audience table directly');

-- a3 is a stranger who is signed in.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001823a3","role":"authenticated"}',true);
select ok(not (public.visible_account('00000000-0000-4000-8000-0000001823a1') ? 'identity'),'a stranger does not see a name kept for my spaces');
select ok(not (public.visible_account('00000000-0000-4000-8000-0000001823a1')->>'can_message')::boolean,'a stranger may not start a conversation');
select is(jsonb_array_length(public.search_available_accounts('Visa1')),0,'a stranger does not find the account');
-- 0388: outside the reachability the first message is held as a request, one only.
select lives_ok($$select public.send_account_message('00000000-0000-4000-8000-0000001823a1','Hi','00000000-0000-4000-8000-0000001823a3')$$,'a stranger first message is held as a request');
select throws_ok($$select public.send_account_message('00000000-0000-4000-8000-0000001823a1','Hi again','00000000-0000-4000-8000-0000001823a3')$$,'P0001','request pending','a second message waits for the answer');
select is(jsonb_array_length(public.search_available_accounts('Visa5')),1,'the legacy available switch still means anyone signed in');

-- a1 widens some fields and narrows another.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001823a1","role":"authenticated"}',true);
select lives_ok($$select public.set_visibility('about','chosen_spaces',array['00000000-0000-4000-8000-0000001823b2']::uuid[])$$,'about for one chosen space');
select throws_ok($$select public.set_visibility('about','chosen_spaces',array['00000000-0000-4000-8000-0000001823b3']::uuid[])$$,'P0001','choose spaces you belong to','a space one is not in cannot be chosen');
select throws_ok($$select public.set_visibility('salary','signed_in')$$,'P0001','unknown field','an unknown field is refused');
select throws_ok($$select public.set_visibility('contact_channels','signed_in')$$,'P0001','this field never goes beyond your spaces','contact channels never reach anyone signed in (0392, #2211)');
select lives_ok($$select public.set_visibility('reachability','signed_in')$$,'reachable by anyone signed in');
select ok(public.my_contact_availability(),'the legacy reader follows reachability');
select ok(not (public.preview_my_account('signed_in') ? 'contact_channels') and not (public.preview_my_account('signed_in') ? 'about'),'the signed-in preview shows neither the channels nor the chosen-space about');
select ok(public.preview_my_account('my_spaces') ? 'about','the my-spaces preview shows the chosen-space about');
select ok(public.preview_my_account('nobody') ? 'presence' and not (public.preview_my_account('nobody')->>'can_message')::boolean,'the nobody preview is what only I see');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001823a4","role":"authenticated"}',true);
select is(public.visible_account('00000000-0000-4000-8000-0000001823a1')->'about'->>'profession','Architect','a member of the chosen space sees the about');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001823a3","role":"authenticated"}',true);
select ok(not (public.visible_account('00000000-0000-4000-8000-0000001823a1') ? 'contact_channels'),'a stranger never sees the contact channels (0392)');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001823a1","role":"authenticated"}',true);
select lives_ok($$select public.set_contact_availability(false)$$,'the legacy switch turns reachability back');
select is(public.my_visibility()->'reachability'->>'audience','my_spaces','off means my spaces again');

reset role;
select ok(not has_function_privilege('anon','public.visible_account(uuid)','execute'),'anonymous callers cannot read an account');

select * from finish();
rollback;
