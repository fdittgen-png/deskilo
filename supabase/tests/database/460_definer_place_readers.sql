-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4144 (0806): every server function that runs with its definer's rights and
-- reads reservations, seats, desks, offices or levels applies their reading
-- rules (room_visible, level_visible, desk_room_visible,
-- reservation_place_visible, place_visible_to, booking_place_hidden) or is listed below with the
-- tables it reads and what it returns. Read from the database itself, keyed
-- by signature. The list is closed: a new reader fails until it applies the
-- rules or is listed; an entry fails when its function no longer exists,
-- reads other tables, or now applies the rules.
-- test/lint/definer_event_readers_test.dart checks each listed signature
-- against the effective contract.
begin;
select plan(7);

create temp table listed (sig text primary key, tables text not null, reason text not null check (length(reason) > 0));
insert into listed (sig, tables, reason) values
  ('analytics_seat_reopen(uuid)', 'desks,offices,seats',
   'callable by the service role only'),
  ('assert_member_quota(uuid,timestamp with time zone)', 'reservations',
   'callable by the service role only'),
  ('assert_seat_not_blocked(uuid,timestamp with time zone,timestamp with time zone)', 'seats',
   'callable by the service role only'),
  ('booking_prices(uuid,timestamp with time zone,timestamp with time zone)', 'reservations',
   'the members'' billing under the finance right; a usage names what was used'),
  ('check_in_reservation(uuid)', 'reservations',
   'writes or checks: returns an id, nothing, or a refusal about what the caller acts on'),
  ('check_out_reservation(uuid)', 'reservations',
   'writes or checks: returns an id, nothing, or a refusal about what the caller acts on'),
  ('clear_sample_data(uuid,uuid)', 'reservations',
   'writes or checks: returns an id, nothing, or a refusal about what the caller acts on'),
  ('complete_check_out(uuid)', 'reservations',
   'callable by the service role only'),
  ('convert_to_series(uuid,text,timestamp with time zone,timestamp with time zone,timestamp with time zone)', 'reservations',
   'writes a booking: returns an id, nothing, or a refusal about the booking the caller makes'),
  ('create_invoice(uuid,uuid,text,uuid,boolean,text,boolean,text,text,text)', 'desks,levels,offices,reservations,seats',
   'writes or checks: returns an id, nothing, or a refusal about what the caller acts on'),
  ('create_sample_data(uuid,uuid)', 'desks,levels,offices,reservations,seats',
   'writes or checks: returns an id, nothing, or a refusal about what the caller acts on'),
  ('delete_plan_object(text,uuid)', 'desks,levels,offices,reservations,seats',
   'writes or checks: returns an id, nothing, or a refusal about what the caller acts on, under the sites right'),
  ('enforce_booking_rules(uuid,timestamp with time zone,timestamp with time zone,boolean,uuid)', 'seats',
   'callable by the service role only'),
  ('ensure_usage_records(uuid,text)', 'reservations',
   'callable by the service role only'),
  ('export_floor_plan(uuid)', 'desks,levels,offices,seats',
   'callable by the service role only'),
  ('export_my_data(uuid)', 'reservations',
   'returns only the caller''s own bookings'),
  ('import_floor_plan_v2(uuid,jsonb,jsonb)', 'levels,reservations',
   'writes or checks: returns an id, nothing, or a refusal about what the caller acts on, under the sites right'),
  ('import_floor_plan_v3(uuid,jsonb,jsonb)', 'levels,reservations',
   'writes or checks: returns an id, nothing, or a refusal about what the caller acts on, under the sites or the configuration right'),
  ('import_floor_plan(uuid,jsonb)', 'levels,reservations',
   'writes or checks: returns an id, nothing, or a refusal about what the caller acts on, under the sites right'),
  ('kpi_cost_allocation(uuid,text,text)', 'desks,levels,offices,seats',
   'figures under their own reading right, which name the rooms they are about'),
  ('kpi_resource_counts(uuid,timestamp with time zone,timestamp with time zone,uuid)', 'desks,offices,reservations,seats',
   'callable by the service role only'),
  ('kpi_sales_quality(uuid,text,text)', 'offices',
   'figures under their own reading right, which name the rooms they are about'),
  ('level_has_conflict(uuid,timestamp with time zone,timestamp with time zone)', 'desks,offices,reservations,seats',
   'callable by the service role only'),
  ('mcp_own_reservation(mcp_call_context,jsonb)', 'reservations',
   'callable by the service role only'),
  ('member_credit_uses_in_period(uuid,timestamp with time zone,timestamp with time zone)', 'reservations',
   'callable by the service role only'),
  ('member_months_extra_half_days(uuid,uuid[],text[])', 'reservations',
   'callable by the service role only'),
  ('member_pause_money(uuid,date,date)', 'reservations',
   'callable by the service role only'),
  ('member_quota_shortfall(uuid,timestamp with time zone)', 'reservations',
   'callable by the service role only'),
  ('member_statement(uuid,text)', 'desks,levels,offices,reservations',
   'money figures of a member under the finance right; no place'),
  ('merge_floor_plan(uuid,jsonb)', 'desks,levels,offices,seats',
   'callable by the service role only'),
  ('message_ref_workspace(text,uuid)', 'desks,levels,offices,reservations,seats',
   'callable by the service role only'),
  ('place_feedback_member(uuid,text,uuid)', 'desks,levels,offices,seats',
   'callable by the service role only'),
  ('plan_media_orphans(uuid,integer)', 'levels',
   'under the sites right; returns stored file names, no place'),
  ('preview_my_erasure(uuid)', 'reservations',
   'counts of the caller''s own records'),
  ('purchase_place_name(purchase_lines)', 'desks,levels,offices,seats',
   'callable by the service role only'),
  ('purchase_resource_site(uuid,text,uuid)', 'desks,levels,offices,seats',
   'callable by the service role only'),
  ('rebalance_member_credits(uuid,timestamp with time zone,uuid)', 'reservations',
   'callable by the service role only'),
  ('reorder_levels(uuid,uuid[],uuid[])', 'levels',
   'under the sites right (the owner holds every right)'),
  ('request_reservation_deletion(uuid,text)', 'reservations',
   'writes or checks: returns an id, nothing, or a refusal about what the caller acts on (the callers own booking)'),
  ('reservation_counts_for_usage(reservations,jsonb,text)', 'reservations',
   'callable by the service role only'),
  ('reservation_request_outcome(uuid,uuid)', 'reservations',
   'the caller''s own request'),
  ('reservation_site(reservations)', 'desks,levels,offices,seats',
   'callable by the service role only'),
  ('reservation_uses_seat_quota(reservations)', 'seats',
   'callable by the service role only'),
  ('reset_workspace(uuid)', 'desks,levels,offices,reservations,seats',
   'writes or checks: returns an id, nothing, or a refusal about what the caller acts on'),
  ('revoke_guest_pass(uuid,uuid,uuid)', 'reservations',
   'writes or checks: returns an id, nothing, or a refusal about what the caller acts on'),
  ('room_rental_json(room_rentals)', 'offices',
   'callable by the service role only'),
  ('room_rentals_v1(uuid)', 'levels,offices',
   'under the sites or the finance right, which read the rentals'' terms'),
  ('room_visible(uuid)', 'levels,offices',
   'the reading rule itself: whether the caller sees a room'),
  ('save_cost_allocation_rule_v1(uuid,uuid,integer,jsonb,uuid)', 'desks,levels,offices,seats',
   'writes or checks: returns an id, nothing, or a refusal about what the caller acts on'),
  ('save_room_rental_v1(uuid,uuid,uuid,date,date,text,bigint,text,text,uuid,integer,boolean)', 'levels,offices',
   'writes or checks: returns an id, nothing, or a refusal about what the caller acts on, under the right to manage the rooms'),
  ('seat_is_resource(uuid)', 'seats',
   'callable by the service role only'),
  ('set_level_kind_v1(uuid,uuid,text)', 'desks,levels,offices,reservations,seats',
   'writes or checks: returns an id, nothing, or a refusal about what the caller acts on, under the right to manage the rooms'),
  ('set_level_site(uuid,uuid)', 'levels',
   'under the sites right'),
  ('update_reservation(uuid,timestamp with time zone,timestamp with time zone)', 'reservations',
   'writes or checks: returns an id, nothing, or a refusal about what the caller acts on (the callers own booking)'),
  ('upsert_usage_record(uuid)', 'reservations',
   'callable by the service role only'),
  ('usage_records_read_v1(uuid,text,uuid)', 'reservations',
   'the members'' billing under the finance right; a usage names what was used'),
  ('member_workspaces_without_external_level()', 'levels',
   'the caller''s own businesses that have no external level; no place'),
  ('workspace_has_external_level(uuid)', 'levels',
   'one yes or no for the business, to its members; no place'),
  ('workspace_readiness(uuid)', 'reservations,seats',
   'counts under the configuration right; no place');

