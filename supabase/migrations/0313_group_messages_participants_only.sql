-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0313 (#1822) -- a group message is read by the people in its
-- conversation, never by every administrator of the space.
--
-- 0089 wrote `member_notes_select` for two kinds of row: a note to one
-- member, and the ADMIN BROADCAST (`to_member_id` null, no conversation),
-- which fans out to whoever is an owner or an administrator. 0126 then
-- stored every GROUP message with `to_member_id` null as well, and the
-- broadcast clause matched them all: any active owner or administrator
-- could read every group of the space, including groups they were never
-- in.
--
-- The rule now:
--   * a message WITH a conversation is read by its sender, and by a
--     participant of that conversation whose `left_at` is null or later
--     than the message -- someone who left keeps what was said before
--     they left and nothing after. No administrator clause.
--   * a message with NO conversation and NO recipient is the legacy
--     admin broadcast: active owners and administrators read it, as
--     before.
--   * a direct note with no conversation: its sender and its recipient,
--     as before.
--
-- The rule lives in ONE definer function, `can_read_member_note`, so the
-- policies and every definer function that reads `member_notes` ask the
-- same question. It has to be a definer function: the policy asks about
-- `conversation_participants`, whose own policy asks about itself
-- (`in_conversation`), and a function is what keeps RLS from recursing.
-- It answers only for the CALLER (auth.uid()), so granting it to
-- `authenticated` discloses nothing a select would not.
--
-- Delete keeps 0092's rule (sender, or the direct recipient) and adds
-- the same reading scope, so a removed participant cannot delete what
-- they can no longer read.
--
-- Definer readers: `calendar_items` asked `in_conversation`, which counts
-- a participant who LEFT as in the conversation forever; it now asks
-- `can_read_member_note` for each row. `my_conversations`,
-- `mark_conversation_read`, `mark_conversation_unread` and
-- `send_conversation_message` already require a participant row and read
-- only that conversation; `export_my_data` exports only the caller's own
-- sent messages; `erase_my_membership` deletes only the caller's own.

create or replace function public.can_read_member_note(
  p_workspace uuid,
  p_from uuid,
  p_to uuid,
  p_conversation uuid,
  p_created_at timestamptz
) returns boolean
language sql stable security definer
set search_path = public as $$
  select exists (
    select 1
      from public.members m
     where m.user_id = auth.uid()
       and m.workspace_id = p_workspace
       and m.status = 'active'
       and (
         m.id = p_from
         or (p_conversation is null and m.id = p_to)
         or (p_conversation is null and p_to is null
             and (m.is_admin or m.is_owner))
         or (p_conversation is not null and exists (
               select 1
                 from public.conversation_participants p
                where p.conversation_id = p_conversation
                  and p.member_id = m.id
                  and (p.left_at is null or p.left_at > p_created_at)))
       )
  );
$$;
revoke execute on function public.can_read_member_note(uuid, uuid, uuid, uuid, timestamptz)
  from public, anon;
grant execute on function public.can_read_member_note(uuid, uuid, uuid, uuid, timestamptz)
  to authenticated;

drop policy if exists member_notes_select on public.member_notes;
create policy member_notes_select on public.member_notes
  for select using (
    public.can_read_member_note(workspace_id, from_member_id, to_member_id,
                                conversation_id, created_at)
  );

drop policy if exists member_notes_delete on public.member_notes;
create policy member_notes_delete on public.member_notes
  for delete using (
    public.can_read_member_note(workspace_id, from_member_id, to_member_id,
                                conversation_id, created_at)
    and exists (
      select 1 from public.members m
       where m.user_id = auth.uid()
         and m.workspace_id = member_notes.workspace_id
         and m.status = 'active'
         and (m.id = member_notes.from_member_id
              or m.id = member_notes.to_member_id)
    )
  );

-- calendar_items: both message branches (my own calendar, and another
-- member's) asked `in_conversation`, which ignores `left_at`.
do $patch$
declare
  v_def text;
  v_anchor text := 'public.in_conversation(n.conversation_id)';
  v_new text := 'public.can_read_member_note(n.workspace_id, n.from_member_id, n.to_member_id, n.conversation_id, n.created_at)';
  v_count int;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace s on s.oid = p.pronamespace
   where s.nspname = 'public' and p.proname = 'calendar_items';
  v_count := (length(v_def) - length(replace(v_def, v_anchor, ''))) / length(v_anchor);
  if v_count <> 2 then
    raise exception '0313: calendar_items anchor found % times, expected 2', v_count;
  end if;
  execute replace(v_def, v_anchor, v_new);
end;
$patch$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(313);
