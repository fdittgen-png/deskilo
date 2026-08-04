-- SPDX-License-Identifier: 0BSD
-- Swipe-to-delete for member notes (#467): the sender may delete what
-- they sent; the DIRECT recipient may delete what they received. A
-- received broadcast stays — deleting it would erase it for every
-- admin, not just the swiper.
create policy member_notes_delete on public.member_notes
  for delete using (
    exists (
      select 1 from public.members m
      where m.user_id = auth.uid()
        and m.workspace_id = member_notes.workspace_id
        and m.status = 'active'
        and (m.id = member_notes.from_member_id
             or m.id = member_notes.to_member_id)
    )
  );
