-- SPDX-License-Identifier: 0BSD
--
-- #1312 — the schema version is written by the migrations and readable
-- before anybody signs in.
--
-- The lint (`migration_version_marker_test`) proves every file ENDS with
-- its marker line. This proves the line does what it says on a database
-- the migrations actually built: after the whole history replays, the
-- marker equals the highest migration number the replay recorded — so a
-- file that typed the line and never ran it, or ran it with the wrong
-- number, fails here rather than on a customer's upgrade.
begin;
select plan(7);

select is(
  public.deskilo_schema_version(),
  (select max(version::int) from supabase_migrations.schema_migrations
    where version ~ '^[0-9]{4}$'),
  'the marker equals the last migration the replay applied'
);

select ok(
  has_function_privilege('anon', 'public.deskilo_schema_version()', 'EXECUTE'),
  'anon may ask the version — the app asks before anybody signs in'
);

select ok(
  not has_function_privilege('anon', 'public.set_deskilo_schema_version(int)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.set_deskilo_schema_version(int)', 'EXECUTE'),
  'nobody but the migration role may write the version'
);

select ok(
  not (select prosecdef from pg_proc where oid = 'public.deskilo_schema_version()'::regprocedure),
  'the reader is SECURITY INVOKER — a version needs no elevated rights'
);

-- The setter never lowers the marker: re-running an old file by hand must
-- not make an instance look older than it is.
select public.set_deskilo_schema_version(1);
select is(
  public.deskilo_schema_version(),
  (select max(version::int) from supabase_migrations.schema_migrations
    where version ~ '^[0-9]{4}$'),
  'an older number never lowers the marker'
);

set local role anon;
select is(
  (select count(*)::int from public.deskilo_schema_version),
  1,
  'anon reads exactly one row'
);
select throws_ok(
  $$ update public.deskilo_schema_version set version = 1 $$,
  '42501',
  null,
  'anon cannot write the row'
);
reset role;

select * from finish();
rollback;
