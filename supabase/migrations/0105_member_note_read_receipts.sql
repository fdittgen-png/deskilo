-- SPDX-License-Identifier: 0BSD
-- Read receipts for member notes (field request): the sender's message
-- list shows a small check — grey once delivered, blue once the DIRECT
-- recipient has read it. read_at is stamped by the recipient's app via
-- mark_member_notes_read when they open their messages; realtime (the
-- 0089 publication already carries updates) flips the sender's check
-- live. Broadcasts (to_member_id null) have many readers and no single
-- read state — they stay at the grey delivered check by design.

alter table public.member_notes add column read_at timestamptz;

create or replace function public.mark_member_notes_read(
  p_workspace_id uuid
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
      and read_at is null;
end;
$$;
revoke execute on function public.mark_member_notes_read(uuid)
  from public, anon;
