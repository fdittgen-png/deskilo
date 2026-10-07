-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2211 / 0389: a signed-out visitor sees nothing of a person until that
-- person publishes a public profile on purpose; then the public card holds
-- exactly the name, the profession and the bio — never a contact channel. No
-- card for the unpublished or the withdrawn. Publications are unreadable.
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
select is_empty($$select 1 from public.public_person_cards where user_id = '00000000-0000-4000-8000-0000002211a1'$$,
  'an unpublished person has no public card');
reset role;

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002211a1","role":"authenticated"}',true);
set local role authenticated;
select is(public.my_public_profile()->>'published', 'false', 'nothing is published by default');
select lives_ok($$select public.set_public_profile(true)$$, 'the person publishes');
select is(public.my_public_profile()->>'published', 'true', 'and reads it back');
select throws_ok($$select * from public.account_public_profiles$$, '42501', null, 'the table is not readable directly');
reset role;

set local role anon;
select results_eq($$select name, profession, bio from public.public_person_cards where user_id = '00000000-0000-4000-8000-0000002211a1'$$,
  $$values ('Pub Lic'::text, 'Architect'::text, 'Draws things'::text)$$,
  'a visitor reads exactly the name, the profession and the bio');
select throws_ok($$select email from public.public_person_cards$$, '42703', null,
  'a contact channel is not even a column of the card');
reset role;

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002211a1","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($$select public.set_public_profile(false)$$, 'the person withdraws');
reset role;

set local role anon;
select is_empty($$select 1 from public.public_person_cards where user_id = '00000000-0000-4000-8000-0000002211a1'$$,
  'a withdrawn profile is gone at once');
reset role;

select * from finish();
rollback;
