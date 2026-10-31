-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3095 / 0613: the defaults stop handing out access. A new function is
-- closed to PUBLIC and anon, a new table to anon; anon holds no table-level
-- SELECT but keeps what is deliberate (the schema version, the column grants
-- of the published cards); the feature-operation oracle is closed to the
-- signed-in user.
begin;
select plan(6);

create function public.zz_privilege_probe() returns int language sql as 'select 1';
create table public.zz_privilege_probe_table (id int);

select is(has_function_privilege('anon', 'public.zz_privilege_probe()', 'execute'), false,
  'a new function is not executable by anon');
select is(has_table_privilege('anon', 'public.zz_privilege_probe_table', 'select'), false,
  'a new table carries no SELECT for anon');

set local role anon;
select throws_ok($$select count(*) from public.workspaces$$, '42501', null,
  'anon cannot read a tenant table at all');
select lives_ok($$select count(*) from public.deskilo_schema_version$$,
  'anon still reads the schema version');
select lives_ok($$select count(workspace_id) from public.public_workspace_cards$$,
  'anon still reads the published card columns it was granted');
reset role;

select is(has_function_privilege('authenticated',
  'public.feature_operation_allowed(uuid, text, text)', 'execute'), false,
  'the feature-operation oracle is closed to the signed-in user');

select * from finish();
rollback;
