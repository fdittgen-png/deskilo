-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2562 C1c: a token issued to an enrolled identity-only client carries
-- `deskilo_identity` and reaches no table, Storage object or function here,
-- while the same person's native session keeps working. The role holds no
-- dangerous attribute and no membership; no application function or table
-- is reachable through PUBLIC (exploded ACL, grantee 0); every personal
-- surface carries the restrictive `personal_native_session` policy (the
-- inventory ratchet: a new RLS table without `workspace_id` fails here
-- until it carries the policy). A banned canonical account loses its
-- personal rows and its native-only definers until the ban ends.
--
-- The role IS the subject, so the file seeds first (as postgres, by direct
-- insert) and only then switches roles, resetting after every scene. SQL
-- claim injection proves the database half; the Auth service actually
-- stamping the role on a real OAuth token is provider evidence (#2561 C2).
begin;
select plan(30);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values ('00000000-0000-4000-8000-0000002562a1','00000000-0000-0000-0000-000000000000',
        'authenticated','authenticated','person@boundary.test','',now(),now(),now());
update public.profiles set display_name = 'Boundary Person'
 where id = '00000000-0000-4000-8000-0000002562a1';
insert into storage.objects(bucket_id, name)
values ('avatars', '00000000-0000-4000-8000-0000002562a1/avatar');
select public.operator_register_identity_federation_client(
  '00000000-0000-4000-8000-0000002562c1',
  '00000000-0000-4000-8000-0000002562c2', 'https://workspace.example/auth/v1');
select public.operator_set_identity_federation_client(
  '00000000-0000-4000-8000-0000002562c1', true);

create function pg_temp.claims(p_client text, p_role text default 'authenticated',
  p_scope text default 'openid profile') returns jsonb language sql as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'sub', '00000000-0000-4000-8000-0000002562a1', 'role', p_role,
    'client_id', p_client, 'scope', p_scope));
$$;
grant execute on all functions in schema pg_temp to authenticated, anon, deskilo_identity;

-- ── the role ──────────────────────────────────────────────────────────
select ok(exists (select 1 from pg_roles where rolname = 'deskilo_identity'
   and not rolcanlogin and not rolsuper and not rolbypassrls
   and not rolcreaterole and not rolcreatedb and not rolreplication),
  'deskilo_identity exists without login, superuser, BYPASSRLS or creation rights');
select is_empty($$select b.rolname from pg_auth_members m join pg_roles b on b.oid = m.roleid
   where m.member = 'deskilo_identity'::regrole$$,
  'deskilo_identity is a member of no role (not authenticated, anon or service_role)');
select ok(not pg_has_role('deskilo_identity', 'authenticated', 'USAGE')
   and not pg_has_role('deskilo_identity', 'anon', 'USAGE')
   and not pg_has_role('deskilo_identity', 'service_role', 'USAGE'),
  'and inherits none of their privileges');
select ok(pg_has_role('authenticator', 'deskilo_identity', 'MEMBER'),
  'the API role may switch to it for a valid JWT');

-- ── effective privileges ─────────────────────────────────────────────
select is_empty($$select p.oid::regprocedure::text from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and not exists (select 1 from pg_depend d where d.classid = 'pg_proc'::regclass
                     and d.objid = p.oid and d.deptype = 'e')
    and exists (select 1 from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
                 where a.grantee = 0)$$,
  'no application function is executable through PUBLIC (exploded ACL)');
select is_empty($$select c.oid::regclass::text from pg_class c
   join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and exists (select 1 from aclexplode(c.relacl) a where a.grantee = 0)$$,
  'no table, view or sequence of public grants anything to PUBLIC');
select is_empty($$select d.defaclobjtype from pg_default_acl d
  where d.defaclnamespace = 'public'::regnamespace
    and exists (select 1 from aclexplode(d.defaclacl) a where a.grantee = 0)$$,
  'no default privilege of public hands new objects to PUBLIC');
select is_empty($$select p.oid::regprocedure::text from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and has_function_privilege('deskilo_identity', p.oid, 'EXECUTE')$$,
  'deskilo_identity executes no application function, overloads included');
select is_empty($$select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r', 'p', 'v', 'm')
    and has_table_privilege('deskilo_identity', c.oid, 'SELECT, INSERT, UPDATE, DELETE')$$,
  'deskilo_identity holds no privilege on any table of public');
select ok(not has_table_privilege('deskilo_identity', 'storage.objects', 'SELECT, INSERT, UPDATE, DELETE'),
  'nor on Storage objects');
select ok(has_function_privilege('authenticated', 'public.personal_native_session()', 'EXECUTE')
   and has_function_privilege('anon', 'public.personal_native_session()', 'EXECUTE')
   and has_function_privilege('authenticated', 'public.my_visibility()', 'EXECUTE'),
  'native roles keep what their policies and RPCs need');

-- ── the inventory ratchet ────────────────────────────────────────────
select is_empty($$select n.nspname || '.' || c.relname from pg_class c
   join pg_namespace n on n.oid = c.relnamespace
  where c.relkind = 'r' and c.relrowsecurity
    and ((n.nspname = 'public' and not exists (select 1 from pg_attribute a
           where a.attrelid = c.oid and a.attname = 'workspace_id' and not a.attisdropped))
         or (n.nspname = 'storage' and c.relname = 'objects'))
    and not exists (select 1 from pg_policy p where p.polrelid = c.oid
                     and p.polname = 'personal_native_session' and not p.polpermissive
                     and p.polroles = array[0::oid] and p.polcmd = '*')$$,
  'every personal surface carries the restrictive personal_native_session policy for every role');
