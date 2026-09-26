-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1613/#1614: a delegated (OAuth client) token reaches the MCP facade
-- and nothing else. Assertions run as `authenticated`, once with a
-- native session and once with the same person's delegated claims.
begin;
select plan(13);

create function pg_temp.act_as(p_user uuid, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'client_id', p_client))::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.pre(p_method text, p_path text) returns text language plpgsql as $$
begin
  perform set_config('request.method', p_method, true);
  perform set_config('request.path', p_path, true);
  perform public.mcp_pre_request();
  return 'allowed';
exception when others then
  return 'refused';
end;
$$;

select is(public.mcp_facade_guard_status()->'tables_without_denial', '[]'::jsonb,
  'every RLS table carries the restrictive denial (a new table must add it)');
select ok((public.mcp_facade_guard_status()->>'pre_request_installed')::boolean,
  'the pre-request guard is installed on the API role');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000000164a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'c1613@deskilo.test', '', now(), now(), now());
select pg_temp.act_as('00000000-0000-4000-8000-0000000164a1');
select set_config('t.w', public.create_workspace('Contain', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select is((select count(*)::int from public.workspaces where id = current_setting('t.w')::uuid), 1,
  'a native session reads its workspace');
select is(pg_temp.pre('GET', '/workspaces'), 'allowed', 'a native session passes the pre-request guard');

select pg_temp.act_as('00000000-0000-4000-8000-0000000164a1', 'claude-test');
select is((select count(*)::int from public.workspaces where id = current_setting('t.w')::uuid), 0,
  'the same person with a delegated token reads nothing directly');
select is((select count(*)::int from public.members where workspace_id = current_setting('t.w')::uuid), 0,
  'not even their own membership');
update public.workspaces set name = 'written by a delegated token' where id = current_setting('t.w')::uuid;
select is(pg_temp.pre('GET', '/workspaces'), 'refused', 'a raw table route is refused');
select is(pg_temp.pre('POST', '/rpc/request_refund'), 'refused', 'a business RPC route is refused');
select is(pg_temp.pre('POST', '/rpc/mcp_execute_v1'), 'allowed', 'the facade is the one way in');
reset role;
select is((select name from public.workspaces where id = current_setting('t.w')::uuid), 'Contain',
  'and writes nothing: the update matched no row');
select ok(exists (select 1 from pg_policy p join pg_class c on c.oid = p.polrelid
                   join pg_namespace n on n.oid = c.relnamespace
                  where n.nspname = 'storage' and c.relname = 'objects' and p.polname = 'mcp_delegated_deny'
                    and not p.polpermissive),
  'Storage objects carry the restrictive denial');

-- PostgREST runs the pre-request as the request's own role: an anonymous
-- request must pass it, or every signed-out call answers 401.
reset role;
select ok(has_function_privilege('anon', 'public.mcp_is_delegated()', 'execute')
          and has_function_privilege('anon', 'public.mcp_pre_request()', 'execute'),
  'an anonymous request can run the guard');

drop policy mcp_delegated_deny on public.accessories;
select throws_ok($$select public.operator_set_mcp_runtime(true)$$, 'P0001', null,
  'the runtime stays off while any table lacks the denial');

select * from finish();
rollback;
