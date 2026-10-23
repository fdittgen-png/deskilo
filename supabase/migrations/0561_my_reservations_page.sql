-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0561 (#2553 C1) -- a person's own reservations, read on the installation
-- that holds them. The personal home (P) never copies operational rows: it
-- asks each workspace host (W) for the caller's own reservations through
-- this read, which runs as the caller (SECURITY INVOKER, the row policies
-- apply) and scopes by ownership alone:
--
--   reservations.member_id -> members.id -> members.user_id = auth.uid()
--
-- No member, role or user parameter overrides that. A delegated assistant
-- token is refused outright (42501), like an anonymous caller.
--
-- The page size and the longest window are this installation's own
-- platform settings, resolved ONCE with no workspace before the row query
-- (`setting_value(null, key)` reads the platform value, else the registry
-- default; it tolerates a null workspace because the membership check and
-- the workspace-scope lookup are both conditional on one being named).
-- Neither depends on a row or on the workspace filter, so a page spanning
-- two workspaces on one host has one limit. A window without an end date
-- covers `personal.reservation_window_days`; a window longer than
-- `personal.reservation_max_window_days` is refused whole (22023), never
-- cut. Keyset paging on (starts_at, id) in the asked direction; the cursor
-- is the last returned row.
--
--   personal.read_concurrency              1..8, default 4
--   personal.read_timeout_seconds          3..60 s, default 12
--   personal.reservation_max_window_days   31..1000, default 400, guardrail
--   personal.reservation_page_size         1..100, default 50
--   personal.reservation_window_days       1..400, default 31
--
-- Output: {schema_version: 1, items: [...], next: {after_start, after_id} |
-- null, has_more: bool}. An item names the reservation, its workspace, the
-- booked place (kind, id, label or the substitution label of a deleted
-- place), its times, its status and its check-in/out marks. No other
-- person, no amount, no note.

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('personal.read_concurrency', 'int', '4'::jsonb, 1, 8, 'requests', 'personal', array['platform'], 'workspaceSettings', null, true, null, 'personal source reads (#2553)', 'How many servers the personal space asks at once when it gathers a person''s own records. A bound on the device''s parallel reads, not on any server.'),
('personal.read_timeout_seconds', 'duration', '12'::jsonb, 3, 60, 'seconds', 'personal', array['platform'], 'workspaceSettings', null, true, null, 'personal source reads (#2553)', 'Seconds the personal space waits for one server''s answer before it shows that server as unavailable and goes on with the others.'),
('personal.reservation_max_window_days', 'int', '400'::jsonb, 31, 1000, 'days', 'personal', array['platform'], 'workspaceSettings', null, false, null, 'my_reservations_page_v1 (#2553)', 'Guardrail: the longest period one read of a person''s reservations may ask for. A platform-owned bound on the query, resolved by the server that answers.'),
('personal.reservation_page_size', 'int', '50'::jsonb, 1, 100, 'rows', 'personal', array['platform'], 'workspaceSettings', null, true, null, 'my_reservations_page_v1 (#2553)', 'How many of a person''s reservations one server returns per page. The server that answers resolves it once per read, whatever workspaces the page spans.'),
('personal.reservation_window_days', 'int', '31'::jsonb, 1, 400, 'days', 'personal', array['platform'], 'workspaceSettings', null, true, null, 'my_reservations_page_v1 (#2553); MyReservationsWindow', 'Days the personal space shows by default when it lists a person''s reservations, and the window a read without an end date covers. A query default, not a booking rule.')
on conflict (key) do nothing;
-- END GENERATED SEED

create or replace function public.my_reservations_page_v1(
  p_from timestamptz,
  p_to timestamptz default null,
  p_workspace_id uuid default null,
  p_direction text default 'asc',
  p_after_start timestamptz default null,
  p_after_id uuid default null)
returns jsonb
language plpgsql
stable
security invoker
set search_path = public
as $fn$
declare
  v_page_size int;
  v_max_days int;
  v_to timestamptz := p_to;
  v_rows jsonb;
  v_has_more boolean;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'personal read unavailable' using errcode = '42501';
  end if;
  if p_from is null then
    raise exception 'a start is required' using errcode = '22023';
  end if;
  if p_direction is null or p_direction not in ('asc', 'desc') then
    raise exception 'the direction is asc or desc' using errcode = '22023';
  end if;
  if (p_after_start is null) <> (p_after_id is null) then
    raise exception 'a cursor names both its start and its id' using errcode = '22023';
  end if;

  -- Resolved once, before the rows, with no workspace: this installation's
  -- platform values. A missing registry row raises here (unknown setting),
  -- never a hidden literal.
  v_page_size := (public.setting_value(null::uuid, 'personal.reservation_page_size') #>> '{}')::int;
  v_max_days := (public.setting_value(null::uuid, 'personal.reservation_max_window_days') #>> '{}')::int;
  if v_to is null then
    v_to := p_from + make_interval(days =>
      (public.setting_value(null::uuid, 'personal.reservation_window_days') #>> '{}')::int);
  end if;
  if v_to <= p_from then
    raise exception 'the window ends before it starts' using errcode = '22023';
  end if;
  if v_to - p_from > make_interval(days => v_max_days) then
    raise exception 'the window is longer than % days', v_max_days using errcode = '22023';
  end if;

  if p_direction = 'asc' then
    select coalesce(jsonb_agg(to_jsonb(p) order by p.starts_at asc, p.id asc), '[]'::jsonb)
      into v_rows
      from (
        select r.id, r.workspace_id, w.name as workspace_name,
               case when r.seat_id is not null then 'seat'
                    when r.desk_id is not null then 'desk'
                    when r.office_id is not null then 'office'
                    else 'level' end as place_kind,
               coalesce(r.seat_id, r.desk_id, r.office_id, r.level_id) as place_id,
               coalesce(nullif(s.name, ''), nullif(d.name, ''), o.name, l.name, r.space_label, '') as place_label,
               r.starts_at, r.ends_at, r.status, r.checked_in_at, r.checked_out_at
          from public.reservations r
          join public.members m on m.id = r.member_id and m.workspace_id = r.workspace_id
          join public.workspaces w on w.id = r.workspace_id
          left join public.seats s on s.id = r.seat_id
          left join public.desks d on d.id = r.desk_id
          left join public.offices o on o.id = r.office_id
          left join public.levels l on l.id = r.level_id
         where m.user_id = auth.uid()
           and (p_workspace_id is null or r.workspace_id = p_workspace_id)
           and r.starts_at < v_to and r.ends_at > p_from
           and (p_after_start is null or (r.starts_at, r.id) > (p_after_start, p_after_id))
         order by r.starts_at asc, r.id asc
         limit v_page_size + 1) p;
  else
    select coalesce(jsonb_agg(to_jsonb(p) order by p.starts_at desc, p.id desc), '[]'::jsonb)
      into v_rows
      from (
        select r.id, r.workspace_id, w.name as workspace_name,
               case when r.seat_id is not null then 'seat'
                    when r.desk_id is not null then 'desk'
                    when r.office_id is not null then 'office'
                    else 'level' end as place_kind,
               coalesce(r.seat_id, r.desk_id, r.office_id, r.level_id) as place_id,
               coalesce(nullif(s.name, ''), nullif(d.name, ''), o.name, l.name, r.space_label, '') as place_label,
               r.starts_at, r.ends_at, r.status, r.checked_in_at, r.checked_out_at
          from public.reservations r
          join public.members m on m.id = r.member_id and m.workspace_id = r.workspace_id
          join public.workspaces w on w.id = r.workspace_id
          left join public.seats s on s.id = r.seat_id
          left join public.desks d on d.id = r.desk_id
          left join public.offices o on o.id = r.office_id
          left join public.levels l on l.id = r.level_id
         where m.user_id = auth.uid()
           and (p_workspace_id is null or r.workspace_id = p_workspace_id)
           and r.starts_at < v_to and r.ends_at > p_from
           and (p_after_start is null or (r.starts_at, r.id) < (p_after_start, p_after_id))
         order by r.starts_at desc, r.id desc
         limit v_page_size + 1) p;
  end if;

  -- One row past the page says there is more; it is not returned.
  v_has_more := jsonb_array_length(v_rows) > v_page_size;
  if v_has_more then
    select coalesce(jsonb_agg(e order by n), '[]'::jsonb) into v_rows
      from jsonb_array_elements(v_rows) with ordinality t(e, n)
     where n <= v_page_size;
  end if;
  return jsonb_build_object(
    'schema_version', 1,
    'items', v_rows,
    'has_more', v_has_more,
    'next', case when v_has_more then jsonb_build_object(
                   'after_start', v_rows -> (v_page_size - 1) -> 'starts_at',
                   'after_id', v_rows -> (v_page_size - 1) -> 'id')
                 else null end);
end;
$fn$;
revoke execute on function public.my_reservations_page_v1(timestamptz, timestamptz, uuid, text, timestamptz, uuid) from public, anon;
grant execute on function public.my_reservations_page_v1(timestamptz, timestamptz, uuid, text, timestamptz, uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(561);
