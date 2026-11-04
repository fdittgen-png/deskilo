-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3278 (0668, 0669) — the birthday is read by its person, by viewPersonalData
-- and managePrivacy holders of a shared workspace and by nobody else (a billing
-- clerk reads the address, not the birthday), through the projection AND by a
-- direct read of the table (0669 moved it off profiles, whose row a billing
-- clerk may select); the person writes their own and nobody else's; it is
-- exported to its subject and removed with the rest of the structured identity
-- by the erasure of the last membership, whose preview says so; the table
-- refuses an implausible one.
begin;
select plan(27);

-- a1 owner · a2 subject (only member of this space besides the others) · a3 peer
-- a4 billing clerk (co-owner holding only issueInvoices) · a5 admin holding
-- managePrivacy · a6 stranger (owner of another space).
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000003278'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@birthday.test','',now(),now(),now()
  from unnest(array['a1','a2','a3','a4','a5','a6']) suffix;
update public.profiles set display_name = 'Bday'||right(id::text,2)
 where id::text like '00000000-0000-4000-8000-0000003278%';
update public.profiles set display_name = 'Subject Person', first_name = 'FIRST-CANARY', last_name = 'LAST-CANARY',
       company = 'COMPANY-CANARY', street = 'STREET-CANARY', postal_code = 'PC-CANARY', city = 'CITY-CANARY',
       country_code = 'BE', phone = 'PHONE-CANARY', email = 'mail-canary@x.test', legal_id = 'LEGAL-CANARY',
       courtesy = 'mrs'
 where id = '00000000-0000-4000-8000-0000003278a2';
