-- SPDX-License-Identifier: 0BSD
-- Read follows the CONVERSATION, not the inbox glance (#539). 0105
-- stamped every unread note the moment the Events screen opened —
-- which made "unread" indistinguishable one frame later. The mark RPC
-- now takes an optional sender: opening a conversation reads THAT
-- exchange only; everything else stays visibly unread (and filterable).
--
-- The 1-arg form is DROPPED (an overload would make PostgREST's named-
-- param resolution ambiguous); the 2-arg default keeps every existing
-- 1-arg call working unchanged.

drop function if exists public.mark_member_notes_read(uuid);

create or replace function public.mark_member_notes_read(
  p_workspace_id uuid,
  p_from_member_id uuid default null
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_me public.members;
begin
  select * into v_me from public.members
    where workspace_id = p_workspace_id
      and user_id = auth.uid() and status = 'active';
  if v_me.id is null then
    raise exception 'not an active member of this workspace';
  end if;
  update public.member_notes
    set read_at = now()
    where workspace_id = p_workspace_id
      and to_member_id = v_me.id
      and read_at is null
      and (p_from_member_id is null
           or from_member_id = p_from_member_id);
end;
$$;
revoke execute on function public.mark_member_notes_read(uuid, uuid)
  from public, anon;
