-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3810 (0739, part of #3657): a booking refusal carries a DKK code and its
-- values, so the app maps codes, never sentences. Structure: every refusal a
-- person can meet in the booking functions carries its code, and the
-- thirty-four codes exist (DKK14 and DKK24 are not issued: see 0739). Behaviour: refusals raised for real answer their
-- code, one that names a value carries it as JSON in DETAIL, and the English
-- message an app from before reads is unchanged. Rolled back.
begin;
select plan(8);

-- The sqlstate, the detail and the message a statement is refused with.
create or replace function pg_temp.refusal(sql text) returns text language plpgsql as $f$
declare v_state text; v_detail text; v_message text;
begin
  execute sql;
  return 'no refusal';
exception when others then
  get stacked diagnostics v_state = returned_sqlstate, v_detail = pg_exception_detail,
                          v_message = message_text;
  return v_state || '|' || coalesce(v_detail, '') || '|' || v_message;
end
$f$;

-- The same, as the member (an authenticated session).
create or replace function pg_temp.member_refusal(sql text) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('t.u'), 'role', 'authenticated')::text, true);
  set local role authenticated;
  v := pg_temp.refusal(sql);
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare u uuid := '00000000-0000-4000-8000-000000003810'; o uuid := '00000000-0000-4000-8000-000000038100';
        ws uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  select x, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'refusal-' || x || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u, o]) x;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Refusals', 'FR', 'EUR', 'Europe/Paris', o) returning id into ws;
  -- Open every day, all day, so no refusal here depends on the hour or the
  -- weekday the pipeline runs on.
  update public.workspaces
     set booking_rules = coalesce(booking_rules, '{}'::jsonb)
       || '{"open_weekdays": [1, 2, 3, 4, 5, 6, 7], "work_start_minutes": 0, "work_end_minutes": 1440}'::jsonb
   where id = ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status)
  values (ws, o, true, true, 'active');
  perform set_config('t.u', u::text, false);
  perform set_config('t.ws', ws::text, false);
end;
$seed$;
select pg_temp.seed();
grant execute on all functions in schema pg_temp to authenticated, anon;

create temporary table booking_fns on commit drop as
  select p.proname, p.prosrc from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname in ('create_reservation', 'enforce_booking_rules', 'update_reservation', 'cancel_reservation',
                       'check_in_reservation', 'check_out_reservation', 'assert_member_quota',
                       'assert_workspace_open', 'assert_seat_not_blocked', 'enforce_reservation_limit',
                       'enforce_one_place', 'my_active_member', 'create_series', 'kiosk_act',
                       'admin_create_reservation_for', 'create_reservation_once');

create temporary table booking_raises on commit drop as
  select f.proname, m[1] as stmt from booking_fns f,
         regexp_matches(f.prosrc, '(raise exception ''(?:[^'']|'''')*''[^;]*;)', 'g') m;

select ok((select count(*) from booking_raises) > 60, 'the booking functions'' refusals are read');

select is((select string_agg(proname || ': ' || left(stmt, 80), E'\n') from booking_raises
            where stmt ~ '(workspace is closed|half-day quota|reservation limit|half-day|full day|minute grid|seat is blocked|horizon|minimum duration|maximum duration|in the past|start today|end on the day|working hours|opening hours|check-in window|already have a reservation|checked in elsewhere|reserve a level|bookable as a whole|level booking|already reserved|not checked in|in that period|as a whole|active member|member of this workspace|not your reservation|not cancellable|keeps its start|lie ahead|upcoming reservations|maximum of % days|assign level reservations|reserved state)'
              and stmt !~ 'errcode'), null,
  'every booking refusal a person can meet carries its code');

select is((select count(distinct c[1])::int from booking_fns f,
                  regexp_matches(f.prosrc, 'errcode = ''(DKK[0-9]{2})''', 'g') c), 34,
  'the thirty-four booking codes exist (DKK14 and DKK24 are not issued)');

select is(split_part(pg_temp.refusal(format(
            $$select public.enforce_booking_rules(%L, now() + interval '400 days', now() + interval '400 days 2 hours', false, null)$$,
            current_setting('t.ws'))), '|', 1), 'DKK08',
  'beyond the horizon is DKK08');
select is(nullif(split_part(pg_temp.refusal(format(
            $$select public.enforce_booking_rules(%L, now() + interval '400 days', now() + interval '400 days 2 hours', false, null)$$,
            current_setting('t.ws'))), '|', 2), '')::jsonb, '{"days": 90}'::jsonb,
  'and carries the horizon''s days');
select is(split_part(pg_temp.refusal(format(
            $$select public.enforce_booking_rules(%L, now() + interval '400 days', now() + interval '400 days 2 hours', false, null)$$,
            current_setting('t.ws'))), '|', 3), 'beyond the advance-booking horizon of 90 days',
  'its message is the one an app from before reads');

select is(split_part(pg_temp.refusal(format(
            $$select public.enforce_booking_rules(%L, now() + interval '1 day', now() + interval '1 day 10 minutes', false, null)$$,
            current_setting('t.ws'))), '|', 1) || ' ' ||
          split_part(pg_temp.refusal(format(
            $$select public.enforce_booking_rules(%L, now() + interval '1 day', now() + interval '1 day 10 minutes', false, null)$$,
            current_setting('t.ws'))), '|', 2),
  'DKK09 {"minutes" : 30}', 'below the minimum duration is DKK09, with its minutes');

select is(split_part(pg_temp.member_refusal(format($$select public.my_active_member(%L)$$, current_setting('t.ws'))), '|', 1),
  'DKK28', 'a person who is not a member is told so by code');

select * from finish();
rollback;
