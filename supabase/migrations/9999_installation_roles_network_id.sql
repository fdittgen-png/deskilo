-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- Transforming: backfills workspaces.network_id on every existing row
-- (installation id : local id) before making it not null; no row is
-- deleted, no other column moves (user triggers are stood down for the
-- backfill so the modification stamp does not).
--
-- 9999 (#2561 L1) -- what kind of installation this database is, and the
-- network identity of every workspace it hosts.
--
-- A personal home is an ORDINARY installation on the same migration
-- stream (#2413 D1): same bundle, wizard and doctor, its workspace tables
-- simply empty. What tells the two apart at runtime is
-- `installation_identity.roles`:
--
--   {personal_home, workspace_host}  combined -- every installation today,
--                                    and the default, so nothing changes
--                                    on the day this lands;
--   {personal_home}                  a personal home: hosts no workspace;
--   {workspace_host}                 a workspace host: hosts spaces, is
--                                    nobody's home.
--
-- Three things follow from the roles:
--
--   * `operator_set_installation_roles` changes them. It is an operator
--     function in the sense of 0312/0318: SECURITY DEFINER, executable by
--     nobody the API lets in (revoked from public, anon, authenticated), so
--     only the operator's own tooling reaches it. It refuses to make an
--     installation a personal home while `workspaces` or `members` hold a
--     row (SQLSTATE DKR02): a role change never deletes or relocates
--     anything; it is not a deletion button. Every change is audited.
--   * `workspaces_hosted_here` refuses a workspace row on an installation
--     without `workspace_host` (SQLSTATE DKR01), BEFORE the row is written
--     and before anything that follows the row (members, numbering, the
--     twin). It guards the table, so every creation path -- create_workspace,
--     create_workspace_once, create_workspace_twin, an import -- refuses the
--     same way with the same words; the RPC's transaction rolls back whole.
--   * `public_network_descriptor()` advertises the roles and the capability
--     version each role carries (`personal@1`, `workspace@1`), so a client
--     can tell a personal home from a workspace host before it trusts one.
--     The descriptor stays SECURITY INVOKER: anonymous readers get the
--     `roles` column the way 0299 gave them `installation_id`, a column
--     grant under the existing read policy, never a definer door.
--
-- `workspaces.network_id` (#2413 D2) is the workspace's birth record:
-- `<installation id>:<local id>`, stamped by the server on insert (a value
-- a client sends is replaced, as the system columns are), unique, and never
-- updated. Equal local UUIDs on two installations are two distinct objects;
-- a workspace re-created elsewhere is a new object with a new record.

-- ── roles ────────────────────────────────────────────────────────────
alter table public.installation_identity
  add column if not exists roles text[] not null
    default array['personal_home', 'workspace_host']::text[];
alter table public.installation_identity
  drop constraint if exists installation_identity_roles_check;
alter table public.installation_identity
  add constraint installation_identity_roles_check check (
    roles <@ array['personal_home', 'workspace_host']::text[]
    and cardinality(roles) between 1 and 2
    and (cardinality(roles) = 1 or roles[1] <> roles[2]));
comment on column public.installation_identity.roles is
  '#2561 -- personal_home, workspace_host or both (combined, the default). '
  'Changed only by operator_set_installation_roles; advertised by '
  'public_network_descriptor().';
-- Anonymous discovery reads the roles the way it reads the installation
-- id (0299): one more column under the same policy.
grant select (roles) on public.installation_identity to anon, authenticated;

create or replace function public.operator_set_installation_roles(
  p_roles text[], p_installation_id uuid default null)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_roles text[];
  v_current text[];
  v_workspaces bigint;
  v_members bigint;
begin
  perform pg_advisory_xact_lock(hashtextextended('installation_roles', 2561));
  -- The operator names the installation they inspected; another database
  -- answering is a mismatched target, not a request to honour.
  if p_installation_id is not null
     and p_installation_id is distinct from public.installation_id() then
    raise exception 'this database is installation %, not %',
      public.installation_id(), p_installation_id using errcode = '55000';
  end if;
  select array_agg(distinct r order by r) into v_roles
    from unnest(coalesce(p_roles, '{}'::text[])) r;
  if v_roles is null
     or not (v_roles <@ array['personal_home', 'workspace_host']::text[]) then
    raise exception 'roles must be a non-empty subset of personal_home, workspace_host'
      using errcode = '22023';
  end if;
  select roles into v_current from public.installation_identity;
  if not ('workspace_host' = any (v_roles)) then
    select count(*) into v_workspaces from public.workspaces;
    select count(*) into v_members from public.members;
    if v_workspaces > 0 or v_members > 0 then
      raise exception 'a personal home hosts no workspace: this installation holds % workspaces and % members; nothing was changed or deleted',
        v_workspaces, v_members using errcode = 'DKR02';
    end if;
  end if;
  if v_current = v_roles then
    return jsonb_build_object('roles', to_jsonb(v_roles), 'unchanged', true);
  end if;
  update public.installation_identity set roles = v_roles;
  insert into public.database_authority_audit (installation_id, action, actor, detail)
  values (public.installation_id(), 'installation_roles_set', 'operator',
          jsonb_build_object('from', to_jsonb(v_current), 'to', to_jsonb(v_roles)));
  return jsonb_build_object('roles', to_jsonb(v_roles), 'unchanged', false);
end;
$fn$;
revoke execute on function public.operator_set_installation_roles(text[], uuid)
  from public, anon, authenticated;

-- The guard at the table: a workspace row exists only where the
-- installation hosts workspaces. SECURITY DEFINER so a definer caller and a
-- direct insert read the same singleton; the message is the one every
-- creation path shows.
create or replace function public.workspaces_hosted_here()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if not exists (select 1 from public.installation_identity
                  where 'workspace_host' = any (roles)) then
    raise exception 'this installation is a personal home and hosts no workspace'
      using errcode = 'DKR01',
            hint = 'operator_set_installation_roles adds workspace_host to an installation that should host workspaces';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.workspaces_hosted_here() from public, anon, authenticated;
drop trigger if exists workspaces_hosted_here on public.workspaces;
create trigger workspaces_hosted_here
  before insert on public.workspaces
  for each row execute function public.workspaces_hosted_here();

-- ── network_id ───────────────────────────────────────────────────────
alter table public.workspaces add column if not exists network_id text;
-- The backfill is the one write this file makes to existing rows. The
-- user triggers of workspaces (delegated columns, configuration guards, the
-- modification stamp) are stood down for it: a technical column arriving is
-- not an owner's edit.
alter table public.workspaces disable trigger user;
update public.workspaces
   set network_id = public.installation_id()::text || ':' || id::text
 where network_id is null;
alter table public.workspaces enable trigger user;
alter table public.workspaces alter column network_id set not null;
alter table public.workspaces drop constraint if exists workspaces_network_id_key;
alter table public.workspaces add constraint workspaces_network_id_key unique (network_id);
alter table public.workspaces drop constraint if exists workspaces_network_id_shape;
alter table public.workspaces add constraint workspaces_network_id_shape
  check (network_id ~ '^[0-9a-f-]{36}:[0-9a-f-]{36}$');
comment on column public.workspaces.network_id is
  '#2561 -- the birth record: installation id : local id, stamped by the '
  'server, unique, never updated. Equal local ids on two installations are '
  'two workspaces.';

-- The server names the birth. A client value is replaced, as the system
-- columns are (0184): the record says where the row was born, and only the
-- database knows that.
create or replace function public.workspaces_network_id_stamp()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  new.network_id := public.installation_id()::text || ':' || new.id::text;
  return new;
end;
$fn$;
revoke execute on function public.workspaces_network_id_stamp() from public, anon, authenticated;
drop trigger if exists workspaces_network_id_stamp on public.workspaces;
create trigger workspaces_network_id_stamp
  before insert on public.workspaces
  for each row execute function public.workspaces_network_id_stamp();

create or replace function public.workspaces_network_id_immutable()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if new.network_id is distinct from old.network_id then
    raise exception 'a workspace''s network id is its birth record and never changes';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.workspaces_network_id_immutable() from public, anon, authenticated;
drop trigger if exists workspaces_network_id_immutable on public.workspaces;
create trigger workspaces_network_id_immutable
  before update of network_id on public.workspaces
  for each row execute function public.workspaces_network_id_immutable();

-- ── the descriptor advertises the roles ──────────────────────────────
-- Generated from contracts/public_network/operations.json
-- (renderPublicNetworkDescriptorSql; test/tool/public_network_contract_test.dart
-- pins it). Stable now, not immutable: the roles are read live.
create or replace function public.public_network_descriptor()
returns jsonb
language sql
stable
set search_path = public
as $descriptor$
  select $json${"protocol":"deskilo.public-network","protocol_versions":[1],"capabilities":["operation_header"],"operations":[{"id":"network.descriptor.read","versions":[1],"requires":[]},{"id":"directory.sources.list","versions":[1],"requires":[]},{"id":"directory.workspaces.search","versions":[1],"requires":[]},{"id":"directory.workspaces.detail","versions":[1],"requires":[]},{"id":"directory.sources.register","versions":[1],"requires":[],"unlabelled":1},{"id":"workspace.profile.request","versions":[1],"requires":[],"unlabelled":1}]}$json$::jsonb
    || jsonb_build_object(
         'roles', to_jsonb(i.roles),
         'role_capabilities', coalesce((
           select jsonb_agg(c.capability order by c.ordinal)
             from (values (1, 'personal_home', 'personal@1'), (2, 'workspace_host', 'workspace@1')) as c (ordinal, role, capability)
            where c.role = any (i.roles)), '[]'::jsonb))
    from public.installation_identity i
$descriptor$;
revoke execute on function public.public_network_descriptor() from public;
grant execute on function public.public_network_descriptor() to anon, authenticated;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(9999);
