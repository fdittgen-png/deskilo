-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2211 / 0389: a signed-out visitor sees nothing of a person until that
-- person publishes a public profile on purpose; then exactly the name, the
-- profession and the bio — never a contact channel. Unknown, unpublished and
-- withdrawn all read the same refusal. The table itself is unreadable.
begin;
select plan(9);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values ('00000000-0000-4000-8000-0000002211a1','00000000-0000-0000-0000-000000000000',
        'authenticated','authenticated','pub@public.test','',now(),now(),now());
update public.profiles set display_name = 'Pub Lic', email = 'secret@contact.test', whatsapp = '+33600000009'
 where id = '00000000-0000-4000-8000-0000002211a1';
insert into public.account_about(user_id, profession, bio)
values ('00000000-0000-4000-8000-0000002211a1', 'Architect', 'Draws things');

set local role anon;
select throws_ok($$select public.public_person('00000000-0000-4000-8000-0000002211a1')$$,
  'P0001', 'profile unavailable', 'an unpublished person is not readable');
reset role;

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002211a1","role":"authenticated"}',true);
set local role authenticated;
select is(public.my_public_profile()->>'published', 'false', 'nothing is published by default');
select lives_ok($$select public.set_public_profile(true)$$, 'the person publishes');
select is(public.my_public_profile()->>'published', 'true', 'and reads it back');
select throws_ok($$select * from public.account_public_profiles$$, '42501', null, 'the table is not readable directly');
reset role;

set local role anon;
select is(public.public_person('00000000-0000-4000-8000-0000002211a1'),
  '{"bio": "Draws things", "name": "Pub Lic", "profession": "Architect"}'::jsonb,
  'a visitor reads exactly the name, the profession and the bio');
select throws_ok($$select public.public_person('00000000-0000-4000-8000-00000000dead')$$,
  'P0001', 'profile unavailable', 'an unknown person reads the same refusal');
reset role;

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002211a1","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($$select public.set_public_profile(false)$$, 'the person withdraws');
reset role;

set local role anon;
select throws_ok($$select public.public_person('00000000-0000-4000-8000-0000002211a1')$$,
  'P0001', 'profile unavailable', 'a withdrawn profile is gone at once');
reset role;

select * from finish();
rollback;
