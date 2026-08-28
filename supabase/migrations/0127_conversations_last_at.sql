-- SPDX-License-Identifier: 0BSD
-- 0127 — `my_conversations.last_at` is never null, and an empty direct
-- thread is visible (#692).
--
-- TWO BUGS, ONE SCREEN, both reported from the first beta build.
--
-- 1. "Une erreur est survenue" on the whole conversation list.
--
--    A group with no messages yet has no last message, so `last_at`
--    came back NULL. The client fell back to a `created_at` column that
--    this function DOES NOT RETURN, so it parsed null as a String and
--    threw — killing the entire list, not just that row.
--
--    Creating a group therefore looked like it had failed. It had
--    worked; it then broke the screen that would have shown it.
--
--    `last_message_at` is the right fallback and was on the table all
--    along: it defaults to now() at insert, which is exactly "nothing
--    said yet, sort me by when I was made".
--
-- 2. Starting a one-to-one chat appeared to do nothing.
--
--    An empty DIRECT thread was filtered out — reasonable when the only
--    way to create one was opening someone's profile, where the row
--    would have been an artefact. It is wrong now that "Démarrer" in
--    the messaging centre creates one deliberately: the filter hid the
--    result of the thing the member just did.
--
-- The client half of both fixes is in the same PR: a null timestamp can
-- no longer crash the parse, and starting a conversation OPENS it.

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
         (select p2.member_id from public.conversation_participants p2
           where p2.conversation_id = c.id and p2.member_id <> v_me.id
           limit 1) as other_member_id,
         coalesce(last.body, '') as last_body,
         -- NEVER null.
         coalesce(last.created_at, c.last_message_at) as last_at,
         last.from_member_id,
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
   order by c.last_message_at desc;
end;
$$;

notify pgrst, 'reload schema';
