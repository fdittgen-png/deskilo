-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- #2562 C1c -- a token this installation issues to an enrolled
-- identity-only client (a workspace server signing a person in with
-- Deskilo) proves who the person is and reaches nothing else here.
--
-- OAuth `openid profile` scopes restrict the identity CLAIMS, not
-- database access: a Supabase OAuth access token keeps the user's role,
-- so without this boundary the workspace server holding it could replay
-- it against `/rest/v1`, Storage or Realtime as the person.
--
--   * `deskilo_identity` is the database role such a token carries:
--     NOLOGIN, not a superuser, no BYPASSRLS, member of nothing.
--     `authenticator` may switch to it for a valid JWT; it holds no table
--     privilege and no EXECUTE on any application function, so PostgREST
--     refuses every route (even the pre-request hook) for it.
--   * The Custom Access Token Hook (v2 of 0292) stamps that role on
--     tokens of enabled identity clients after their scopes passed. A
--     native session keeps its role; a token that claims the identity
--     role without being an identity client's is refused, so the role is
--     never a caller's choice.
--   * `personal_native_session()` is the one predicate for "a first-party
--     session of a person this installation still recognises": no
--     `client_id` (no delegated or identity token), not the identity
--     role, and the canonical account neither banned nor deleted. It is
--     a RESTRICTIVE policy on every personal table (RLS-enabled, no
--     `workspace_id` column) and on Storage objects, and the entry of
--     every definer that calls `mcp_require_native()`.
--   * No application function or table in `public` is reachable through
--     PUBLIC: an exploded ACL entry for grantee 0 is revoked, and a role
--     that held EXECUTE only through it (authenticated, service_role) is
--     granted it directly, so nothing native changes. anon is never
--     regranted: anon access only through PUBLIC is the #1048 accident.
--
-- Enabling the hook on a hosted project is an Auth setting, not SQL:
-- `dart run tool/instance.dart federation-hook --ref <ref> --apply`.
-- If that Auth cannot change `role`, split mode stays off (#2562).
-- pgTAP 268 proves the role, the hook, the predicate, the policies and
-- the effective privileges, and is the inventory ratchet a new personal
-- table without the policy fails.

do $role$
begin
  if not exists (select 1 from pg_roles where rolname = 'deskilo_identity') then
    create role deskilo_identity nologin noinherit nosuperuser nocreatedb
      nocreaterole noreplication nobypassrls;
  end if;
  if exists (select 1 from pg_roles where rolname = 'deskilo_identity'
              and (rolcanlogin or rolsuper or rolbypassrls or rolcreaterole
                   or rolcreatedb or rolreplication)) then
    raise exception '0564: deskilo_identity carries an attribute it must not have';
  end if;
  if exists (select 1 from pg_auth_members m
              where m.member = 'deskilo_identity'::regrole) then
    raise exception '0564: deskilo_identity is a member of another role';
  end if;
end
$role$;
grant deskilo_identity to authenticator;

-- No application object is reachable through PUBLIC.
do $public$
declare
  v_fn record;
  v_rel record;
  v_role text;
begin
  for v_fn in
    select p.oid, p.oid::regprocedure::text as sig
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and not exists (select 1 from pg_depend d
                        where d.classid = 'pg_proc'::regclass and d.objid = p.oid
                          and d.deptype = 'e')
       and exists (select 1 from aclexplode(coalesce(p.proacl,
                      acldefault('f', p.proowner))) a
                    where a.grantee = 0 and a.privilege_type = 'EXECUTE')
  loop
    foreach v_role in array array['authenticated', 'service_role'] loop
      if has_function_privilege(v_role, v_fn.oid, 'EXECUTE') then
        execute format('grant execute on function %s to %I', v_fn.sig, v_role);
      end if;
    end loop;
    execute format('revoke execute on function %s from public', v_fn.sig);
  end loop;
  for v_rel in
    select c.oid::regclass::text as rel
      from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind in ('r', 'p', 'v', 'm', 'S')
       and exists (select 1 from aclexplode(c.relacl) a where a.grantee = 0)
  loop
    execute format('revoke all on %s from public', v_rel.rel);
  end loop;
end
$public$;

create or replace function public.personal_native_session()
returns boolean language sql stable security definer set search_path = '' as $fn$
  select not (c.claims ? 'client_id')
     and coalesce(c.claims->>'role', '') <> 'deskilo_identity'
     and not exists (
       select 1 from auth.users u
        where u.id = auth.uid()
          and (u.deleted_at is not null or u.banned_until > now()))
    from (select coalesce(nullif(current_setting('request.jwt.claims', true), ''),
                          '{}')::jsonb as claims) c;
$fn$;
revoke execute on function public.personal_native_session() from public;
-- Policies run as the caller: every role a personal table answers to asks.
grant execute on function public.personal_native_session()
  to anon, authenticated, service_role, supabase_auth_admin;

-- The personal surfaces, derived from the schema: RLS-enabled tables of
-- `public` without a `workspace_id`, and Storage objects (the avatars).
do $personal$
declare
  v_table record;
begin
  for v_table in
    select n.nspname as schema_name, c.relname as table_name
      from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where c.relkind = 'r' and c.relrowsecurity
       and ((n.nspname = 'public'
             and not exists (select 1 from pg_attribute a
                              where a.attrelid = c.oid and a.attname = 'workspace_id'
                                and not a.attisdropped))
            or (n.nspname = 'storage' and c.relname = 'objects'))
  loop
    execute format('drop policy if exists personal_native_session on %I.%I',
                   v_table.schema_name, v_table.table_name);
    execute format(
      'create policy personal_native_session on %I.%I as restrictive for all to public '
      'using ((select public.personal_native_session())) '
      'with check ((select public.personal_native_session()))',
      v_table.schema_name, v_table.table_name);
  end loop;
end
$personal$;

-- Every definer that already demands a native session now also demands a
-- recognised one.
create or replace function public.mcp_require_native()
returns void language plpgsql stable set search_path = public as $fn$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if public.mcp_is_delegated() then raise exception 'connections are managed in the Deskilo app'; end if;
  if not public.personal_native_session() then raise exception 'identity_session_refused'; end if;
end;
$fn$;
revoke execute on function public.mcp_require_native() from public, anon, authenticated;

-- Hook v2: the 0292 scope rules, then the identity role.
create or replace function public.identity_federation_token_hook(event jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_claims jsonb := event->'claims';
  v_client text := v_claims->>'client_id';
  v_enabled boolean;
  v_scopes text[];
begin
  if jsonb_typeof(v_claims) is distinct from 'object' then
    raise sqlstate '28000' using message = 'invalid_identity_token_event';
  end if;
  if v_client is not null then
    select enabled into v_enabled from public.identity_federation_clients
      where client_id = v_client::uuid;
  end if;
  if v_client is null or v_enabled is null then
    if v_claims->>'role' = 'deskilo_identity' then
      raise sqlstate '28000' using message = 'identity_role_refused';
    end if;
    return jsonb_build_object('claims', v_claims);
  end if;
  if not v_enabled then
    raise sqlstate '28000' using message = 'identity_client_disabled';
  end if;
  if jsonb_typeof(v_claims->'scope') is distinct from 'string' then
    raise sqlstate '28000' using message = 'identity_client_scope_refused';
  end if;
  v_scopes := regexp_split_to_array(btrim(v_claims->>'scope'), '[[:space:]]+');
  if not ('openid' = any(v_scopes)) or not (v_scopes <@ array['openid', 'profile']) then
    raise sqlstate '28000' using message = 'identity_client_scope_refused';
  end if;
  return jsonb_build_object('claims', jsonb_set(v_claims, '{role}', '"deskilo_identity"'));
end;
$$;
revoke execute on function public.identity_federation_token_hook(jsonb)
  from public, anon, authenticated, service_role;
grant execute on function public.identity_federation_token_hook(jsonb) to supabase_auth_admin;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(564);
