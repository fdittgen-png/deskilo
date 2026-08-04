-- SPDX-License-Identifier: 0BSD
-- Advisor follow-up to 0089 (#456): notify_member_note is a TRIGGER
-- function — nothing but the member_notes insert trigger may run it.
-- 0089 forgot the revoke the other trigger functions carry.
revoke execute on function public.notify_member_note()
  from public, anon, authenticated;
