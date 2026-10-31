-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3134 / 0618: a new function in `public` is reachable by the service key
-- alone until its migration grants it; an explicit grant to authenticated
-- still works and still leaves anon out.
begin;
select plan(5);

create function public.zz_closed_probe() returns int language sql as 'select 1';
create function public.zz_open_probe() returns int language sql as 'select 1';
grant execute on function public.zz_open_probe() to authenticated;

select is(has_function_privilege('authenticated', 'public.zz_closed_probe()', 'execute'), false,
  'a new function is not executable by authenticated');
select is(has_function_privilege('anon', 'public.zz_closed_probe()', 'execute'), false,
  'nor by anon');
select is(has_function_privilege('service_role', 'public.zz_closed_probe()', 'execute'), true,
  'the service key still runs it');
select is(has_function_privilege('authenticated', 'public.zz_open_probe()', 'execute'), true,
  'an explicitly granted function runs for authenticated');
select is(has_function_privilege('anon', 'public.zz_open_probe()', 'execute'), false,
  'and stays closed to anon');

select * from finish();
rollback;
