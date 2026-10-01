-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1833 (checkpoint A): what one member reads of another inside a space
-- is a purpose-specific projection. A space mate gets the community
-- group (name, photo, WhatsApp, status, presence) and never the postal
-- address, VAT id, legal id, phone, identity e-mail, document language
-- or PIN hash; only a holder of viewPersonalData or issueInvoices IN
-- THAT space gets the operational group; an administrator without them
-- does not. Pending, exited and unrelated accounts get nothing, a space
-- the caller does not belong to grants nothing, the same subject is
-- read per target space, revoking the permission or the membership
-- takes the group away, and the subject reads all of themselves without
-- any membership. The badge PIN hash is no longer on the profile row a
-- space mate can select, and badge sign-in still works through its own
-- table. The preview of "how others see me" is byte-equal to
-- what those readers actually receive. The two internal functions are
-- not callable by clients, and anonymous callers cannot call the RPCs.
begin;
select plan(53);

-- a1 owner of b1 · a2 subject (b1 + b2) · a3 peer member of b1
-- a4 admin of b1 WITHOUT billing permissions · a5 billing clerk of b1
-- (co-owner role holding only issueInvoices) · a6 stranger (owner of b3)
-- a7 owner of b2 · a8 pending in b1 · a9 exited from b1 · aa no space.
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000001833'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@projection.test','',now(),now(),now()
  from unnest(array['a1','a2','a3','a4','a5','a6','a7','a8','a9','aa']) suffix;
update public.profiles set display_name = 'Proj'||right(id::text,2)
 where id::text like '00000000-0000-4000-8000-0000001833%';
