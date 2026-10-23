-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #2915 — how long a setup step takes, observed. The guide says each
-- step's time as a range, never a promise; until now the range was the
-- catalogue's one figure widened by a fixed rule, because no session was
-- ever timed. This records them: a session is the time from opening a
-- step's page to the step turning ready, as the app saw it.
--
-- Privacy, by construction rather than by policy:
--   * a row names no person — no user id, no name, no e-mail. The six
--     system columns are on this table like on every other (#992); the
--     two that would carry the caller (created_by_user, modified_by_user)
--     are blanked by a trigger that runs after the house stamp, so a
--     restored backup or a direct insert cannot carry one either;
--   * the workspace id is kept, in clear, as the key that makes reporting
--     the same session twice harmless (workspace, step, opened_at) and so
--     that the rows leave with their workspace (on delete cascade). A hash
--     would keep neither and hide nothing: no client reads the table;
--   * nothing reads the rows but setup_step_timing_ranges(), which answers
--     per STEP over the whole instance, never per workspace, and only from
--     five sessions on — fewer would say more about one space than about
--     the step. The threshold is this file's c_minimum_sessions;
--   * a workspace filming with invented people (recordingPrivacy) reports
--     nothing: the app sends nothing, and the server keeps nothing if it
--     does. Nothing leaves the instance.
--
--   * record_setup_step_timing(workspace, step, opened_at, seconds) ->
--     whether a new session was kept (false: the same session again, or
--     recording privacy is on). manageConfiguration (42501 otherwise),
--     native only, a step the catalogue names (22023 otherwise), a
--     non-negative duration (22023 otherwise).
--   * setup_step_timing_ranges() -> [{step, low_minutes, high_minutes,
--     samples}] for every step with at least five sessions: low is the
--     median in whole minutes (rounded down, never under one), high the
--     80th percentile (rounded up, always above low), over the instance.
--     Any signed-in native caller: the answer names no space and no person.

create table if not exists public.setup_step_timings (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  step text not null,
  opened_at timestamptz not null,
  duration_seconds int not null check (duration_seconds >= 0),
  recorded_at timestamptz not null default now(),
  constraint setup_step_timings_key unique (workspace_id, step, opened_at)
);
select public.ensure_system_columns('setup_step_timings');
alter table public.setup_step_timings enable row level security;
revoke all on table public.setup_step_timings from anon, authenticated;
drop policy if exists mcp_delegated_deny on public.setup_step_timings;
create policy mcp_delegated_deny on public.setup_step_timings
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- No row names a person. The house stamp (zz_system_columns_stamp) writes
-- the caller into created_by_user and modified_by_user; triggers fire in
-- name order, so this one, named after it, has the last word.
create or replace function public.setup_step_timings_no_person()
returns trigger language plpgsql set search_path = public as $fn$
begin
  new.created_by_user := null;
  new.modified_by_user := null;
  return new;
end;
$fn$;
revoke execute on function public.setup_step_timings_no_person() from public, anon, authenticated;
drop trigger if exists zzz_setup_step_timings_no_person on public.setup_step_timings;
create trigger zzz_setup_step_timings_no_person
  before insert or update on public.setup_step_timings
  for each row execute function public.setup_step_timings_no_person();

create or replace function public.record_setup_step_timing(
  p_workspace_id uuid,
  p_step text,
  p_opened_at timestamptz,
  p_seconds int
) returns boolean language plpgsql volatile security definer set search_path = public as $fn$
begin
  perform public.mcp_require_native();
  if not public.has_permission(p_workspace_id, 'manageConfiguration') then
    raise exception 'only someone who configures this workspace reports a setup session'
      using errcode = '42501';
  end if;
  if not public.setup_step_catalogue() @> jsonb_build_array(jsonb_build_object('id', p_step)) then
    raise exception 'the setup guide has no step %', coalesce(p_step, '(none)')
      using errcode = '22023';
  end if;
  if p_opened_at is null or p_seconds is null or p_seconds < 0 then
    raise exception 'a setup session is when its page opened and how long it took'
      using errcode = '22023';
  end if;
  -- A shoot with invented people is not a setup session.
  if public.feature_effective(p_workspace_id, 'recordingPrivacy') then
    return false;
  end if;
  insert into public.setup_step_timings (workspace_id, step, opened_at, duration_seconds)
  values (p_workspace_id, p_step, p_opened_at, p_seconds)
  on conflict on constraint setup_step_timings_key do nothing;
  return found;
end;
$fn$;
revoke execute on function public.record_setup_step_timing(uuid, text, timestamptz, int) from public, anon;
grant execute on function public.record_setup_step_timing(uuid, text, timestamptz, int) to authenticated;

create or replace function public.setup_step_timing_ranges()
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  -- Below this many sessions a range would describe one space, not the
  -- step; the app widens the catalogue's figure instead.
  c_minimum_sessions constant int := 5;
begin
  if auth.uid() is null then
    raise exception 'sign in to read the setup guide''s times' using errcode = '42501';
  end if;
  perform public.mcp_require_native();
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'step', t.step,
             'low_minutes', t.low,
             'high_minutes', greatest(t.high, t.low + 1),
             'samples', t.samples)
           order by t.step)
      from (
        -- The percentiles interpolate in floating point (300 + 0.2 * 300
        -- is 360.00000000000006): rounded to the millisecond before the
        -- minute is cut, so 360 s reads as 6 min, not 7.
        select s.step,
               count(*) as samples,
               greatest(1, floor(round((percentile_cont(0.5) within group (order by s.duration_seconds))::numeric, 3) / 60))::int as low,
               ceil(round((percentile_cont(0.8) within group (order by s.duration_seconds))::numeric, 3) / 60)::int as high
          from public.setup_step_timings s
         group by s.step
        having count(*) >= c_minimum_sessions
      ) t
  ), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.setup_step_timing_ranges() from public, anon;
grant execute on function public.setup_step_timing_ranges() to authenticated;

select public.set_deskilo_schema_version(557);
