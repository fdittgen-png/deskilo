-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0361 (#2145) -- what an assistant needs to answer a person in their own
-- words, and what the workspace keeps about what an assistant booked.
--
--   * Places are named without naming anybody: every availability item and
--     every own booking carries `label`, built from the level, office and
--     desk names and a neutral seat letter ("Level 2 · Open space · Desk 4 ·
--     Seat B"); a desk without a name is numbered within its office. A
--     seat's own `name`, which may name a person, stays the optional
--     display field (#1645) it was. get_availability takes optional
--     level_id / office_id filters and returns each seat's desk, office and
--     level ids; its page cursor now follows the seat ids it paged by.
--   * get_my_statement is always the caller's own: member_id is gone from
--     the contract (a stray one that is not the caller is still not_found),
--     and the answer carries the workspace currency.
--   * get_capabilities carries the workspace's time zone, currency and
--     opening hours, so "tomorrow morning" is read in the workspace's zone.
--   * list_workspaces' declared output is what the endpoint returns
--     (workspace_id, name, operations).
--   * Provenance: a booking an assistant created is recorded in
--     reservation_origins (which assistant, which request), written inside
--     mcp_execute_v1's create branch after create_reservation_once
--     returned, so it commits or rolls back with the booking. The member
--     reads their own rows; the workspace's reservation managers read all.
--     The reservations table and create_reservation_once are untouched.

-- ── labels ──────────────────────────────────────────────────────────
create or replace function public.mcp_place_label(
  p_seat_id uuid, p_desk_id uuid, p_office_id uuid, p_level_id uuid)
returns text language plpgsql stable set search_path = public as $fn$
declare
  v_seat public.seats;
  v_desk public.desks;
  v_office public.offices;
  v_level public.levels;
  v_n bigint;
  v_parts text[] := '{}';
begin
  if p_seat_id is not null then
    select * into v_seat from public.seats where id = p_seat_id;
  end if;
  select * into v_desk from public.desks where id = coalesce(v_seat.desk_id, p_desk_id);
  select * into v_office from public.offices where id = coalesce(v_desk.office_id, p_office_id);
  select * into v_level from public.levels where id = coalesce(v_office.level_id, p_level_id);
  if v_level.id is not null then v_parts := v_parts || btrim(v_level.name); end if;
  if v_office.id is not null then v_parts := v_parts || btrim(v_office.name); end if;
  if v_desk.id is not null then
    if btrim(v_desk.name) <> '' then
      v_parts := v_parts || btrim(v_desk.name);
    else
      select count(*) into v_n from public.desks d
       where d.office_id = v_desk.office_id and (d.y, d.x, d.id) <= (v_desk.y, v_desk.x, v_desk.id);
      v_parts := v_parts || ('Desk ' || v_n);
    end if;
  end if;
  if v_seat.id is not null then
    -- Never the seat's own name: it may name a person (#1645).
    select count(*) into v_n from public.seats s
     where s.desk_id = v_seat.desk_id and (s.y, s.x, s.id) <= (v_seat.y, v_seat.x, v_seat.id);
    v_parts := v_parts || ('Seat ' || case when v_n between 1 and 26 then chr(64 + v_n::int) else v_n::text end);
  end if;
  return nullif(array_to_string(v_parts, ' · '), '');
end;
$fn$;
revoke execute on function public.mcp_place_label(uuid, uuid, uuid, uuid) from public, anon, authenticated;

-- ── the workspace's clock and hours ─────────────────────────────────
create or replace function public.mcp_workspace_context(p_workspace_id uuid)
returns jsonb language sql stable set search_path = public as $fn$
  select jsonb_build_object(
    'time_zone', w.timezone,
    'currency', w.currency_code,
    'opening_hours', jsonb_strip_nulls(jsonb_build_object(
      'open_weekdays', coalesce(w.booking_rules->'open_weekdays', '[1,2,3,4,5]'::jsonb),
      'work_start', to_char(make_interval(mins => coalesce((w.booking_rules->>'work_start_minutes')::int, 480)), 'HH24:MI'),
      'half_boundary', to_char(make_interval(mins => coalesce((w.booking_rules->>'half_boundary_minutes')::int, 720)), 'HH24:MI'),
      'work_end', to_char(make_interval(mins => coalesce((w.booking_rules->>'work_end_minutes')::int, 1020)), 'HH24:MI'),
      'granularity', w.booking_rules->>'granularity')))
    from public.workspaces w where w.id = p_workspace_id;
$fn$;
revoke execute on function public.mcp_workspace_context(uuid) from public, anon, authenticated;

-- ── provenance ──────────────────────────────────────────────────────
create table if not exists public.reservation_origins (
  reservation_id uuid primary key references public.reservations(id) on delete cascade,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  channel text not null check (channel in ('assistant')),
  client_id text not null check (char_length(client_id) between 1 and 200),
  client_name text not null check (char_length(client_name) between 1 and 200),
  request_id uuid not null,
  created_at timestamptz not null default now()
);
select public.ensure_system_columns('reservation_origins');
create index if not exists reservation_origins_workspace
  on public.reservation_origins (workspace_id, created_at desc);
create index if not exists reservation_origins_member
  on public.reservation_origins (member_id, created_at desc);

alter table public.reservation_origins enable row level security;
revoke all on table public.reservation_origins from public, anon, authenticated;
grant select on table public.reservation_origins to authenticated;
drop policy if exists reservation_origins_select on public.reservation_origins;
create policy reservation_origins_select on public.reservation_origins
  for select to authenticated using (
    exists (select 1 from public.members m
             where m.id = reservation_origins.member_id and m.user_id = (select auth.uid()) and m.status = 'active')
    or public.has_permission(reservation_origins.workspace_id, 'manageReservations'));
drop policy if exists mcp_delegated_deny on public.reservation_origins;
create policy mcp_delegated_deny on public.reservation_origins
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create or replace function public.mcp_record_reservation_origin(
  p_reservation_id uuid, p_workspace_id uuid, p_member_id uuid, p_client_id text, p_request_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $fn$
begin
  if p_reservation_id is null or p_client_id is null or p_request_id is null then
    return;
  end if;
  insert into public.reservation_origins
    (reservation_id, workspace_id, member_id, channel, client_id, client_name, request_id)
  values (p_reservation_id, p_workspace_id, p_member_id, 'assistant', p_client_id,
          left(coalesce(nullif(btrim((select k.name from public.mcp_clients k where k.client_id = p_client_id)), ''),
                        p_client_id), 200),
          p_request_id)
  on conflict (reservation_id) do nothing;
end;
$fn$;
revoke execute on function public.mcp_record_reservation_origin(uuid, uuid, uuid, text, uuid) from public, anon, authenticated;


-- ── the bounded reads (0275, with 0345's engine verdict) ────────────
create or replace function public.mcp_read_v1(
  p_workspace_id uuid, p_member public.members, p_operation text, p_args jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
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
  v_ids uuid[];
  v_more boolean;
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
    -- #2145 — optionally one level or one office. A page is the next
    -- seat ids in order; it is shown by label, and the cursor follows the
    -- ids it paged by. "free" is the booking engine's own verdict (0345),
    -- asked only for the seats on this page.
    v_level := public.mcp_uuid_arg(p_args, 'level_id', false);
    v_office := public.mcp_uuid_arg(p_args, 'office_id', false);
    select coalesce(array_agg(id order by id), '{}') into v_ids
      from (select s.id
              from public.seats s
              join public.desks d on d.id = s.desk_id
              join public.offices o on o.id = d.office_id
             where s.workspace_id = p_workspace_id
               and (v_level is null or o.level_id = v_level)
               and (v_office is null or o.id = v_office)
               and (v_after_id is null or s.id > v_after_id)
             order by s.id
             limit v_limit + 1) q;
    v_more := cardinality(v_ids) > v_limit;
    v_ids := v_ids[1:v_limit];
    select coalesce(jsonb_agg(r order by r->>'label', r->>'seat_id'), '[]'::jsonb) into v_rows
      from (
        select jsonb_build_object('seat_id', s.id, 'desk_id', d.id, 'office_id', o.id, 'level_id', o.level_id,
                 'label', public.mcp_place_label(s.id, null, null, null), 'name', s.name,
                 'free', public.mcp_seat_bookable(p_workspace_id, s.id, v_from, v_to) is null) as r
          from unnest(v_ids) i(id)
          join public.seats s on s.id = i.id
          join public.desks d on d.id = s.desk_id
          join public.offices o on o.id = d.office_id) q;
    return jsonb_build_object('window', jsonb_build_object('starts_at', v_from, 'ends_at', v_to),
      'observed_at', now(), 'items', v_rows,
      'next_cursor', case when v_more then
        public.mcp_cursor(p_operation, p_workspace_id, now(), v_ids[cardinality(v_ids)]) end,
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
    -- Pending events the caller authored, is the subject of, or may answer.
    select coalesce(jsonb_agg(r order by (r->>'requested_at')::timestamptz, r->>'event_id'), '[]'::jsonb) into v_rows
      from (
        select jsonb_build_object('event_id', e.id, 'type', e.type, 'requested_at', e.created_at,
                 'mine', e.actor_member_id = p_member.id or e.subject_member_id = p_member.id) as r
          from public.events e
         where e.workspace_id = p_workspace_id and e.status = 'pending'
           and (e.actor_member_id = p_member.id or e.subject_member_id = p_member.id
                or p_member.is_owner or p_member.is_admin
                or public.may_validate_event_type(p_workspace_id, e.type))
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
               or p_member.is_owner or p_member.is_admin
               or public.may_validate_event_type(p_workspace_id, v_event.type)) then
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

  return jsonb_build_object('refused', 'validation_error', 'code', 'unknown_operation');
end;
$fn$;
revoke execute on function public.mcp_read_v1(uuid, public.members, text, jsonb) from public, anon, authenticated;

-- ── mcp_execute_v1: anchored patches ────────────────────────────────
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
  v_def text := pg_get_functiondef('public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid)'::regprocedure);
  v_next text;
begin
  if position('#2145' in v_def) > 0 then
    raise exception '0358: mcp_execute_v1 already carries #2145';
  end if;

  -- The statement is always the caller's own; a stray other id stays not_found.
  v_next := pg_temp.anchor_replace(v_def,
    $a$if public.mcp_uuid_arg(v_args, 'member_id') <> v_member.id then$a$,
    $b$if v_args ? 'member_id' and public.mcp_uuid_arg(v_args, 'member_id') <> v_member.id then -- #2145$b$);
  if v_next is null then raise exception '0358: statement member anchor missing'; end if;
  v_def := v_next;

  v_next := pg_temp.anchor_replace(v_def,
    $a$v_data := public.member_statement(v_member.id, v_args->>'period');$a$,
    $b$v_data := public.member_statement(v_member.id, v_args->>'period')
          || jsonb_build_object('currency', (select w.currency_code from public.workspaces w where w.id = p_workspace_id));$b$);
  if v_next is null then raise exception '0358: statement anchor missing'; end if;
  v_def := v_next;

  -- The workspace's zone, currency and hours beside what it exposes.
  v_next := pg_temp.anchor_replace(v_def,
    $a$'eligible_until', v_grant.expires_at);$a$,
    $b$'eligible_until', v_grant.expires_at)
                  || public.mcp_workspace_context(p_workspace_id);$b$);
  if v_next is null then raise exception '0358: capabilities anchor missing'; end if;
  v_def := v_next;

  -- Provenance, inside the same subtransaction as the booking.
  v_next := pg_temp.anchor_replace(v_def,
    $a$v_data := jsonb_build_object('reservation_id', v_id);$a$,
    $b$v_data := jsonb_build_object('reservation_id', v_id);
        perform public.mcp_record_reservation_origin(v_id, p_workspace_id, v_member.id, v_client, p_request_id);$b$);
  if v_next is null then raise exception '0358: create anchor missing'; end if;

  execute v_next;
end
$migration$;

-- ── the catalogue ───────────────────────────────────────────────────
-- GENERATED from contracts/mcp/operations.json by tool/mcp_contract/render.dart
-- (renderMcpCatalogueSql); mcp_contract_test fails until this is verbatim.
create or replace function public.mcp_operation_catalogue()
returns jsonb
language sql
immutable
set search_path = public
as $catalogue$
  select $json${"version":1,"operations":{"list_workspaces":{"rpc":null,"dispatch":false,"authority":"self","permission":null,"features":[],"scope":"discovery","mutation":"read","confirmation":"none","output":["confirmation_id","expires_at","operations","reason","unchanged","workspace_id"],"optional":["name"]},"get_capabilities":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["confirmation_id","currency","eligible_until","expires_at","opening_hours","operations","reason","target_ceiling","time_zone","unchanged"],"optional":[]},"get_availability":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["confirmation_id","desk_id","ends_at","expires_at","free","items","label","level_id","next_cursor","not_checked","observed_at","office_id","reason","seat_id","starts_at","unchanged","window"],"optional":["name"]},"list_my_reservations":{"rpc":null,"dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"read","confirmation":"none","output":["confirmation_id","desk_id","ends_at","expires_at","items","label","level_id","next_cursor","office_id","reason","reservation_id","seat_id","starts_at","status","unchanged"],"optional":[]},"get_my_statement":{"rpc":"member_statement","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess","moneyTab"],"scope":"own","mutation":"read","confirmation":"none","output":["accessory_supplement_by_rate","accessory_supplement_cents","active","amount_cents","balance_cents","confirmation_id","credits_cents","currency","default_fee_cents","default_overage_fee_cents","desk_supplement_cents","discount_percent","expires_at","extra_half_days","fee_cents","granted_half_days","included_half_days","level_supplement_cents","negotiated","office_supplement_cents","open_days","overage_cents","overage_fee_cents","overage_policy","overage_rate_cents","period","reason","remaining_half_days","subscription_pct","unchanged","used_half_days","valid_from","vat_percent"],"optional":[]},"list_my_invoices":{"rpc":null,"dispatch":true,"authority":"self","permission":null,"features":["mcpAccess","invoicing"],"scope":"own","mutation":"read","confirmation":"none","output":["confirmation_id","currency","expires_at","invoice_id","issued_at","items","kind","next_cursor","number","period","reason","total_cents","unchanged","voided"],"optional":[]},"create_reservation":{"rpc":"create_reservation_once","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"update_reservation":{"rpc":"update_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"check_in":{"rpc":"check_in_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"check_out":{"rpc":"check_out_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"request_reservation_deletion":{"rpc":"request_reservation_deletion","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"request","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","event_id","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"request_invoice_issue":{"rpc":"request_invoice_issue","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","currency","event_id","expires_at","invoice_id","invoice_number","period","reason","total_cents","unchanged","voided"],"optional":[]},"request_invoice_void":{"rpc":"request_invoice_void","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","currency","event_id","expires_at","invoice_id","invoice_number","period","reason","total_cents","unchanged","voided"],"optional":[]},"request_refund":{"rpc":"request_refund","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","currency","event_id","expires_at","invoice_id","invoice_number","period","reason","total_cents","unchanged","voided"],"optional":[]},"request_member_status_change":{"rpc":"request_member_status_change","dispatch":true,"authority":"permission","permission":"manageMembers","features":["mcpAccess"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","event_id","expires_at","member_id","member_status","reason","subscription_pct","unchanged"],"optional":[]},"request_subscription_change":{"rpc":"request_subscription_change","dispatch":true,"authority":"permission","permission":"manageMembers","features":["mcpAccess"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","event_id","expires_at","member_id","member_status","reason","subscription_pct","unchanged"],"optional":[]},"list_pending_validations":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["confirmation_id","event_id","expires_at","items","mine","next_cursor","reason","requested_at","type","unchanged"],"optional":[]},"get_validation":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["can_respond","confirmation_id","decisions","event_id","expires_at","reason","requested_at","status","type","unchanged"],"optional":[]},"respond_to_validation":{"rpc":"respond_to_event","dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"decision","confirmation":"native","output":["confirmation_id","decision_recorded","effect_applied","event_id","event_status","expires_at","reason","unchanged"],"optional":[]}}}$json$::jsonb
$catalogue$;
revoke execute on function public.mcp_operation_catalogue() from public, anon;
grant execute on function public.mcp_operation_catalogue() to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(358);
