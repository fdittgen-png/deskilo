-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (badge_auth_verify takes the kiosk's credential and is restated whole; the
--  old three-argument signature is dropped; businesses that already issued
--  badges keep signing in on any device until their owner switches)
--
-- #3675 (GHSA-9525-vh85-5hjg, step b) -- a business enrols the devices it
-- uses as kiosks and decides where badge sign-in works.
--
--  * kiosk_devices: an enrolled device of a business. The server keeps the
--    sha256 of the device's credential, never the credential; a revoked
--    device is kept with who revoked it and when. No client reads the table:
--    kiosk_devices_v1 lists it without the hash.
--  * enrol_kiosk_device_v1 / revoke_kiosk_device_v1: a holder of
--    operateKiosk or an owner, in their own session (never an assistant's),
--    with kioskEnrolment on. The credential is answered once, at enrolment.
--    Each enrolment and revocation tells the owners (event kiosk_device).
--  * security.badge_signin_where: enrolled_kiosks (the default) or
--    any_device. A business that already issued badges is set to any_device
--    here, so nothing changes for it until its owner switches.
--  * badge_auth_verify(uid, pin, source, device_id, device_secret): a device
--    counts only when it is enrolled, not revoked, its credential matches,
--    and it belongs to the business of the tag; otherwise it is exactly no
--    device. On such a kiosk the scan names the person and a paused
--    business answers "locked" for every tag. Without one, no answer tells a
--    tag of a business from an unknown tag, whatever the setting.

-- ── the devices ─────────────────────────────────────────────────────────
create table public.kiosk_devices (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 80),
  secret_hash text not null check (secret_hash ~ '^[0-9a-f]{64}$'),
  enrolled_by uuid references public.members(id) on delete set null,
  enrolled_at timestamptz not null default now(),
  last_used_at timestamptz,
  revoked_at timestamptz,
  revoked_by uuid references public.members(id) on delete set null
);
select public.ensure_system_columns('kiosk_devices');
create index kiosk_devices_workspace on public.kiosk_devices (workspace_id, enrolled_at desc);

comment on table public.kiosk_devices is
  '#3675 -- the devices a business enrolled as kiosks: badge sign-in may be limited to them. Only the sha256 of a device''s credential is kept.';

alter table public.kiosk_devices enable row level security;
revoke all on public.kiosk_devices from public, anon, authenticated;
create policy mcp_delegated_deny on public.kiosk_devices as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- Equality of two sha256 hex digests in a time that does not depend on
-- where they differ.
create or replace function public.same_sha256_hex(p_a text, p_b text)
returns boolean language plpgsql immutable set search_path = '' as $fn$
declare
  a bytea;
  b bytea;
  diff int := 0;
