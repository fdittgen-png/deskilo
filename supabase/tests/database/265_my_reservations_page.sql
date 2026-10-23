-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2553 C1 (0561): a person's own reservations on one installation, through
-- my_reservations_page_v1. Two workspaces on one host: the caller sees their
-- own bookings of both and nobody else's, a workspace filter narrows and
-- never widens (a workspace the caller is no member of answers empty), an
-- anonymous or delegated caller is refused. The page size and the window
-- ceiling are the installation's platform settings read with NO workspace
-- (the null-workspace read), so one limit covers both workspaces; keyset
-- pages walk forward and backward without a duplicate or a gap, equal
-- starts ordered by id. A read without an end date covers the default
-- window; a longer window than the ceiling is refused whole; a registry
-- without the rows is a typed failure, not a hidden literal.
begin;
select plan(41);

create function pg_temp.act_as(p_user uuid, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'client_id', p_client))::text, true);
end;
$$;
create function pg_temp.nobody() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '', true);
end;
$$;
create function pg_temp.page(p_from text, p_to text, p_ws uuid default null, p_dir text default 'asc',
                             p_after_start text default null, p_after_id uuid default null) returns jsonb language sql as $$
  select public.my_reservations_page_v1(p_from::timestamptz, p_to::timestamptz, p_ws, p_dir, p_after_start::timestamptz, p_after_id);
