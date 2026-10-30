-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (two functions are restated; no stored row moves)
--
-- 0610 (#3091, SEC-E2 of the #2960 audit) -- the badge PIN is longer by
-- default and the lockout grows.
--
--   1. security.badge_pin_min_length (4..8, default 6): the fewest digits a
--      NEW PIN may have. set_badge_pin reads it; a PIN set earlier keeps
--      working until its owner changes it. One guessing script on a 4-digit
--      PIN needed about ten days; six digits take a hundred times longer.
--   2. badge_auth_verify, restated whole: the configured failures within the
--      configured window still lock a tag for that window, and now twice as
--      many within an hour lock it for the hour, three times as many within
--      a day for the day. The answer stays the single uniform "locked".
--
-- Not here: the per-workspace failure ceiling that alerts the owner.

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('security.badge_pin_min_length', 'int', '6'::jsonb, 4, 8, 'characters', 'security', array['platform'], 'workspaceSettings', null, true, null, 'set_badge_pin (0123, 0319, #3091)', 'The fewest digits a new badge PIN may have. A PIN set earlier keeps working until its owner changes it. A short PIN falls to a guessing script in days, so 6 is the default.')
on conflict (key) do nothing;
-- END GENERATED SEED

create or replace function public.badge_auth_verify(p_uid text, p_pin text default null)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_hash text;
  v_badge public.member_badges;
  v_member public.members;
  v_profile public.profiles;
  v_enabled boolean;
  v_failures int := (public.setting_value(null, 'security.badge_lockout_failures') #>> '{}')::int;
  v_recent int;
  v_hour int;
  v_day int;
begin
  v_hash := public.badge_token_hash(p_uid);

  select * into v_badge from public.member_badges
   where token_hash = v_hash and revoked_at is null and auth_enabled
   order by created_at limit 1;

  -- Lockout is checked BEFORE the PIN, and on the tag alone, so an
  -- attacker cannot use the response time or shape to tell a real tag
  -- from a fake one. It GROWS (#3091): the configured failures within the
  -- configured window lock the tag for that window (15 minutes by default);
  -- twice as many within an hour lock it for the hour; three times as many
  -- within a day lock it for the day. One guessing script on one tag meets
  -- a wall that rises with every round instead of the same 15-minute gate.
  select count(*) filter (where attempted_at > now() - make_interval(mins => (public.setting_value(null, 'security.badge_lockout_minutes') #>> '{}')::int)),
         count(*) filter (where attempted_at > now() - interval '1 hour'),
         count(*)
    into v_recent, v_hour, v_day
    from public.badge_auth_attempts
   where token_hash = v_hash
     and not succeeded
     and attempted_at > now() - interval '24 hours';
  if v_recent >= v_failures or v_hour >= 2 * v_failures or v_day >= 3 * v_failures then
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
  select public.feature_effective_in(w.feature_flags, 'badgeSignIn')
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
  if coalesce((select k.pin_hash from public.account_badge_pins k where k.user_id = v_member.user_id), '') = ''
     or (select k.pin_hash from public.account_badge_pins k where k.user_id = v_member.user_id)
        <> extensions.crypt(p_pin, (select k.pin_hash from public.account_badge_pins k where k.user_id = v_member.user_id)) then
    insert into public.badge_auth_attempts (token_hash, succeeded)
      values (v_hash, false);
    return jsonb_build_object('ok', false, 'reason', 'refused');
  end if;

  insert into public.badge_auth_attempts (token_hash, succeeded)
    values (v_hash, true);
  return jsonb_build_object('ok', true, 'user_id', v_member.user_id);
end;
$function$;
revoke execute on function public.badge_auth_verify(text, text) from public, anon, authenticated;

create or replace function public.set_badge_pin(p_pin text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_min int := (public.setting_value(null, 'security.badge_pin_min_length') #>> '{}')::int;
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  -- At least the registry's minimum (6 by default, #3091) and at most 8
  -- digits. A PIN set earlier keeps working until its owner changes it.
  if p_pin !~ ('^[0-9]{' || v_min || ',8}$') then
    -- the client pins this substring
    raise exception 'the PIN must be % to 8 digits', v_min;
  end if;
  if p_pin in ('0000','1111','2222','3333','4444','5555','6666','7777',
               '8888','9999','1234','12345','123456','1234567','12345678',
               '4321','0123','000000','111111','654321','121212','112233') then
    -- the client pins this substring
    raise exception 'that PIN is too easy to guess';
  end if;
  insert into public.account_badge_pins (user_id, pin_hash, pin_set_at)
  values (auth.uid(), extensions.crypt(p_pin, extensions.gen_salt('bf', 10)), now())
  on conflict (user_id) do update
    set pin_hash = excluded.pin_hash, pin_set_at = excluded.pin_set_at;
end;
$function$;
revoke execute on function public.set_badge_pin(text) from public, anon;
grant execute on function public.set_badge_pin(text) to authenticated;

select public.set_deskilo_schema_version(610);