begin
  if p_a !~ '^[0-9a-f]{64}$' or p_b !~ '^[0-9a-f]{64}$' then
    return false;
  end if;
  a := decode(p_a, 'hex');
  b := decode(p_b, 'hex');
  for i in 0 .. 31 loop
    diff := diff | (get_byte(a, i) # get_byte(b, i));
  end loop;
  return diff = 0;
end;
$fn$;
revoke execute on function public.same_sha256_hex(text, text) from public, anon, authenticated;

-- The business of a valid device: enrolled, not revoked, and presenting its
-- own credential. Anything else is null, through the same steps: the digest
-- is always taken and always compared (with a stand-in for a missing row).
create or replace function public.kiosk_device_business(p_device_id uuid, p_secret text)
returns uuid language plpgsql security definer set search_path = '' as $fn$
declare
  v_presented text := encode(extensions.digest(coalesce(p_secret, ''), 'sha256'), 'hex');
  v_row public.kiosk_devices;
  v_same boolean;
begin
  select * into v_row from public.kiosk_devices
   where id = p_device_id and revoked_at is null;
  v_same := public.same_sha256_hex(v_presented,
    coalesce(v_row.secret_hash, repeat('0', 64)));
  if v_row.id is null or not v_same or coalesce(p_secret, '') = '' then
    return null;
  end if;
  return v_row.workspace_id;
end;
$fn$;
revoke execute on function public.kiosk_device_business(uuid, text) from public, anon, authenticated;

-- Who may enrol, list and revoke: a holder of operateKiosk or an owner, in
-- their own session.
create or replace function public.may_manage_kiosk_devices(p_workspace_id uuid)
returns boolean language sql stable security definer set search_path = '' as $fn$
  select auth.uid() is not null and not public.mcp_is_delegated() and (
    public.has_permission(p_workspace_id, 'operateKiosk')
    or exists (select 1 from public.members m
                where m.workspace_id = p_workspace_id and m.user_id = auth.uid()
                  and m.status = 'active' and (m.is_owner or m.co_owner = 'active')))
$fn$;
revoke execute on function public.may_manage_kiosk_devices(uuid) from public, anon, authenticated;

-- One event per owner: who did what to which device.
create or replace function public.tell_owners_kiosk_device(
  p_workspace_id uuid, p_change text, p_device public.kiosk_devices)
returns void language sql security definer set search_path = '' as $fn$
  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  select p_workspace_id, 'kiosk_device', 'created',
         (select a.id from public.members a
           where a.workspace_id = p_workspace_id and a.user_id = auth.uid() limit 1),
         m.id,
         jsonb_build_object('change', p_change, 'device_id', p_device.id, 'device_name', p_device.name),
         'applied'
    from public.members m
   where m.workspace_id = p_workspace_id and m.status = 'active'
     and (m.is_owner or m.co_owner = 'active')
$fn$;
revoke execute on function public.tell_owners_kiosk_device(uuid, text, public.kiosk_devices) from public, anon, authenticated;

-- Enrols the calling device. The credential is in this answer and nowhere
-- else, ever.
create or replace function public.enrol_kiosk_device_v1(p_workspace_id uuid, p_name text)
returns jsonb language plpgsql security definer set search_path = '' as $fn$
declare
  v_credential text;
  v_row public.kiosk_devices;
begin
  if not public.may_manage_kiosk_devices(p_workspace_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if not public.feature_effective(p_workspace_id, 'kioskEnrolment') then
    raise exception 'kiosk enrolment is off' using errcode = '42501';
  end if;
  if length(btrim(coalesce(p_name, ''))) not between 1 and 80 then
    raise exception 'a name of 1 to 80 characters is required' using errcode = '22023';
  end if;
  v_credential := encode(extensions.gen_random_bytes(32), 'hex');
  insert into public.kiosk_devices (workspace_id, name, secret_hash, enrolled_by)
  values (p_workspace_id, btrim(p_name),
          encode(extensions.digest(v_credential, 'sha256'), 'hex'),
          (select m.id from public.members m
            where m.workspace_id = p_workspace_id and m.user_id = auth.uid() limit 1))
  returning * into v_row;
  perform public.tell_owners_kiosk_device(p_workspace_id, 'enrolled', v_row);
  return jsonb_build_object('device_id', v_row.id, 'credential', v_credential);
end;
$fn$;
revoke execute on function public.enrol_kiosk_device_v1(uuid, text) from public, anon;
grant execute on function public.enrol_kiosk_device_v1(uuid, text) to authenticated;

-- Revokes a device: it is no kiosk from now on. false when it was revoked
-- already.
create or replace function public.revoke_kiosk_device_v1(p_device_id uuid)
returns boolean language plpgsql security definer set search_path = '' as $fn$
declare
  v_row public.kiosk_devices;
begin
  select * into v_row from public.kiosk_devices where id = p_device_id for update;
  if v_row.id is null or not public.may_manage_kiosk_devices(v_row.workspace_id) then
    raise exception 'unknown device' using errcode = '42501';
  end if;
  if v_row.revoked_at is not null then
    return false;
  end if;
  update public.kiosk_devices
     set revoked_at = now(),
         revoked_by = (select m.id from public.members m
                        where m.workspace_id = v_row.workspace_id and m.user_id = auth.uid() limit 1)
   where id = p_device_id
  returning * into v_row;
  perform public.tell_owners_kiosk_device(v_row.workspace_id, 'revoked', v_row);
  return true;
end;
$fn$;
revoke execute on function public.revoke_kiosk_device_v1(uuid) from public, anon;
grant execute on function public.revoke_kiosk_device_v1(uuid) to authenticated;

-- A business's devices, newest first, without their hash.
create or replace function public.kiosk_devices_v1(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $fn$
begin
  if not public.may_manage_kiosk_devices(p_workspace_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', d.id, 'name', d.name,
             'enrolled_by', public.profile_full_name(m.user_id),
             'enrolled_at', d.enrolled_at, 'last_used_at', d.last_used_at,
             'revoked_at', d.revoked_at) order by d.enrolled_at desc, d.id)
      from public.kiosk_devices d
      left join public.members m on m.id = d.enrolled_by
     where d.workspace_id = p_workspace_id), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.kiosk_devices_v1(uuid) from public, anon;
grant execute on function public.kiosk_devices_v1(uuid) to authenticated;

-- ── where badge sign-in works ───────────────────────────────────────────
-- SETTING SEED (generated below)

-- A business that already issued badges keeps today's behaviour until its
-- owner switches.
-- EXISTING BUSINESSES (below)

-- ── the pause ───────────────────────────────────────────────────────────
-- Badge sign-in of a business is paused while as many distinct badges of it
-- as its ceiling failed their PIN within the window.
create or replace function public.badge_signin_paused(p_workspace_id uuid)
returns boolean language plpgsql stable security definer set search_path = '' as $fn$
declare
  v_window int := (public.setting_value(null, 'security.badge_lockout_minutes') #>> '{}')::int;
  v_limit int := (public.setting_value(p_workspace_id, 'security.badge_workspace_failure_limit') #>> '{}')::int;
begin
  return p_workspace_id is not null and (
    select count(distinct token_hash) from public.badge_auth_attempts
     where workspace_id = p_workspace_id and not succeeded and step = 'pin'
       and attempted_at > now() - make_interval(mins => v_window)) >= v_limit;
end;
$fn$;
revoke execute on function public.badge_signin_paused(uuid) from public, anon, authenticated;

drop function if exists public.badge_auth_verify(text, text, text);
create or replace function public.badge_auth_verify(
  p_uid text, p_pin text default null, p_source text default null,
  p_device_id uuid default null, p_device_secret text default null)
returns jsonb language plpgsql security definer set search_path = '' as $fn$
declare
  v_hash text := public.badge_token_hash(p_uid);
  v_source text := public.badge_source_key(p_source);
  v_badge public.member_badges;
  v_member public.members;
  v_pin_hash text;
  v_pin_matches boolean := false;
  v_enabled boolean := false;
  v_failures int := (public.setting_value(null, 'security.badge_lockout_failures') #>> '{}')::int;
  v_window int := (public.setting_value(null, 'security.badge_lockout_minutes') #>> '{}')::int;
  v_per_tag int;
  v_per_source int;
  v_recent int;
  v_hour int;
  v_day int;
  v_profile public.profiles;
  v_kiosk uuid;
  v_on_kiosk boolean;
  v_where text;
  v_name text;
begin
  -- #3675: the device first, through the same steps whether it is one or
  -- not; a revoked, unknown or foreign device is no device.
  v_kiosk := public.kiosk_device_business(p_device_id, p_device_secret);

  -- SCAN: counted per tag and per source; the same answer for every tag,
  -- except on a valid kiosk, which names the person of its own business.
  if p_pin is null then
    v_per_tag := (public.setting_value(null, 'security.badge_identify_per_tag_limit') #>> '{}')::int;
    v_per_source := (public.setting_value(null, 'security.badge_identify_per_source_limit') #>> '{}')::int;
    perform pg_advisory_xact_lock(hashtextextended('badge-identify:' || v_hash, 0));
    if v_source is not null then
      perform pg_advisory_xact_lock(hashtextextended('badge-identify-source:' || v_source, 0));
    end if;
    -- Scans older than the window count for nothing: they go.
    delete from public.badge_auth_attempts
     where step = 'identify' and attempted_at <= now() - make_interval(mins => v_window);
    if v_source is not null and (select count(*) from public.badge_auth_attempts
         where source_hash = v_source and step = 'identify') >= v_per_source then
      -- One place scanning past its ceiling: the business of a known badge
      -- is told once per window.
      select * into v_badge from public.member_badges
       where token_hash = v_hash and revoked_at is null
       order by created_at, id limit 1;
      if v_badge.workspace_id is not null and not exists (
        select 1 from public.events where workspace_id = v_badge.workspace_id
          and type = 'badge_security_alert'
          and created_at > now() - make_interval(mins => v_window)) then
        insert into public.events
          (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
        select v_badge.workspace_id, 'badge_security_alert', 'created', m.id, m.id,
          jsonb_build_object('failures', v_per_source, 'window_minutes', v_window), 'applied'
          from public.members m where m.workspace_id = v_badge.workspace_id
            and m.status = 'active' and (m.is_owner or m.co_owner = 'active');
      end if;
      return jsonb_build_object('ok', false, 'reason', 'locked');
    end if;
    if (select count(*) from public.badge_auth_attempts
         where token_hash = v_hash and step = 'identify') >= v_per_tag then
      return jsonb_build_object('ok', false, 'reason', 'locked');
    end if;
    -- A valid kiosk of a paused business: every tag scanned there waits.
    if v_kiosk is not null and public.badge_signin_paused(v_kiosk) then
      return jsonb_build_object('ok', false, 'reason', 'locked');
    end if;
    insert into public.badge_auth_attempts (token_hash, succeeded, step, source_hash)
    values (v_hash, true, 'identify', v_source);
    if v_kiosk is not null then
      select p.display_name into v_name
        from public.member_badges b
        join public.members m on m.id = b.member_id and m.status = 'active'
        join public.workspaces w on w.id = b.workspace_id
        join public.profiles p on p.id = m.user_id
       where b.token_hash = v_hash and b.revoked_at is null and b.auth_enabled
         and b.workspace_id = v_kiosk
         and public.feature_effective_in(w.feature_flags, 'badgeSignIn')
       order by b.created_at, b.id limit 1;
      if v_name is not null then
        return jsonb_build_object('ok', true, 'display_name', v_name);
      end if;
    end if;
    return jsonb_build_object('ok', true);
  end if;

  select * into v_badge from public.member_badges
   where token_hash = v_hash and revoked_at is null and auth_enabled
   order by created_at, id limit 1;
  v_on_kiosk := v_kiosk is not null and v_kiosk = v_badge.workspace_id;

  -- Every PIN attempt does one bcrypt operation at the stored cost, including
  -- unknown, inactive, disabled, missing-PIN, off-kiosk and locked
  -- credentials. This fixed dummy is not a credential and can never
  -- authorize an account.
  select k.pin_hash into v_pin_hash from public.account_badge_pins k
    join public.members m on m.user_id = k.user_id where m.id = v_badge.member_id;
  v_pin_matches := extensions.crypt(p_pin, coalesce(nullif(v_pin_hash,''),
    '$2a$10$2plMicy7EHI.UoIbbvMoN.1Qo8HHEaVimd3U1x43GzYgUfyETw.H.')) = v_pin_hash;

  -- Serialize the check and the failure record across badges of one workspace.
  -- An unknown tag retains its own lock without charging an unrelated workspace.
  perform pg_advisory_xact_lock(hashtextextended(
    'badge-signin:' || coalesce(v_badge.workspace_id::text, v_hash), 0));
  select count(*) filter (where attempted_at > now() - make_interval(mins => v_window)),
         count(*) filter (where attempted_at > now() - interval '1 hour'), count(*)
    into v_recent, v_hour, v_day from public.badge_auth_attempts
   where token_hash = v_hash and not succeeded and step = 'pin'
     and attempted_at > now() - interval '24 hours';
  if v_recent >= v_failures or v_hour >= 2*v_failures or v_day >= 3*v_failures then
    return jsonb_build_object('ok',false,'reason','locked');
  end if;
  -- A valid kiosk of a paused business: every tag there waits.
  if v_kiosk is not null and public.badge_signin_paused(v_kiosk) then
    return jsonb_build_object('ok',false,'reason','locked');
  end if;
  -- Off a kiosk of its own business, a tag of a business that signs in on
  -- enrolled kiosks only, or of a paused one, is answered and counted as an
  -- unknown tag: per tag, never against the business.
  if not v_on_kiosk and v_badge.workspace_id is not null then
    v_where := public.setting_value(v_badge.workspace_id, 'security.badge_signin_where') #>> '{}';
    if v_where is distinct from 'any_device' or public.badge_signin_paused(v_badge.workspace_id) then
      perform public.record_badge_auth_failure(v_hash, null);
      return jsonb_build_object('ok',false,'reason','refused');
    end if;
  end if;

  select * into v_member from public.members
   where id = v_badge.member_id and status = 'active';
  if v_member.id is not null then
    select public.feature_effective_in(w.feature_flags,'badgeSignIn') into v_enabled
      from public.workspaces w where w.id = v_member.workspace_id;
  end if;
  if v_badge.id is null or v_member.id is null or not coalesce(v_enabled,false)
      or length(coalesce(p_uid,'')) < 8 or not coalesce(v_pin_matches,false) then
    perform public.record_badge_auth_failure(v_hash,v_badge.workspace_id);
    return jsonb_build_object('ok',false,'reason','refused');
  end if;
  insert into public.badge_auth_attempts (token_hash,succeeded,workspace_id,step)
  values (v_hash,true,v_badge.workspace_id,'pin');
  -- The right PIN: this badge's scans stop counting.
  delete from public.badge_auth_attempts
   where step = 'identify' and token_hash = v_hash;
  if v_on_kiosk then
    update public.kiosk_devices set last_used_at = now() where id = p_device_id;
  end if;
  select * into v_profile from public.profiles where id = v_member.user_id;
  -- The name is said once the PIN is right.
  return jsonb_build_object('ok',true,'user_id',v_member.user_id,
    'display_name',coalesce(v_profile.display_name,''));
end;
$fn$;
revoke execute on function public.badge_auth_verify(text, text, text, uuid, text) from public, anon, authenticated;
grant execute on function public.badge_auth_verify(text, text, text, uuid, text) to service_role;
