-- SPDX-License-Identifier: 0BSD
-- 0146 — #821: a conversation the reader can PIN, MUTE, ARCHIVE and mark
-- UNREAD again. Per participant, because they are one person's view of a
-- shared thread: my pin is not your pin.
--
--  * conversation_participants.pinned_at / muted / archived_at
--  * set_conversation_prefs(conversation, pinned, muted, archived) — each
--    argument null = leave as is; the caller must be a live participant.
--  * mark_conversation_unread(conversation) — moves my watermark back to
--    just before the last message from someone else, so the thread reads
--    unread again without touching the 0105 receipts the sender already
--    saw.
--  * my_conversations v3 — returns the three flags, orders pinned threads
--    first, and hides archived ones unless asked (p_include_archived).
--  * member_notes_unarchive — a new message in an archived thread brings
--    it back to the list for every participant.

alter table public.conversation_participants
  add column if not exists pinned_at timestamptz,
  add column if not exists muted boolean not null default false,
  add column if not exists archived_at timestamptz;

create or replace function public.set_conversation_prefs(
  p_conversation_id uuid,
  p_pinned boolean default null,
  p_muted boolean default null,
  p_archived boolean default null
) returns void language plpgsql security definer
set search_path = public as $$
declare v_me uuid;
begin
  select p.member_id into v_me
    from public.conversation_participants p
    join public.members m on m.id = p.member_id
   where p.conversation_id = p_conversation_id
     and m.user_id = auth.uid() and m.status = 'active'
     and p.left_at is null;
  if v_me is null then raise exception 'not a participant'; end if;
  update public.conversation_participants
     set pinned_at = case when p_pinned is null then pinned_at
                          when p_pinned then coalesce(pinned_at, now())
                          else null end,
         muted = coalesce(p_muted, muted),
         archived_at = case when p_archived is null then archived_at
                            when p_archived then coalesce(archived_at, now())
                            else null end
   where conversation_id = p_conversation_id and member_id = v_me;
end;
$$;
revoke execute on function public.set_conversation_prefs(uuid, boolean, boolean, boolean)
  from public, anon;
grant execute on function public.set_conversation_prefs(uuid, boolean, boolean, boolean)
  to authenticated;

create or replace function public.mark_conversation_unread(p_conversation_id uuid)
returns void language plpgsql security definer
set search_path = public as $$
declare v_me uuid; v_last timestamptz;
begin
  select p.member_id into v_me
    from public.conversation_participants p
    join public.members m on m.id = p.member_id
   where p.conversation_id = p_conversation_id
     and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null then return; end if;
  select max(n.created_at) into v_last from public.member_notes n
   where n.conversation_id = p_conversation_id and n.from_member_id <> v_me;
  if v_last is null then return; end if;
  update public.conversation_participants
     set last_read_at = v_last - interval '1 millisecond'
   where conversation_id = p_conversation_id and member_id = v_me;
end;
$$;
revoke execute on function public.mark_conversation_unread(uuid) from public, anon;
grant execute on function public.mark_conversation_unread(uuid) to authenticated;

-- my_conversations v3: the 0127 body + the three flags, pinned first,
-- archived hidden unless asked. The old one-argument signature stays
-- callable (a default), so nothing that still calls it breaks.
drop function if exists public.my_conversations(uuid);
create or replace function public.my_conversations(
  p_workspace_id uuid,
  p_include_archived boolean default false
)
returns table (
  id uuid,
  kind text,
  title text,
  avatar_path text,
  other_member_id uuid,
  last_body text,
  last_at timestamptz,
  last_from_member_id uuid,
  unread int,
  participant_count int,
  pinned_at timestamptz,
  muted boolean,
  archived_at timestamptz
) language plpgsql stable security definer
set search_path = public as $$
declare v_me public.members;
begin
  v_me := public.my_active_member(p_workspace_id);
  return query
  select c.id,
         c.kind,
         c.title,
         c.avatar_path,
         (select p2.member_id from public.conversation_participants p2
           where p2.conversation_id = c.id and p2.member_id <> v_me.id
           limit 1) as other_member_id,
         coalesce(last.body, '') as last_body,
         coalesce(last.created_at, c.last_message_at) as last_at,
         last.from_member_id,
         (select count(*)::int from public.member_notes n
           where n.conversation_id = c.id
             and n.from_member_id <> v_me.id
             and n.created_at > coalesce(mine.last_read_at, '-infinity'))
           as unread,
         (select count(*)::int from public.conversation_participants p3
           where p3.conversation_id = c.id and p3.left_at is null)
           as participant_count,
         mine.pinned_at,
         mine.muted,
         mine.archived_at
    from public.conversations c
    join public.conversation_participants mine
      on mine.conversation_id = c.id and mine.member_id = v_me.id
    left join lateral (
      select n.body, n.created_at, n.from_member_id
        from public.member_notes n
       where n.conversation_id = c.id
       order by n.created_at desc
       limit 1
    ) last on true
   where c.workspace_id = p_workspace_id
     and mine.left_at is null
     and (p_include_archived or mine.archived_at is null)
   order by (mine.pinned_at is not null) desc, mine.pinned_at desc,
            c.last_message_at desc;
end;
$$;
revoke execute on function public.my_conversations(uuid, boolean) from public, anon;
grant execute on function public.my_conversations(uuid, boolean) to authenticated;

-- An archived thread comes BACK when someone writes in it: archiving is
-- "out of my way for now", not "never again". A trigger rather than a
-- patch of send_conversation_message, so every insert path counts.
create or replace function public.unarchive_conversation_on_message()
returns trigger language plpgsql security definer
set search_path = public as $$
begin
  if new.conversation_id is not null then
    update public.conversation_participants
       set archived_at = null
     where conversation_id = new.conversation_id
       and archived_at is not null;
  end if;
  return new;
end;
$$;
drop trigger if exists member_notes_unarchive on public.member_notes;
create trigger member_notes_unarchive
  after insert on public.member_notes
  for each row execute function public.unarchive_conversation_on_message();

notify pgrst, 'reload schema';