-- A table with row-level security off is outside this inventory;
-- 00_schema_guarantees refuses it.

-- ── the hook ─────────────────────────────────────────────────────────
select is(public.identity_federation_token_hook(jsonb_build_object('claims',
    pg_temp.claims('00000000-0000-4000-8000-0000002562c1')))->'claims',
  pg_temp.claims('00000000-0000-4000-8000-0000002562c1', 'deskilo_identity'),
  'an enabled identity client''s token carries deskilo_identity, every other claim unchanged');
select is(public.identity_federation_token_hook(jsonb_build_object('claims',
    pg_temp.claims(null, 'authenticated', null)))->'claims',
  pg_temp.claims(null, 'authenticated', null), 'a native session keeps its role');
select is(public.identity_federation_token_hook(jsonb_build_object('claims',
    pg_temp.claims('00000000-0000-4000-8000-0000002562c9', 'authenticated', 'openid email')))->'claims',
  pg_temp.claims('00000000-0000-4000-8000-0000002562c9', 'authenticated', 'openid email'),
  'another OAuth client keeps its role and its client_id guard');
select throws_ok($$select public.identity_federation_token_hook(jsonb_build_object('claims',
    pg_temp.claims(null, 'deskilo_identity', null)))$$, '28000', 'identity_role_refused',
  'a native token cannot arrive already carrying the identity role');
select throws_ok($$select public.identity_federation_token_hook(jsonb_build_object('claims',
    pg_temp.claims('00000000-0000-4000-8000-0000002562c1', 'authenticated', 'openid email')))$$,
  '28000', 'identity_client_scope_refused', 'the 0292 scope rules still come first');

-- ── the identity token at the database ───────────────────────────────
-- pgTAP itself is out of the identity role's reach, so the scene records
-- each outcome (an SQLSTATE) and is asserted after `reset role`.
create function pg_temp.attempt(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return 'allowed';
exception when others then
  return sqlstate;
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon, deskilo_identity;
do $$
begin
  if not (select rolsuper from pg_roles where rolname = current_user)
     and not pg_has_role(current_user, 'deskilo_identity', 'SET') then
    execute format('grant deskilo_identity to %I with set true, inherit false', current_user);
  end if;
end
$$;
select set_config('request.jwt.claims',
  pg_temp.claims('00000000-0000-4000-8000-0000002562c1', 'deskilo_identity')::text, true);
set local role deskilo_identity;
select set_config('boundary.role', current_user, true);
select set_config('boundary.profiles', pg_temp.attempt('select id from public.profiles'), true);
select set_config('boundary.objects', pg_temp.attempt('select name from storage.objects'), true);
select set_config('boundary.rpc', pg_temp.attempt('select public.my_visibility()'), true);
reset role;
select is(current_setting('boundary.role'), 'deskilo_identity', 'the scene ran as the identity role');
select is(current_setting('boundary.profiles'), '42501', 'the identity token reads no personal table');
select is(current_setting('boundary.objects'), '42501', 'nor a private Storage object');
select is(current_setting('boundary.rpc'), '42501', 'nor calls a personal RPC');

-- ── the same person, delegated with the ordinary role ────────────────
select set_config('request.jwt.claims',
  pg_temp.claims('00000000-0000-4000-8000-0000002562c1')::text, true);
set local role authenticated;
select is(public.personal_native_session(), false, 'a client_id token is not a native session');
select is((select count(*)::int from public.profiles where id = '00000000-0000-4000-8000-0000002562a1'), 0,
  'and reads no personal row even with the ordinary role');
reset role;

-- ── the same person, native ──────────────────────────────────────────
select set_config('request.jwt.claims', pg_temp.claims(null, 'authenticated', null)::text, true);
set local role authenticated;
select is(public.personal_native_session(), true, 'the first-party session is native');
select is((select display_name from public.profiles where id = '00000000-0000-4000-8000-0000002562a1'),
  'Boundary Person', 'and reads its own profile');
select is((select count(*)::int from storage.objects where bucket_id = 'avatars'
   and name = '00000000-0000-4000-8000-0000002562a1/avatar'), 1, 'and its own photo');
select lives_ok($$select public.my_visibility()$$, 'and its native-only RPC');
reset role;

-- ── banned at the canonical account ──────────────────────────────────
update auth.users set banned_until = now() + interval '1 day'
 where id = '00000000-0000-4000-8000-0000002562a1';
set local role authenticated;
select is((select count(*)::int from public.profiles where id = '00000000-0000-4000-8000-0000002562a1'), 0,
  'a banned account''s still-valid token reads no personal row');
select throws_ok($$select public.my_visibility()$$, 'P0001', 'identity_session_refused',
  'and its native-only RPC refuses');
reset role;
update auth.users set banned_until = now() - interval '1 second'
 where id = '00000000-0000-4000-8000-0000002562a1';
set local role authenticated;
select is((select count(*)::int from public.profiles where id = '00000000-0000-4000-8000-0000002562a1'), 1,
  'an ended ban gives the row back');
reset role;

select * from finish();
rollback;
