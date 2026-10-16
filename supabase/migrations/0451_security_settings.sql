-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0451 (#2485, S2 of #2483) -- the security and access limits are registry
-- settings; no limit stays a literal in SQL.
--
-- Seven rows (group `security`), each with a bound that lets an owner TIGHTEN
-- the limit and never loosen it past today's value (#2596):
--   security.badge_lockout_failures    5 attempts, 1..5        (platform)
--   security.badge_lockout_minutes     15 minutes, 15..1440    (platform)
--   security.invitation_expiry_days    14 days, 1..14          (platform, workspace)
--   mcp.confirmation_expiry_minutes    5 minutes, 1..5         (platform)
--   mcp.probe_freshness_minutes        15 minutes, 1..15       (platform)
--   messaging.group_creation_per_hour  10, 1..10               (platform)
--   messaging.message_requests_per_day 10, 1..10               (platform)
-- Defaults are today's values exactly. The badge lockout runs before the
-- badge is resolved to a workspace, so it reads the platform value: a caller
-- cannot pick an easier workspace.
--
-- Anchored patches (pg_temp.anchor_replace, as 0227/0230) of the live bodies of
-- badge_auth_verify, instance_mcp_overview, instance_set_mcp_runtime,
-- create_account_group, send_account_message and create_invitation. Each anchor
-- is asserted to occur exactly once, so a body that drifted fails the migration
-- instead of shipping a silent no-op.
--
-- An invitation and an assistant confirmation keep the expiry they were created
-- with (the setting is read at creation only): create_invitation now writes
-- expires_at, and the confirmation table's column default calls
-- public.mcp_confirmation_expires_at() instead of a literal interval, so none of
-- the mcp_* functions is restated.

-- ── the registry rows ────────────────────────────────────────────────────
-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('security.badge_lockout_failures', 'int', '5'::jsonb, 1, 5, 'attempts', 'security', array['platform'], 'workspaceSettings', null, true, null, 'badge_auth_verify (0123, 0124)', 'Failed badge PIN attempts within the lockout window before a badge is locked. May be tightened (fewer attempts), never loosened.'),
('security.badge_lockout_minutes', 'duration', '15'::jsonb, 15, 1440, 'minutes', 'security', array['platform'], 'workspaceSettings', null, true, null, 'badge_auth_verify (0123, 0124)', 'Minutes over which failed badge PIN attempts are counted, and for which a locked badge stays locked. May be lengthened, never shortened.'),
('security.invitation_expiry_days', 'duration', '14'::jsonb, 1, 14, 'days', 'security', array['platform', 'workspace'], 'manageMembers', null, true, null, 'create_invitation (0051, 0361)', 'Days a personal invitation stays redeemable. An invitation keeps the expiry it was created with. May be shortened, never lengthened.'),
('mcp.confirmation_expiry_minutes', 'duration', '5'::jsonb, 1, 5, 'minutes', 'security', array['platform'], 'workspaceSettings', null, true, null, 'mcp_action_confirmations (0272)', 'Minutes an assistant-requested action waits for the person to confirm it. A confirmation keeps the expiry it was created with. May be shortened, never lengthened.'),
('mcp.probe_freshness_minutes', 'duration', '15'::jsonb, 1, 15, 'minutes', 'security', array['platform'], 'workspaceSettings', null, true, null, 'instance_mcp_overview, instance_set_mcp_runtime (0343, 0360)', 'Minutes a successful check of the MCP endpoint stays fresh enough to turn the interface on. May be shortened, never lengthened.'),
('messaging.group_creation_per_hour', 'int', '10'::jsonb, 1, 10, 'per hour', 'security', array['platform'], 'workspaceSettings', null, true, null, 'create_account_group (0384)', 'Groups one person may create per hour. May be lowered, never raised.'),
('messaging.message_requests_per_day', 'int', '10'::jsonb, 1, 10, 'per day', 'security', array['platform'], 'workspaceSettings', null, true, null, 'send_account_message (0388)', 'Message requests one person may send per day to people who did not allow them. May be lowered, never raised.')
on conflict (key) do nothing;
-- END GENERATED SEED

-- ── the anchored-patch helpers (session-local) ───────────────────────────
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

-- Patch a function's live definition: every anchor must be present exactly once.
create or replace function pg_temp.patch_function(p_proc regprocedure, p_old text[], p_new text[])
returns void
language plpgsql
as $f$
declare
  v_def text := pg_get_functiondef(p_proc);
  v_next text;
  v_pattern text;
  i int;
begin
  for i in 1 .. cardinality(p_old) loop
    if position(p_old[i] in v_def) > 0 then
      if (length(v_def) - length(replace(v_def, p_old[i], ''))) <> length(p_old[i]) then
        raise exception '0451: anchor % occurs more than once in %', i, p_proc;
      end if;
    else
      v_pattern := regexp_replace(btrim(p_old[i], E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
      v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
      if (select count(*) from regexp_matches(v_def, v_pattern, 'g')) <> 1 then
        raise exception '0451: anchor % not found exactly once in %', i, p_proc;
      end if;
    end if;
    v_next := pg_temp.anchor_replace(v_def, p_old[i], p_new[i]);
    if v_next is null or v_next = v_def then
      raise exception '0451: anchor % did not change %', i, p_proc;
    end if;
    v_def := v_next;
  end loop;
  execute v_def;
end
$f$;
revoke execute on function pg_temp.patch_function(regprocedure, text[], text[]) from public;

-- ── badge sign-in lockout (platform scope: the badge is not yet resolved) ──
select pg_temp.patch_function('public.badge_auth_verify(text, text)'::regprocedure,
  array[
    $a$and attempted_at > now() - interval '15 minutes';$a$,
    $a$if v_recent >= 5 then$a$],
  array[
    $a$and attempted_at > now() - make_interval(mins => (public.setting_value(null, 'security.badge_lockout_minutes') #>> '{}')::int);$a$,
    $a$if v_recent >= (public.setting_value(null, 'security.badge_lockout_failures') #>> '{}')::int then$a$]);

-- ── MCP probe freshness ───────────────────────────────────────────────────
select pg_temp.patch_function('public.instance_mcp_overview()'::regprocedure,
  array[
    $a$'fresh', v_probe.requested_at >= now() - interval '15 minutes'$a$],
  array[
    $a$'fresh', v_probe.requested_at >= now() - make_interval(mins => (public.setting_value(null, 'mcp.probe_freshness_minutes') #>> '{}')::int)$a$]);

select pg_temp.patch_function('public.instance_set_mcp_runtime(boolean, text)'::regprocedure,
  array[
    $a$< now() - interval '15 minutes' then$a$,
    $a$'probe older than 15 minutes'$a$],
  array[
    $a$< now() - make_interval(mins => (public.setting_value(null, 'mcp.probe_freshness_minutes') #>> '{}')::int) then$a$,
    $a$'probe older than ' || (public.setting_value(null, 'mcp.probe_freshness_minutes') #>> '{}') || ' minutes'$a$]);

-- ── group creation and message requests ───────────────────────────────────
select pg_temp.patch_function('public.create_account_group(text, uuid[], uuid)'::regprocedure,
  array[
    $a$created_at > now() - interval '1 hour') >= 10 then$a$],
  array[
    $a$created_at > now() - interval '1 hour') >= (public.setting_value(null, 'messaging.group_creation_per_hour') #>> '{}')::int then$a$]);

select pg_temp.patch_function('public.send_account_message(uuid, text, uuid)'::regprocedure,
  array[
    $a$c.created_datetime > now() - interval '1 day') >= 10 then$a$],
  array[
    $a$c.created_datetime > now() - interval '1 day') >= (public.setting_value(null, 'messaging.message_requests_per_day') #>> '{}')::int then$a$]);

-- ── invitation lifetime: stated at creation, kept afterwards ──────────────
select pg_temp.patch_function('public.create_invitation(uuid, boolean, text, text, uuid, boolean)'::regprocedure,
  array[
    $a$created_by, member_id, also_prod)$a$,
    $a$p_member_id, v_also)$a$],
  array[
    $a$created_by, member_id, also_prod, expires_at)$a$,
    $a$p_member_id, v_also, now() + make_interval(days => (public.setting_value(p_workspace_id, 'security.invitation_expiry_days') #>> '{}')::int))$a$]);

-- ── assistant confirmation lifetime: the column default reads the setting ──
create or replace function public.mcp_confirmation_expires_at()
returns timestamptz
language sql
stable
security definer
set search_path = public
as $fn$
  select now() + make_interval(mins => (public.setting_value(null, 'mcp.confirmation_expiry_minutes') #>> '{}')::int)
$fn$;
revoke execute on function public.mcp_confirmation_expires_at() from public, anon, authenticated;

alter table public.mcp_action_confirmations
  alter column expires_at set default public.mcp_confirmation_expires_at();

select public.set_deskilo_schema_version(451);
