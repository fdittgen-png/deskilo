-- SPDX-License-Identifier: 0BSD
-- 0128 — a group name is unique within its workspace (#694).
--
-- Two groups called "test" in one list are two rows nobody can tell
-- apart: the name IS the identity of a group, the way a member's name is
-- theirs. Picking the wrong one is silent — you write into it and only
-- find out when nobody answers.
--
-- CASE- AND SPACE-INSENSITIVE. "Team", "team" and " Team " are the same
-- name to everyone reading the list, so treating them as different is a
-- distinction only the database can see.
--
-- DIRECT threads are exempt: they have no title at all (0125 enforces
-- `title is null` for them), so the partial index simply does not cover
-- them.

-- ---------------------------------------------------------------- 1
-- Existing duplicates, resolved BEFORE the constraint can be added.
--
-- Renamed, never deleted: these are real groups with real messages in
-- them, and a constraint is not a reason to lose one. Deterministic —
-- the OLDEST keeps the name it has, later ones get " (2)", " (3)" — so
-- the outcome does not depend on which row the planner reached first,
-- and whoever created the group they are looking at keeps its name.

with ranked as (
  select id,
         title,
         row_number() over (
           partition by workspace_id, lower(btrim(title))
           order by created_at, id
         ) as n
    from public.conversations
   where kind = 'group'
)
update public.conversations c
   set title = ranked.title || ' (' || ranked.n || ')'
  from ranked
 where c.id = ranked.id
   and ranked.n > 1;

-- ---------------------------------------------------------------- 2
-- The constraint.

create unique index conversations_group_name_unique
  on public.conversations (workspace_id, lower(btrim(title)))
  where kind = 'group';

-- ---------------------------------------------------------------- 3
-- A refusal someone can act on.
--
-- The bare index violation is `duplicate key value violates unique
-- constraint "conversations_group_name_unique"`, which is a sentence
-- for a developer. Catching it and re-raising says what to DO, and the
-- client pins the substring.

create or replace function public.create_group_conversation(
  p_workspace_id uuid, p_title text, p_member_ids uuid[]
) returns uuid language plpgsql security definer
set search_path = public as $$
declare
  v_me public.members;
  v_id uuid;
  v_member uuid;
begin
  v_me := public.my_active_member(p_workspace_id);
  if length(btrim(coalesce(p_title, ''))) = 0 then
    raise exception 'a group needs a name';
  end if;

  begin
    insert into public.conversations (workspace_id, kind, title, created_by)
      values (p_workspace_id, 'group', btrim(p_title), v_me.id)
      returning id into v_id;
  exception when unique_violation then
    -- the client pins this substring
    raise exception 'a group with that name already exists';
  end;

  insert into public.conversation_participants
    (conversation_id, member_id, is_admin)
    values (v_id, v_me.id, true);

  foreach v_member in array coalesce(p_member_ids, '{}')
  loop
    if v_member <> v_me.id and exists (
      select 1 from public.members
       where id = v_member and workspace_id = p_workspace_id
         and status = 'active'
    ) then
      insert into public.conversation_participants (conversation_id, member_id)
        values (v_id, v_member)
        on conflict do nothing;
    end if;
  end loop;
  return v_id;
end;
$$;

-- Renaming has to refuse the same way, or the rule is only enforced on
-- the path that happens to be checked.
create or replace function public.set_conversation_meta(
  p_conversation_id uuid, p_title text, p_avatar_path text
) returns void language plpgsql security definer
set search_path = public as $$
begin
  if not public.is_conversation_admin(p_conversation_id) then
    raise exception 'only a group admin can change the group';
  end if;
  begin
    update public.conversations
       set title = coalesce(nullif(btrim(coalesce(p_title, '')), ''), title),
           avatar_path = case
             when p_avatar_path is null then avatar_path
             when p_avatar_path = '' then null
             else p_avatar_path
           end
     where id = p_conversation_id and kind = 'group';
  exception when unique_violation then
    raise exception 'a group with that name already exists';
  end;
end;
$$;

notify pgrst, 'reload schema';
