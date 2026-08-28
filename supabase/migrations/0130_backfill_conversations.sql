-- SPDX-License-Identifier: 0BSD
-- 0130 — every message that predates 0125 gets the conversation it
-- always belonged to (#702).
--
-- THE MESSAGES WERE NOT LOST, THEY WERE UNREACHABLE. 0125 gave
-- `member_notes` a `conversation_id` and 0126 taught the app to read
-- threads through it — but nothing ever filled the column for the notes
-- already in the table. So every exchange from before that migration
-- has `conversation_id is null`, and the messaging centre, which reads
-- by conversation, renders it nowhere: `direct_conversation` happily
-- opens a BRAND NEW empty thread for a pair who had been writing to
-- each other for months.
--
-- The rows were still there and still readable through the old
-- filter-based sheet, which is why nobody noticed while both existed.
-- #702 deletes that sheet — one thread, one read path — so this has to
-- be true before that ships.
--
-- BROADCASTS ARE LEFT ALONE (`to_member_id is null`): a fan-out to
-- whoever is an admin at read time has no pair and no thread. It lives
-- in the alerts feed, which is where 0125 deliberately left it.

do $backfill$
declare
  r record;
  v_id uuid;
begin
  -- One direct conversation per unordered pair per workspace, for the
  -- pairs that have orphaned notes and no thread yet.
  for r in
    with pairs as (
      select distinct
             n.workspace_id,
             least(n.from_member_id, n.to_member_id)    as a,
             greatest(n.from_member_id, n.to_member_id) as b
        from public.member_notes n
       where n.conversation_id is null
         and n.to_member_id is not null
         and n.from_member_id is not null
         and n.from_member_id <> n.to_member_id
    )
    select p.* from pairs p
     where not exists (
       -- An EXISTING direct thread for the pair wins: they may have
       -- written again since 0125, and a second conversation for the
       -- same two people is the one thing `direct_conversation` exists
       -- to prevent.
       select 1
         from public.conversations c
         join public.conversation_participants pa on pa.conversation_id = c.id
         join public.conversation_participants pb on pb.conversation_id = c.id
        where c.kind = 'direct'
          and c.workspace_id = p.workspace_id
          and pa.member_id = p.a
          and pb.member_id = p.b
     )
  loop
    insert into public.conversations (workspace_id, kind, created_by)
      values (r.workspace_id, 'direct', r.a)
      returning id into v_id;

    insert into public.conversation_participants (conversation_id, member_id)
      values (v_id, r.a), (v_id, r.b)
      on conflict do nothing;

    update public.member_notes n
       set conversation_id = v_id
     where n.conversation_id is null
       and n.workspace_id = r.workspace_id
       and least(n.from_member_id, n.to_member_id) = r.a
       and greatest(n.from_member_id, n.to_member_id) = r.b;
  end loop;
end;
$backfill$;

-- Notes whose pair ALREADY had a conversation — written before 0125,
-- then the pair wrote again after it. Same thread, no new row.
update public.member_notes n
   set conversation_id = c.id
  from public.conversations c
  join public.conversation_participants pa on pa.conversation_id = c.id
  join public.conversation_participants pb on pb.conversation_id = c.id
 where n.conversation_id is null
   and n.to_member_id is not null
   and n.from_member_id is not null
   and n.from_member_id <> n.to_member_id
   and c.kind = 'direct'
   and c.workspace_id = n.workspace_id
   and pa.member_id = least(n.from_member_id, n.to_member_id)
   and pb.member_id = greatest(n.from_member_id, n.to_member_id);

-- Every touched thread sorts by its HISTORY, not by the moment this
-- migration ran: a backfilled conversation whose last word was in March
-- belongs in March's place in the list.
update public.conversations c
   set last_message_at = last.at
  from (
    select conversation_id, max(created_at) as at
      from public.member_notes
     where conversation_id is not null
     group by conversation_id
  ) last
 where last.conversation_id = c.id
   and c.last_message_at is distinct from last.at;

notify pgrst, 'reload schema';
