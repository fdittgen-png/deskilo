-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0348 (#2085) -- the Administrator is a role.
--
-- Everyone in a workspace is a member, and what they can do beyond that
-- comes from their roles. "Admin" was the one exception: a flag on the
-- member row, with its permissions in the matrix and no place among the
-- roles. It becomes the built-in role **Administrator**:
--
--   * one `workspace_roles` row per workspace, `builtin = true`, key
--     `admin`. It can be renamed by the owner (`rename_administrator_role`)
--     and never deleted, put aside, redefined or carried by a template.
--   * **Its permissions do not move.** They stay where `has_permission`
--     reads them -- the matrix row `admin` and its defaults, plus the
--     legacy adminInvoicing grant -- so no resolver changes and nobody
--     gains or loses anything: an Administrator still holds viewAnalytics
--     by default (0340), and manageIntegrations only when an owner grants
--     it (#1826, 0317). The row's own `permissions` stay empty, and
--     `member_custom_permissions` skips built-in rows so the custom branch
--     can never count them twice.
--   * **Who holds it is `members.is_admin`, as before.** Every path that
--     writes it (the role_change quorum, co-ownership, succession, admin
--     invitations) keeps working unchanged, and so do `is_admin_of`, the
--     functions and policies that read the column, and old clients. A
--     trigger keeps a `workspace_role_members` row for each holder --
--     `is_admin` and neither owner nor active co-owner -- so the
--     Administrator lists its members like any other role.
--   * `assign_workspace_role` on the Administrator asks the validation
--     quorum through `request_role_change`, exactly as the member page
--     always did. Old clients keep calling `request_role_change` directly.
--   * The configuration export never carries the built-in row, and an
--     import in mirror mode never puts it aside.

alter table public.workspace_roles
  add column if not exists builtin boolean not null default false;
create unique index if not exists workspace_roles_one_builtin
  on public.workspace_roles (workspace_id) where builtin;

create or replace function public.administrator_role_names()
returns jsonb language sql immutable set search_path = public as $fn$
  select '{"en": "Administrator", "fr": "Administrateur·rice",
           "de": "Administrator:in", "es": "Administrador/a",
           "it": "Amministratore"}'::jsonb;
$fn$;

create or replace function public.ensure_administrator_role(p_workspace_id uuid)
returns uuid
language plpgsql security definer set search_path = public as $fn$
declare
  v_id uuid;
begin
  select r.id into v_id from public.workspace_roles r
   where r.workspace_id = p_workspace_id and r.builtin;
  if v_id is not null then return v_id; end if;
  -- The key `admin` is refused to every other door (0247, 0251), so no
  -- custom role can already hold it.
  insert into public.workspace_roles
    (workspace_id, key, permissions, names, sort_order, active, builtin)
  values (p_workspace_id, 'admin', '{}'::text[],
          public.administrator_role_names(), 0, true, true)
  returning id into v_id;
  return v_id;
end $fn$;

revoke execute on function public.ensure_administrator_role(uuid)
  from public, anon, authenticated;
revoke execute on function public.administrator_role_names()
  from public, anon;

-- Who holds the Administrator: is_admin, and neither owner nor active
-- co-owner (they hold every owner permission already).
create or replace function public.members_administrator_holding()
returns trigger
language plpgsql security definer set search_path = public as $fn$
declare
  v_role uuid;
  v_holds boolean := new.is_admin and not new.is_owner
                     and new.co_owner <> 'active';
begin
  if tg_op = 'INSERT' and not v_holds then return null; end if;
  if tg_op = 'UPDATE'
     and (old.is_admin and not old.is_owner and old.co_owner <> 'active')
         is not distinct from v_holds then
    return null;
  end if;
  v_role := public.ensure_administrator_role(new.workspace_id);
  if v_holds then
    insert into public.workspace_role_members (workspace_id, role_id, member_id)
    values (new.workspace_id, v_role, new.id)
    on conflict (role_id, member_id) do nothing;
  else
    delete from public.workspace_role_members
     where role_id = v_role and member_id = new.id;
  end if;
  return null;
end $fn$;

revoke execute on function public.members_administrator_holding()
  from public, anon, authenticated;

drop trigger if exists members_administrator_holding on public.members;
create trigger members_administrator_holding
  after insert or update of is_admin, is_owner, co_owner on public.members
  for each row execute function public.members_administrator_holding();

create or replace function public.workspaces_administrator_role()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  perform public.ensure_administrator_role(new.id);
  return null;
end $fn$;

revoke execute on function public.workspaces_administrator_role()
  from public, anon, authenticated;

drop trigger if exists workspaces_administrator_role on public.workspaces;
create trigger workspaces_administrator_role
  after insert on public.workspaces
  for each row execute function public.workspaces_administrator_role();

-- Backfill: one row per workspace, one holder row per Administrator.
select public.ensure_administrator_role(w.id) from public.workspaces w;
insert into public.workspace_role_members (workspace_id, role_id, member_id)
select m.workspace_id, r.id, m.id
  from public.members m
  join public.workspace_roles r on r.workspace_id = m.workspace_id and r.builtin
 where m.is_admin and not m.is_owner and m.co_owner <> 'active'
on conflict (role_id, member_id) do nothing;

-- The custom branch never counts a built-in row.
create or replace function public.member_custom_permissions(p_member_id uuid)
returns text[]
language sql stable security definer set search_path = public as $fn$
  select coalesce(array_agg(distinct p), '{}'::text[])
    from public.workspace_role_members rm
    join public.workspace_roles r on r.id = rm.role_id and r.active
                                 and not r.builtin
    cross join unnest(r.permissions) p
   where rm.member_id = p_member_id;
$fn$;

revoke execute on function public.member_custom_permissions(uuid) from public, anon;
grant execute on function public.member_custom_permissions(uuid) to authenticated;

-- Renaming is the owner's, as defining a role is (0255).
create or replace function public.rename_administrator_role(
  p_workspace_id uuid, p_names jsonb
) returns void
language plpgsql security definer set search_path = public as $fn$
declare
  v_locale text;
begin
  if auth.uid() is null or not public.is_owner_of(p_workspace_id) then
    raise exception 'only an owner defines the roles of a workspace';
  end if;
  if p_names is null or jsonb_typeof(p_names) <> 'object'
     or p_names = '{}'::jsonb then
    raise exception 'the Administrator needs a name';
  end if;
  for v_locale in select jsonb_object_keys(p_names) loop
    if v_locale not in ('en', 'fr', 'de', 'es', 'it') then
      raise exception 'unsupported locale %', v_locale;
    end if;
    if jsonb_typeof(p_names->v_locale) <> 'string'
       or btrim(p_names->>v_locale) = '' then
      raise exception 'the name for % is empty', v_locale;
    end if;
  end loop;
  perform public.ensure_administrator_role(p_workspace_id);
  update public.workspace_roles set names = p_names
   where workspace_id = p_workspace_id and builtin;
end $fn$;

revoke execute on function public.rename_administrator_role(uuid, jsonb)
  from public, anon;
grant execute on function public.rename_administrator_role(uuid, jsonb)
  to authenticated;

-- The export carries what a space defined, never the built-in row.
create or replace function public.workspace_roles_export(p_workspace_id uuid)
returns jsonb
language sql stable security definer set search_path = public as $fn$
  select coalesce(jsonb_agg(jsonb_build_object(
      'key', r.key, 'permissions', to_jsonb(r.permissions),
      'names', r.names, 'sort_order', r.sort_order, 'active', r.active)
      order by r.sort_order, r.key), '[]'::jsonb)
    from public.workspace_roles r
   where r.workspace_id = p_workspace_id and not r.builtin;
$fn$;

revoke execute on function public.workspace_roles_export(uuid)
  from public, anon, authenticated;

-- The 0255 import, with the built-in row left out of both mirror
-- clauses: an import never puts the Administrator aside.
create or replace function public.workspace_roles_import(
  p_workspace_id uuid, p_roles jsonb, p_mode text
) returns void
language plpgsql security definer set search_path = public as $fn$
declare
  e jsonb;
  v_perm text;
  v_changes boolean := false;
  v_current public.workspace_roles%rowtype;
begin
  if p_roles is null then return; end if;

  for e in select jsonb_array_elements(p_roles) loop
    if e->>'key' in ('owner', 'co_owner', 'admin', 'member') then
      raise exception 'the built-in roles are not redefined here';
    end if;
    for v_perm in select jsonb_array_elements_text(coalesce(e->'permissions', '[]'::jsonb)) loop
      if not (v_perm = any(public.role_permission_catalog())) then
        raise exception 'unknown permission %', v_perm;
      end if;
    end loop;

    select * into v_current from public.workspace_roles r
     where r.workspace_id = p_workspace_id and r.key = e->>'key';

    if not found then
      v_changes := true;
    elsif v_current.permissions is distinct from
            coalesce((select array_agg(value)
                        from jsonb_array_elements_text(e->'permissions')), '{}'::text[])
       or v_current.names is distinct from coalesce(e->'names', '{}'::jsonb)
       or v_current.sort_order is distinct from coalesce((e->>'sort_order')::int, 0)
       or v_current.active is distinct from coalesce((e->>'active')::boolean, true)
    then
      v_changes := true;
    end if;
  end loop;

  if p_mode = 'mirror' and exists (
       select 1 from public.workspace_roles r
        where r.workspace_id = p_workspace_id
          and r.active
          and not r.builtin
          and not exists (select 1 from jsonb_array_elements(p_roles) e2
                           where e2.value->>'key' = r.key))
  then
    v_changes := true;
  end if;

  if v_changes and (auth.uid() is null or not public.is_owner_of(p_workspace_id)) then
    raise exception 'only an owner defines the roles of a workspace';
  end if;

  if not v_changes then return; end if;

  for e in select jsonb_array_elements(p_roles) loop
    insert into public.workspace_roles
      (workspace_id, key, permissions, names, sort_order, active)
    values (p_workspace_id, e->>'key',
            coalesce((select array_agg(value) from jsonb_array_elements_text(e->'permissions')),
                     '{}'::text[]),
            coalesce(e->'names', '{}'::jsonb),
            coalesce((e->>'sort_order')::int, 0),
            coalesce((e->>'active')::boolean, true))
    on conflict (workspace_id, key) do update
      set permissions = excluded.permissions, names = excluded.names,
          sort_order = excluded.sort_order, active = excluded.active;
  end loop;

  if p_mode = 'mirror' then
    update public.workspace_roles r set active = false
     where r.workspace_id = p_workspace_id
       and not r.builtin
       and not exists (select 1 from jsonb_array_elements(p_roles) e
                        where e.value->>'key' = r.key);
  end if;
end $fn$;

revoke execute on function public.workspace_roles_import(uuid, jsonb, text)
  from public, anon, authenticated;

-- assign_workspace_role: the 0341 body, plus the Administrator branch.
create or replace function public.assign_workspace_role(
  p_member_id uuid, p_role_id uuid, p_assign boolean default true
) returns void
language plpgsql security definer set search_path = public as $fn$
declare
  v_subject public.members;
  v_role public.workspace_roles;
  v_actor uuid;
  v_perm text;
begin
  select * into v_subject from public.members m where m.id = p_member_id;
  if v_subject.id is null then raise exception 'unknown member'; end if;
  select * into v_role from public.workspace_roles r where r.id = p_role_id;
  if v_role.id is null or v_role.workspace_id <> v_subject.workspace_id then
    raise exception 'that role belongs to another workspace';
  end if;
  -- The Administrator goes through the validation quorum, as the member
  -- page always did: `request_role_change` asks for the owner, refuses
  -- the owner as a target and a change that changes nothing.
  if v_role.builtin then
    if v_subject.user_id = auth.uid() then
      raise exception 'a role is never assigned to yourself';
    end if;
    perform public.request_role_change(v_subject.workspace_id, v_subject.id, p_assign);
    return;
  end if;
  if auth.uid() is null
     or not public.has_permission(v_subject.workspace_id, 'manageRoles') then
    raise exception 'only someone who manages the roles may assign one';
  end if;
  if v_subject.user_id = auth.uid() then
    raise exception 'a role is never assigned to yourself';
  end if;
  if not public.feature_effective(v_subject.workspace_id, 'customRoles') then
    raise exception 'custom roles are off in this workspace';
  end if;

  -- #2085 -- the owner gives anything; anybody else only what they hold,
  -- and never the power to give roles.
  if not public.is_owner_of(v_subject.workspace_id) then
    if 'manageRoles' = any(v_role.permissions) then
      raise exception 'only an owner gives a role that manages roles';
    end if;
    foreach v_perm in array v_role.permissions loop
      if not public.has_permission(v_subject.workspace_id, v_perm) then
        raise exception 'a role is given only by someone who holds what it gives';
      end if;
    end loop;
  end if;

  if p_assign then
    if v_subject.is_kiosk or v_subject.status <> 'active' then
      raise exception 'this member cannot hold a role';
    end if;
    if not v_role.active then
      raise exception 'that role was put aside';
    end if;
  end if;

  select m.id into v_actor from public.members m
   where m.workspace_id = v_subject.workspace_id and m.user_id = auth.uid()
     and m.status = 'active';

  if p_assign then
    insert into public.workspace_role_members (workspace_id, role_id, member_id)
    values (v_subject.workspace_id, p_role_id, p_member_id)
    on conflict (role_id, member_id) do nothing;
  else
    delete from public.workspace_role_members
     where role_id = p_role_id and member_id = p_member_id;
  end if;

  -- Only a change is recorded: giving a role somebody already holds, or
  -- taking back one they do not, writes nothing.
  if found then
    perform public.record_applied_event(
      v_subject.workspace_id, 'role_change', v_actor, v_subject.id,
      jsonb_build_object('role_key', v_role.key, 'role_id', v_role.id,
                         'role_names', v_role.names, 'assign', p_assign));
  end if;
end $fn$;

revoke execute on function public.assign_workspace_role(uuid, uuid, boolean)
  from public, anon;
grant execute on function public.assign_workspace_role(uuid, uuid, boolean)
  to authenticated;


notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(348);
