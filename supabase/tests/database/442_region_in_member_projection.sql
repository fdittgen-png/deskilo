-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3649 (0788) -- a person's region travels in the member profile projection
-- with the rest of their address: in the operational group, beside the city,
-- and nowhere a group without the address reaches. Who receives which group
-- is pinned by 104. Rolled back.
begin;
select plan(4);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values ('00000000-0000-4000-8000-0000036495a1','00000000-0000-0000-0000-000000000000','authenticated',
        'authenticated','region-projection@deskilo.test','',now(),now(),now());
update public.profiles set street = '350 Fifth Avenue', postal_code = '10118', city = 'New York',
       country_code = 'US', subdivision = 'NY'
 where id = '00000000-0000-4000-8000-0000036495a1';

select is(public.member_profile_projection('00000000-0000-4000-8000-0000036495a1', array['operational'])
            -> 'operational' ->> 'subdivision', 'NY',
  'the operational group carries the region of the address');
select is(public.member_profile_projection('00000000-0000-4000-8000-0000036495a1', array['operational'])
            -> 'operational' ->> 'city', 'New York',
  'beside the city it belongs to');
select ok(public.member_profile_projection('00000000-0000-4000-8000-0000036495a1', array['community', 'birthday'])::text
            not like '%NY%',
  'a group without the address carries no region');
update public.profiles set subdivision = '' where id = '00000000-0000-4000-8000-0000036495a1';
select is(public.member_profile_projection('00000000-0000-4000-8000-0000036495a1', array['operational'])
            -> 'operational' ->> 'subdivision', '',
  'an address without a region projects an empty one');

select * from finish();
rollback;
