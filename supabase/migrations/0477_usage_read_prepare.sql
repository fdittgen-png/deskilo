-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0477 (#2590, C1) -- reading a month of usage no longer writes it.
--
-- `usage_records_for` (0151) calls `ensure_usage_records` before it answers:
-- every report, filter or export read could materialise business records. It
-- stays as the compatibility wrapper with those documented semantics (old
-- clients keep working), and two functions take over the two jobs:
--
--   * `usage_records_read_v1(workspace, period, member)`: a pure, bounded
--     read. The same authorised projection as the wrapper -- one's own
--     records always, anybody else's only through the money gate -- and a
--     `coverage` block that says how many past bookings of the month have no
--     usage record YET. A month nobody has prepared reads as incomplete, never
--     as zero usage. No insert, update, delete, sweep or notification, in it
--     or in anything it calls. An invalid period is refused, never mapped to
--     today.
--   * `prepare_usage_period_v1(workspace, period, request_id)`: the explicit
--     business-preparation command around the existing idempotent
--     materialiser. Same caller policy as the wrapper (an active member of
--     the workspace); no member or target override; the same request answers
--     the same result.
--
-- Not here (C2): routing the analytical and export consumers to the pure read.

create or replace function public.usage_records_read_v1(
  p_workspace_id uuid, p_period text, p_member_id uuid default null
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me public.members;
  v_tz text;
  v_rows jsonb;
  v_unprepared int;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select m.* into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid()
     and m.status = 'active';
  if v_me.id is null then raise exception 'not a member'; end if;
  if p_period is null or p_period !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' then
    raise exception 'invalid period';
  end if;

  select coalesce(jsonb_agg(to_jsonb(u) order by u.reserved_from desc), '[]'::jsonb)
    into v_rows
    from public.usage_records u
   where u.workspace_id = p_workspace_id
     and u.period = p_period
     and (p_member_id is null or u.member_id = p_member_id)
     and (u.member_id = v_me.id or public.may_view_member_finances(u.member_id));

  select coalesce(w.timezone, 'UTC') into v_tz from public.workspaces w where w.id = p_workspace_id;
  -- The bookings `ensure_usage_records` would look at, visible to this person
  -- and without a record. Some of them count for nothing (an outside-hours
  -- booking that rides free) and stay unrecorded after preparation: the figure
  -- is an upper bound, which is the honest side to err on.
  select count(*)::int into v_unprepared
    from public.reservations r
   where r.workspace_id = p_workspace_id
     and r.ends_at < now()
     and r.status in ('reserved', 'checked_in', 'completed')
     and to_char(r.starts_at at time zone v_tz, 'YYYY-MM') = p_period
     and (p_member_id is null or r.member_id = p_member_id)
     and (r.member_id = v_me.id or public.may_view_member_finances(r.member_id))
     and not exists (select 1 from public.usage_records u where u.reservation_id = r.id);

  return jsonb_build_object(
    'records', v_rows,
    'coverage', jsonb_build_object(
      'period', p_period,
      'complete', v_unprepared = 0,
      'unprepared_reservations', v_unprepared));
end;
$fn$;
revoke execute on function public.usage_records_read_v1(uuid, text, uuid) from public, anon;
grant execute on function public.usage_records_read_v1(uuid, text, uuid) to authenticated;

create or replace function public.prepare_usage_period_v1(
  p_workspace_id uuid, p_period text, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me public.members;
  v_digest text;
  v_done jsonb;
  v_n int;
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select m.* into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid()
     and m.status = 'active';
  if v_me.id is null then raise exception 'not a member'; end if;
  if p_period is null or p_period !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' then
    raise exception 'invalid period';
  end if;
  v_digest := md5(v_me.id::text || p_workspace_id::text || p_period);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'usage_prepare', v_digest);
  if v_done is not null then return v_done; end if;

  v_n := public.ensure_usage_records(p_workspace_id, p_period);
  v_result := jsonb_build_object('period', p_period, 'prepared', v_n);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'usage_prepare', v_digest, v_result);
end;
$fn$;
revoke execute on function public.prepare_usage_period_v1(uuid, text, uuid) from public, anon;
grant execute on function public.prepare_usage_period_v1(uuid, text, uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(477);
