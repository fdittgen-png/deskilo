-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0456 (#2487, S4 of #2483, first checkpoint) -- the messenger windows are
-- registry settings; Dart and SQL read the same value.
--
-- Three rows (group `messaging`), defaults are today's values exactly:
--   messaging.edit_window_minutes  15 minutes, 1..1440  (platform, workspace)
--   messaging.thread_poll_seconds  15 seconds, 5..300   (platform; Dart reader)
--   messaging.inbox_poll_seconds   30 seconds, 10..600  (platform; Dart reader)
--
-- edit_message (live body of 0384) had four literal 15-minute windows, one per
-- message kind. A workspace note (member_note) reads the setting of ITS
-- workspace (the note's workspace, not a selected one); a personal, group or
-- inquiry message has no workspace and reads the platform value. A caller who
-- is no longer a member of the note's workspace falls back to the platform
-- value, so the refusal text stays "this message can no longer be edited".
-- The four anchors are asserted to occur exactly once each, so a body that
-- drifted fails the migration instead of shipping a silent no-op.
--
-- Nothing is purged and no retention rule changes here: the legally
-- constrained retention periods are #2571's.

-- ── the registry rows ────────────────────────────────────────────────────
-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('messaging.edit_window_minutes', 'duration', '15'::jsonb, 1, 1440, 'minutes', 'messaging', array['platform', 'workspace'], 'workspaceSettings', null, true, null, 'edit_message (0382, 0384); MessagingWindows', 'Minutes after sending in which the author may still correct a message. A workspace message reads its own workspace, a personal or group message the platform value.'),
('messaging.thread_poll_seconds', 'duration', '15'::jsonb, 5, 300, 'seconds', 'messaging', array['platform'], 'workspaceSettings', null, true, null, 'ContextThreadScreen', 'Seconds between two refreshes of an open conversation. Lower values load the server more.'),
('messaging.inbox_poll_seconds', 'duration', '30'::jsonb, 10, 600, 'seconds', 'messaging', array['platform'], 'workspaceSettings', null, true, null, 'UnifiedInboxView; MeShell badge', 'Seconds between two refreshes of the inbox and its unread badge. Lower values load the server more.')
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
        raise exception '0456: anchor % occurs more than once in %', i, p_proc;
      end if;
    else
      v_pattern := regexp_replace(btrim(p_old[i], E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
      v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
      if (select count(*) from regexp_matches(v_def, v_pattern, 'g')) <> 1 then
        raise exception '0456: anchor % not found exactly once in %', i, p_proc;
      end if;
    end if;
    v_next := pg_temp.anchor_replace(v_def, p_old[i], p_new[i]);
    if v_next is null or v_next = v_def then
      raise exception '0456: anchor % did not change %', i, p_proc;
    end if;
    v_def := v_next;
  end loop;
  execute v_def;
end
$f$;
revoke execute on function pg_temp.patch_function(regprocedure, text[], text[]) from public;


-- ── edit_message: one window per message kind ────────────────────────────
select pg_temp.patch_function('public.edit_message(text, uuid, text)'::regprocedure,
  array[
    $a$and n.created_at > now() - interval '15 minutes'$a$,
    $a$and a.created_at > now() - interval '15 minutes';$a$,
    $a$and q.created_at > now() - interval '15 minutes';$a$,
    $a$and g.created_at > now() - interval '15 minutes'$a$],
  array[
    $a$and n.created_at > now() - make_interval(mins => case
         when public.is_member_of(n.workspace_id)
           then (public.setting_value(n.workspace_id, 'messaging.edit_window_minutes') #>> '{}')::int
         else (public.setting_value(null, 'messaging.edit_window_minutes') #>> '{}')::int end)$a$,
    $a$and a.created_at > now() - make_interval(mins => (public.setting_value(null, 'messaging.edit_window_minutes') #>> '{}')::int);$a$,
    $a$and q.created_at > now() - make_interval(mins => (public.setting_value(null, 'messaging.edit_window_minutes') #>> '{}')::int);$a$,
    $a$and g.created_at > now() - make_interval(mins => (public.setting_value(null, 'messaging.edit_window_minutes') #>> '{}')::int)$a$]);

select public.set_deskilo_schema_version(456);
