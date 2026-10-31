-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2562 C2c: the enrolled workspace installations a person may create a
-- workspace on. The reader is a definer only a native personal session
-- calls (never anon, a delegated token or an identity-only token); it lists
-- each enrolment in force with its origin, publishable key and state
-- (available, not_accepting, unverified), never a revoked one, never the
-- roles, capabilities or who enrolled it, and says whether this
-- installation hosts workspaces itself. Reading changes nothing.
--
-- Every write goes through the operator functions as the owner; roles are
-- switched only at the end and reset after each scene.
begin;
select plan(18);

create function pg_temp.id(p_tail text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-' || p_tail)::uuid $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.inst(p_c text) returns uuid language sql as $$
  select pg_temp.id('0000025620c' || p_c) $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.me() returns uuid language sql as $$
  select pg_temp.id('00002562c201') $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.hosts(p_claims jsonb default '{}') returns jsonb language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    (jsonb_build_object('sub', pg_temp.me(), 'role', 'authenticated') || p_claims)::text, true);
  return public.my_workspace_hosts_v1();
end $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
-- The fixture hosts only, as "letter:state" in the reader's order.
create function pg_temp.states(p jsonb) returns text language sql as $$
  select coalesce(string_agg(right(h->>'installation_id', 1) || ':' || (h->>'state'), ',' order by o), '')
    from jsonb_array_elements(p->'hosts') with ordinality x(h, o)
   where left(h->>'installation_id', 35) = '00000000-0000-4000-8000-0000025620c' $$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- ── fixtures ──────────────────────────────────────────────────────────
select public.operator_set_installation_roles(array['personal_home', 'workspace_host']);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values (pg_temp.me(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
        'c2c-2562@deskilo.test', '', now(), now(), now());
-- a: accepting, with an enabled identity client; b: accepting, its client
-- disabled; c: closed to new workspaces; d: enrolled, then revoked.
select public.operator_enrol_installation(pg_temp.inst(c), 'https://w-' || c || '.c2c.test',
         'sb_publishable_w' || c || '_key_123', array['workspace_host'], array['workspace@1'], c <> 'c')
  from unnest(array['a', 'b', 'c', 'd']) c;
insert into public.identity_federation_clients (client_id, target_installation_id, target_auth_url, enabled)
values (pg_temp.id('0000025620e1'), pg_temp.inst('a'), 'https://w-a.c2c.test/auth/v1', true),
       (pg_temp.id('0000025620e2'), pg_temp.inst('b'), 'https://w-b.c2c.test/auth/v1', false),
       (pg_temp.id('0000025620e3'), pg_temp.inst('c'), 'https://w-c.c2c.test/auth/v1', true),
       (pg_temp.id('0000025620e4'), pg_temp.inst('d'), 'https://w-d.c2c.test/auth/v1', true);
select public.operator_revoke_installation(pg_temp.inst('d'));

-- ── the door ──────────────────────────────────────────────────────────
select ok((select prosecdef from pg_proc where oid = 'public.my_workspace_hosts_v1()'::regprocedure),
  'the reader is a definer');
select is(has_function_privilege('anon', 'public.my_workspace_hosts_v1()', 'EXECUTE')::text, 'false',
  'anon does not execute it');
select is(has_function_privilege('deskilo_identity', 'public.my_workspace_hosts_v1()', 'EXECUTE')::text, 'false',
  'an identity-only token does not execute it');
select is(has_function_privilege('authenticated', 'public.my_workspace_hosts_v1()', 'EXECUTE')::text, 'true',
  'a signed-in person executes it');

-- ── what it says ──────────────────────────────────────────────────────
select is(pg_temp.states(pg_temp.hosts()), 'a:available,b:unverified,c:not_accepting',
  'each enrolment in force with its state, by origin; the revoked one is absent');
select is((select h->>'origin' || ' ' || (h->>'publishable_key')
             from jsonb_array_elements(pg_temp.hosts()->'hosts') h
            where h->>'installation_id' = pg_temp.inst('a')::text),
  'https://w-a.c2c.test sb_publishable_wa_key_123', 'with its origin and its publishable key');
select is((select string_agg(distinct k, ',' order by k)
             from jsonb_array_elements(pg_temp.hosts()->'hosts') h, jsonb_object_keys(h) k),
  'installation_id,origin,publishable_key,state',
  'never its roles, capabilities, enrolment dates or who enrolled it');
select is((pg_temp.hosts()->>'here_hosts'), 'true', 'this installation hosts workspaces itself');

-- ── it follows the operator ───────────────────────────────────────────
update public.identity_federation_clients set enabled = true where client_id = pg_temp.id('0000025620e2');
select is(pg_temp.states(pg_temp.hosts()), 'a:available,b:available,c:not_accepting',
  'an identity client enabled for b makes it available');
select public.operator_enrol_installation(pg_temp.inst('d'), 'https://w-d.c2c.test',
  'sb_publishable_wd_key_123', array['workspace_host'], array['workspace@1'], true);
select is(pg_temp.states(pg_temp.hosts()), 'a:available,b:available,c:not_accepting,d:available',
  're-enrolled, d is listed again');
select public.operator_revoke_installation(pg_temp.inst('a'));
select is(pg_temp.states(pg_temp.hosts()), 'b:available,c:not_accepting,d:available',
  'revoked, a is gone at once');
select is((select count(*)::int from public.enrolled_installations
            where installation_id in (pg_temp.inst('a'), pg_temp.inst('b'), pg_temp.inst('c'), pg_temp.inst('d'))
              and enabled), 3, 'reading changed no enrolment');

-- ── who is refused ────────────────────────────────────────────────────
select throws_ok($$select pg_temp.hosts('{"client_id":"00000000-0000-4000-8000-0000025620e1"}')$$,
  'P0001', 'connections are managed in the Deskilo app', 'a delegated token is refused');
select throws_ok($$select pg_temp.hosts('{"role":"deskilo_identity"}')$$,
  'P0001', 'identity_session_refused', 'an identity-only session is refused');
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
select throws_ok($$select public.my_workspace_hosts_v1()$$, 'P0001', 'not authenticated',
  'no account, no list');

-- ── as the API roles ──────────────────────────────────────────────────
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00002562c201","role":"authenticated"}', true);
set local role authenticated;
select is(jsonb_typeof(public.my_workspace_hosts_v1()->'hosts'), 'array',
  'the signed-in person reads the list');
reset role;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok($$select public.my_workspace_hosts_v1()$$, '42501', null,
  'an anonymous caller reads nothing');
reset role;
select set_config('request.jwt.claims', '', true);
select is((select count(*)::int from public.database_authority_audit
            where detail->>'enrolled_installation_id' = pg_temp.inst('b')::text), 1,
  'b was audited once, by its enrolment; reading wrote nothing');

select * from finish();
rollback;
