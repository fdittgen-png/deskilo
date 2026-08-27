-- SPDX-License-Identifier: 0BSD
-- 0124 — badge sign-in obeys the workspace's own feature flag (#662).
--
-- THE PROBLEM THE CLIENT CANNOT SOLVE. Every other feature flag is
-- checked in the app: the widget asks `enabledFeatures` and hides
-- itself. That does not work here, because the gate has to be decided
-- BEFORE anyone is signed in — and before sign-in the app has no
-- workspace, so it has no flags. `enabledFeatures` falls back to the
-- registry defaults with no workspace, which would make the decision on
-- behalf of a workspace it has never read.
--
-- Only the server can answer, and only after the scan: the badge is
-- what names the workspace. So the flag is enforced here, and the
-- login button on the auth screen is just an affordance — a workspace
-- that has not opted in refuses at the badge, and the refusal is the
-- same `refused` a stranger's card gets.
--
-- Default OFF, matching the registry: a workspace opts IN to its shared
-- tablet becoming a login surface. `coalesce(... , false)` is what makes
-- a workspace that has never heard of the flag refuse rather than allow,
-- which is the right way round for a credential.

create or replace function public.badge_auth_verify(
  p_uid text, p_pin text default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_hash text;
  v_badge public.member_badges;
  v_member public.members;
  v_profile public.profiles;
  v_enabled boolean;
  v_recent int;
begin
  v_hash := public.badge_token_hash(p_uid);

  select * into v_badge from public.member_badges
   where token_hash = v_hash and revoked_at is null and auth_enabled
   order by created_at limit 1;

  -- Lockout is checked BEFORE the PIN, and on the tag alone, so an
  -- attacker cannot use the response time or shape to tell a real tag
  -- from a fake one.
  select count(*) into v_recent from public.badge_auth_attempts
   where token_hash = v_hash
     and not succeeded
     and attempted_at > now() - interval '15 minutes';
  if v_recent >= 5 then
    return jsonb_build_object('ok', false, 'reason', 'locked');
  end if;

  if v_badge.id is null then
    if p_pin is not null then
      insert into public.badge_auth_attempts (token_hash, succeeded)
        values (v_hash, false);
    end if;
    return jsonb_build_object('ok', false, 'reason', 'refused');
  end if;

  select * into v_member from public.members
   where id = v_badge.member_id and status = 'active';
  if v_member.id is null then
    if p_pin is not null then
      insert into public.badge_auth_attempts (token_hash, succeeded)
        values (v_hash, false);
    end if;
    return jsonb_build_object('ok', false, 'reason', 'refused');
  end if;

  -- THE FLAG. Checked on the workspace the BADGE belongs to, not on any
  -- workspace the caller claims — the caller is anonymous here and has
  -- nothing to claim with. Both parents must be on: `badgeSignIn` sits
  -- under `nfcBadges` in the registry, and a hierarchy the client
  -- enforces but the server ignores is not a hierarchy.
  select coalesce(w.feature_flags -> 'badgeSignIn' = to_jsonb(true), false)
     and coalesce(w.feature_flags -> 'nfcBadges' = to_jsonb(true), true)
     and coalesce(w.feature_flags -> 'kioskMode' = to_jsonb(true), true)
    into v_enabled
    from public.workspaces w
   where w.id = v_member.workspace_id;

  if not coalesce(v_enabled, false) then
    -- Deliberately the same shape and the same attempt row as a wrong
    -- PIN. A distinct answer here would tell whoever is holding a card
    -- that the card is REAL and only the workspace setting is in the
    -- way, which is exactly what the uniform refusal exists to withhold.
    if p_pin is not null then
      insert into public.badge_auth_attempts (token_hash, succeeded)
        values (v_hash, false);
    end if;
    return jsonb_build_object('ok', false, 'reason', 'refused');
  end if;

  select * into v_profile from public.profiles where id = v_member.user_id;

  -- IDENTIFY: who is this? No attempt consumed, no e-mail returned.
  if p_pin is null then
    return jsonb_build_object(
      'ok', true,
      'user_id', v_member.user_id,
      'display_name', coalesce(v_profile.display_name, ''),
      'has_avatar', coalesce(v_profile.avatar_path, '') <> ''
    );
  end if;

  -- AUTHENTICATE. A profile with no PIN can never match, whatever is
  -- presented: crypt('', '') is not a valid hash and `= ''` would let an
  -- empty PIN through.
  if coalesce(v_profile.pin_hash, '') = ''
     or v_profile.pin_hash <> extensions.crypt(p_pin, v_profile.pin_hash) then
    insert into public.badge_auth_attempts (token_hash, succeeded)
      values (v_hash, false);
    return jsonb_build_object('ok', false, 'reason', 'refused');
  end if;

  insert into public.badge_auth_attempts (token_hash, succeeded)
    values (v_hash, true);
  return jsonb_build_object('ok', true, 'user_id', v_member.user_id);
end;
$$;

revoke execute on function public.badge_auth_verify(text, text)
  from public, anon, authenticated;
grant execute on function public.badge_auth_verify(text, text)
  to service_role;

notify pgrst, 'reload schema';