-- One distinct canary per private field of the subject.
update public.profiles set display_name = 'Subject Person', whatsapp = '+33600001833',
       status_text = 'Here today', avatar_path = '00000000-0000-4000-8000-0000001833a2/avatar',
       first_name = 'FIRST-CANARY', last_name = 'LAST-CANARY', company = 'COMPANY-CANARY',
       street = 'STREET-CANARY', postal_code = 'PC-CANARY', city = 'CITY-CANARY',
       country_code = 'BE', phone = 'PHONE-CANARY', email = 'mail-canary@x.test',
       vat_id = 'VAT-CANARY-1833', legal_id = 'LEGAL-CANARY', address = 'ADDRESS-CANARY',
       preferred_locale = 'de'
 where id = '00000000-0000-4000-8000-0000001833a2';
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,role_permissions,feature_flags) values
 ('00000000-0000-4000-8000-0000001833b1','Projection one','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001833a1','dev',
  '{"admin":["manageMembers"],"co_owner":["issueInvoices"]}','{"adminInvoicing":false}'),
 ('00000000-0000-4000-8000-0000001833b2','Projection two','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001833a7','dev','{}','{}'),
 ('00000000-0000-4000-8000-0000001833b3','Projection three','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001833a6','dev','{}','{}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,co_owner,status) values
 ('00000000-0000-4000-8000-0000001833c1','00000000-0000-4000-8000-0000001833b1','00000000-0000-4000-8000-0000001833a1',true,true,'none','active'),
 ('00000000-0000-4000-8000-0000001833c2','00000000-0000-4000-8000-0000001833b1','00000000-0000-4000-8000-0000001833a2',false,false,'none','active'),
 ('00000000-0000-4000-8000-0000001833c3','00000000-0000-4000-8000-0000001833b1','00000000-0000-4000-8000-0000001833a3',false,false,'none','active'),
 ('00000000-0000-4000-8000-0000001833c4','00000000-0000-4000-8000-0000001833b1','00000000-0000-4000-8000-0000001833a4',false,true,'none','active'),
 ('00000000-0000-4000-8000-0000001833c5','00000000-0000-4000-8000-0000001833b1','00000000-0000-4000-8000-0000001833a5',false,false,'active','active'),
 ('00000000-0000-4000-8000-0000001833c6','00000000-0000-4000-8000-0000001833b3','00000000-0000-4000-8000-0000001833a6',true,true,'none','active'),
 ('00000000-0000-4000-8000-0000001833c7','00000000-0000-4000-8000-0000001833b2','00000000-0000-4000-8000-0000001833a7',true,true,'none','active'),
 ('00000000-0000-4000-8000-0000001833c8','00000000-0000-4000-8000-0000001833b2','00000000-0000-4000-8000-0000001833a2',false,false,'none','active'),
 ('00000000-0000-4000-8000-0000001833c9','00000000-0000-4000-8000-0000001833b1','00000000-0000-4000-8000-0000001833a8',false,false,'none','pending'),
 ('00000000-0000-4000-8000-0000001833ca','00000000-0000-4000-8000-0000001833b1','00000000-0000-4000-8000-0000001833a9',false,false,'none','exited');

create temp table subj as select '00000000-0000-4000-8000-0000001833a2'::uuid id;
create temp table seen(k text primary key, v jsonb);
grant select on subj to authenticated;
grant select, insert on seen to authenticated;

-- ── the peer member a3 ──────────────────────────────────────────────
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001833a3","role":"authenticated"}',true);
set local role authenticated;
select is(jsonb_array_length(public.member_profiles('00000000-0000-4000-8000-0000001833b1',array[(select id from subj)])),1,'a space mate reads the subject');
select is(public.member_profiles('00000000-0000-4000-8000-0000001833b1',array[(select id from subj)])->0->'community'->>'display_name','Subject Person','the space mate sees the name');
select is(public.member_profiles('00000000-0000-4000-8000-0000001833b1',array[(select id from subj)])->0->'community'->>'whatsapp','+33600001833','the space mate sees the shared WhatsApp number');
select ok(not (public.member_profiles('00000000-0000-4000-8000-0000001833b1',array[(select id from subj)])->0 ? 'operational'),'the space mate gets no operational group');
select is(public.member_profiles('00000000-0000-4000-8000-0000001833b1',array[(select id from subj)])::text ilike '%canary%',false,'no private canary reaches the space mate');
select is((select array_agg(k order by k) from jsonb_object_keys(public.member_profiles('00000000-0000-4000-8000-0000001833b1',array[(select id from subj)])->0) k),
          array['community','id','purposes'],'the space mate answer has exactly id, purposes and community');
select is((select array_agg(k order by k) from jsonb_object_keys(public.member_profiles('00000000-0000-4000-8000-0000001833b1',array[(select id from subj)])->0->'community') k),
          array['avatar_path','display_name','last_seen_at','status_text','whatsapp'],'the community group has exactly its five fields');
select is(jsonb_array_length(public.member_profiles('00000000-0000-4000-8000-0000001833b1',array[(select id from subj),(select id from subj),null,'00000000-0000-4000-8000-0000001833ff'])),1,'duplicates, nulls and unknown ids add nothing');
select is(jsonb_array_length(public.member_profiles('00000000-0000-4000-8000-0000001833b1',array['00000000-0000-4000-8000-0000001833a8'::uuid])),0,'a pending member is not projected to a space mate');
select is(jsonb_array_length(public.member_profiles('00000000-0000-4000-8000-0000001833b1',array['00000000-0000-4000-8000-0000001833a9'::uuid])),0,'an exited member is not projected to a space mate');
select is(jsonb_array_length(public.member_profiles('00000000-0000-4000-8000-0000001833b2',array[(select id from subj)])),0,'a space the caller does not belong to grants nothing');
insert into seen select 'mate', public.member_profiles('00000000-0000-4000-8000-0000001833b1',array[(select id from subj)])->0;
select throws_ok($$select public.member_profile_projection('00000000-0000-4000-8000-0000001833a2',array['community','operational'])$$,'42501',null,'the projection itself is not callable by a client');
select throws_ok($$select public.member_profile_purposes('00000000-0000-4000-8000-0000001833b1','00000000-0000-4000-8000-0000001833a2')$$,'42501',null,'nor is the purpose decision');

-- ── the administrator a4 without viewPersonalData / issueInvoices ───
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001833a4","role":"authenticated"}',true);
select ok(public.has_permission('00000000-0000-4000-8000-0000001833b1','manageMembers'),'fixture: the administrator holds manageMembers');
select ok(not public.has_permission('00000000-0000-4000-8000-0000001833b1','viewPersonalData') and not public.has_permission('00000000-0000-4000-8000-0000001833b1','issueInvoices'),'fixture: but neither personal-data nor invoicing permission');
select ok(public.member_profiles('00000000-0000-4000-8000-0000001833b1',array[(select id from subj)])->0 ? 'community','an administrator reads the community group');
select ok(not (public.member_profiles('00000000-0000-4000-8000-0000001833b1',array[(select id from subj)])->0 ? 'operational'),'being an administrator does not open the operational group');

-- ── the billing clerk a5 (issueInvoices only) ───────────────────────
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001833a5","role":"authenticated"}',true);
select is(public.member_profiles('00000000-0000-4000-8000-0000001833b1',array[(select id from subj)])->0->'operational'->>'vat_id','VAT-CANARY-1833','the billing clerk reads the VAT id');
select is(public.member_profiles('00000000-0000-4000-8000-0000001833b1',array[(select id from subj)])->0->'operational'->>'address','ADDRESS-CANARY','and the postal address');
select is((select array_agg(k order by k) from jsonb_object_keys(public.member_profiles('00000000-0000-4000-8000-0000001833b1',array[(select id from subj)])->0->'operational') k),
          array['address','city','company','country_code','courtesy','email','first_name','last_name','legal_id','phone','postal_code','preferred_locale','street','vat_id'],
          'the operational group has exactly the identity documents print');
select is(public.member_profiles('00000000-0000-4000-8000-0000001833b1',array['00000000-0000-4000-8000-0000001833a3'::uuid])->0->'operational'->>'vat_id','','the clerk reads another member too, with its own values');
insert into seen select 'clerk', public.member_profiles('00000000-0000-4000-8000-0000001833b1',array[(select id from subj)])->0;

-- ── the owner a1 reads in b1, not through b2 ─────────────────────────
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001833a1","role":"authenticated"}',true);
select is(public.member_profiles('00000000-0000-4000-8000-0000001833b1',array[(select id from subj)])->0->'operational'->>'legal_id','LEGAL-CANARY','the owner reads the operational group in their space');
select is(jsonb_array_length(public.member_profiles('00000000-0000-4000-8000-0000001833b2',array[(select id from subj)])),0,'naming the subject''s other space does not lend the owner its rights');

-- ── the owner a7 of b2: the same subject id on another target ───────
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001833a7","role":"authenticated"}',true);
select is(public.member_profiles('00000000-0000-4000-8000-0000001833b2',array[(select id from subj)])->0->'operational'->>'city','CITY-CANARY','the owner of the other space reads the subject there');
select is(jsonb_array_length(public.member_profiles('00000000-0000-4000-8000-0000001833b1',array[(select id from subj)])),0,'but not through a space they are not in');
select is(jsonb_array_length(public.member_profiles('00000000-0000-4000-8000-0000001833b2',array['00000000-0000-4000-8000-0000001833a3'::uuid])),0,'an owner reaches no one outside their space');

-- ── the stranger a6, the pending a8, the exited a9 ──────────────────
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001833a6","role":"authenticated"}',true);
select is(jsonb_array_length(public.member_profiles('00000000-0000-4000-8000-0000001833b1',array[(select id from subj)])),0,'a stranger reads nothing through the subject''s space');
select is(jsonb_array_length(public.member_profiles('00000000-0000-4000-8000-0000001833b3',array[(select id from subj)])),0,'nor through their own space');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001833a8","role":"authenticated"}',true);
select is(jsonb_array_length(public.member_profiles('00000000-0000-4000-8000-0000001833b1',array[(select id from subj)])),0,'a pending member reads nothing');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001833a9","role":"authenticated"}',true);
select is(jsonb_array_length(public.member_profiles('00000000-0000-4000-8000-0000001833b1',array[(select id from subj)])),0,'an exited member reads nothing');

-- ── the subject reads all of themselves, without any space ──────────
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001833a2","role":"authenticated"}',true);
select is(public.member_profiles(null,array[(select id from subj)])->0->'operational'->>'vat_id','VAT-CANARY-1833','the subject reads their own operational group');
select is(public.preview_my_member_profile('space_mate'),(select v from seen where k = 'mate'),'the space-mate preview is exactly what the space mate receives');
select is(public.preview_my_member_profile('personal_data'),(select v from seen where k = 'clerk'),'the personal-data preview is exactly what the billing clerk receives');
select throws_ok($$select public.preview_my_member_profile('operational')$$,'P0001','unknown audience','a preview audience outside the list is refused');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001833aa","role":"authenticated"}',true);
select is(public.member_profiles(null,array['00000000-0000-4000-8000-0000001833aa'::uuid])->0->'purposes','["community", "operational"]'::jsonb,'an account in no space reads its own projection');
select ok(not (public.preview_my_member_profile('space_mate') ? 'operational'),'and previews it without any membership');

-- ── the badge PIN hash is not on the profile row any more ───────────
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001833a2","role":"authenticated"}',true);
select lives_ok($$select public.set_badge_pin('4826')$$,'the subject sets a badge PIN');
select ok(public.has_badge_pin(),'and the app sees that a PIN is set');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001833a3","role":"authenticated"}',true);
select is((select display_name||'|'||pin_hash||'|'||coalesce(pin_set_at::text,'') from public.profiles where id = (select id from subj)),'Subject Person||','a space mate reading the raw profile row finds no PIN hash');
select throws_ok($$select * from public.account_badge_pins$$,'42501',null,'nobody reads the PIN table directly');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001833a5","role":"authenticated"}',true);
select is(public.member_profiles('00000000-0000-4000-8000-0000001833b1',array[(select id from subj)])::text like '%$2%',false,'the operational projection never carries the PIN hash');
reset role;
update public.workspaces set feature_flags = '{"badgeSignIn":true}' where id = '00000000-0000-4000-8000-0000001833b2';
insert into public.member_badges(workspace_id,member_id,token_hash,auth_enabled) values
 ('00000000-0000-4000-8000-0000001833b2','00000000-0000-4000-8000-0000001833c8',public.badge_token_hash('UID-1833'),true);
select is(public.badge_auth_verify('UID-1833','4826')->>'user_id','00000000-0000-4000-8000-0000001833a2','the right PIN still signs in through the moved hash');
select is(public.badge_auth_verify('UID-1833','9173')->>'reason','refused','a wrong PIN is refused');
select throws_ok($$update public.profiles set pin_hash = 'x' where id = '00000000-0000-4000-8000-0000001833a2'$$,'23514',null,'nothing writes a hash back onto the profile');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001833a2","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($$select public.clear_badge_pin()$$,'the subject clears the PIN');
select ok(not public.has_badge_pin(),'and no PIN is set any more');
reset role;
select is(public.badge_auth_verify('UID-1833','4826')->>'reason','refused','a cleared PIN signs nobody in');

-- ── revocation: the permission, then the membership ─────────────────
reset role;
update public.members set co_owner = 'none' where id = '00000000-0000-4000-8000-0000001833c5';
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001833a5","role":"authenticated"}',true);
set local role authenticated;
select ok(not (public.member_profiles('00000000-0000-4000-8000-0000001833b1',array[(select id from subj)])->0 ? 'operational'),'the clerk whose role was withdrawn loses the operational group at once');
select ok(public.member_profiles('00000000-0000-4000-8000-0000001833b1',array[(select id from subj)])->0 ? 'community','and keeps what a space mate sees');
reset role;
update public.members set status = 'exited' where id = '00000000-0000-4000-8000-0000001833c3';
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001833a3","role":"authenticated"}',true);
set local role authenticated;
select is(jsonb_array_length(public.member_profiles('00000000-0000-4000-8000-0000001833b1',array[(select id from subj)])),0,'a member who left reads nobody any more');

-- ── grants ──────────────────────────────────────────────────────────
reset role;
select ok(not has_function_privilege('anon','public.member_profiles(uuid,uuid[])','execute'),'anonymous callers cannot read a member profile');
select ok(not has_function_privilege('anon','public.preview_my_member_profile(text)','execute'),'nor preview one');
select ok(not has_function_privilege('authenticated','public.member_profile_projection(uuid,text[])','execute')
      and not has_function_privilege('authenticated','public.member_profile_purposes(uuid,uuid)','execute'),'the internal functions are granted to no client');

select * from finish();
rollback;
