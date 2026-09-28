-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1645 / 0304: a seat's name leaves the database only when the
-- installation maximum, the workspace policy and the person's consent for
-- this client and workspace all name it, and only as the native read
-- returned it. Each negative case removes ONE layer; workspace A never
-- decides for workspace B; the owner cannot exceed the maximum; consent
-- cannot exceed the policy; unknown names are refused everywhere.
begin;
select plan(16);

create function pg_temp.act_as(p_user uuid, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2', 'client_id', p_client))::text, true);
  execute 'set local role authenticated';
end;
$$;
-- The member's availability answer in a workspace, through a client.
create function pg_temp.avail(p_ws text, p_client text default 'claude-test') returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.act_as('00000000-0000-4000-8000-0000001645a2', p_client);
  v := public.mcp_execute_v1(current_setting('t.i')::uuid, current_setting('t.' || p_ws)::uuid, 'get_availability',
         jsonb_build_object('starts_at', current_setting('t.s'), 'ends_at', current_setting('t.e')), null);
  execute 'reset role';
  return v;
end;
$$;
-- How many items carry a name.
create function pg_temp.named(p_ws text, p_client text default 'claude-test') returns integer language sql as $$
  select count(*)::integer from jsonb_array_elements(pg_temp.avail(p_ws, p_client)->'data'->'items') r where r ? 'name';
$$;
-- The refusal a statement raises for a caller, or 'no error'.
create function pg_temp.err(p_user uuid, p_client text, p_sql text) returns text language plpgsql as $$
begin
  perform pg_temp.act_as(p_user, p_client);
  begin
    execute p_sql;
  exception when others then
    execute 'reset role';
    return sqlerrm;
  end;
  execute 'reset role';
  return 'no error';
end;
$$;
-- The owner saves workspace X's policy with these optional fields.
create function pg_temp.policy(p_ws text, p_fields text[]) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.act_as('00000000-0000-4000-8000-0000001645a1');
  v := public.save_mcp_policy(current_setting('t.' || p_ws)::uuid,
         (public.mcp_policy_status(current_setting('t.' || p_ws)::uuid)->>'revision')::integer, gen_random_uuid(),
         true, array['get_availability'], 'workspace', null, p_fields);
  execute 'reset role';
  return v;
end;
$$;
create function pg_temp.maximum(p_fields text[]) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.act_as('00000000-0000-4000-8000-0000001645a1');
  v := public.set_mcp_disclosure_maximum(p_fields);
  execute 'reset role';
  return v;
end;
$$;
-- The member's consent for a client in a workspace, seeded as postgres.
create function pg_temp.consent(p_ws text, p_fields text[], p_client text default 'claude-test') returns void language sql as $$
  update public.mcp_connection_scopes s set optional_fields = p_fields
    from public.mcp_connections c
   where c.id = s.connection_id and c.client_id = p_client
     and c.local_user_id = '00000000-0000-4000-8000-0000001645a2'
     and s.workspace_id = current_setting('t.' || p_ws)::uuid;
$$;

select set_config('t.i', public.installation_id()::text, true);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000001645a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'own-1645@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000001645a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'mem-1645@deskilo.test', '', now(), now(), now());
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
insert into public.mcp_clients (client_id, name) values ('claude-test', 'Test assistant'), ('other-test', 'Other assistant')
  on conflict do nothing;
update public.mcp_runtime set enabled = true;
update public.mcp_disclosure_maximum set optional_fields = '{}';
select pg_temp.act_as('00000000-0000-4000-8000-0000001645a1');
select public.finalize_identity_binding();
select set_config('t.a', public.create_workspace('MCP D A', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select public.apply_workspace_template(current_setting('t.a')::uuid, (select id from public.workspace_templates where key = 'tiny'));
select set_config('t.b', public.create_workspace('MCP D B', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select public.apply_workspace_template(current_setting('t.b')::uuid, (select id from public.workspace_templates where key = 'tiny'));
select pg_temp.act_as('00000000-0000-4000-8000-0000001645a2');
select public.finalize_identity_binding();
reset role;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"mcpAccess": true}'
 where id in (current_setting('t.a')::uuid, current_setting('t.b')::uuid);
insert into public.members (workspace_id, user_id, status)
select w, '00000000-0000-4000-8000-0000001645a2', 'active'
  from unnest(array[current_setting('t.a')::uuid, current_setting('t.b')::uuid]) w;
select set_config('t.seat', (select id::text from public.seats where workspace_id = current_setting('t.a')::uuid order by name limit 1), true);
select public.operator_grant_database_admin('00000000-0000-4000-8000-0000001645a1');
select pg_temp.act_as('00000000-0000-4000-8000-0000001645a1');
select public.decide_mcp_eligibility('00000000-0000-4000-8000-0000001645a2', '00000000-0000-4000-8000-00000000e645', true);
reset role;
select pg_temp.policy('a', '{}');
select pg_temp.policy('b', '{}');
insert into public.mcp_connections (installation_id, local_user_id, binding_id, client_id)
select public.installation_id(), local_user_id, id, k from public.identity_bindings,
       unnest(array['claude-test', 'other-test']) k
 where local_user_id = '00000000-0000-4000-8000-0000001645a2' and status = 'active';
insert into public.mcp_connection_scopes (connection_id, workspace_id, operations, target_ceiling)
select c.id, w, array['get_availability'], 'workspace'
  from public.mcp_connections c, unnest(array[current_setting('t.a')::uuid, current_setting('t.b')::uuid]) w
 where c.local_user_id = '00000000-0000-4000-8000-0000001645a2';
select set_config('t.day', ((now() at time zone 'Europe/Paris')::date + 2)::text, true);
select set_config('t.s', to_jsonb((current_setting('t.day') || ' 08:00')::timestamp at time zone 'Europe/Paris')->>0, true);
select set_config('t.e', to_jsonb((current_setting('t.day') || ' 12:00')::timestamp at time zone 'Europe/Paris')->>0, true);

-- 1. By default no layer names a field: the answer is minimized.
select is(pg_temp.avail('a')->>'status' || '/' || pg_temp.named('a'), 'completed/0',
  'by default a seat''s name is absent');

-- 2. The owner cannot expose what the database does not allow.
select is(pg_temp.err('00000000-0000-4000-8000-0000001645a1', null,
  format('select public.save_mcp_policy(%L, 1, gen_random_uuid(), true, array[''get_availability''], ''workspace'', null, array[''name''])',
         current_setting('t.a'))),
  'field name is above this database''s disclosure maximum', 'a policy above the installation maximum is refused');

-- All four layers name it in A; B's owner does not; the other client has no consent.
select pg_temp.maximum(array['name']);
select pg_temp.policy('a', array['name']);
select pg_temp.consent('a', array['name']);
select pg_temp.consent('b', array['name']);

-- 3. Present, as the native read returned it.
select ok(exists (select 1 from jsonb_array_elements(pg_temp.avail('a')->'data'->'items') r
                   where r->>'seat_id' = current_setting('t.seat')
                     and r->>'name' = (select name from public.seats where id = current_setting('t.seat')::uuid)),
  'with the maximum, the policy and the consent, the seat''s own name is sent');
select is(pg_temp.named('a'), (select count(*)::integer from public.seats where workspace_id = current_setting('t.a')::uuid),
  'every seat in the answer carries it');

-- 4. B: only its policy lacks the field.
select is(pg_temp.named('b'), 0, 'workspace A''s policy never discloses in workspace B');

-- 5. The same person, the same workspace, another client without consent.
select is(pg_temp.named('a', 'other-test'), 0, 'consent belongs to one client: another assistant gets no name');

-- 6. Only the maximum removed.
select pg_temp.maximum('{}');
select is(pg_temp.named('a'), 0, 'lowering the installation maximum strips it');
select pg_temp.maximum(array['name']);

-- 7. Only the policy removed.
select pg_temp.policy('a', '{}');
select is(pg_temp.named('a'), 0, 'removing it from the workspace policy strips it');
select pg_temp.policy('a', array['name']);

-- 8. Only the consent removed.
select pg_temp.consent('a', '{}');
select is(pg_temp.named('a'), 0, 'removing it from the consent strips it');
select pg_temp.consent('a', array['name']);

-- 9. Restored: every layer again, the field again.
select ok(pg_temp.named('a') > 0, 'restoring the three layers sends it again');

-- 10. Consent above the policy (B offers no field) is refused.
select is(pg_temp.err('00000000-0000-4000-8000-0000001645a2', null,
  format('select public.mcp_prepare_connection(''claude-test'', ''authz-1645-b'', %L::jsonb)',
         jsonb_build_array(jsonb_build_object('workspace_id', current_setting('t.b'),
           'operations', array['get_availability'], 'optional_fields', array['name'])))),
  'field name is not offered there', 'consent above the workspace policy is refused');

-- 11. Consent within the policy is recorded, field by name.
select pg_temp.act_as('00000000-0000-4000-8000-0000001645a2');
select set_config('t.prep', public.mcp_prepare_connection('claude-test', 'authz-1645-a',
  jsonb_build_array(jsonb_build_object('workspace_id', current_setting('t.a'),
    'operations', array['get_availability'], 'optional_fields', array['name'])))::text, true);
reset role;
select is(current_setting('t.prep')::jsonb->'scopes'->0->'optional_fields', '["name"]'::jsonb,
  'consent within the policy is prepared with exactly the named field');

-- 12–14. Unknown names are refused by every layer.
select is(pg_temp.err('00000000-0000-4000-8000-0000001645a1', null,
  'select public.set_mcp_disclosure_maximum(array[''email''])'),
  'unknown optional field email', 'an unknown field is refused for the maximum');
select is(pg_temp.err('00000000-0000-4000-8000-0000001645a1', null,
  format('select public.save_mcp_policy(%L, 0, gen_random_uuid(), true, array[''get_availability''], ''workspace'', null, array[''email''])',
         current_setting('t.a'))),
  'unknown optional field email', 'an unknown field is refused for the policy');
select is(pg_temp.err('00000000-0000-4000-8000-0000001645a2', null,
  format('select public.mcp_prepare_connection(''claude-test'', ''authz-1645-c'', %L::jsonb)',
         jsonb_build_array(jsonb_build_object('workspace_id', current_setting('t.a'),
           'operations', array['get_availability'], 'optional_fields', array['email'])))),
  'unknown optional field email', 'an unknown field is refused for consent');

-- 15. The maximum is a database administrator's, not a member's or an assistant's.
select is(pg_temp.err('00000000-0000-4000-8000-0000001645a2', null,
  'select public.set_mcp_disclosure_maximum(array[''name''])'),
  'not a database administrator here', 'a member cannot set the installation maximum');

select * from finish();
rollback;
