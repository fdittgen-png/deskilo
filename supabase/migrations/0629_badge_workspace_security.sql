-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- Existing PINs remain usable; their historical length is unknown until changed.

alter table public.account_badge_pins
  add column if not exists pin_length smallint
  check (pin_length between 4 and 8);

alter table public.badge_auth_attempts
  add column if not exists workspace_id uuid references public.workspaces(id) on delete cascade;
create index if not exists badge_auth_attempts_workspace_failures
  on public.badge_auth_attempts (workspace_id, attempted_at desc) where not succeeded;

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('security.badge_workspace_failure_limit', 'int', '50'::jsonb, 1, 50, 'attempts', 'security', array['platform', 'workspace'], 'workspaceSettings', null, true, null, 'badge workspace sign-in failure ceiling', 'Failed PIN attempts across all badges of one workspace within the badge lockout window. Reaching this ceiling pauses badge sign-in and alerts the owners. May be tightened, never loosened.')
on conflict (key) do nothing;
-- END GENERATED SEED

-- Preserve event types introduced by every earlier migration.
do $constraints$
declare r record; v_def text;
begin
  for r in select * from (values
    ('events','events_type_check','type'),
    ('validation_policies','validation_policies_event_type_check','event_type')
  ) as c(table_name,constraint_name,column_name) loop
    select pg_get_constraintdef(oid) into v_def from pg_constraint
     where conrelid=('public.'||r.table_name)::regclass and conname=r.constraint_name;
    if v_def is null or position('CHECK (' in v_def) <> 1 then
      raise exception 'event type constraint anchor missing: %',r.constraint_name;
    end if;
    if position('badge_security_alert' in v_def)=0 then
      execute format('alter table public.%I drop constraint %I',r.table_name,r.constraint_name);
      execute format('alter table public.%I add constraint %I ',r.table_name,r.constraint_name)
        || replace(v_def,'CHECK (',format('CHECK (%I = %L OR ',r.column_name,'badge_security_alert'));
    end if;
  end loop;
end;
$constraints$;

