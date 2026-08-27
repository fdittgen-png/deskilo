-- SPDX-License-Identifier: 0BSD
-- #662 — sign in by scanning an RFID badge: the tag IDENTIFIES, a PIN
-- CONFIRMS. Two steps behind one form; the sequencing is what lets the
-- PIN belong to the user rather than to a workspace, because sign-in
-- happens before anyone knows which workspace is being entered.
--
-- WHY A PIN AT ALL. An RFID UID is not a secret: it is broadcast to any
-- reader a few centimetres away and clonable with hardware costing about
-- thirty euros. Until now that was contained — a badge only worked at a
-- device already authenticated as a workspace kiosk, standing in the
-- space, and only to book. Turning the UID into a login credential would
-- make it a password anyone can copy off a member in a lift and replay
-- from any device, with the member unable to tell. The PIN is what keeps
-- a cloned tag worthless.
--
-- WHAT THIS MIGRATION DOES AND DELIBERATELY DOES NOT DO. It stores the
-- PIN, marks which badges may sign in, and records attempts so the PIN
-- can be rate limited. It does NOT mint sessions: no SQL function here
-- can turn a tag into a login, because a function that could would be
-- one `grant` away from being callable by `anon`. The exchange lives in
-- the `badge-signin` Edge Function under the service role, and the
-- helpers below are REVOKED from public and anon so only it can reach
-- them.

-- ---------------------------------------------------------------- 1
-- A badge is a booking credential until its owner deliberately makes it
-- a sign-in credential. Every badge that exists today keeps exactly the
-- powers it has now.
alter table public.member_badges
  add column if not exists auth_enabled boolean not null default false;

comment on column public.member_badges.auth_enabled is
  '#662 — may this badge be used to SIGN IN (not just to act at a '
  'kiosk)? Default false: enabling it is an explicit act by the badge''s '
  'own member, because it turns a tag into a key.';

-- ---------------------------------------------------------------- 2
-- The PIN lives on the ACCOUNT. Sign-in precedes knowing the workspace,
-- so a per-workspace PIN could not be resolved at the moment it is
-- needed. One PIN therefore covers every space the member belongs to —
-- stated plainly because it is a real consequence: compromise reaches
-- all of them.
--
-- Stored as a bcrypt hash via pgcrypto, never reversible, never returned
-- by any query below. pgcrypto lives in the `extensions` schema on this
-- project, and every function here pins `search_path = public`, so the
-- calls are SCHEMA-QUALIFIED: `extensions.crypt(...)`. An unqualified
-- call parses fine and fails at RUN time — the DDL applies, and the
-- first real sign-in is what discovers it.
alter table public.profiles
  add column if not exists pin_hash text not null default '',
  add column if not exists pin_set_at timestamptz;

comment on column public.profiles.pin_hash is
  '#662 — bcrypt hash of the badge sign-in PIN, or empty when unset. '
  'Never selected by any client-facing function.';

-- ---------------------------------------------------------------- 3
-- Attempts, so a four-digit PIN cannot simply be enumerated: ~5 000
-- tries would otherwise walk the space. Keyed on the BADGE rather than
-- the account, because the attacker holds a tag, not an e-mail.
create table if not exists public.badge_auth_attempts (
  id uuid primary key default gen_random_uuid(),
  token_hash text not null,
  succeeded boolean not null,
  attempted_at timestamptz not null default now()
);

create index if not exists badge_auth_attempts_recent
  on public.badge_auth_attempts (token_hash, attempted_at desc);

-- Deny-all: the attempt log is an attack signal, and reading it would
-- tell an attacker which tags exist. Only the service role touches it.
alter table public.badge_auth_attempts enable row level security;

