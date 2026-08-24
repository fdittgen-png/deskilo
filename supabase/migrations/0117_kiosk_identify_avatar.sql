-- SPDX-License-Identifier: 0BSD
-- #616 — the kiosk receipt shows the member's own photo: kiosk_identify
-- v2 returns the subject's user_id and whether their profile carries an
-- avatar. The photo itself downloads through the 0038 avatars bucket,
-- whose select policy already admits workspace co-members — the kiosk
-- member included; this only tells the client WHERE to look, and only
-- after the badge resolved.
create or replace function public.kiosk_identify(
  p_workspace_id uuid, p_badge_token text
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_kiosk public.members;
  v_badge public.member_badges;
  v_subject public.members;
  v_name text;
  v_avatar text;
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

  select display_name, avatar_path into v_name, v_avatar
    from public.profiles where id = v_subject.user_id;
  return jsonb_build_object(
    'member_id', v_subject.id,
    'display_name', coalesce(v_name, ''),
    'user_id', v_subject.user_id,
    'has_avatar', coalesce(v_avatar, '') <> ''
  );
end;
$$;
revoke execute on function public.kiosk_identify(uuid, text) from public, anon;
