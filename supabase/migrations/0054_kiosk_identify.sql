-- SPDX-License-Identifier: 0BSD
-- Kiosk identify. NOT YET applied to the hosted reference project — the
-- orchestrator applies it after review.
--
-- The confirm-step flow (field request): after the badge/QR is read the
-- kiosk CLOSES the readers and shows a summary — "«name», check in on
-- A1, 09:00–13:00 — Confirm / Reject" — before anything happens.
-- kiosk_identify resolves a badge to its member's display name WITHOUT
-- acting; the confirmed action still runs through kiosk_act unchanged.

create or replace function public.kiosk_identify(
  p_workspace_id uuid, p_badge_token text
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_kiosk public.members;
  v_badge public.member_badges;
  v_subject public.members;
  v_name text;
begin
  select * into v_kiosk from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid()
      and status = 'active' and is_kiosk;
  if v_kiosk.id is null then raise exception 'not a kiosk of this workspace'; end if;

  select * into v_badge from public.member_badges
    where workspace_id = p_workspace_id
      and token_hash = public.badge_token_hash(p_badge_token)
      and revoked_at is null;
  if v_badge.id is null then
    -- the client pins this substring (same as kiosk_act)
    raise exception 'badge not recognized';
  end if;
  select * into v_subject from public.members
    where id = v_badge.member_id and status = 'active';
  if v_subject.id is null then raise exception 'badge member not active'; end if;

  select display_name into v_name from public.profiles
    where id = v_subject.user_id;
  return jsonb_build_object(
    'member_id', v_subject.id,
    'display_name', coalesce(v_name, '')
  );
end;
$$;
revoke execute on function public.kiosk_identify(uuid, text) from public, anon;
