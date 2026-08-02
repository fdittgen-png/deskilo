-- SPDX-License-Identifier: 0BSD
-- Auto check-in/check-out (#396). A reservation nobody touched stays
-- 'reserved' for ever, and one nobody closed stays 'checked_in' — the
-- spec's §4.4 auto check-out was never enforced. For communities that
-- bill by reservation and do not police attendance, the owner can now
-- have day-end close the books:
--
--   * never checked IN  ('reserved',   ends_at past) → checked in at its
--     start, checked out at its end, 'completed'. The complement of
--     no-show release: the booking held the seat, the booking counts.
--   * never checked OUT ('checked_in', ends_at past) → checked out at
--     its end, 'completed'.
--
-- Cancelled and released rows are untouched. Sweeping keys off the
-- reservation's OWN end (end of day at the latest): once ends_at has
-- passed, the check-in window is long gone, so nothing a user could
-- still do is pre-empted.
--
-- No cron: the sweep is invoked LAZILY before reservation reads, the
-- sweep_pending_events pattern — any member's visit closes out the past.
-- Gated per workspace by the 'autoCheckInOut' feature flag (default
-- OFF — it rewrites attendance records, an explicit owner decision),
-- checked HERE server-side like adminSeatBlocking (0021): the client
-- flag is cosmetic, this is the enforcement.

create or replace function public.sweep_day_end(p_workspace_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  -- Any active member may trigger the sweep for their own workspace —
  -- the write it performs is the workspace's own configured policy, not
  -- the caller's privilege.
  if not exists (
    select 1 from public.members m
    where m.workspace_id = p_workspace_id
      and m.user_id = auth.uid() and m.status = 'active'
  ) then
    raise exception 'not a member of this workspace';
  end if;

  -- jsonb equality: true only for a stored JSON boolean true — junk
  -- values count as OFF, like the client's resolveEnabledFeatures.
  if not coalesce((
    select w.feature_flags->'autoCheckInOut' = 'true'::jsonb
    from public.workspaces w where w.id = p_workspace_id
  ), false) then
    return;
  end if;

  -- Attended by decree: the booking held the seat for its whole window.
  update public.reservations
    set checked_in_at = starts_at,
        checked_out_at = ends_at,
        status = 'completed'
    where workspace_id = p_workspace_id
      and status = 'reserved'
      and ends_at < now();

  -- Forgot to leave: close at the reservation's own end, not at now() —
  -- the seat was only theirs until ends_at.
  update public.reservations
    set checked_out_at = ends_at,
        status = 'completed'
    where workspace_id = p_workspace_id
      and status = 'checked_in'
      and ends_at < now();
end;
$$;

revoke execute on function public.sweep_day_end(uuid) from public, anon;
