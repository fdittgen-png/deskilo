-- SPDX-License-Identifier: 0BSD
-- Delete revoked badges. NOT YET applied to the hosted reference project —
-- the orchestrator applies it after review.
--
-- Field request: revoked badges pile up in the badge manager (the
-- screenshot showed eight) — a swipe removes them for good. Only
-- REVOKED badges can be deleted (live ones must be revoked first, so
-- the kiosk rejection trail stays deliberate), by the badge's own
-- member or a workspace admin — the union of the two surfaces that
-- share the badge manager dialog.

create or replace function public.delete_revoked_badge(p_badge_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_count int;
begin
  delete from public.member_badges b
    where b.id = p_badge_id
      and b.revoked_at is not null
      and (public.is_admin_of(b.workspace_id)
           or exists (select 1 from public.members m
                       where m.id = b.member_id
                         and m.user_id = auth.uid()));
  get diagnostics v_count = row_count;
  if v_count = 0 then raise exception 'unknown badge'; end if;
end;
$$;
revoke execute on function public.delete_revoked_badge(uuid) from public, anon;