insert into public.profile_birthdays(user_id, birthday)
values ('00000000-0000-4000-8000-0000003278a2', date '1990-04-12');
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,role_permissions,feature_flags) values
 ('00000000-0000-4000-8000-0000003278b1','Birthday one','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000003278a1','dev',
  '{"admin":["managePrivacy"],"co_owner":["issueInvoices"]}','{}'),
 ('00000000-0000-4000-8000-0000003278b2','Birthday two','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000003278a6','dev','{}','{}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,co_owner,status) values
 ('00000000-0000-4000-8000-0000003278c1','00000000-0000-4000-8000-0000003278b1','00000000-0000-4000-8000-0000003278a1',true,true,'none','active'),
 ('00000000-0000-4000-8000-0000003278c2','00000000-0000-4000-8000-0000003278b1','00000000-0000-4000-8000-0000003278a2',false,false,'none','active'),
 ('00000000-0000-4000-8000-0000003278c3','00000000-0000-4000-8000-0000003278b1','00000000-0000-4000-8000-0000003278a3',false,false,'none','active'),
 ('00000000-0000-4000-8000-0000003278c4','00000000-0000-4000-8000-0000003278b1','00000000-0000-4000-8000-0000003278a4',false,false,'active','active'),
 ('00000000-0000-4000-8000-0000003278c5','00000000-0000-4000-8000-0000003278b1','00000000-0000-4000-8000-0000003278a5',false,true,'none','active'),
 ('00000000-0000-4000-8000-0000003278c6','00000000-0000-4000-8000-0000003278b2','00000000-0000-4000-8000-0000003278a6',true,true,'none','active');
create temp table subj as select '00000000-0000-4000-8000-0000003278a2'::uuid id;
grant select on subj to authenticated;

create function pg_temp.read_as(p_user text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform set_config('request.jwt.claims', json_build_object('sub','00000000-0000-4000-8000-0000003278'||p_user,'role','authenticated')::text, true);
  execute 'set local role authenticated';
  v := public.member_profiles('00000000-0000-4000-8000-0000003278b1', array[(select id from subj)]) -> 0;
  execute 'reset role';
  return v;
end $$;
-- A DIRECT read of the table as [p_user], the path the projection does not guard.
create function pg_temp.direct_as(p_user text) returns int language plpgsql as $$
declare v int;
begin
  perform set_config('request.jwt.claims', json_build_object('sub','00000000-0000-4000-8000-0000003278'||p_user,'role','authenticated')::text, true);
  execute 'set local role authenticated';
  select count(*) into v from public.profile_birthdays where user_id = (select id from subj);
  execute 'reset role';
  return v;
end $$;
grant execute on all functions in schema pg_temp to authenticated;

-- ── who reads it ────────────────────────────────────────────────────
select is(pg_temp.read_as('a2') -> 'birthday' ->> 'birthday', '1990-04-12', 'the person reads their own birthday');
select is(pg_temp.read_as('a5') -> 'birthday' ->> 'birthday', '1990-04-12', 'a managePrivacy holder reads it');
select is(pg_temp.read_as('a1') -> 'birthday' ->> 'birthday', '1990-04-12', 'an owner (who holds viewPersonalData and managePrivacy) reads it');
select ok(not (pg_temp.read_as('a4') ? 'birthday'), 'a billing clerk (issueInvoices only) does not read it');
select ok(pg_temp.read_as('a4') ? 'operational', 'while the clerk still reads the operational group');
select ok(not (pg_temp.read_as('a3') ? 'birthday'), 'a space mate does not read it');
select ok(pg_temp.read_as('a6') is null, 'a stranger reads nothing of the person');
update public.workspaces set role_permissions = '{"admin":["viewPersonalData"],"co_owner":["issueInvoices"]}'
 where id = '00000000-0000-4000-8000-0000003278b1';
select is(pg_temp.read_as('a5') -> 'birthday' ->> 'birthday', '1990-04-12', 'a viewPersonalData holder reads it too');
update public.workspaces set role_permissions = '{"admin":["manageMembers"],"co_owner":["issueInvoices"]}'
 where id = '00000000-0000-4000-8000-0000003278b1';
select ok(not (pg_temp.read_as('a5') ? 'birthday'), 'an admin holding neither right does not');

-- ── the direct path (0669): the profiles row carries no birthday any more ──
select is((select count(*)::int from information_schema.columns
            where table_schema = 'public' and table_name = 'profiles' and column_name = 'birthday'), 0,
  'profiles has no birthday column: a row a billing clerk may select carries none');
select is(pg_temp.direct_as('a4'), 0, 'a billing clerk reads no birthday row directly');
select is(pg_temp.direct_as('a3'), 0, 'nor does a space mate');
select is(pg_temp.direct_as('a6'), 0, 'nor a stranger');
select is(pg_temp.direct_as('a5'), 0, 'nor an admin holding neither right');
select is(pg_temp.direct_as('a1'), 1, 'an owner reads it directly');
select is(pg_temp.direct_as('a2'), 1, 'the person reads their own');
update public.workspaces set role_permissions = '{"admin":["viewPersonalData"],"co_owner":["issueInvoices"]}'
 where id = '00000000-0000-4000-8000-0000003278b1';
select is(pg_temp.direct_as('a5'), 1, 'a viewPersonalData holder reads it directly');
update public.workspaces set role_permissions = '{"admin":["manageMembers"],"co_owner":["issueInvoices"]}'
 where id = '00000000-0000-4000-8000-0000003278b1';

-- ── the table and the previews ──────────────────────────────────────
select throws_ok($$insert into public.profile_birthdays(user_id, birthday) values ('00000000-0000-4000-8000-0000003278a3', current_date + 1)$$,
  '23514', null, 'a birthday in the future is refused');
select throws_ok($$insert into public.profile_birthdays(user_id, birthday) values ('00000000-0000-4000-8000-0000003278a3', date '1899-12-31')$$,
  '23514', null, 'and one before 1900');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000003278a2","role":"authenticated"}',true);
set local role authenticated;
select throws_ok($$insert into public.profile_birthdays(user_id, birthday) values ('00000000-0000-4000-8000-0000003278a3', date '1980-01-01')$$,
  '42501', null, 'the person cannot write somebody else''s birthday');
select lives_ok($$update public.profile_birthdays set birthday = date '1990-04-12' where user_id = '00000000-0000-4000-8000-0000003278a2'$$,
  'the person writes their own');
select ok(not (public.preview_my_member_profile('personal_data') ? 'birthday'), 'the billing reader preview carries no birthday');
select is(public.preview_my_member_profile('privacy_admin') -> 'birthday' ->> 'birthday', '1990-04-12', 'the privacy admin preview carries it');

-- ── export and erasure ──────────────────────────────────────────────
select ok(public.export_my_data('00000000-0000-4000-8000-0000003278b1')::text like '%1990-04-12%', 'the subject export carries the birthday');
select ok(public.preview_my_erasure('00000000-0000-4000-8000-0000003278b1')::text ilike '%birthday%', 'the erasure preview names the birthday');
select lives_ok($$select public.erase_my_membership('00000000-0000-4000-8000-0000003278b1')$$, 'the last membership is erased');
reset role;
select ok(not exists (select 1 from public.profile_birthdays where user_id = '00000000-0000-4000-8000-0000003278a2')
          and (select first_name = '' and last_name = '' and company = '' and street = ''
                  and postal_code = '' and city = '' and phone = '' and email = '' and legal_id = ''
                  and courtesy = '' and country_code = ''
             from public.profiles where id = '00000000-0000-4000-8000-0000003278a2'),
  'the birthday row is removed and the whole structured identity cleared, not only the name and address');

select * from finish();
rollback;
