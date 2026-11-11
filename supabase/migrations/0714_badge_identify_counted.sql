-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (two nullable/defaulted columns on public.badge_auth_attempts, two
-- registry settings, badge_auth_verify and record_badge_auth_failure
-- restated; existing rows are PIN attempts and keep their meaning)
--
-- #3594 lane, GHSA-9525-vh85-5hjg -- badge sign-in at the kiosk:
--
--  * the scan step names nobody: it answers the same for every well-formed
--    tag, and the name appears once the PIN is right;
--  * the scan step is counted here, per tag and per source, within the
--    badge lockout window; past either ceiling it answers "wait";
--  * the business-wide pause counts the DISTINCT badges that failed in the
--    window, so one badge cannot pause badge sign-in for everyone.

alter table public.badge_auth_attempts
  add column if not exists step text not null default 'pin'
    check (step in ('identify', 'pin')),
  add column if not exists source_hash text;

create index if not exists badge_auth_attempts_identify_source
  on public.badge_auth_attempts (source_hash, attempted_at desc)
  where step = 'identify';

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('security.badge_identify_per_tag_limit', 'int', '10'::jsonb, 1, 10, 'attempts', 'security', array['platform'], 'workspaceSettings', null, true, null, 'badge_auth_verify scan step (#3594 lane)', 'Scans of one badge within the badge lockout window before the scan step answers wait. May be tightened, never loosened.'),
('security.badge_identify_per_source_limit', 'int', '30'::jsonb, 1, 30, 'attempts', 'security', array['platform'], 'workspaceSettings', null, true, null, 'badge_auth_verify scan step (#3594 lane)', 'Scans from one source within the badge lockout window before the scan step answers wait. May be tightened, never loosened.')
on conflict (key) do nothing;
-- END GENERATED SEED

update public.setting_definitions
   set note = 'Distinct badges of one workspace with a failed PIN within the badge lockout window. Reaching this ceiling pauses badge sign-in and alerts the owners; one badge alone cannot reach it. May be tightened, never loosened.'
 where key = 'security.badge_workspace_failure_limit';

create or replace function public.record_badge_auth_failure(p_hash text, p_workspace uuid)
returns void language plpgsql security definer set search_path = '' as $fn$
declare
  v_window int := (public.setting_value(null, 'security.badge_lockout_minutes') #>> '{}')::int;
  v_limit int;
  v_badges int;
  v_count int;
begin
  insert into public.badge_auth_attempts (token_hash, succeeded, workspace_id, step)
  values (p_hash, false, p_workspace, 'pin');
  if p_workspace is null then return; end if;
  v_limit := (public.setting_value(p_workspace, 'security.badge_workspace_failure_limit') #>> '{}')::int;
  select count(distinct token_hash), count(*) into v_badges, v_count
    from public.badge_auth_attempts
   where workspace_id = p_workspace and not succeeded and step = 'pin'
     and attempted_at > now() - make_interval(mins => v_window);
  if v_badges >= v_limit and not exists (
    select 1 from public.events where workspace_id = p_workspace
      and type = 'badge_security_alert'
      and created_at > now() - make_interval(mins => v_window)
  ) then
    insert into public.events
      (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
    select p_workspace, 'badge_security_alert', 'created', m.id, m.id,
      jsonb_build_object('failures', v_count, 'window_minutes', v_window), 'applied'
      from public.members m where m.workspace_id = p_workspace
        and m.status = 'active' and (m.is_owner or m.co_owner = 'active');
  end if;
end;
$fn$;
revoke execute on function public.record_badge_auth_failure(text,uuid) from public, anon, authenticated;

drop function if exists public.badge_auth_verify(text, text);

create or replace function public.badge_auth_verify(
  p_uid text, p_pin text default null, p_source text default null)
returns jsonb language plpgsql security definer set search_path = '' as $fn$
declare
  v_hash text := public.badge_token_hash(p_uid);
  v_source text := case when p_source is null then null
                        else public.badge_token_hash(p_source) end;
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
  v_workspace_badges int;
  v_limit int;
  v_profile public.profiles;
begin
  -- SCAN: the same answer for every well-formed tag, counted per tag and
  -- per source. Nothing about the badge or its owner is read here.
  if p_pin is null then
    v_per_tag := (public.setting_value(null, 'security.badge_identify_per_tag_limit') #>> '{}')::int;
    v_per_source := (public.setting_value(null, 'security.badge_identify_per_source_limit') #>> '{}')::int;
    perform pg_advisory_xact_lock(hashtextextended('badge-identify:' || v_hash, 0));
    if (select count(*) from public.badge_auth_attempts
         where token_hash = v_hash and step = 'identify'
           and attempted_at > now() - make_interval(mins => v_window)) >= v_per_tag
       or (v_source is not null and (select count(*) from public.badge_auth_attempts
         where source_hash = v_source and step = 'identify'
           and attempted_at > now() - make_interval(mins => v_window)) >= v_per_source) then
      return jsonb_build_object('ok', false, 'reason', 'locked');
    end if;
    insert into public.badge_auth_attempts (token_hash, succeeded, step, source_hash)
    values (v_hash, true, 'identify', v_source);
    return jsonb_build_object('ok', true);
  end if;

  select * into v_badge from public.member_badges
   where token_hash = v_hash and revoked_at is null and auth_enabled
   order by created_at, id limit 1;

  -- Every PIN attempt does one bcrypt operation at the stored cost, including
  -- unknown, inactive, disabled, missing-PIN and locked credentials. This fixed
  -- dummy is not a credential and can never authorize an account.
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
  if v_badge.workspace_id is not null then
    v_limit := (public.setting_value(v_badge.workspace_id, 'security.badge_workspace_failure_limit') #>> '{}')::int;
    select count(distinct token_hash) into v_workspace_badges from public.badge_auth_attempts
     where workspace_id = v_badge.workspace_id and not succeeded and step = 'pin'
       and attempted_at > now() - make_interval(mins => v_window);
    if v_workspace_badges >= v_limit then
      return jsonb_build_object('ok',false,'reason','locked');
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
  select * into v_profile from public.profiles where id = v_member.user_id;
  -- The name is said once the PIN is right.
  return jsonb_build_object('ok',true,'user_id',v_member.user_id,
    'display_name',coalesce(v_profile.display_name,''));
end;
$fn$;
revoke execute on function public.badge_auth_verify(text,text,text) from public, anon, authenticated;
grant execute on function public.badge_auth_verify(text,text,text) to service_role;

select public.set_deskilo_schema_version(714);