create function pg_temp.readers() returns table (sig text, tables text, applies boolean) language sql stable as $$
  select p.oid::regprocedure::text,
         array_to_string(array(select t from unnest(array['levels','offices','desks','seats','reservations']) t
                                where p.prosrc ~* ('\m(from|join)\s+("?public"?\s*\.\s*)?"?' || t || '"?\M') order by t), ','),
         p.prosrc ~* '\m(room_visible|level_visible|desk_room_visible|reservation_place_visible|place_visible_to|booking_place_hidden)\s*\('
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prosecdef and p.prorettype <> 'trigger'::regtype
     and p.prosrc ~* '\m(from|join)\s+("?public"?\s*\.\s*)?"?(reservations|seats|desks|offices|levels)"?\M';
$$;

select is((select coalesce(string_agg(r.sig, ', ' order by r.sig), '') from pg_temp.readers() r
            where not r.applies and r.sig not in (select sig from listed)), '',
  'every server function that reads bookings or places applies their reading rules or is listed with what it returns');
select is((select coalesce(string_agg(l.sig || ' (' || l.tables || ' / ' || coalesce(r.tables, 'gone') || ')', ', ' order by l.sig), '')
             from listed l left join pg_temp.readers() r on r.sig = l.sig
            where r.sig is null or r.tables <> l.tables), '',
  'every listed function exists and reads the tables it is listed for');
