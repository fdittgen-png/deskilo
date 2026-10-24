-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- Additive: two settings rows, one private helper and one reader. No table,
-- no policy, no grant on a table; no existing function is restated.
--
-- #2472 (P) -- the new discussion at the personal home: who I can write to,
-- by workspace, and my groups, read where my account lives.
--
--   my_personal_message_directory_v1(p_section, p_workspace_network_id,
--                                    p_after_key, p_query)
--
-- Sections:
--   * workspaces -- my relationships: a local membership in force (active,
--     in a workspace whose community directory is on, as 0547 asked) or a
--     verified membership fact in force (#2563 C2, status active). Each
--     item {network_id, installation_id, workspace_id, permitted_name}; the
--     name only for a workspace this database hosts, never a copy of a
--     remote one;
--   * people -- for ONE of my workspaces (its network id): the other
--     accounts of THIS home that hold the same relationship (local active
--     membership, or an active fact in force for the same network id),
--     filtered by the policy that already decides messaging:
--     `visible_account(candidate).can_message` (blocks either way, the
--     reachability audience, an accepted conversation). Each item
--     {person_id (this home's account id), personal_home_id,
--     context_workspace_ref, view (the redacted projection)}. A name the
--     person hides is neither returned, nor searched, nor sorted on;
--   * groups -- the account groups I am in now, whether or not they have a
--     message: {group_id, title, announce_only, can_write}, can_write the
--     0384 rule (not announce-only, or I am one of its admins).
--
-- Authorization reads memberships, verified facts, blocks, audiences and
-- group memberships; never a self-editable profiles column. A workspace I
-- hold no relationship with is refused (42501), never answered empty; a
-- relationship whose fact lapsed answers no items with
-- `relationship_status: 'unavailable'`, so a stale source never reads as
-- "nobody". The sections say `ready`, `partial` (some of my facts lapsed)
-- or `unavailable` (all of them, and nothing local).
--
-- Keyset paging, ascending on the section's key (network id, person id,
-- group id); the cursor is the last key returned and must have that
-- section's shape. One more row than the page tells has_more AFTER every
-- visibility and search filter; no total is ever returned. The query is
-- literal (`%`, `_` and `\` escaped), case-insensitive, from the first
-- character. Page size and longest query come from the platform settings
-- (resolved once, no workspace):
--
--   personal.message_directory_page_size    1..100, default 50
--   personal.message_directory_query_length 1..200, default 120
--
-- First-party native sessions only (mcp_require_native: no anonymous
-- caller, no delegated assistant, no identity-only upstream token);
-- executable by authenticated alone.

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('personal.message_directory_page_size', 'int', '50'::jsonb, 1, 100, 'rows', 'personal', array['platform'], 'workspaceSettings', null, true, null, 'my_personal_message_directory_v1 (#2472)', 'How many workspaces, people or groups the personal home returns per page of the new-discussion directory. A bound on one read, not on who may be written to.'),
('personal.message_directory_query_length', 'int', '120'::jsonb, 1, 200, 'characters', 'personal', array['platform'], 'workspaceSettings', null, true, null, 'my_personal_message_directory_v1 (#2472)', 'The longest text the new-discussion directory searches for; a longer one is refused, never cut. A query default, not a rule about names.')
on conflict (key) do nothing;
-- END GENERATED SEED

-- My relationships, local and verified: one row per workspace network id,
-- fresh while it can authorize anything. Private: only the reader asks.
create or replace function public.personal_directory_relationships(p_user uuid)
returns table (network_id text, permitted_name text, fresh boolean)
language sql
stable
security definer
set search_path = public
as $fn$
  select w.network_id, w.name, true
    from public.members m
    join public.workspaces w on w.id = m.workspace_id
   where m.user_id = p_user and m.status = 'active'
     and public.feature_effective(w.id, 'membersDirectory')
  union
  select f.network_id, null::text,
         public.membership_fact_in_force(p_user, f.network_id, array['active'])
    from public.membership_facts f
   where f.user_id = p_user and f.status = 'active'
     and not exists (select 1 from public.workspaces w where w.network_id = f.network_id);
$fn$;
revoke execute on function public.personal_directory_relationships(uuid)
  from public, anon, authenticated, service_role;

create or replace function public.my_personal_message_directory_v1(
  p_section text,
  p_workspace_network_id text default null,
  p_after_key text default null,
  p_query text default '')
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  c_ref constant text := '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
  c_uuid constant text := '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
  v_me uuid;
  v_size int;
  v_longest int;
  v_query text := lower(btrim(coalesce(p_query, '')));
  v_like text;
  v_fresh boolean;
  v_status text := 'ready';
  v_rows jsonb;
  v_more boolean;
  v_key text;
begin
  perform public.mcp_require_native();
  v_me := auth.uid();
  if p_section is null or p_section not in ('workspaces', 'people', 'groups') then
    raise exception 'the section is workspaces, people or groups' using errcode = '22023';
  end if;
  if (p_section = 'people') <> (p_workspace_network_id is not null) then
    raise exception 'people take one workspace reference, the other sections none'
      using errcode = '22023';
  end if;
  if p_workspace_network_id is not null and p_workspace_network_id !~ c_ref then
    raise exception 'a workspace reference is installation:workspace' using errcode = '22023';
  end if;
  if p_after_key is not null
     and p_after_key !~ (case when p_section = 'workspaces' then c_ref else c_uuid end) then
    raise exception 'the cursor does not belong to this section' using errcode = '22023';
  end if;
  -- Resolved once, before the rows: a missing registry row raises here.
  v_size := (public.setting_value(null::uuid, 'personal.message_directory_page_size') #>> '{}')::int;
  v_longest := (public.setting_value(null::uuid, 'personal.message_directory_query_length') #>> '{}')::int;
  if length(v_query) > v_longest then
    raise exception 'the search is longer than % characters', v_longest using errcode = '22023';
  end if;
  v_like := '%' || replace(replace(replace(v_query, '\', '\\'), '%', '\%'), '_', '\_') || '%';

  if p_section = 'workspaces' then
    v_key := 'network_id';
    select coalesce(jsonb_agg(jsonb_build_object(
             'network_id', x.network_id,
             'installation_id', split_part(x.network_id, ':', 1),
             'workspace_id', split_part(x.network_id, ':', 2),
             'permitted_name', x.permitted_name) order by x.network_id collate "C"), '[]'::jsonb)
      into v_rows
      from (select r.network_id, r.permitted_name
              from public.personal_directory_relationships(v_me) r
             where r.fresh
               and (p_after_key is null or r.network_id collate "C" > p_after_key collate "C")
               and (v_query = '' or lower(coalesce(r.permitted_name, '')) like v_like escape '\')
             order by r.network_id collate "C"
             limit v_size + 1) x;
    select case when count(*) filter (where not r.fresh) = 0 then 'ready'
                when count(*) filter (where r.fresh) > 0 then 'partial'
                else 'unavailable' end
      into v_status
      from public.personal_directory_relationships(v_me) r;
  elsif p_section = 'people' then
    v_key := 'person_id';
    select bool_or(r.fresh) into v_fresh
      from public.personal_directory_relationships(v_me) r
     where r.network_id = p_workspace_network_id;
    if v_fresh is null then
      raise exception 'not a workspace of yours' using errcode = '42501';
    end if;
    if not v_fresh then
      v_status := 'unavailable';
      v_rows := '[]'::jsonb;
    else
      select coalesce(jsonb_agg(jsonb_build_object(
               'person_id', y.id,
               'personal_home_id', public.installation_id(),
               'context_workspace_ref', p_workspace_network_id,
               'view', y.v - 'user_id') order by y.id), '[]'::jsonb)
        into v_rows
        from (select x.id, x.v
                from (select c.id, public.visible_account(c.id) as v
                        from (select m.user_id as id
                                from public.members m
                                join public.workspaces w on w.id = m.workspace_id
                               where w.network_id = p_workspace_network_id
                                 and m.status = 'active' and m.user_id is not null
                                 and public.feature_effective(w.id, 'membersDirectory')
                              union
                              select f.user_id
                                from public.membership_facts f
                               where f.network_id = p_workspace_network_id and f.status = 'active'
                                 and public.membership_fact_in_force(f.user_id, f.network_id,
                                                                     array['active'])) c
                       where c.id <> v_me
                         and (p_after_key is null or c.id > p_after_key::uuid)) x
               where (x.v->>'can_message')::boolean
                 and (v_query = ''
                      or lower(coalesce(x.v->'identity'->>'name', '')) like v_like escape '\')
               order by x.id
               limit v_size + 1) y;
    end if;
  else
    v_key := 'group_id';
    select coalesce(jsonb_agg(jsonb_build_object(
             'group_id', x.id,
             'title', x.title,
             'announce_only', x.announce_only,
             'can_write', x.can_write) order by x.id), '[]'::jsonb)
      into v_rows
      from (select g.id, g.title, g.announce_only, (not g.announce_only or gm.is_admin) as can_write
              from public.account_groups g
              join public.account_group_members gm
                on gm.group_id = g.id and gm.user_id = v_me and gm.left_at is null
             where (p_after_key is null or g.id > p_after_key::uuid)
               and (v_query = '' or lower(g.title) like v_like escape '\')
             order by g.id
             limit v_size + 1) x;
  end if;

  v_more := jsonb_array_length(v_rows) > v_size;
  if v_more then
    v_rows := v_rows - v_size;
  end if;
  return jsonb_build_object(
    'schema_version', 1,
    'section', p_section,
    'items', v_rows,
    'next_key', case when v_more then v_rows->(v_size - 1)->>v_key end,
    'has_more', v_more,
    'relationship_status', v_status);
end;
$fn$;
revoke execute on function public.my_personal_message_directory_v1(text, text, text, text)
  from public, anon;
grant execute on function public.my_personal_message_directory_v1(text, text, text, text)
  to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(570);
