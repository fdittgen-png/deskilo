-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0350 (#1923 C) -- saved Web-BI views: a name and a bounded declarative
-- definition (the query context and the cards, in order), private to the
-- person who saved it or shared with the workspace as a team view.
--
-- A definition is data, never code: an object of at most 2 KB with the
-- keys v (= 1), query (short string parameters from a fixed list) and
-- cards (at most 20 module ids). No results, no permissions and no
-- amounts are stored; opening a view reads every figure again under the
-- reader's CURRENT rights, so sharing a view shares a question, not an
-- answer.
--
-- Reading needs viewAnalytics. A private view is its author's alone; a
-- team view and the workspace default are written by someone who holds
-- workspaceSettings NOW. Each person may mark one of their private views
-- as their own default, which wins over the workspace default; clearing
-- it touches nobody else's. Every update names the revision it read, so
-- a concurrent save is refused instead of silently lost (40001).

create or replace function public.bi_definition_valid(p jsonb)
returns boolean language sql immutable set search_path = public as $fn$
  select p is not null
     and jsonb_typeof(p) = 'object'
     and octet_length(p::text) <= 2048
     and not exists (select 1 from jsonb_object_keys(p) k where k not in ('v', 'query', 'cards'))
     and p -> 'v' = '1'::jsonb
     and jsonb_typeof(coalesce(p -> 'query', '{}'::jsonb)) = 'object'
     and not exists (
       select 1 from jsonb_each(coalesce(p -> 'query', '{}'::jsonb)) e
        where e.key not in ('grain', 'at', 'cmp', 'by', 'sort', 'view')
           or jsonb_typeof(e.value) <> 'string'
           or char_length(e.value #>> '{}') > 32)
     and jsonb_typeof(coalesce(p -> 'cards', '[]'::jsonb)) = 'array'
     and jsonb_array_length(coalesce(p -> 'cards', '[]'::jsonb)) <= 20
     and not exists (
       select 1 from jsonb_array_elements(coalesce(p -> 'cards', '[]'::jsonb)) c
        where jsonb_typeof(c) <> 'string'
           or (c #>> '{}') !~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$'
           or char_length(c #>> '{}') > 64);
$fn$;
revoke execute on function public.bi_definition_valid(jsonb) from public, anon;

create table if not exists public.bi_views (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  scope text not null check (scope in ('private', 'workspace')),
  name text not null check (char_length(btrim(name)) between 1 and 80),
  definition jsonb not null check (public.bi_definition_valid(definition)),
  is_default boolean not null default false,
  revision integer not null default 1 check (revision >= 1)
);
select public.ensure_system_columns('bi_views');
create unique index if not exists bi_views_private_name
  on public.bi_views (workspace_id, user_id, lower(btrim(name))) where scope = 'private';
create unique index if not exists bi_views_workspace_name
  on public.bi_views (workspace_id, lower(btrim(name))) where scope = 'workspace';
create unique index if not exists bi_views_private_default
  on public.bi_views (workspace_id, user_id) where scope = 'private' and is_default;
create unique index if not exists bi_views_workspace_default
  on public.bi_views (workspace_id) where scope = 'workspace' and is_default;
create index if not exists bi_views_user_idx on public.bi_views (user_id);
alter table public.bi_views enable row level security;
revoke all on table public.bi_views from anon, authenticated;
drop policy if exists mcp_delegated_deny on public.bi_views;
create policy mcp_delegated_deny on public.bi_views
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- The common gate: a signed-in person, not a delegated assistant, who
-- may read this workspace's analytics.
create or replace function public.bi_views_gate(p_workspace_id uuid)
returns void language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not public.has_permission(p_workspace_id, 'viewAnalytics') then
    raise exception 'only someone who reads this workspace''s analytics keeps views of them'
      using errcode = '42501';
  end if;
end;
$fn$;
revoke execute on function public.bi_views_gate(uuid) from public, anon, authenticated;

create or replace function public.bi_view_json(v public.bi_views)
returns jsonb language sql stable set search_path = public as $fn$
  select jsonb_build_object(
    'id', v.id, 'scope', v.scope, 'name', v.name, 'definition', v.definition,
    'is_default', v.is_default, 'revision', v.revision,
    'mine', v.user_id = auth.uid());
$fn$;
revoke execute on function public.bi_view_json(public.bi_views) from public, anon, authenticated;

-- My private views and the workspace's team views; nobody else's.
create or replace function public.bi_views_list(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  perform public.bi_views_gate(p_workspace_id);
  return coalesce((
    select jsonb_agg(public.bi_view_json(v) order by v.scope, lower(v.name))
      from public.bi_views v
     where v.workspace_id = p_workspace_id
       and (v.scope = 'workspace' or v.user_id = auth.uid())), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.bi_views_list(uuid) from public, anon;
grant execute on function public.bi_views_list(uuid) to authenticated;

create or replace function public.bi_view_save(
  p_workspace_id uuid, p_id uuid, p_scope text, p_name text, p_definition jsonb,
  p_expected_revision int
) returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v public.bi_views;
begin
  perform public.bi_views_gate(p_workspace_id);
  if p_scope is null or p_scope not in ('private', 'workspace') then
    raise exception 'a view is private or the workspace''s' using errcode = '22023';
  end if;
  if p_scope = 'workspace' and not public.has_permission(p_workspace_id, 'workspaceSettings') then
    raise exception 'only someone who manages the workspace shares a view with it'
      using errcode = '42501';
  end if;
  if p_name is null or char_length(btrim(p_name)) not between 1 and 80 then
    raise exception 'a view has a name of 1 to 80 characters' using errcode = '22023';
  end if;
  if not public.bi_definition_valid(p_definition) then
    raise exception 'the view definition is not a valid analysis definition' using errcode = '22023';
  end if;
  if p_id is null then
    if coalesce(p_expected_revision, -1) <> 0 then
      raise exception 'stale view' using errcode = '40001';
    end if;
    insert into public.bi_views (workspace_id, user_id, scope, name, definition)
    values (p_workspace_id, auth.uid(), p_scope, btrim(p_name), p_definition)
    returning * into v;
  else
    select * into v from public.bi_views
     where id = p_id and workspace_id = p_workspace_id for update;
    if v.id is null
       or (v.scope = 'private' and v.user_id <> auth.uid())
       or (v.scope = 'workspace'
           and not public.has_permission(p_workspace_id, 'workspaceSettings')) then
      raise exception 'not a view you may change' using errcode = '42501';
    end if;
    if v.scope <> p_scope then
      raise exception 'a view keeps its scope; save a copy instead' using errcode = '22023';
    end if;
    if coalesce(p_expected_revision, -1) <> v.revision then
      raise exception 'stale view: someone saved it since you read it' using errcode = '40001';
    end if;
    update public.bi_views
       set name = btrim(p_name), definition = p_definition, revision = v.revision + 1
     where id = v.id
     returning * into v;
  end if;
  return public.bi_view_json(v);
end;
$fn$;
revoke execute on function public.bi_view_save(uuid, uuid, text, text, jsonb, int) from public, anon;
grant execute on function public.bi_view_save(uuid, uuid, text, text, jsonb, int) to authenticated;

create or replace function public.bi_view_delete(p_workspace_id uuid, p_id uuid, p_expected_revision int)
returns void language plpgsql volatile security definer set search_path = public as $fn$
declare
  v public.bi_views;
begin
  perform public.bi_views_gate(p_workspace_id);
  select * into v from public.bi_views
   where id = p_id and workspace_id = p_workspace_id for update;
  if v.id is null
     or (v.scope = 'private' and v.user_id <> auth.uid())
     or (v.scope = 'workspace'
         and not public.has_permission(p_workspace_id, 'workspaceSettings')) then
    raise exception 'not a view you may delete' using errcode = '42501';
  end if;
  if coalesce(p_expected_revision, -1) <> v.revision then
    raise exception 'stale view: someone saved it since you read it' using errcode = '40001';
  end if;
  delete from public.bi_views where id = v.id;
end;
$fn$;
revoke execute on function public.bi_view_delete(uuid, uuid, int) from public, anon;
grant execute on function public.bi_view_delete(uuid, uuid, int) to authenticated;

-- p_scope 'private': my own default (one of my private views), or none.
-- p_scope 'workspace': the team default (a team view), or none; needs
-- workspaceSettings. Neither touches the other, nor anyone else's.
create or replace function public.bi_view_set_default(p_workspace_id uuid, p_scope text, p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $fn$
begin
  perform public.bi_views_gate(p_workspace_id);
  if p_scope is null or p_scope not in ('private', 'workspace') then
    raise exception 'a default is mine or the workspace''s' using errcode = '22023';
  end if;
  if p_scope = 'workspace' and not public.has_permission(p_workspace_id, 'workspaceSettings') then
    raise exception 'only someone who manages the workspace sets its default view'
      using errcode = '42501';
  end if;
  if p_id is not null and not exists (
       select 1 from public.bi_views v
        where v.id = p_id and v.workspace_id = p_workspace_id and v.scope = p_scope
          and (p_scope = 'workspace' or v.user_id = auth.uid())) then
    raise exception 'not a view you may make the default' using errcode = '42501';
  end if;
  update public.bi_views set is_default = false
   where workspace_id = p_workspace_id and scope = p_scope and is_default
     and (p_scope = 'workspace' or user_id = auth.uid())
     and id is distinct from p_id;
  if p_id is not null then
    update public.bi_views set is_default = true where id = p_id and not is_default;
  end if;
end;
$fn$;
revoke execute on function public.bi_view_set_default(uuid, text, uuid) from public, anon;
grant execute on function public.bi_view_set_default(uuid, text, uuid) to authenticated;

-- The person's own saved views travel in their access export: the names
-- and definitions they wrote, in every workspace. Team views someone
-- else saved are the workspace's, not theirs.
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $export$
declare
  v_def text;
  v_next text;
begin
  v_def := pg_get_functiondef('public.export_my_data(uuid)'::regprocedure);
  if position('public.bi_views' in v_def) > 0 then
    raise exception '0350: export_my_data already returns bi_views';
  end if;
  v_next := pg_temp.anchor_replace(v_def, $a$    'exported_at', now(),$a$, $a$    'exported_at', now(),
    'bi_views', (select coalesce(jsonb_agg(jsonb_build_object('workspace_id', bv.workspace_id, 'scope', bv.scope, 'name', bv.name, 'definition', bv.definition, 'is_default', bv.is_default, 'created_at', bv.created_datetime) order by bv.created_datetime), '[]'::jsonb) from public.bi_views bv where bv.user_id = auth.uid()),$a$);
  if v_next is null then raise exception '0350: export anchor missing'; end if;
  execute v_next;
end;
$export$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(350);
