-- SPDX-License-Identifier: 0BSD
-- 0126 — the conversation write path and the list query (#687).
--
-- Every mutation is an RPC because the rules are not expressible as row
-- policies without repeating them: "only a group admin may add someone",
-- "a direct thread has exactly two participants and is created on
-- demand", "you may only leave a group you are in". A client that could
-- INSERT into conversation_participants directly would be one bug away
-- from adding itself to someone else's group.

-- ---------------------------------------------------------------- 1
-- My active membership in a workspace, or an exception. Every RPC below
-- starts here, so the check is written once.

create or replace function public.my_active_member(p_workspace_id uuid)
returns public.members language plpgsql stable security definer
set search_path = public as $$
declare v_member public.members;
begin
  select * into v_member from public.members
   where workspace_id = p_workspace_id
     and user_id = auth.uid()
     and status = 'active';
  if v_member.id is null then
    raise exception 'not a member of this workspace';
  end if;
  return v_member;
end;
$$;

-- ---------------------------------------------------------------- 2
-- The direct thread with one other member, created if it does not exist.
--
-- Idempotent by construction: two people opening each other at the same
-- moment must not end up with two threads, so the lookup is by the
-- PARTICIPANT PAIR rather than by anything a client passes in.

create or replace function public.direct_conversation(
  p_workspace_id uuid, p_other_member_id uuid
) returns uuid language plpgsql security definer
set search_path = public as $$
declare
  v_me public.members;
  v_other public.members;
  v_id uuid;
begin
  v_me := public.my_active_member(p_workspace_id);
  if p_other_member_id = v_me.id then
    raise exception 'cannot open a thread with yourself';
  end if;
  select * into v_other from public.members
   where id = p_other_member_id
     and workspace_id = p_workspace_id
     and status = 'active';
  if v_other.id is null then raise exception 'no such member'; end if;

  -- Exactly two participants, both of them these two.
  select c.id into v_id
    from public.conversations c
   where c.workspace_id = p_workspace_id
     and c.kind = 'direct'
     and (select count(*) from public.conversation_participants p
           where p.conversation_id = c.id) = 2
     and exists (select 1 from public.conversation_participants p
                  where p.conversation_id = c.id and p.member_id = v_me.id)
     and exists (select 1 from public.conversation_participants p
                  where p.conversation_id = c.id
                    and p.member_id = p_other_member_id)
   limit 1;
  if v_id is not null then return v_id; end if;

  insert into public.conversations (workspace_id, kind, created_by)
    values (p_workspace_id, 'direct', v_me.id)
    returning id into v_id;
  insert into public.conversation_participants (conversation_id, member_id)
    values (v_id, v_me.id), (v_id, p_other_member_id);
  return v_id;
end;
$$;

-- ---------------------------------------------------------------- 3
-- Create a group. The creator is its first admin.

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

  insert into public.conversations (workspace_id, kind, title, created_by)
    values (p_workspace_id, 'group', btrim(p_title), v_me.id)
    returning id into v_id;
  insert into public.conversation_participants
    (conversation_id, member_id, is_admin)
    values (v_id, v_me.id, true);

  -- Silently skips anyone who is not an active member of THIS workspace,
  -- rather than failing the whole call: a stale picker entry should not
  -- lose the group someone just named.
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

-- ---------------------------------------------------------------- 4
-- Am I an admin of this group?

create or replace function public.is_conversation_admin(p_conversation_id uuid)
returns boolean language sql stable security definer
set search_path = public as $$
  select exists (
    select 1
      from public.conversation_participants p
      join public.members m on m.id = p.member_id
     where p.conversation_id = p_conversation_id
       and m.user_id = auth.uid()
       and m.status = 'active'
       and p.left_at is null
       and p.is_admin
  );
$$;

-- ---------------------------------------------------------------- 5
-- Roster changes.

create or replace function public.add_conversation_participant(
  p_conversation_id uuid, p_member_id uuid
) returns void language plpgsql security definer
set search_path = public as $$
declare v_conversation public.conversations;
begin
  select * into v_conversation from public.conversations
   where id = p_conversation_id;
  if v_conversation.id is null then raise exception 'no such conversation'; end if;
  if v_conversation.kind <> 'group' then
    raise exception 'a direct thread has exactly two people';
  end if;
  if not public.is_conversation_admin(p_conversation_id) then
    raise exception 'only a group admin can add people';
  end if;
  if not exists (
    select 1 from public.members
     where id = p_member_id
       and workspace_id = v_conversation.workspace_id
       and status = 'active'
  ) then
    raise exception 'no such member';
  end if;
  -- Re-adding someone who left clears their exit rather than making a
  -- second row: they get the group back, history included.
  insert into public.conversation_participants (conversation_id, member_id)
    values (p_conversation_id, p_member_id)
    on conflict (conversation_id, member_id)
      do update set left_at = null;
end;
$$;

create or replace function public.remove_conversation_participant(
  p_conversation_id uuid, p_member_id uuid
) returns void language plpgsql security definer
set search_path = public as $$
declare v_me public.members;
begin
  if not public.is_conversation_admin(p_conversation_id) then
    raise exception 'only a group admin can remove people';
  end if;
  select m.* into v_me from public.members m
    join public.conversation_participants p on p.member_id = m.id
   where p.conversation_id = p_conversation_id and m.user_id = auth.uid();
  -- An admin removing themselves is a LEAVE, and leave() has the
  -- last-admin rule. Routing it here would let the last admin strand the
  -- group with nobody able to manage it.
  if v_me.id = p_member_id then
    raise exception 'use leave_conversation to remove yourself';
  end if;
  update public.conversation_participants
     set left_at = now()
   where conversation_id = p_conversation_id
     and member_id = p_member_id
     and left_at is null;
end;
$$;

create or replace function public.leave_conversation(p_conversation_id uuid)
returns void language plpgsql security definer
set search_path = public as $$
declare
  v_me uuid;
  v_was_admin boolean;
  v_remaining int;
begin
  select p.member_id, p.is_admin into v_me, v_was_admin
    from public.conversation_participants p
    join public.members m on m.id = p.member_id
   where p.conversation_id = p_conversation_id
     and m.user_id = auth.uid()
     and p.left_at is null;
  if v_me is null then raise exception 'not in this conversation'; end if;

  update public.conversation_participants
     set left_at = now()
   where conversation_id = p_conversation_id and member_id = v_me;

  -- If the last admin walks out, promote whoever has been there longest
  -- rather than leaving a group nobody can manage. Silent on purpose:
  -- the alternative is refusing to let someone leave, which is worse.
  if v_was_admin and not exists (
    select 1 from public.conversation_participants
     where conversation_id = p_conversation_id
       and left_at is null and is_admin
  ) then
    select count(*) into v_remaining
      from public.conversation_participants
     where conversation_id = p_conversation_id and left_at is null;
    if v_remaining > 0 then
      update public.conversation_participants
         set is_admin = true
       where conversation_id = p_conversation_id
         and member_id = (
           select member_id from public.conversation_participants
            where conversation_id = p_conversation_id and left_at is null
            order by joined_at limit 1
         );
    end if;
  end if;
end;
$$;

-- ---------------------------------------------------------------- 6
-- Group metadata: name and photo, admins only.

create or replace function public.set_conversation_meta(
  p_conversation_id uuid, p_title text, p_avatar_path text
) returns void language plpgsql security definer
set search_path = public as $$
begin
  if not public.is_conversation_admin(p_conversation_id) then
    raise exception 'only a group admin can change the group';
  end if;
  update public.conversations
     set title = coalesce(nullif(btrim(coalesce(p_title, '')), ''), title),
         -- '' clears the photo; null leaves it alone. Without the
         -- distinction there is no way to REMOVE a group photo.
         avatar_path = case
           when p_avatar_path is null then avatar_path
           when p_avatar_path = '' then null
           else p_avatar_path
         end
   where id = p_conversation_id and kind = 'group';
end;
$$;

-- ---------------------------------------------------------------- 7
-- Send into a conversation.

create or replace function public.send_conversation_message(
  p_conversation_id uuid, p_body text
) returns uuid language plpgsql security definer
set search_path = public as $$
declare
  v_conversation public.conversations;
  v_me uuid;
  v_other uuid;
  v_id uuid;
begin
  select * into v_conversation from public.conversations
   where id = p_conversation_id;
  if v_conversation.id is null then raise exception 'no such conversation'; end if;
  if length(btrim(coalesce(p_body, ''))) = 0 then
    raise exception 'empty message';
  end if;

  select p.member_id into v_me
    from public.conversation_participants p
    join public.members m on m.id = p.member_id
   where p.conversation_id = p_conversation_id
     and m.user_id = auth.uid()
     and m.status = 'active'
     and p.left_at is null;
  if v_me is null then raise exception 'not in this conversation'; end if;

  -- A DIRECT message keeps its `to_member_id`, so every path that has
  -- read it since 0089 — the push trigger, the read receipts, the
  -- recipient's RLS — keeps working unchanged. A GROUP message has no
  -- single recipient and leaves it null; group delivery reads the
  -- roster.
  if v_conversation.kind = 'direct' then
    select member_id into v_other from public.conversation_participants
     where conversation_id = p_conversation_id and member_id <> v_me
     limit 1;
  end if;

  insert into public.member_notes
    (workspace_id, from_member_id, to_member_id, body, conversation_id)
    values (v_conversation.workspace_id, v_me, v_other, btrim(p_body),
            p_conversation_id)
    returning id into v_id;
  return v_id;
end;
$$;

-- ---------------------------------------------------------------- 8
-- The conversation LIST: one row per thread, newest activity first.
--
-- Returned by an RPC rather than assembled client-side because the
-- unread count and the last message are per-viewer, and doing that in
-- Dart means one query per conversation.

create or replace function public.my_conversations(p_workspace_id uuid)
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
  participant_count int
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
         -- Direct threads render the OTHER person; the client has no
         -- other way to know who that is without the roster.
         (select p2.member_id from public.conversation_participants p2
           where p2.conversation_id = c.id and p2.member_id <> v_me.id
           limit 1) as other_member_id,
         last.body,
         last.created_at,
         last.from_member_id,
         -- Unread = messages from someone else that I have not read.
         -- Group messages carry no per-reader receipt, so a group's
         -- count is "since I last opened it" — see mark_conversation_read.
         (select count(*)::int from public.member_notes n
           where n.conversation_id = c.id
             and n.from_member_id <> v_me.id
             and n.created_at > coalesce(mine.last_read_at, '-infinity'))
           as unread,
         (select count(*)::int from public.conversation_participants p3
           where p3.conversation_id = c.id and p3.left_at is null)
           as participant_count
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
     -- A direct thread with nothing in it is an artefact of opening a
     -- profile, not a conversation. Groups show from the moment they
     -- exist: someone made one and is about to write in it.
     and (c.kind = 'group' or last.created_at is not null)
   order by c.last_message_at desc;
end;
$$;

revoke execute on function public.my_active_member(uuid) from public, anon;

-- ---------------------------------------------------------------- 9
-- Opening a conversation clears its unread.
--
-- Moves the watermark AND stamps the direct read receipts (0105), so a
-- 1:1 sender still sees their check turn blue. Two mechanisms, one call,
-- because "I opened it" is one event and splitting it is how they drift.

create or replace function public.mark_conversation_read(p_conversation_id uuid)
returns void language plpgsql security definer
set search_path = public as $$
declare v_me uuid;
begin
  select p.member_id into v_me
    from public.conversation_participants p
    join public.members m on m.id = p.member_id
   where p.conversation_id = p_conversation_id
     and m.user_id = auth.uid()
     and m.status = 'active';
  if v_me is null then return; end if;

  update public.conversation_participants
     set last_read_at = now()
   where conversation_id = p_conversation_id and member_id = v_me;

  -- Only messages addressed TO me, and only once: re-opening a thread
  -- must not move a receipt that already exists, or the sender sees the
  -- read time drift every time the reader glances at it.
  update public.member_notes
     set read_at = now()
   where conversation_id = p_conversation_id
     and to_member_id = v_me
     and read_at is null;
end;
$$;