select is((select coalesce(string_agg(l.sig, ', ' order by l.sig), '') from listed l
            join pg_temp.readers() r on r.sig = l.sig where r.applies), '',
  'no listed function applies the rules: it leaves the list');
select is((select string_agg(r.sig, ', ' order by r.sig) from pg_temp.readers() r where r.applies),
  'admin_create_reservation_for(uuid,uuid,uuid,timestamp with time zone,timestamp with time zone,uuid), booking_event_visible(uuid,uuid), booking_place_hidden(uuid,uuid,uuid,uuid,uuid), calendar_items(uuid,timestamp with time zone,timestamp with time zone,text[],uuid), cancel_reservation(uuid), create_reservation(uuid,uuid,uuid,timestamp with time zone,timestamp with time zone,boolean,uuid,uuid), create_series(uuid,uuid,timestamp with time zone,timestamp with time zone,text,timestamp with time zone,uuid,uuid,uuid), desk_room_visible(uuid), kiosk_act(uuid,text,text,uuid,timestamp with time zone,timestamp with time zone,uuid), kpi_seat_capacity(uuid,timestamp with time zone,timestamp with time zone,uuid), level_visible(uuid), mcp_place_v1(uuid,members,jsonb), mcp_read_v1(uuid,members,text,jsonb), my_favorites(uuid), place_visible_to(uuid,uuid,uuid), reservation_place_visible(uuid,uuid,uuid,uuid,uuid,uuid,boolean), set_seat_block(uuid,timestamp with time zone,timestamp with time zone)',
  'the readers that apply the rules');

create function public.zz_fixture_place_reader(p_ws uuid) returns bigint language sql stable as
  $f$ select count(*) from "reservations" r where r.workspace_id = p_ws $f$;
alter function public.zz_fixture_place_reader(uuid) security definer;
create function public.zz_fixture_place_ruled(p_ws uuid) returns bigint language sql stable security definer as
  $f$ select count(*) from public.offices o where o.workspace_id = p_ws and public.room_visible(o.id) $f$;
select is((select string_agg(r.sig || ':' || r.tables || ':' || r.applies, ', ' order by r.sig) from pg_temp.readers() r
            where r.sig like 'zz_fixture_place_%'),
  'zz_fixture_place_reader(uuid):reservations:false, zz_fixture_place_ruled(uuid):offices:true',
  'a reader is found whatever its name''s form and however it became definer; the rules are seen in its source');
select is((select coalesce(string_agg(l.sig, ', ' order by l.sig), '') from listed l
            where l.reason like 'callable by the service role only%'
              and has_function_privilege('authenticated', l.sig::regprocedure, 'execute')), '',
  'every entry listed as callable by the service role only is not executable by a signed-in client');
select ok((select count(*) from listed) = 59, 'the list holds 59 reasoned exceptions');

select * from finish();
rollback;
