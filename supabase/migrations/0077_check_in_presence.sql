-- SPDX-License-Identifier: 0BSD
-- Check-in requires PRESENCE (#408). The RPC verified ownership and
-- workspace-open but never the clock: a member could check in to next
-- week's reservation today, or retroactively into one that ended.
-- Sign-in means "I am here and the seat is occupied, now" — for
-- oneself, or by an authorized admin for the member standing there.
--
-- Two changes to check_in_reservation, none to its signature:
--
--   * The spec §4.3 check-in window, until now unimplemented: allowed
--     iff now() ∈ [starts_at − 15 min, ends_at). Not before the window
--     opens (the future), never after the reservation ended (the past).
--     Walk-ups are untouched — they are created at now() by design.
--   * An admin/owner of the workspace may check in ANOTHER member's
--     reservation while the bookForOthers feature is on — DIRECT, no
--     pending event, the kiosk_act precedent: the subject already
--     confirmed the reservation, and their standing at the desk is the
--     presence this rule is about. The same window applies to everyone.

create or replace function public.check_in_reservation(p_reservation_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_res public.reservations;
  v_own boolean;
begin
  select r.* into v_res from public.reservations r
    where r.id = p_reservation_id;
  if v_res.id is null then raise exception 'not your reservation'; end if;

  select exists (
    select 1 from public.members m
    where m.id = v_res.member_id and m.user_id = auth.uid()
  ) into v_own;

  if not v_own then
    -- The authorized-for-others path: admin/owner + the bookForOthers
    -- feature (jsonb boolean check, junk counts as OFF — the 0021
    -- idiom; the feature defaults ON in the registry, so an ABSENT key
    -- must count as ON here, unlike the default-off flags).
    if not (
      public.is_admin_of(v_res.workspace_id)
      and coalesce((
        select w.feature_flags->'bookForOthers' is distinct from 'false'::jsonb
        from public.workspaces w where w.id = v_res.workspace_id
      ), true)
    ) then
      raise exception 'not your reservation';
    end if;
  end if;

  if v_res.status <> 'reserved' then raise exception 'not in reserved state'; end if;

  -- Presence: the check-in window (spec §4.3). Before it opens the
  -- member is checking into the FUTURE; after ends_at, into the PAST.
  if now() < v_res.starts_at - interval '15 minutes' then
    raise exception 'check-in window not open yet';
  end if;
  if now() >= v_res.ends_at then
    raise exception 'check-in window closed';
  end if;

  perform public.assert_workspace_open(v_res.workspace_id, now(), now() + interval '1 minute');
  update public.reservations
    set status = 'checked_in', checked_in_at = now()
    where id = p_reservation_id;
end;
$$;
