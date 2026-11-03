-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (workspaces.role_permissions gains makeReservations for the roles of people
-- who already hold a reservation; create_reservation, create_series and
-- kiosk_act patched at asserted anchors, nothing else of them changes)
--
-- 0661 (#3269) -- a reservation is made only by someone who holds
-- makeReservations. 0373 made the six everyday features permissions, and the
-- setup step `member_rights` and the readiness section `member_permissions`
-- (0399) say that until the owner grants makeReservations a plain member
-- cannot book. The app agrees (/reserve and /plan are gated on it). The
-- server did not: create_reservation, create_series and the kiosk's reserve
-- never asked, so a direct call, the MCP booking tool or an older client
-- booked regardless of the matrix.
--
-- Who holds it is member_has_permission's answer, unchanged: owners, active
-- co-owners (unless their matrix says otherwise), admins and members through
-- the role matrix, and anyone through a custom role (customRoles). The check
-- sits right after the caller (or, at the kiosk, the badge's member) is known
-- to be active:
--   create_reservation   the caller books for themselves
--   create_series        the caller books a series for themselves
--   kiosk_act            'reserve' and 'check_in' for the badge's member
--                        (check-out, cancel and the rest are not bookings)
-- admin_create_reservation_for is untouched: its authority is the acting
-- admin's manageReservations, not the subject's right. create_sample_data
-- is the owner's own seeding.
--
-- Compatibility: nobody who could book yesterday loses it silently. Before
-- the checks, every role whose active members already hold a reservation
-- while lacking the right gains it in the workspace's matrix, read the way the
-- permission functions read each role: 'member' (an absent list becomes just
-- makeReservations); 'admin' (an absent list is first written out as the
-- defaults has_permission_raw grants, 16 entries that contain
-- member_has_permission's 14, so nothing else an admin holds changes through
-- either function); an active co-owner only where the workspace has an
-- explicit 'co_owner' list (otherwise they hold the whole catalogue). Owners
-- are not touched. Custom roles are read through member_has_permission as
-- well: a custom-role holder who books today and lacks the right on the base
-- matrix is covered the same way, by the role of their membership. The grant
-- is per role, as the old behaviour was. Idempotent: a second run finds
-- nobody lacking the right. The lists only gain; nothing is removed or
-- reordered, so no earlier choice of an owner is changed.
--
-- Refusal: 'not allowed to make reservations' (42501). The client words it
-- (bookingErrorText) in the five languages.

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
begin
  -- An anchor names one place: it occurs exactly once, or nothing is patched.
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    return null;
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public, anon, authenticated;

-- ── nobody loses booking silently ─────────────────────────────────────────
-- Each role is read the way the permission functions read it:
--   * an ACTIVE co-owner holds everything unless the workspace has an explicit
--     'co_owner' list (so only a workspace with that list is touched);
--   * an admin (not a co-owner) is read by 'admin' list, or, with none, by the
--     defaults. The defaults are two lists: member_has_permission's 14 and
--     has_permission_raw's 16 (which also grants paymentTermsEdit and
--     viewAnalytics and is the one the RPC guards ask). The 16 contain the 14,
--     so writing the 16 out loses nothing through either function;
--   * anyone else is read by the 'member' list (an absent list holds nothing).
do $backfill$
declare
  r record;
  -- has_permission_raw's admin defaults, while a workspace has no 'admin' list.
  v_admin_default jsonb := to_jsonb(array[
    'manageMembers','manageDocuments','manageServices','approveExpenses','viewFinances',
    'viewNegotiations','manageNegotiations','paymentTermsEdit','manageSites','manageReservations',
    'operateKiosk','exportData','viewPersonalData','deployToDev','accessProd','viewAnalytics']);
begin
  for r in
    select distinct m.workspace_id,
           case when m.co_owner = 'active' then 'co_owner'
                when m.is_admin then 'admin'
                else 'member' end as role_key
      from public.members m
     where m.status = 'active'
       and not m.is_owner
       and exists (select 1 from public.reservations x where x.member_id = m.id)
       and not public.member_has_permission(m.id, 'makeReservations')
  loop
    update public.workspaces w
       set role_permissions = jsonb_set(
             case when jsonb_typeof(w.role_permissions) = 'object' then w.role_permissions else '{}'::jsonb end,
             array[r.role_key],
             (case when jsonb_typeof(w.role_permissions->r.role_key) = 'array' then w.role_permissions->r.role_key
                   when r.role_key = 'admin' then v_admin_default
                   else '[]'::jsonb end) || '["makeReservations"]'::jsonb,
             true)
     where w.id = r.workspace_id;
  end loop;
end
$backfill$;

-- ── the checks ────────────────────────────────────────────────────────────
do $migration$
declare
  v_def text;
  v_patched text;
begin
  -- create_reservation: the caller books for themselves.
  select pg_get_functiondef(
    'public.create_reservation(uuid, uuid, uuid, timestamp with time zone, timestamp with time zone, boolean, uuid, uuid)'::regprocedure
  ) into v_def;
  if position('makeReservations' in v_def) = 0 then
    v_patched := pg_temp.anchor_replace(v_def,
      $a$  if v_member.id is null then raise exception 'not an active member'; end if;$a$,
      $a$  if v_member.id is null then raise exception 'not an active member'; end if;
  if not public.member_has_permission(v_member.id, 'makeReservations') then
    raise exception 'not allowed to make reservations' using errcode = '42501';
  end if;$a$);
    if v_patched is null then
      raise exception '0661: create_reservation anchor missing (active member check)';
    end if;
    execute v_patched;
  end if;

  -- create_series: the caller books a series for themselves.
  select pg_get_functiondef(
    'public.create_series(uuid, uuid, timestamp with time zone, timestamp with time zone, text, timestamp with time zone, uuid, uuid, uuid)'::regprocedure
  ) into v_def;
  if position('makeReservations' in v_def) = 0 then
    v_patched := pg_temp.anchor_replace(v_def,
      $a$  if v_member.id is null then raise exception 'not an active member'; end if;$a$,
      $a$  if v_member.id is null then raise exception 'not an active member'; end if;
  if not public.member_has_permission(v_member.id, 'makeReservations') then
    raise exception 'not allowed to make reservations' using errcode = '42501';
  end if;$a$);
    if v_patched is null then
      raise exception '0661: create_series anchor missing (active member check)';
    end if;
    execute v_patched;
  end if;

  -- kiosk_act: 'reserve' and 'check_in' book for the badge's member.
  select pg_get_functiondef(
    'public.kiosk_act(uuid, text, text, uuid, timestamp with time zone, timestamp with time zone, uuid)'::regprocedure
  ) into v_def;
  if position('makeReservations' in v_def) = 0 then
    v_patched := pg_temp.anchor_replace(v_def,
      $a$    raise exception 'unknown kiosk action';
  end if;$a$,
      $a$    raise exception 'unknown kiosk action';
  end if;
  if not public.member_has_permission(v_subject.id, 'makeReservations') then
    raise exception 'not allowed to make reservations' using errcode = '42501';
  end if;$a$);
    if v_patched is null then
      raise exception '0661: kiosk_act anchor missing (reserve / check_in)';
    end if;
    execute v_patched;
  end if;
end
$migration$;

select public.set_deskilo_schema_version(661);
