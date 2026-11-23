-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3726 (0900): the installation states the oldest app it accepts. The default is no floor (null), readable before
-- sign-in and by a member, writable by nobody, with no parameters, so an app cannot pass its own number in.
-- Rolled back.
begin;
select plan(7);

select has_function('public', 'deskilo_app_floor', array[]::text[], 'the floor function exists without parameters');
select function_returns('public', 'deskilo_app_floor', array[]::text[], 'integer', 'it answers an integer');
select is(public.deskilo_app_floor(), null::int, 'by default there is no floor: every app is accepted');

select ok(has_function_privilege('anon', 'public.deskilo_app_floor()', 'execute'),
  'it is readable before sign-in');
select ok(has_function_privilege('authenticated', 'public.deskilo_app_floor()', 'execute'),
  'and by a signed-in person');
select ok(not has_function_privilege('public', 'public.deskilo_app_floor()', 'execute'),
  'PUBLIC holds no grant of its own');

set local role anon;
select is(public.deskilo_app_floor(), null::int, 'anon reads the same answer');
reset role;

select * from finish();
rollback;
