-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3095 / 0614: the defaults stop handing out access. A new function is
-- closed to PUBLIC and anon, a new table to anon; anon holds no table-level
-- SELECT but keeps what is deliberate (the schema version, the column grants
-- of the published cards); the feature-operation oracle is closed to the
-- signed-in user.
begin;
select plan(13);

create function public.zz_privilege_probe() returns int language sql as 'select 1';
create table public.zz_privilege_probe_table (id int);
create function public.zz_privilege_probe_granted() returns int language sql as 'select 1';
grant execute on function public.zz_privilege_probe_granted() to authenticated;

select is(has_function_privilege('anon', 'public.zz_privilege_probe()', 'execute'), false,
  'a new function is not executable by anon');
select is(has_table_privilege('anon', 'public.zz_privilege_probe_table', 'select'), false,
  'a new table carries no SELECT for anon');

select is(has_function_privilege('authenticated', 'public.zz_privilege_probe_granted()', 'execute'), true,
  'a function granted explicitly to authenticated still executes');
select is(has_function_privilege('anon', 'public.zz_privilege_probe_granted()', 'execute'), false,
  'and is still closed to anon');
select is(has_function_privilege('authenticated', 'public.zz_privilege_probe()', 'execute'), true,
  'a new function stays executable by the signed-in user: only anon was closed');

set local role anon;
select throws_ok($$select count(*) from public.workspaces$$, '42501', null,
  'anon cannot read a tenant table at all');
select lives_ok($$select count(*) from public.deskilo_schema_version$$,
  'anon still reads the schema version');
select lives_ok($$select count(workspace_id) from public.public_workspace_cards$$,
  'anon still reads the published card columns it was granted');
select lives_ok($$select count(installation_id) from public.installation_identity$$,
  'anon still reads the installation identity columns it was granted');
select lives_ok($$select count(origin) from public.public_directory_sources$$,
  'anon still reads the directory source columns it was granted');
select lives_ok($$select count(user_id) from public.public_person_cards$$,
  'anon still reads the published person card columns it was granted');
select lives_ok($$select count(kind) from public.identity_authority$$,
  'anon still reads the identity authority columns it was granted');
reset role;

select is(has_function_privilege('authenticated',
  'public.feature_operation_allowed(uuid, text, text)', 'execute'), false,
  'the feature-operation oracle is closed to the signed-in user');

select * from finish();
rollback;
