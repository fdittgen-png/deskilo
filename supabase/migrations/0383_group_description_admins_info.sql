-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0383 — running a workspace group the way chat apps do.
--
--   * a group has a DESCRIPTION and can be ANNOUNCEMENT-ONLY (only admins post;
--     notices stay);
--   * admins can promote and demote each other (never the last admin away);
--   * the author of a message can see who it reached: `message_info` names who
--     read it (a participant's last read stamp is at or after it) and who has
--     not yet.
-- Renaming already exists (`set_conversation_meta`); the app now offers it.

alter table public.conversations
  add column if not exists description text not null default '',
  add column if not exists announce_only boolean not null default false;
alter table public.conversations
  add constraint conversations_description_len check (char_length(description) <= 500);

create or replace function public.conversation_details(p_conversation_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $fn$
  select jsonb_build_object('description', c.description, 'announce_only', c.announce_only)
    from public.conversations c
   where c.id = p_conversation_id
     and exists (select 1 from public.conversation_participants p
                   join public.members m on m.id = p.member_id
                  where p.conversation_id = c.id and m.user_id = auth.uid());
$fn$;

create or replace function public.set_conversation_details(
  p_conversation_id uuid, p_description text, p_announce_only boolean)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if not public.is_conversation_admin(p_conversation_id) then
    raise exception 'only a group admin can change the group';
  end if;
  update public.conversations
     set description = left(btrim(coalesce(p_description, '')), 500),
         announce_only = coalesce(p_announce_only, announce_only)
   where id = p_conversation_id and kind = 'group';
end;
$fn$;

create or replace function public.set_participant_admin(
  p_conversation_id uuid, p_member_id uuid, p_admin boolean)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if not public.is_conversation_admin(p_conversation_id) then
    raise exception 'only a group admin can change the group';
  end if;
  if not exists (select 1 from public.conversation_participants
                  where conversation_id = p_conversation_id and member_id = p_member_id
                    and left_at is null) then
    raise exception 'not in this group';
  end if;
  if not p_admin and not exists (
    select 1 from public.conversation_participants
     where conversation_id = p_conversation_id and left_at is null and is_admin
       and member_id <> p_member_id) then
    raise exception 'a group needs at least one admin';
  end if;
  update public.conversation_participants set is_admin = p_admin
   where conversation_id = p_conversation_id and member_id = p_member_id;
end;
$fn$;

-- An announcement-only group: only admins post.
create or replace function public.member_notes_announce_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if new.conversation_id is null or new.notice is not null then return new; end if;
  if exists (select 1 from public.conversations c
              where c.id = new.conversation_id and c.announce_only)
     and not exists (select 1 from public.conversation_participants p
                      where p.conversation_id = new.conversation_id
                        and p.member_id = new.from_member_id and p.is_admin
                        and p.left_at is null) then
    raise exception 'only admins post in this group';
  end if;
  return new;
end;
$fn$;
drop trigger if exists member_notes_announce_guard on public.member_notes;
create trigger member_notes_announce_guard before insert on public.member_notes
  for each row execute function public.member_notes_announce_guard();

create or replace function public.message_info(p_message_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  n public.member_notes;
begin
  perform public.mcp_require_native();
  select * into n from public.member_notes where id = p_message_id;
  if n.id is null or n.conversation_id is null then raise exception 'message unavailable'; end if;
  if not exists (select 1 from public.members m
                  where m.id = n.from_member_id and m.user_id = auth.uid()) then
    raise exception 'only the author sees who a message reached';
  end if;
  return jsonb_build_object(
    'sent_at', n.created_at,
    'readers', coalesce((
      select jsonb_agg(jsonb_build_object('member_id', p.member_id, 'read_at', p.last_read_at)
                       order by p.last_read_at)
        from public.conversation_participants p
       where p.conversation_id = n.conversation_id and p.left_at is null
         and p.member_id <> n.from_member_id and p.last_read_at is not null
         and p.last_read_at >= n.created_at), '[]'::jsonb),
    'pending', coalesce((
      select jsonb_agg(p.member_id)
        from public.conversation_participants p
       where p.conversation_id = n.conversation_id and p.left_at is null
         and p.member_id <> n.from_member_id
         and (p.last_read_at is null or p.last_read_at < n.created_at)), '[]'::jsonb));
end;
$fn$;

revoke execute on function public.conversation_details(uuid) from public, anon;
revoke execute on function public.set_conversation_details(uuid, text, boolean) from public, anon;
revoke execute on function public.set_participant_admin(uuid, uuid, boolean) from public, anon;
revoke execute on function public.member_notes_announce_guard() from public, anon;
revoke execute on function public.message_info(uuid) from public, anon;
grant execute on function public.conversation_details(uuid) to authenticated;
grant execute on function public.set_conversation_details(uuid, text, boolean) to authenticated;
grant execute on function public.set_participant_admin(uuid, uuid, boolean) to authenticated;
grant execute on function public.message_info(uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(383);
