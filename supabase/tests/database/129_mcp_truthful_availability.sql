-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- 0345 — an assistant's "free" is the booking engine's own verdict.
-- mcp_seat_bookable tries the booking as the member and always rolls it
-- back: a free seat answers null and leaves no row behind; a seat another
-- member holds answers the engine's refusal; get_availability asks it.
begin;
select plan(4);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u uuid := '00000000-0000-4000-8000-000000000b41';
  v uuid := '00000000-0000-4000-8000-000000000b42';
  ws uuid; m uuid; rv uuid; lvl uuid; office uuid; desk uuid; seat uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'avail-341@deskilo.test', '', now(), now(), now()),
         (v, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'avail-rival-341@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Availability', 'FR', 'EUR', 'Europe/Paris', u) returning id into ws;
  update public.workspaces
     set booking_rules = coalesce(booking_rules, '{}'::jsonb)
       || '{"open_weekdays": [1, 2, 3, 4, 5, 6, 7]}'::jsonb
   where id = ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u, true, true) returning id into m;
  insert into public.members (workspace_id, user_id) values (ws, v) returning id into rv;
  insert into public.levels (workspace_id, name) values (ws, 'Ground') returning id into lvl;
  insert into public.offices (workspace_id, level_id, name, x, y, w, h)
  values (ws, lvl, 'Room', 0, 0, 10, 10) returning id into office;
  insert into public.desks (workspace_id, office_id, x, y, w, h)
  values (ws, office, 1, 1, 4, 2) returning id into desk;
  insert into public.seats (workspace_id, desk_id, x, y) values (ws, desk, 1, 1) returning id into seat;
  perform set_config('deskilo.av.ws', ws::text, false);
  perform set_config('deskilo.av.seat', seat::text, false);
  perform set_config('deskilo.av.rival', rv::text, false);
  perform set_config('deskilo.av.from', (date_trunc('day', now()) + interval '1 day 9 hours')::text, false);
  perform set_config('request.jwt.claims',
    json_build_object('sub', u::text, 'role', 'authenticated')::text, false);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.bookable() returns text language sql as $$
  select public.mcp_seat_bookable(current_setting('deskilo.av.ws')::uuid,
    current_setting('deskilo.av.seat')::uuid,
    current_setting('deskilo.av.from')::timestamptz,
    current_setting('deskilo.av.from')::timestamptz + interval '4 hours');
$$;

select is(pg_temp.bookable(), null, 'a free seat is bookable for the member');
select is((select count(*)::int from public.reservations
            where workspace_id = current_setting('deskilo.av.ws')::uuid), 0,
  'and the probe leaves no reservation behind');

insert into public.reservations (workspace_id, member_id, seat_id, starts_at, ends_at)
values (current_setting('deskilo.av.ws')::uuid, current_setting('deskilo.av.rival')::uuid,
        current_setting('deskilo.av.seat')::uuid,
        current_setting('deskilo.av.from')::timestamptz,
        current_setting('deskilo.av.from')::timestamptz + interval '4 hours');
select isnt(pg_temp.bookable(), null, 'a seat another member holds answers the engine''s refusal');

select ok(position('mcp_seat_bookable' in pg_get_functiondef('public.mcp_read_v1(uuid, public.members, text, jsonb)'::regprocedure)) > 0,
  'get_availability asks the engine');

select * from finish();
rollback;