-- The caller holds the workspace lock, so the threshold transition and alert
-- are atomic even when several badges are attacked concurrently.
create or replace function public.record_badge_auth_failure(p_hash text, p_workspace uuid)
returns void language plpgsql security definer set search_path = '' as $fn$
declare
  v_window int := (public.setting_value(null, 'security.badge_lockout_minutes') #>> '{}')::int;
  v_limit int;
  v_count int;
begin
  insert into public.badge_auth_attempts (token_hash, succeeded, workspace_id)
  values (p_hash, false, p_workspace);
  if p_workspace is null then return; end if;
  v_limit := (public.setting_value(p_workspace, 'security.badge_workspace_failure_limit') #>> '{}')::int;
  select count(*) into v_count from public.badge_auth_attempts
   where workspace_id = p_workspace and not succeeded
     and attempted_at > now() - make_interval(mins => v_window);
  if v_count >= v_limit and not exists (
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

create or replace function public.badge_auth_verify(p_uid text, p_pin text default null)
returns jsonb language plpgsql security definer set search_path = '' as $fn$
declare
  v_hash text := public.badge_token_hash(p_uid);
  v_badge public.member_badges;
  v_member public.members;
  v_pin_hash text;
  v_pin_matches boolean := false;
  v_enabled boolean := false;
  v_failures int := (public.setting_value(null, 'security.badge_lockout_failures') #>> '{}')::int;
  v_window int := (public.setting_value(null, 'security.badge_lockout_minutes') #>> '{}')::int;
  v_recent int;
  v_hour int;
  v_day int;
  v_workspace_failures int;
  v_limit int;
  v_profile public.profiles;
begin
  select * into v_badge from public.member_badges
   where token_hash = v_hash and revoked_at is null and auth_enabled
   order by created_at, id limit 1;

  -- Every PIN attempt does one bcrypt operation at the stored cost, including
  -- unknown, inactive, disabled, missing-PIN and locked credentials. This fixed
  -- dummy is not a credential and can never authorize an account.
  select k.pin_hash into v_pin_hash from public.account_badge_pins k
    join public.members m on m.user_id = k.user_id where m.id = v_badge.member_id;
  if p_pin is not null then
    v_pin_matches := extensions.crypt(p_pin, coalesce(nullif(v_pin_hash,''),
      '$2a$10$2plMicy7EHI.UoIbbvMoN.1Qo8HHEaVimd3U1x43GzYgUfyETw.H.')) = v_pin_hash;
  end if;

  -- Serialize the check and the failure record across badges of one workspace.
  -- An unknown tag retains its own lock without charging an unrelated workspace.
  perform pg_advisory_xact_lock(hashtextextended(
    'badge-signin:' || coalesce(v_badge.workspace_id::text, v_hash), 0));
  select count(*) filter (where attempted_at > now() - make_interval(mins => v_window)),
         count(*) filter (where attempted_at > now() - interval '1 hour'), count(*)
    into v_recent, v_hour, v_day from public.badge_auth_attempts
   where token_hash = v_hash and not succeeded
     and attempted_at > now() - interval '24 hours';
  if v_recent >= v_failures or v_hour >= 2*v_failures or v_day >= 3*v_failures then
    return jsonb_build_object('ok',false,'reason','locked');
  end if;
  if v_badge.workspace_id is not null then
    v_limit := (public.setting_value(v_badge.workspace_id, 'security.badge_workspace_failure_limit') #>> '{}')::int;
    select count(*) into v_workspace_failures from public.badge_auth_attempts
     where workspace_id = v_badge.workspace_id and not succeeded
       and attempted_at > now() - make_interval(mins => v_window);
    if v_workspace_failures >= v_limit then
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
      or length(coalesce(p_uid,'')) < 8 then
    if p_pin is not null then
      perform public.record_badge_auth_failure(v_hash,v_badge.workspace_id);
    end if;
    return jsonb_build_object('ok',false,'reason','refused');
  end if;
  if p_pin is null then
    select * into v_profile from public.profiles where id = v_member.user_id;
    return jsonb_build_object('ok',true,'user_id',v_member.user_id,
      'display_name',coalesce(v_profile.display_name,''),
      'has_avatar',coalesce(v_profile.avatar_path,'') <> '');
  end if;
  if not coalesce(v_pin_matches,false) then
    perform public.record_badge_auth_failure(v_hash,v_badge.workspace_id);
    return jsonb_build_object('ok',false,'reason','refused');
  end if;
  insert into public.badge_auth_attempts (token_hash,succeeded,workspace_id)
  values (v_hash,true,v_badge.workspace_id);
  return jsonb_build_object('ok',true,'user_id',v_member.user_id);
end;
$fn$;
revoke execute on function public.badge_auth_verify(text,text) from public, anon, authenticated;
grant execute on function public.badge_auth_verify(text,text) to service_role;

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
  insert into public.account_badge_pins (user_id, pin_hash, pin_set_at, pin_length)
  values (auth.uid(), extensions.crypt(p_pin, extensions.gen_salt('bf', 10)), now(), length(p_pin))
  on conflict (user_id) do update
    set pin_hash = excluded.pin_hash, pin_set_at = excluded.pin_set_at,
        pin_length = excluded.pin_length;
end;
$function$;
revoke execute on function public.set_badge_pin(text) from public, anon;
grant execute on function public.set_badge_pin(text) to authenticated;

-- Only badge administrators may learn that a member needs a PIN refresh;
-- neither the PIN, its hash nor its length crosses this boundary.
create or replace function public.badge_pin_needs_review(p_workspace_id uuid, p_member_id uuid)
returns boolean language plpgsql stable security definer set search_path = '' as $fn$
begin
  if auth.uid() is null or not public.has_permission(p_workspace_id,'operateKiosk') then
    raise exception 'not allowed';
  end if;
  if not public.feature_effective(p_workspace_id,'badgeSignIn') then return false; end if;
  return exists (
    select 1 from public.members m join public.account_badge_pins k on k.user_id=m.user_id
     where m.workspace_id=p_workspace_id and m.id=p_member_id
       and (k.pin_length is null or k.pin_length <
         (public.setting_value(null,'security.badge_pin_min_length') #>> '{}')::int)
  );
end;
$fn$;
revoke execute on function public.badge_pin_needs_review(uuid,uuid) from public,anon;
grant execute on function public.badge_pin_needs_review(uuid,uuid) to authenticated;

select public.set_deskilo_schema_version(629);