-- ---------------------------------------------------------------- 4
-- The member's own PIN management. `security definer` so the write
-- reaches profiles.pin_hash, which no RLS policy exposes; scoped hard to
-- auth.uid() so it can only ever set the caller's own.
create or replace function public.set_badge_pin(p_pin text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  -- 4 to 8 digits. Short enough to type at a door, long enough that the
  -- lockout below does the rest of the work.
  if p_pin !~ '^[0-9]{4,8}$' then
    -- the client pins this substring
    raise exception 'the PIN must be 4 to 8 digits';
  end if;
  -- Reject the sequences people reach for first; a lockout protects a
  -- guessed PIN, but not one an attacker tries FIRST.
  if p_pin in ('0000','1111','2222','3333','4444','5555','6666','7777',
               '8888','9999','1234','12345','123456','1234567','12345678',
               '4321','0123') then
    -- the client pins this substring
    raise exception 'that PIN is too easy to guess';
  end if;
  update public.profiles
     set pin_hash = extensions.crypt(p_pin, extensions.gen_salt('bf', 10)),
         pin_set_at = now()
   where id = auth.uid();
end;
$$;

create or replace function public.clear_badge_pin()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  update public.profiles
     set pin_hash = '', pin_set_at = null
   where id = auth.uid();
  -- Without a PIN nothing may sign in with a tag: clearing the PIN
  -- disarms every badge at once, which is the behaviour someone
  -- clearing it expects.
  update public.member_badges b
     set auth_enabled = false
    from public.members m
   where b.member_id = m.id and m.user_id = auth.uid()
     and b.auth_enabled;
end;
$$;

-- Whether the CALLER has a PIN — a boolean, never the hash. The settings
-- screen needs to say "set" or "not set" without ever reading it.
create or replace function public.has_badge_pin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select pin_hash <> '' from public.profiles
                    where id = auth.uid()), false);
$$;

-- Arm or disarm ONE of the caller's own badges. A member may only ever
-- reach a badge that belongs to a membership of theirs.
create or replace function public.set_badge_auth_enabled(
  p_badge_id uuid, p_enabled boolean
) returns void language plpgsql security definer set search_path = public as $$
declare v_owned boolean;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select exists (
    select 1 from public.member_badges b
    join public.members m on m.id = b.member_id
    where b.id = p_badge_id and m.user_id = auth.uid()
      and b.revoked_at is null
  ) into v_owned;
  if not v_owned then raise exception 'not your badge'; end if;
  -- Arming a badge without a PIN would be exactly the "UID is the
  -- password" design this feature exists to avoid.
  if p_enabled and not public.has_badge_pin() then
    -- the client pins this substring
    raise exception 'set a PIN before a badge can sign you in';
  end if;
  update public.member_badges
     set auth_enabled = p_enabled
   where id = p_badge_id;
end;
$$;

revoke execute on function public.set_badge_pin(text) from public, anon;
revoke execute on function public.clear_badge_pin() from public, anon;
revoke execute on function public.has_badge_pin() from public, anon;
revoke execute on function public.set_badge_auth_enabled(uuid, boolean)
  from public, anon;

-- ---------------------------------------------------------------- 5
-- THE verification, for the Edge Function alone.
--
-- One function does identify AND verify so the two can never drift
-- apart, and so the attempt is recorded on the same code path that
-- decides. It returns a uniform failure — unknown tag, disarmed badge,
-- wrong PIN and lockout are indistinguishable to the caller — because
-- telling them apart is how an attacker learns which tags are real.
--
-- p_pin null = the IDENTIFY step: it resolves who the tag belongs to
-- WITHOUT consuming an attempt, so a member fumbling their PIN is not
-- locked out by the scan itself. It reveals a display name and whether
-- an avatar exists; deliberately never an e-mail.
create or replace function public.badge_auth_verify(
  p_uid text, p_pin text default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_hash text;
  v_badge public.member_badges;
  v_member public.members;
  v_profile public.profiles;
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

-- The Edge Function calls this as the service role. Nobody else may:
-- reaching it directly would hand out a "does this tag exist" oracle,
-- and — with a PIN — the ability to brute force one outside any client.
revoke execute on function public.badge_auth_verify(text, text)
  from public, anon, authenticated;

-- ...but the Edge Function DOES need it, and `revoke ... from public`
-- strips the grant `service_role` inherits through PUBLIC as well. Found
-- the hard way: without this line the function refused every badge,
-- including valid ones, with the same `refused` a stranger gets — the
-- uniform failure shape that protects members also hid this bug.
grant execute on function public.badge_auth_verify(text, text)
  to service_role;

-- PostgREST caches the schema; without this the new functions are
-- invisible until the next pool recycle.
notify pgrst, 'reload schema';
