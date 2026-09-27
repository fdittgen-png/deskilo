-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0288 (#1620) -- the five owned-reservation MCP tools report what
-- actually happened, and refuse to act on a state the caller did not see.
--
-- mcp_execute_v1 (0275) already routes create / retime / check in / check
-- out / request deletion to the existing business RPCs inside its guarded
-- subtransaction. Three gaps remained:
--   * create ignored the caller's check_in and always booked without it;
--     create_reservation_once(..., p_check_in) now receives the caller's
--     explicit choice (default false), atomically;
--   * a lifecycle call read the reservation without a lock and acted on
--     whatever it held; it now locks the row (FOR UPDATE, before the
--     business RPC takes it again) and, when the caller passes the
--     expected_state digest it last read, answers 'conflict'/'stale' with
--     the current state instead of acting on a changed booking;
--   * the outcome carried at most an id; every reservation tool now reads
--     the reservation back after the business RPC (status, interval,
--     resource, check-in/out, state_digest), and an empty read-back is an
--     error, never a success.
-- Authority, rules, idempotency and the envelope are unchanged.

create or replace function public.mcp_reservation_digest(p_reservation_id uuid)
returns text language sql stable set search_path = public as $fn$
  select md5(concat_ws('|', r.status, r.starts_at, r.ends_at,
                       r.checked_in_at, r.checked_out_at))
    from public.reservations r where r.id = p_reservation_id;
$fn$;
revoke execute on function public.mcp_reservation_digest(uuid) from public, anon, authenticated;

create or replace function public.mcp_reservation_view(p_reservation_id uuid)
returns jsonb language sql stable set search_path = public as $fn$
  select jsonb_build_object(
           'reservation_id', r.id, 'status', r.status,
           'starts_at', r.starts_at, 'ends_at', r.ends_at,
           'seat_id', r.seat_id, 'desk_id', r.desk_id,
           'office_id', r.office_id, 'level_id', r.level_id,
           'checked_in_at', r.checked_in_at, 'checked_out_at', r.checked_out_at,
           'state_digest', public.mcp_reservation_digest(r.id))
    from public.reservations r where r.id = p_reservation_id;
$fn$;
revoke execute on function public.mcp_reservation_view(uuid) from public, anon, authenticated;

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text language plpgsql as $f$
begin
  if position(p_old in p_def) = 0 then return null; end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text := pg_get_functiondef('public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid)'::regprocedure);
  v_missing text[] := '{}';
  v_next text;
begin
  if position('public.mcp_reservation_view(' in v_def) > 0 then
    return;
  end if;

  v_next := pg_temp.anchor_replace(v_def,
    $a$public.mcp_time_arg(v_args, 'starts_at'), public.mcp_time_arg(v_args, 'ends_at'), false);$a$,
    $a$public.mcp_time_arg(v_args, 'starts_at'), public.mcp_time_arg(v_args, 'ends_at'),
          coalesce((v_args->>'check_in')::boolean, false));$a$);
  if v_next is null then v_missing := v_missing || 'check_in'::text; else v_def := v_next; end if;

  v_next := pg_temp.anchor_replace(v_def,
    $a$         and workspace_id = p_workspace_id and member_id = v_member.id;
      if v_reservation.id is null then
        v_status := 'not_found'; v_code := 'not_found';
      end if;$a$,
    $a$         and workspace_id = p_workspace_id and member_id = v_member.id
         for update;
      if v_reservation.id is null then
        v_status := 'not_found'; v_code := 'not_found';
      elsif v_args ? 'expected_state'
            and v_args->>'expected_state' is distinct from public.mcp_reservation_digest(v_reservation.id) then
        v_status := 'conflict'; v_code := 'stale';
        v_data := public.mcp_reservation_view(v_reservation.id);
      end if;$a$);
  if v_next is null then v_missing := v_missing || 'lock'::text; else v_def := v_next; end if;

  v_next := pg_temp.anchor_replace(v_def,
    $a$      end if;
    end if;
  exception$a$,
    $a$      end if;
      if p_operation in ('create_reservation', 'update_reservation', 'check_in', 'check_out',
                         'request_reservation_deletion') then
        if public.mcp_reservation_view(case when p_operation = 'create_reservation' then v_id
                                            else v_reservation.id end) is null then
          raise exception 'the reservation could not be read back';
        end if;
        v_data := coalesce(v_data, '{}'::jsonb) || public.mcp_reservation_view(
          case when p_operation = 'create_reservation' then v_id else v_reservation.id end);
      end if;
    end if;
  exception$a$);
  if v_next is null then v_missing := v_missing || 'read_back'::text; else v_def := v_next; end if;

  if cardinality(v_missing) > 0 then
    raise exception '0288: mcp_execute_v1 anchors not found: %', v_missing;
  end if;
  execute v_def;
end
$migration$;

select public.set_deskilo_schema_version(288);
