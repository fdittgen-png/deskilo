-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0442 (#2631, checkpoint 2) -- a meeting room: a bookable resource of the
-- plan with its own capacity and its own booking slot.
--
-- A room, like a seat, is a row of `seats` (so the reservation, conflict,
-- hierarchy and billing machinery are the ones that already exist),
-- told apart by `resource_kind` ('seat' | 'room' | 'parking'; parking
-- arrives with 0443). A room has a `capacity` (people) and, unless set,
-- the one-hour slot of 0441. Everything about rooms is behind the
-- `meetingRooms` flag, enforced here: no room is created, and none booked,
-- while the flag is off. The kind of a resource never changes.
--
--   * a member may hold a room and a seat at the same time: the
--     one-place limit counts seats only (`seat_is_resource`);
--   * the capacity history (seat_history) never records a room, so every
--     seat figure of `kpi_seat_capacity` is unchanged; the KPI names the
--     rooms apart under `resources` ({room: {resources, reserved_hours}});
--   * availability (MCP get_availability) lists a room under kind `room`,
--     and a parking slot under kind `parking`, while their flag is on.

alter table public.seats add column resource_kind text not null default 'seat'
  check (resource_kind in ('seat', 'room', 'parking'));
alter table public.seats add column capacity int
  check (capacity is null or capacity between 1 and 1000);
alter table public.seats add constraint seats_capacity_room
  check (capacity is null or resource_kind = 'room');

-- The flag a kind lives behind (null: none). An unknown or not yet
-- registered flag is off (feature_effective_in).
create or replace function public.resource_kind_feature(p_kind text)
returns text language sql immutable set search_path = public as $fn$
  select case p_kind when 'room' then 'meetingRooms' when 'parking' then 'parking' end;
$fn$;
revoke execute on function public.resource_kind_feature(text) from public, anon, authenticated;

create or replace function public.resource_kind_enabled(p_workspace_id uuid, p_kind text)
returns boolean language sql stable security definer set search_path = public as $fn$
  select p_kind = 'seat'
      or (p_kind = 'room' and public.feature_effective(p_workspace_id, 'meetingRooms'));
$fn$;
revoke execute on function public.resource_kind_enabled(uuid, text) from public, anon, authenticated;

-- True for a seat id that is a room or a parking slot.
create or replace function public.seat_is_resource(p_seat_id uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select coalesce((select s.resource_kind <> 'seat' from public.seats s where s.id = p_seat_id), false);
$fn$;
revoke execute on function public.seat_is_resource(uuid) from public, anon, authenticated;

create or replace function public.seats_resource_guard()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if tg_op = 'UPDATE' and new.resource_kind is distinct from old.resource_kind then
    raise exception 'the kind of a resource cannot change';
  end if;
  if new.resource_kind <> 'seat' then
    if tg_op = 'INSERT' and not public.resource_kind_enabled(new.workspace_id, new.resource_kind) then
      raise exception 'the % feature is off', public.resource_kind_feature(new.resource_kind)
        using errcode = '42501';
    end if;
    if new.resource_kind = 'room' and new.slot_minutes is null then
      new.slot_minutes := 60;
    end if;
  end if;
  return new;
end;
$fn$;
revoke execute on function public.seats_resource_guard() from public, anon, authenticated;
create trigger seats_resource_guard
  before insert or update on public.seats
  for each row execute function public.seats_resource_guard();

create or replace function public.reservations_resource_gate()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_kind text;
begin
  if new.seat_id is null then return new; end if;
  select s.resource_kind into v_kind from public.seats s where s.id = new.seat_id;
  if v_kind is not null and v_kind <> 'seat'
     and not public.resource_kind_enabled(new.workspace_id, v_kind) then
    raise exception 'the % feature is off', public.resource_kind_feature(v_kind)
      using errcode = '42501';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.reservations_resource_gate() from public, anon, authenticated;
create trigger reservations_resource_gate
  before insert or update of seat_id on public.reservations
  for each row execute function public.reservations_resource_gate();

-- The KPI names rooms and parking apart (resources, reserved hours in the
-- period); the seat figures never include them.
create or replace function public.kpi_resource_counts(
  p_workspace_id uuid, p_from timestamptz, p_to timestamptz, p_level_id uuid)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select case when count(*) = 0 then '{}'::jsonb
    else jsonb_build_object('resources', jsonb_object_agg(k.kind,
           jsonb_build_object('resources', k.n, 'reserved_hours', round(k.h, 2)))) end
    from (
      select s.resource_kind as kind, count(distinct s.id) as n,
             coalesce(sum(extract(epoch from (least(r.ends_at, p_to) - greatest(r.starts_at, p_from))) / 3600)
                      filter (where r.id is not null), 0) as h
        from public.seats s
        join public.desks d on d.id = s.desk_id
        join public.offices o on o.id = d.office_id
        left join public.reservations r
               on r.seat_id = s.id and r.status in ('reserved', 'checked_in', 'completed')
              and r.starts_at < p_to and r.ends_at > p_from
       where s.workspace_id = p_workspace_id and s.resource_kind <> 'seat'
         and (p_level_id is null or o.level_id = p_level_id)
       group by s.resource_kind) k;
$fn$;
revoke execute on function public.kpi_resource_counts(uuid, timestamptz, timestamptz, uuid)
  from public, anon, authenticated;

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

do $migration$
declare
  v_def text;
begin
  -- 1. a room is not a seat of the capacity history.
  select pg_get_functiondef('public.analytics_seat_reopen(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$where s.id = p_seat_id;$a$,
    $a$where s.id = p_seat_id and s.resource_kind = 'seat';$a$);
  if v_def is null then raise exception '0442: analytics_seat_reopen anchor missing'; end if;
  execute v_def;

  -- 2. the KPI names rooms and parking apart.
  select pg_get_functiondef('public.kpi_seat_capacity(uuid,timestamptz,timestamptz,uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$'computed_at', now());$a$,
    $a$'computed_at', now())
    || public.kpi_resource_counts(p_workspace_id, p_from, p_to, p_level_id);$a$);
  if v_def is null then raise exception '0442: kpi_seat_capacity anchor missing'; end if;
  execute v_def;

  -- 3. a member's rooms and parking do not count against the seat limit.
  select pg_get_functiondef('public.enforce_one_place()'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$if new.status in ('reserved', 'checked_in') then$a$,
    $a$if new.status in ('reserved', 'checked_in')
       and not public.seat_is_resource(new.seat_id) then$a$);
  if v_def is null then raise exception '0442: enforce_one_place status anchor missing'; end if;
  v_def := pg_temp.anchor_replace(v_def,
    $a$and r.id <> new.id$a$,
    $a$and r.id <> new.id
        and not public.seat_is_resource(r.seat_id)$a$);
  if v_def is null then raise exception '0442: enforce_one_place overlap anchor missing'; end if;
  execute v_def;
end
$migration$;

-- 4. availability lists rooms and parking slots under their own kind, while
-- their flag is on (mcp_read_v1 whole, as it stood in 0412 plus the kind).
create or replace function public.mcp_read_v1(p_workspace_id uuid, p_member members, p_operation text, p_args jsonb)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_limit integer := least(greatest(coalesce((p_args->>'limit')::integer, 25), 1), 100);
  v_from timestamptz;
  v_to timestamptz;
  v_after_at timestamptz;
  v_after_id uuid;
  v_rows jsonb;
  v_count integer;
  v_last jsonb;
  v_event public.events;
  v_can boolean;
  v_reason text;
  v_level uuid;
  v_office uuid;
  v_kind text;
  v_page jsonb;
  v_more boolean;
  -- #2391 — beyond her own rows only when her consent reaches the
  -- workspace (the facade always says which; a direct definer call is the
  -- service role's).
  v_wide boolean := coalesce(p_args->>'_ceiling', 'workspace') = 'workspace';
begin
  select at, id into v_after_at, v_after_id
    from public.mcp_cursor_position(p_args->>'cursor', p_operation, p_workspace_id);

  if p_operation in ('get_availability', 'list_my_reservations') then
    v_from := public.mcp_time_arg(p_args, case when p_operation = 'get_availability' then 'starts_at' else 'from' end);
    v_to := public.mcp_time_arg(p_args, case when p_operation = 'get_availability' then 'ends_at' else 'to' end);
    if v_to <= v_from or v_to - v_from > interval '31 days' then
      return jsonb_build_object('refused', 'validation_error', 'code', 'window');
    end if;
  end if;

  if p_operation = 'list_my_reservations' then
    select coalesce(jsonb_agg(r order by (r->>'starts_at')::timestamptz, r->>'reservation_id'), '[]'::jsonb) into v_rows
      from (
        select jsonb_build_object('reservation_id', x.id, 'seat_id', x.seat_id, 'desk_id', x.desk_id,
                 'office_id', x.office_id, 'level_id', x.level_id,
                 'label', public.mcp_place_label(x.seat_id, x.desk_id, x.office_id, x.level_id),
                 'starts_at', x.starts_at, 'ends_at', x.ends_at, 'status', x.status) as r
          from public.reservations x
         where x.workspace_id = p_workspace_id and x.member_id = p_member.id
           and x.starts_at < v_to and x.ends_at > v_from
           and (v_after_at is null or (x.starts_at, x.id) > (v_after_at, v_after_id))
         order by x.starts_at, x.id
         limit v_limit + 1) q;
    v_count := jsonb_array_length(v_rows);
    if v_count > v_limit then
      v_rows := v_rows - v_limit;
      v_last := v_rows->(v_limit - 1);
      return jsonb_build_object('items', v_rows, 'next_cursor',
        public.mcp_cursor(p_operation, p_workspace_id, (v_last->>'starts_at')::timestamptz, (v_last->>'reservation_id')::uuid));
    end if;
    return jsonb_build_object('items', v_rows, 'next_cursor', null);
  end if;

  if p_operation = 'get_availability' then
    -- #2145 — optionally one level or one office; #2391 — every kind the app
    -- books (seats, and desks, offices and levels booked as a whole),
    -- optionally one kind. A page is the next place ids in order; it is
    -- shown by label, and the cursor follows the ids it paged by. "free" is
    -- the booking engine's own verdict (0345), asked only for this page.
    -- #2631 — a meeting room and a parking slot are places of their own
    -- kind, listed while their flag is on.
    v_level := public.mcp_uuid_arg(p_args, 'level_id', false);
    v_office := public.mcp_uuid_arg(p_args, 'office_id', false);
    v_kind := nullif(p_args->>'kind', '');
    if v_kind is not null and v_kind not in ('seat', 'desk', 'office', 'level', 'room', 'parking') then
      raise exception using errcode = '22023', message = 'kind';
    end if;
    select coalesce(jsonb_agg(to_jsonb(q) order by q.id), '[]'::jsonb) into v_page
      from (select p.*
              from (select s.resource_kind as kind, s.id, s.id as seat_id, d.id as desk_id, o.id as office_id,
                           o.level_id, s.name
                      from public.seats s
                      join public.desks d on d.id = s.desk_id
                      join public.offices o on o.id = d.office_id
                     where s.workspace_id = p_workspace_id
                       and public.resource_kind_enabled(p_workspace_id, s.resource_kind)
                    union all
                    select 'desk', d.id, null, d.id, o.id, o.level_id, d.name
                      from public.desks d
                      join public.offices o on o.id = d.office_id
                     where d.workspace_id = p_workspace_id and d.bookable_as_whole
                    union all
                    select 'office', o.id, null, null, o.id, o.level_id, o.name
                      from public.offices o
                     where o.workspace_id = p_workspace_id and o.bookable_as_whole
                    union all
                    select 'level', l.id, null, null, null, l.id, l.name
                      from public.levels l
                     where l.workspace_id = p_workspace_id and l.bookable_as_whole) p
             where (v_kind is null or p.kind = v_kind)
               and (v_level is null or p.level_id = v_level)
               and (v_office is null or p.office_id = v_office)
               and (v_after_id is null or p.id > v_after_id)
             order by p.id
             limit v_limit + 1) q;
    v_more := jsonb_array_length(v_page) > v_limit;
    if v_more then
      v_page := v_page - v_limit;
    end if;
    select coalesce(jsonb_agg(r order by r->>'label', r->>'kind', coalesce(r->>'seat_id', r->>'desk_id',
                                 r->>'office_id', r->>'level_id')), '[]'::jsonb) into v_rows
      from (
        select jsonb_build_object('kind', x.kind, 'seat_id', x.seat_id, 'desk_id', x.desk_id,
                 'office_id', x.office_id, 'level_id', x.level_id,
                 'label', public.mcp_place_label(x.seat_id,
                            case when x.kind = 'desk' then x.desk_id end,
                            case when x.kind = 'office' then x.office_id end,
                            case when x.kind = 'level' then x.level_id end),
                 'name', x.name,
                 'free', public.mcp_place_bookable(p_workspace_id, x.seat_id,
                            case when x.kind = 'desk' then x.desk_id end,
                            case when x.kind = 'office' then x.office_id end,
                            case when x.kind = 'level' then x.level_id end, v_from, v_to) is null) as r
          from jsonb_to_recordset(v_page) as x(kind text, id uuid, seat_id uuid, desk_id uuid,
                                               office_id uuid, level_id uuid, name text)) q;
    return jsonb_build_object('window', jsonb_build_object('starts_at', v_from, 'ends_at', v_to),
      'observed_at', now(), 'items', v_rows,
      'next_cursor', case when v_more then
        public.mcp_cursor(p_operation, p_workspace_id, now(),
          (v_page->(jsonb_array_length(v_page) - 1)->>'id')::uuid) end,
      'not_checked', jsonb_build_array('price', 'approval'));
  end if;

  if p_operation = 'list_my_invoices' then
    select coalesce(jsonb_agg(r order by (r->>'issued_at')::timestamptz desc, r->>'invoice_id' desc), '[]'::jsonb) into v_rows
      from (
        select jsonb_build_object('invoice_id', i.id, 'number', i.number, 'period', i.period,
                 'kind', i.kind, 'total_cents', i.total_cents, 'currency', i.currency,
                 'issued_at', i.issued_at, 'voided', i.voided_at is not null) as r
          from public.invoices i
         where i.workspace_id = p_workspace_id and i.member_id = p_member.id
           and (v_after_at is null or (i.issued_at, i.id) < (v_after_at, v_after_id))
         order by i.issued_at desc, i.id desc
         limit v_limit + 1) q;
    v_count := jsonb_array_length(v_rows);
    if v_count > v_limit then
      v_rows := v_rows - v_limit;
      v_last := v_rows->(v_limit - 1);
      return jsonb_build_object('items', v_rows, 'next_cursor',
        public.mcp_cursor(p_operation, p_workspace_id, (v_last->>'issued_at')::timestamptz, (v_last->>'invoice_id')::uuid));
    end if;
    return jsonb_build_object('items', v_rows, 'next_cursor', null);
  end if;

  if p_operation = 'list_pending_validations' then
    -- Pending events the caller authored or is the subject of; under a
    -- workspace ceiling also the ones she may answer.
    select coalesce(jsonb_agg(r order by (r->>'requested_at')::timestamptz, r->>'event_id'), '[]'::jsonb) into v_rows
      from (
        select jsonb_build_object('event_id', e.id, 'type', e.type, 'requested_at', e.created_at,
                 'mine', e.actor_member_id = p_member.id or e.subject_member_id = p_member.id) as r
          from public.events e
         where e.workspace_id = p_workspace_id and e.status = 'pending'
           and (e.actor_member_id = p_member.id or e.subject_member_id = p_member.id
                or (v_wide and (p_member.is_owner or p_member.is_admin
                                or public.may_validate_event_type(p_workspace_id, e.type))))
           and (v_after_at is null or (e.created_at, e.id) > (v_after_at, v_after_id))
         order by e.created_at, e.id
         limit v_limit + 1) q;
    v_count := jsonb_array_length(v_rows);
    if v_count > v_limit then
      v_rows := v_rows - v_limit;
      v_last := v_rows->(v_limit - 1);
      return jsonb_build_object('items', v_rows, 'next_cursor',
        public.mcp_cursor(p_operation, p_workspace_id, (v_last->>'requested_at')::timestamptz, (v_last->>'event_id')::uuid));
    end if;
    return jsonb_build_object('items', v_rows, 'next_cursor', null);
  end if;

  if p_operation = 'get_validation' then
    select * into v_event from public.events
     where id = public.mcp_uuid_arg(p_args, 'event_id') and workspace_id = p_workspace_id;
    if v_event.id is null
       or not (v_event.actor_member_id = p_member.id or v_event.subject_member_id = p_member.id
               or (v_wide and (p_member.is_owner or p_member.is_admin
                               or public.may_validate_event_type(p_workspace_id, v_event.type)))) then
      return jsonb_build_object('refused', 'not_found', 'code', 'not_found');
    end if;
    v_can := false;
    if v_event.status = 'pending' then
      begin
        perform public.respond_to_event(v_event.id, true);
        raise exception using errcode = 'P0002', message = 'mcp preview';
      exception
        when no_data_found then
          v_can := sqlerrm = 'mcp preview';
        when raise_exception then
          v_reason := left(sqlerrm, 120);
        when others then
          v_reason := 'unavailable';
      end;
    end if;
    return jsonb_build_object(
      'event_id', v_event.id, 'type', v_event.type, 'status', v_event.status,
      'requested_at', v_event.created_at,
      'decisions', (select count(*) from public.event_decisions d where d.event_id = v_event.id),
      'can_respond', v_can, 'reason', v_reason);
  end if;

  if p_operation = 'list_my_favorites' then
    return public.mcp_favorites_v1(p_workspace_id);
  end if;
  if p_operation = 'get_place' then
    return public.mcp_place_v1(p_workspace_id, p_member, p_args);
  end if;

  return jsonb_build_object('refused', 'validation_error', 'code', 'unknown_operation');
end;
$function$;
revoke execute on function public.mcp_read_v1(uuid, members, text, jsonb) from public, anon, authenticated;

-- the feature registry knows `meetingRooms` (dart run tool/build_feature_registry_sql.dart)
create or replace function public.feature_registry()
returns jsonb
language sql
immutable
set search_path = public
as $registry$
  select '{
    "calendarTab": {"parent": null, "default": true, "core": true},
    "eventsTab": {"parent": null, "default": true, "core": true},
    "moneyTab": {"parent": null, "default": true, "core": true},
    "services": {"parent": "moneyTab", "default": true, "core": true},
    "accessorySupplements": {"parent": "moneyTab", "default": false, "core": false},
    "onlinePayments": {"parent": "moneyTab", "default": false, "core": false},
    "invoicing": {"parent": "moneyTab", "default": true, "core": true},
    "adminInvoicing": {"parent": "invoicing", "default": false, "core": false},
    "pdfExport": {"parent": null, "default": true, "core": true},
    "seriesBooking": {"parent": null, "default": true, "core": true},
    "bookForOthers": {"parent": null, "default": true, "core": true},
    "pushNotifications": {"parent": null, "default": true, "core": true},
    "adminSeatBlocking": {"parent": null, "default": false, "core": false},
    "levelBooking": {"parent": null, "default": false, "core": false},
    "adminLevelAssign": {"parent": "levelBooking", "default": false, "core": false},
    "kioskMode": {"parent": null, "default": true, "core": false},
    "nfcBadges": {"parent": "kioskMode", "default": true, "core": false},
    "membersDirectory": {"parent": null, "default": true, "core": true},
    "whatsappIntegration": {"parent": "membersDirectory", "default": true, "core": false},
    "spaceQrCodes": {"parent": null, "default": true, "core": true},
    "coOwner": {"parent": null, "default": true, "core": false},
    "autoCheckInOut": {"parent": null, "default": false, "core": false},
    "dataExport": {"parent": null, "default": true, "core": true},
    "workingHours": {"parent": null, "default": true, "core": true},
    "invoicePdfTemplate": {"parent": "invoicing", "default": true, "core": false},
    "invoiceAddressWindow": {"parent": "invoicing", "default": true, "core": false},
    "memberNotifications": {"parent": null, "default": true, "core": true},
    "documents": {"parent": null, "default": true, "core": true},
    "dunning": {"parent": "invoicing", "default": true, "core": false},
    "memberReports": {"parent": "moneyTab", "default": true, "core": false},
    "deletionRequests": {"parent": null, "default": true, "core": true},
    "roleManagement": {"parent": null, "default": true, "core": true},
    "vatManagement": {"parent": "invoicing", "default": true, "core": false},
    "vatDeclarations": {"parent": "vatManagement", "default": true, "core": false},
    "einvoiceCustomerDelivery": {"parent": "invoicing", "default": true, "core": false},
    "planObjectDelete": {"parent": null, "default": true, "core": true},
    "notificationGrouping": {"parent": "eventsTab", "default": true, "core": true},
    "bookingPolicies": {"parent": null, "default": true, "core": true},
    "bookingGate": {"parent": "bookingPolicies", "default": true, "core": true},
    "nfcSeatTags": {"parent": null, "default": true, "core": false},
    "qrBadges": {"parent": "kioskMode", "default": true, "core": false},
    "kioskMemberPhotos": {"parent": "kioskMode", "default": true, "core": false},
    "subscriptionInvoices": {"parent": "invoicing", "default": true, "core": false},
    "usageInvoices": {"parent": "invoicing", "default": true, "core": false},
    "invoiceSettlement": {"parent": "invoicing", "default": true, "core": false},
    "invoiceJourney": {"parent": "invoicing", "default": true, "core": false},
    "messageGestures": {"parent": null, "default": true, "core": true},
    "uniqueMonograms": {"parent": null, "default": true, "core": true},
    "planMemberPhotos": {"parent": null, "default": true, "core": false},
    "regionalFormats": {"parent": null, "default": true, "core": true},
    "calendarHub": {"parent": null, "default": true, "core": true},
    "calendarViews": {"parent": "calendarHub", "default": true, "core": true},
    "messagesHub": {"parent": null, "default": true, "core": true},
    "reportDesigner": {"parent": "invoicePdfTemplate", "default": true, "core": false},
    "memberPage": {"parent": "membersDirectory", "default": true, "core": true},
    "invoicingWizard": {"parent": "invoicing", "default": true, "core": false},
    "expenseRepartition": {"parent": "invoicing", "default": true, "core": false},
    "settlementFold": {"parent": "invoiceSettlement", "default": true, "core": false},
    "configurationTransfer": {"parent": "dataExport", "default": true, "core": false},
    "navigationStyle": {"parent": null, "default": true, "core": true},
    "demoMode": {"parent": null, "default": true, "core": false},
    "instanceWizard": {"parent": null, "default": true, "core": false},
    "dataAccessLog": {"parent": "moneyTab", "default": true, "core": false},
    "memberDataExport": {"parent": null, "default": true, "core": true},
    "financeFaces": {"parent": "moneyTab", "default": true, "core": true},
    "paymentReminders": {"parent": "dunning", "default": true, "core": false},
    "supplyExpenses": {"parent": "services", "default": true, "core": false},
    "validationScopes": {"parent": null, "default": true, "core": false},
    "validationChain": {"parent": null, "default": true, "core": false},
    "richMessageRefs": {"parent": "memberNotifications", "default": true, "core": true},
    "calendarValidations": {"parent": "calendarHub", "default": true, "core": false},
    "usageRecords": {"parent": "invoicing", "default": true, "core": false},
    "reportDesignExchange": {"parent": "reportDesigner", "default": true, "core": false},
    "reportLayouts": {"parent": "reportDesigner", "default": true, "core": false},
    "personalInfo": {"parent": null, "default": true, "core": true},
    "managedProfiles": {"parent": "membersDirectory", "default": true, "core": false},
    "numberSequences": {"parent": "invoicing", "default": false, "core": false},
    "workspaceStatus": {"parent": "invoicing", "default": false, "core": false},
    "expenseRepartitionWizard": {"parent": "expenseRepartition", "default": false, "core": false},
    "multiSite": {"parent": null, "default": false, "core": false},
    "siteDocuments": {"parent": "multiSite", "default": false, "core": false},
    "vatGroups": {"parent": "vatManagement", "default": false, "core": false},
    "vatRateHistory": {"parent": "vatManagement", "default": false, "core": false},
    "vatCounterparty": {"parent": "vatManagement", "default": false, "core": false},
    "environmentPairs": {"parent": null, "default": true, "core": false},
    "deployments": {"parent": "environmentPairs", "default": true, "core": false},
    "managedProfileAccess": {"parent": "managedProfiles", "default": false, "core": false},
    "seatDayTimeline": {"parent": null, "default": true, "core": true},
    "memberPaymentTerms": {"parent": "invoicing", "default": true, "core": false},
    "usageReport": {"parent": "usageRecords", "default": true, "core": false},
    "reportTexts": {"parent": "reportDesigner", "default": true, "core": false},
    "letterStandard": {"parent": "reportLayouts", "default": true, "core": false},
    "vatReport": {"parent": "vatDeclarations", "default": true, "core": false},
    "priceNegotiations": {"parent": "moneyTab", "default": true, "core": false},
    "scheduledExpenses": {"parent": "moneyTab", "default": true, "core": false},
    "badgeSignIn": {"parent": "nfcBadges", "default": false, "core": false},
    "formHelpHints": {"parent": null, "default": true, "core": true},
    "uiAnimations": {"parent": null, "default": true, "core": true},
    "memberOrigin": {"parent": "membersDirectory", "default": false, "core": false},
    "memberEnvironments": {"parent": "environmentPairs", "default": false, "core": false},
    "workspaceLibrary": {"parent": null, "default": false, "core": false},
    "singleRoomLevelNames": {"parent": null, "default": true, "core": true},
    "publicHolidays": {"parent": null, "default": false, "core": false},
    "workspaceVocabulary": {"parent": null, "default": false, "core": false},
    "carnets": {"parent": "invoicing", "default": false, "core": false},
    "publicListings": {"parent": null, "default": false, "core": true},
    "workspaceBranding": {"parent": null, "default": false, "core": false},
    "customRoles": {"parent": null, "default": false, "core": false},
    "customFields": {"parent": null, "default": false, "core": false},
    "decisionSurface": {"parent": null, "default": false, "core": false},
    "recordingPrivacy": {"parent": null, "default": false, "core": false},
    "memberAccountMenu": {"parent": null, "default": false, "core": false},
    "mcpAccess": {"parent": null, "default": false, "core": false},
    "calendarFileExport": {"parent": null, "default": true, "core": true},
    "memberGettingStarted": {"parent": null, "default": true, "core": true},
    "placeFeedback": {"parent": null, "default": true, "core": true},
    "spaceInquiries": {"parent": null, "default": true, "core": true},
    "messageForwarding": {"parent": "memberNotifications", "default": true, "core": true},
    "captureProtection": {"parent": "memberNotifications", "default": true, "core": true},
    "holidayImport": {"parent": "publicHolidays", "default": false, "core": false},
    "capacityKpi": {"parent": null, "default": false, "core": false},
    "accountingBook": {"parent": "invoicing", "default": false, "core": false},
    "roleAssignment": {"parent": "roleManagement", "default": true, "core": true},
    "taskRecorder": {"parent": null, "default": false, "core": false},
    "guestParticipation": {"parent": null, "default": false, "core": true},
    "messageMentions": {"parent": "memberNotifications", "default": true, "core": true},
    "supplyClassification": {"parent": "vatManagement", "default": true, "core": false},
    "viesVerification": {"parent": "supplyClassification", "default": true, "core": false},
    "recapitulativeStatement": {"parent": "vatDeclarations", "default": true, "core": false},
    "inputVat": {"parent": "vatDeclarations", "default": true, "core": false},
    "configurableSettings": {"parent": null, "default": true, "core": false},
    "salesTax": {"parent": "invoicing", "default": true, "core": false},
    "meetingRooms": {"parent": null, "default": false, "core": false}
  }'::jsonb
$registry$;
revoke execute on function public.feature_registry() from public, anon;

select public.set_deskilo_schema_version(442);