$$;
create function pg_temp.sqlstate_of(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return '';
exception when others then
  return sqlstate;
end;
$$;
-- The ids of a page, in the order returned.
create function pg_temp.ids(p jsonb) returns text language sql as $$
  select coalesce(string_agg(right(e ->> 'id', 4), ',' order by n), '')
    from jsonb_array_elements(p -> 'items') with ordinality t(e, n);
$$;
create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00002553a' || lpad(n::text, 3, '0'))::uuid;
$$;
create function pg_temp.r(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00002553b' || lpad(n::text, 3, '0'))::uuid;
$$;

-- ── fixtures, by direct insert ───────────────────────────────────────────
-- u1: the caller, member of One and Two. u2: another member of One.
-- u3: the owner of Three, where the caller is nobody.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@my-reservations.test', '', now(), now(), now()
  from generate_series(1, 3) i;

insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, environment, booking_rules, feature_flags) values
 ('00000000-0000-4000-8000-00002553c001', 'One', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'dev', '{"simultaneous_reservations": 2}', '{}'),
 ('00000000-0000-4000-8000-00002553c002', 'Two', 'DE', 'EUR', 'Europe/Berlin', pg_temp.u(1), 'dev', '{}', '{}'),
 ('00000000-0000-4000-8000-00002553c003', 'Three', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(3), 'dev', '{}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
 ('00000000-0000-4000-8000-00002553d001', '00000000-0000-4000-8000-00002553c001', pg_temp.u(1), true, true, 'active'),
 ('00000000-0000-4000-8000-00002553d002', '00000000-0000-4000-8000-00002553c002', pg_temp.u(1), true, true, 'active'),
 ('00000000-0000-4000-8000-00002553d003', '00000000-0000-4000-8000-00002553c001', pg_temp.u(2), false, false, 'active'),
 ('00000000-0000-4000-8000-00002553d004', '00000000-0000-4000-8000-00002553c003', pg_temp.u(3), true, true, 'active');

-- One: a level, a room, a desk, two seats. Two: a level and a room booked
-- whole. Three: a seat for its owner. One allows two bookings at once, so
-- the two equal starts below are a valid fixture.
insert into public.levels (id, workspace_id, name) values
 ('00000000-0000-4000-8000-00002553e001', '00000000-0000-4000-8000-00002553c001', 'Ground floor'),
 ('00000000-0000-4000-8000-00002553e002', '00000000-0000-4000-8000-00002553c002', 'Erdgeschoss'),
 ('00000000-0000-4000-8000-00002553e003', '00000000-0000-4000-8000-00002553c003', 'Floor');
insert into public.offices (id, workspace_id, level_id, name, bookable_as_whole, x, y, w, h) values
 ('00000000-0000-4000-8000-00002553f001', '00000000-0000-4000-8000-00002553c001', '00000000-0000-4000-8000-00002553e001', 'Main room', false, 0, 0, 10, 10),
 ('00000000-0000-4000-8000-00002553f002', '00000000-0000-4000-8000-00002553c002', '00000000-0000-4000-8000-00002553e002', 'Besprechungsraum', true, 0, 0, 10, 10),
 ('00000000-0000-4000-8000-00002553f003', '00000000-0000-4000-8000-00002553c003', '00000000-0000-4000-8000-00002553e003', 'Room', false, 0, 0, 10, 10);
insert into public.desks (id, workspace_id, office_id, name, x, y, w, h) values
 ('00000000-0000-4000-8000-00002553f011', '00000000-0000-4000-8000-00002553c001', '00000000-0000-4000-8000-00002553f001', 'Window desk', 1, 1, 4, 2),
 ('00000000-0000-4000-8000-00002553f013', '00000000-0000-4000-8000-00002553c003', '00000000-0000-4000-8000-00002553f003', 'Desk', 1, 1, 4, 2);
insert into public.seats (id, workspace_id, desk_id, name, x, y) values
 ('00000000-0000-4000-8000-00002553f021', '00000000-0000-4000-8000-00002553c001', '00000000-0000-4000-8000-00002553f011', 'A1', 1, 1),
 ('00000000-0000-4000-8000-00002553f022', '00000000-0000-4000-8000-00002553c001', '00000000-0000-4000-8000-00002553f011', 'A2', 2, 1),
 ('00000000-0000-4000-8000-00002553f023', '00000000-0000-4000-8000-00002553c003', '00000000-0000-4000-8000-00002553f013', 'C1', 1, 1);

-- The caller's bookings, One (seat A1 unless said) and Two (the room):
--  b001 03-02 08:00   b010 03-02 14:00 cancelled   b002 03-03 08:00
--  b003 03-04 08:00 on A2 and b004 03-04 08:00 on A1: equal starts
--  b005 03-05 Two, b006 03-20 Two   b007 03-31 08:00   b008 04-02 08:00
--  b009 05-15 08:00 (inside a 90-day window, outside the default 31)
-- Another member's (b101, b102) and a stranger's (b201) stay invisible.
insert into public.reservations (id, workspace_id, seat_id, office_id, member_id, starts_at, ends_at, status) values
 (pg_temp.r(1), '00000000-0000-4000-8000-00002553c001', '00000000-0000-4000-8000-00002553f021', null, '00000000-0000-4000-8000-00002553d001', '2031-03-02T08:00Z', '2031-03-02T12:00Z', 'reserved'),
 (pg_temp.r(10), '00000000-0000-4000-8000-00002553c001', '00000000-0000-4000-8000-00002553f021', null, '00000000-0000-4000-8000-00002553d001', '2031-03-02T14:00Z', '2031-03-02T16:00Z', 'cancelled'),
 (pg_temp.r(2), '00000000-0000-4000-8000-00002553c001', '00000000-0000-4000-8000-00002553f021', null, '00000000-0000-4000-8000-00002553d001', '2031-03-03T08:00Z', '2031-03-03T12:00Z', 'reserved'),
 (pg_temp.r(4), '00000000-0000-4000-8000-00002553c001', '00000000-0000-4000-8000-00002553f021', null, '00000000-0000-4000-8000-00002553d001', '2031-03-04T08:00Z', '2031-03-04T12:00Z', 'reserved'),
 (pg_temp.r(3), '00000000-0000-4000-8000-00002553c001', '00000000-0000-4000-8000-00002553f022', null, '00000000-0000-4000-8000-00002553d001', '2031-03-04T08:00Z', '2031-03-04T12:00Z', 'reserved'),
 (pg_temp.r(5), '00000000-0000-4000-8000-00002553c002', null, '00000000-0000-4000-8000-00002553f002', '00000000-0000-4000-8000-00002553d002', '2031-03-05T09:00Z', '2031-03-05T17:00Z', 'reserved'),
 (pg_temp.r(6), '00000000-0000-4000-8000-00002553c002', null, '00000000-0000-4000-8000-00002553f002', '00000000-0000-4000-8000-00002553d002', '2031-03-20T09:00Z', '2031-03-20T17:00Z', 'reserved'),
 (pg_temp.r(7), '00000000-0000-4000-8000-00002553c001', '00000000-0000-4000-8000-00002553f021', null, '00000000-0000-4000-8000-00002553d001', '2031-03-31T08:00Z', '2031-03-31T12:00Z', 'reserved'),
 (pg_temp.r(8), '00000000-0000-4000-8000-00002553c001', '00000000-0000-4000-8000-00002553f021', null, '00000000-0000-4000-8000-00002553d001', '2031-04-02T08:00Z', '2031-04-02T12:00Z', 'reserved'),
 (pg_temp.r(9), '00000000-0000-4000-8000-00002553c001', '00000000-0000-4000-8000-00002553f021', null, '00000000-0000-4000-8000-00002553d001', '2031-05-15T08:00Z', '2031-05-15T12:00Z', 'reserved'),
 (pg_temp.r(101), '00000000-0000-4000-8000-00002553c001', '00000000-0000-4000-8000-00002553f022', null, '00000000-0000-4000-8000-00002553d003', '2031-03-02T08:00Z', '2031-03-02T12:00Z', 'reserved'),
 (pg_temp.r(102), '00000000-0000-4000-8000-00002553c001', '00000000-0000-4000-8000-00002553f022', null, '00000000-0000-4000-8000-00002553d003', '2031-03-06T08:00Z', '2031-03-06T12:00Z', 'reserved'),
 (pg_temp.r(201), '00000000-0000-4000-8000-00002553c003', '00000000-0000-4000-8000-00002553f023', null, '00000000-0000-4000-8000-00002553d004', '2031-03-02T08:00Z', '2031-03-02T12:00Z', 'reserved');

-- ── who may read ─────────────────────────────────────────────────────────
select pg_temp.nobody();
select is(pg_temp.sqlstate_of($$select pg_temp.page('2031-03-01T00:00Z', '2031-04-01T00:00Z')$$), '42501',
  'S1 nobody signed in: refused');
select pg_temp.act_as(pg_temp.u(1), 'claude-test');
select is(pg_temp.sqlstate_of($$select pg_temp.page('2031-03-01T00:00Z', '2031-04-01T00:00Z')$$), '42501',
  'S2 a delegated assistant token: refused, like an anonymous caller');
select ok(has_function_privilege('authenticated', 'public.my_reservations_page_v1(timestamptz, timestamptz, uuid, text, timestamptz, uuid)', 'execute'),
  'S3 authenticated callers may execute it');
select ok(not has_function_privilege('anon', 'public.my_reservations_page_v1(timestamptz, timestamptz, uuid, text, timestamptz, uuid)', 'execute'),
  'S4 anonymous callers may not');

-- ── the caller's own rows, across two workspaces ─────────────────────────
select pg_temp.act_as(pg_temp.u(1));
select set_config('t.all', pg_temp.page('2031-03-01T00:00Z', '2031-04-01T00:00Z')::text, true);
select is((current_setting('t.all')::jsonb ->> 'schema_version')::int, 1, 'S5 schema_version 1');
select is(pg_temp.ids(current_setting('t.all')::jsonb), 'b001,b010,b002,b003,b004,b005,b006,b007',
  'S6 own bookings of both workspaces, start then id, every status, nobody else''s');
select is((current_setting('t.all')::jsonb ->> 'has_more')::boolean, false, 'S7 one page: no more');
select is(jsonb_typeof(current_setting('t.all')::jsonb -> 'next'), 'null', 'S8 and no cursor');
select is(pg_temp.ids(pg_temp.page('2031-03-01T00:00Z', '2031-04-01T00:00Z', '00000000-0000-4000-8000-00002553c001')),
  'b001,b010,b002,b003,b004,b007', 'S9 the workspace filter narrows to One');
select is((select count(distinct e ->> 'workspace_id') from jsonb_array_elements(
  pg_temp.page('2031-03-01T00:00Z', '2031-04-01T00:00Z', '00000000-0000-4000-8000-00002553c001') -> 'items') e), 1::bigint,
  'S10 and every item is One''s');
select is(pg_temp.ids(pg_temp.page('2031-03-01T00:00Z', '2031-04-01T00:00Z', '00000000-0000-4000-8000-00002553c003')), '',
  'S11 a workspace the caller is no member of answers empty, never wider');
select pg_temp.act_as(pg_temp.u(2));
select is(pg_temp.ids(pg_temp.page('2031-03-01T00:00Z', '2031-04-01T00:00Z')), 'b101,b102',
  'S12 another member reads only their own');
select pg_temp.act_as(pg_temp.u(3));
select is(pg_temp.ids(pg_temp.page('2031-03-01T00:00Z', '2031-04-01T00:00Z')), 'b201',
  'S13 the owner of Three reads their own, not the caller''s');

-- ── the item ─────────────────────────────────────────────────────────────
select pg_temp.act_as(pg_temp.u(1));
select is((select e - 'starts_at' - 'ends_at' from jsonb_array_elements(current_setting('t.all')::jsonb -> 'items') e where e ->> 'id' = pg_temp.r(5)::text),
  jsonb_build_object('id', pg_temp.r(5), 'workspace_id', '00000000-0000-4000-8000-00002553c002', 'workspace_name', 'Two',
    'place_kind', 'office', 'place_id', '00000000-0000-4000-8000-00002553f002', 'place_label', 'Besprechungsraum',
    'status', 'reserved', 'checked_in_at', null, 'checked_out_at', null),
  'S14 a whole-room booking names its room, workspace and status, nothing else');
select is((select e ->> 'place_kind' || '/' || (e ->> 'place_label') || '/' || (e ->> 'status')
  from jsonb_array_elements(current_setting('t.all')::jsonb -> 'items') e where e ->> 'id' = pg_temp.r(10)::text),
  'seat/A1/cancelled', 'S15 a cancelled seat booking is listed as cancelled: no active-only filter');
select is((select (e ->> 'starts_at')::timestamptz from jsonb_array_elements(current_setting('t.all')::jsonb -> 'items') e where e ->> 'id' = pg_temp.r(1)::text),
  '2031-03-02T08:00Z'::timestamptz, 'S16 the start is the stored instant');
select is((select count(*) from jsonb_array_elements(current_setting('t.all')::jsonb -> 'items') e where e ? 'member_id' or e ? 'notes' or e ? 'price_cents'), 0::bigint,
  'S17 no member id, note or amount travels');

-- ── the null-workspace setting read, and keyset pages ────────────────────
select is(public.setting_value(null::uuid, 'personal.reservation_page_size') #>> '{}', '50',
  'S18 with no workspace the page size is the registry default');
insert into public.setting_values (scope, workspace_id, key, value, note) values ('platform', null, 'personal.reservation_page_size', '3'::jsonb, 'small pages');
select is(public.setting_value(null::uuid, 'personal.reservation_page_size') #>> '{}', '3',
  'S19 the platform row is read with no workspace');
select set_config('t.p1', pg_temp.page('2031-03-01T00:00Z', '2031-04-01T00:00Z')::text, true);
select is(pg_temp.ids(current_setting('t.p1')::jsonb), 'b001,b010,b002', 'S20 the first page is the platform page size, across both workspaces');
select is((current_setting('t.p1')::jsonb ->> 'has_more')::boolean, true, 'S21 and says there is more');
select is(current_setting('t.p1')::jsonb -> 'next' ->> 'after_id', pg_temp.r(2)::text, 'S22 the cursor is the last returned row');
select set_config('t.p2', pg_temp.page('2031-03-01T00:00Z', '2031-04-01T00:00Z', null, 'asc',
  current_setting('t.p1')::jsonb -> 'next' ->> 'after_start', (current_setting('t.p1')::jsonb -> 'next' ->> 'after_id')::uuid)::text, true);
select is(pg_temp.ids(current_setting('t.p2')::jsonb), 'b003,b004,b005', 'S23 the second page continues after the cursor, equal starts by id');
select set_config('t.p3', pg_temp.page('2031-03-01T00:00Z', '2031-04-01T00:00Z', null, 'asc',
  current_setting('t.p2')::jsonb -> 'next' ->> 'after_start', (current_setting('t.p2')::jsonb -> 'next' ->> 'after_id')::uuid)::text, true);
select is(pg_temp.ids(current_setting('t.p3')::jsonb), 'b006,b007', 'S24 the last page holds the rest: no duplicate, no gap');
select is((current_setting('t.p3')::jsonb ->> 'has_more')::boolean, false, 'S25 and says it is the last');
select is(jsonb_typeof(current_setting('t.p3')::jsonb -> 'next'), 'null', 'S26 with no cursor');
select set_config('t.d1', pg_temp.page('2031-03-01T00:00Z', '2031-04-01T00:00Z', null, 'desc')::text, true);
select is(pg_temp.ids(current_setting('t.d1')::jsonb), 'b007,b006,b005', 'S27 backward: the latest first');
select set_config('t.d2', pg_temp.page('2031-03-01T00:00Z', '2031-04-01T00:00Z', null, 'desc',
  current_setting('t.d1')::jsonb -> 'next' ->> 'after_start', (current_setting('t.d1')::jsonb -> 'next' ->> 'after_id')::uuid)::text, true);
select is(pg_temp.ids(current_setting('t.d2')::jsonb), 'b004,b003,b002', 'S28 backward continues before the cursor, equal starts by id descending');
select set_config('t.d3', pg_temp.page('2031-03-01T00:00Z', '2031-04-01T00:00Z', null, 'desc',
  current_setting('t.d2')::jsonb -> 'next' ->> 'after_start', (current_setting('t.d2')::jsonb -> 'next' ->> 'after_id')::uuid)::text, true);
select is(pg_temp.ids(current_setting('t.d3')::jsonb) || '/' || (current_setting('t.d3')::jsonb ->> 'has_more'), 'b010,b001/false',
  'S29 backward ends on the earliest');
select is(pg_temp.ids(pg_temp.page('2031-03-01T00:00Z', '2031-04-01T00:00Z', '00000000-0000-4000-8000-00002553c001', 'desc')), 'b007,b004,b003',
  'S30 a workspace filter still pages by the platform size');

-- ── validation ───────────────────────────────────────────────────────────
select is(pg_temp.sqlstate_of($$select pg_temp.page('2031-03-01T00:00Z', '2031-04-01T00:00Z', null, 'asc', '2031-03-03T08:00Z', null)$$), '22023',
  'S31 half a cursor is refused');
select is(pg_temp.sqlstate_of($$select pg_temp.page('2031-03-01T00:00Z', '2031-04-01T00:00Z', null, 'sideways')$$), '22023',
  'S32 a direction other than asc or desc is refused');
select is(pg_temp.sqlstate_of($$select pg_temp.page('2031-04-01T00:00Z', '2031-03-01T00:00Z')$$), '22023',
  'S33 a window ending before it starts is refused');
select is(pg_temp.sqlstate_of($$select pg_temp.page(null, '2031-03-01T00:00Z')$$), '22023',
  'S34 a window without a start is refused');

-- ── the default window and the ceiling ───────────────────────────────────
select is(pg_temp.ids(pg_temp.page('2031-03-01T00:00Z', null, '00000000-0000-4000-8000-00002553c001', 'desc')), 'b007,b004,b003',
  'S35 no end date: the default 31 days, which hold 03-31 and not 04-02');
insert into public.setting_values (scope, workspace_id, key, value, note) values ('platform', null, 'personal.reservation_window_days', '10'::jsonb, 'short default');
select is(pg_temp.ids(pg_temp.page('2031-03-01T00:00Z', null, '00000000-0000-4000-8000-00002553c001', 'desc')), 'b004,b003,b002',
  'S36 the platform default window is read with no workspace: 10 days end before 03-31');
select is(pg_temp.sqlstate_of($$select pg_temp.page('2031-03-01T00:00Z', '2032-04-10T00:00Z')$$), '22023',
  'S37 more than the 400-day ceiling is refused whole');
select is(pg_temp.sqlstate_of($$select pg_temp.page('2031-03-01T00:00Z', '2032-04-04T00:00Z')$$), '',
  'S38 exactly 400 days is allowed');
insert into public.setting_values (scope, workspace_id, key, value, note) values ('platform', null, 'personal.reservation_max_window_days', '60'::jsonb, 'short ceiling');
select is(pg_temp.sqlstate_of($$select pg_temp.page('2031-03-01T00:00Z', '2031-05-01T00:00Z')$$), '22023',
  'S39 the platform ceiling is read with no workspace: 61 days refused');
select is(pg_temp.ids(pg_temp.page('2031-03-01T00:00Z', '2031-04-29T00:00Z', '00000000-0000-4000-8000-00002553c001', 'desc')), 'b008,b007,b004',
  'S40 59 days pass and reach 04-02');

-- ── a registry without the rows is a typed failure ───────────────────────
delete from public.setting_values where key = 'personal.reservation_page_size';
delete from public.setting_definitions where key = 'personal.reservation_page_size';
select is(pg_temp.sqlstate_of($$select pg_temp.page('2031-03-01T00:00Z', '2031-04-01T00:00Z')$$), 'P0001',
  'S41 a missing page-size row fails the read, it does not fall back to a literal');

select * from finish();
rollback;
