-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1826 / 0313: what a workspace exposes to assistants is delegated by the
-- role matrix. The owner always may; an admin may only once the owner has
-- granted `manageIntegrations`; a plain member never. The three routines
-- behind the screen (policy status, policy save, usage summary) answer the
-- same way, and revoking the grant closes them again. Callers run as
-- `authenticated`; seeds run as postgres.
begin;
select plan(9);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000001826a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner-1826@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000001826a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin-1826@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000001826a3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'member-1826@deskilo.test', '', now(), now(), now());

select pg_temp.act_as('00000000-0000-4000-8000-0000001826a1');
select set_config('t.ws', public.create_workspace('Assistant Role', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
insert into public.members (workspace_id, user_id, status, is_admin) values
 (current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000001826a2', 'active', true),
 (current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000001826a3', 'active', false);

-- ── the owner, always ────────────────────────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000001826a1');
select lives_ok($$select public.mcp_policy_status(current_setting('t.ws')::uuid)$$, 'the owner reads the policy');
select lives_ok($$select public.save_mcp_policy(current_setting('t.ws')::uuid, 0, '00000000-0000-4000-8000-000000182601', false,
  array['get_capabilities'], 'own', null, null)$$, 'the owner saves the policy');
select lives_ok($$select public.mcp_usage_summary_workspace(current_setting('t.ws')::uuid)$$, 'the owner reads the usage');

-- ── an admin without the grant, and a member ────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000001826a2');
select throws_ok($$select public.mcp_policy_status(current_setting('t.ws')::uuid)$$, 'P0001', null, 'an admin without the grant cannot read the policy');
select throws_ok($$select public.save_mcp_policy(current_setting('t.ws')::uuid, 1, '00000000-0000-4000-8000-000000182602', false,
  array['get_capabilities'], 'own', null, null)$$, 'P0001', null, 'an admin without the grant cannot save the policy');
select pg_temp.act_as('00000000-0000-4000-8000-0000001826a3');
select throws_ok($$select public.mcp_policy_status(current_setting('t.ws')::uuid)$$, 'P0001', null, 'a member cannot read the policy');

-- ── the owner delegates it through the matrix ───────────────────────
reset role;
update public.workspaces set role_permissions = jsonb_set(coalesce(role_permissions, '{}'::jsonb), '{admin}', '["manageIntegrations"]'::jsonb)
 where id = current_setting('t.ws')::uuid;
select pg_temp.act_as('00000000-0000-4000-8000-0000001826a2');
select lives_ok($$select public.mcp_policy_status(current_setting('t.ws')::uuid)$$, 'a delegated admin reads the policy');
select lives_ok($$select public.save_mcp_policy(current_setting('t.ws')::uuid, 1, '00000000-0000-4000-8000-000000182603', false,
  array['get_capabilities'], 'own', null, null)$$, 'a delegated admin saves the policy');

-- ── and takes it back ───────────────────────────────────────────────
reset role;
update public.workspaces set role_permissions = jsonb_set(role_permissions, '{admin}', '[]'::jsonb)
 where id = current_setting('t.ws')::uuid;
select pg_temp.act_as('00000000-0000-4000-8000-0000001826a2');
select throws_ok($$select public.save_mcp_policy(current_setting('t.ws')::uuid, 2, '00000000-0000-4000-8000-000000182604', false,
  array['get_capabilities'], 'own', null, null)$$, 'P0001', null, 'the grant taken back closes the save again');

select * from finish();
rollback;
