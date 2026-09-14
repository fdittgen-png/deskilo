-- SPDX-License-Identifier: 0BSD
--
-- #1232 — two sessions, one seat.
--
-- Every other test in this directory runs in one transaction, and one
-- transaction cannot observe a race. "Two members book the same seat,
-- exactly one succeeds" is a statement about two CONNECTIONS, and until
-- now nothing in this repository could make it: the Dart suite has fakes,
-- and pgTAP is single-session.
--
-- `dblink` gives us the second and third connections. The shape is the
-- one that actually proves serialization rather than sequence:
--
--   A: begin; insert the booking;        -- holds, uncommitted
--   B: set lock_timeout; insert the same -- must BLOCK, so it times out
--   A: commit;
--   B: insert the same again             -- must now be refused outright
--
-- The lock timeout is the assertion. If B failed instantly with a
-- conflict while A was uncommitted, the two would not be serialized at
-- all — Postgres would have had to see A's uncommitted row, which it
-- cannot. And if B SUCCEEDED while A held the row, the exclusion
-- constraint would not be doing its job.
--
-- The fixture is committed on connection A rather than seeded in this
-- transaction, because a second connection cannot see uncommitted rows
-- — which is the whole reason this file needs a different shape from its
-- neighbours. CI builds the database from empty for every run, so the
-- rows it leaves behind belong to nobody.
begin;

-- dblink is not in the Supabase image by default and is not worth a
-- migration: it exists for this file and nothing else.
create extension if not exists dblink with schema extensions;

select plan(4);

-- One connection for the writer, one for the rival.
--
-- `dblink_connect_u` and not `dblink_connect`: the plain one refuses a
-- password-less connection ("password or GSSAPI delegated credentials
-- required") however local it is, because it is available to
-- non-superusers and that rule is what keeps it safe for them. The `_u`
-- form is superuser-only and lifts exactly that restriction, which is
-- the right trade in a throwaway test database that CI builds from
-- empty for every run.
create or replace function pg_temp.conninfo() returns text language sql
stable as $$
  select format('dbname=%s port=%s host=/var/run/postgresql',
                current_database(), inet_server_port());
$$;

select ok(
  extensions.dblink_connect_u('booker', pg_temp.conninfo()) = 'OK',
  'a second session can be opened');
select ok(
  extensions.dblink_connect_u('rival', pg_temp.conninfo()) = 'OK',
  'and a third, so the two can race');

-- ------------------------------------------------------------ fixture
do $fixture$
declare seat_id uuid;
begin
  perform extensions.dblink_exec('booker', $sql$
    insert into auth.users (id, instance_id, aud, role, email,
                            encrypted_password, email_confirmed_at,
                            created_at, updated_at)
    values ('00000000-0000-4000-8000-0000000000r1',
            '00000000-0000-0000-0000-000000000000', 'authenticated',
            'authenticated', 'race@deskilo.test', '', now(), now(), now());
    insert into public.workspaces (id, name, country_code, currency_code,
                                   timezone, created_by)
    values ('00000000-0000-4000-8000-0000000000w1', 'Race', 'FR', 'EUR',
            'Europe/Paris', '00000000-0000-4000-8000-0000000000r1');
    insert into public.members (id, workspace_id, user_id, is_owner, is_admin)
    values ('00000000-0000-4000-8000-0000000000m1',
            '00000000-0000-4000-8000-0000000000w1',
            '00000000-0000-4000-8000-0000000000r1', true, true);
    insert into public.levels (id, workspace_id, name)
    values ('00000000-0000-4000-8000-0000000000l1',
            '00000000-0000-4000-8000-0000000000w1', 'Ground');
    insert into public.offices (id, workspace_id, level_id, name, x, y, w, h)
    values ('00000000-0000-4000-8000-0000000000o1',
            '00000000-0000-4000-8000-0000000000w1',
            '00000000-0000-4000-8000-0000000000l1', 'Room', 0, 0, 10, 10);
    insert into public.desks (id, workspace_id, office_id, x, y, w, h)
    values ('00000000-0000-4000-8000-0000000000d1',
            '00000000-0000-4000-8000-0000000000w1',
            '00000000-0000-4000-8000-0000000000o1', 1, 1, 4, 2);
    insert into public.seats (id, workspace_id, desk_id, x, y)
    values ('00000000-0000-4000-8000-0000000000s1',
            '00000000-0000-4000-8000-0000000000w1',
            '00000000-0000-4000-8000-0000000000d1', 1, 1);
  $sql$);
  seat_id := '00000000-0000-4000-8000-0000000000s1';
end;
$fixture$;

-- ------------------------------------------------------------- the race
create or replace function pg_temp.booking_sql() returns text
language sql immutable as $$
  select $sql$
    insert into public.reservations
      (workspace_id, member_id, seat_id, starts_at, ends_at)
    values ('00000000-0000-4000-8000-0000000000w1',
            '00000000-0000-4000-8000-0000000000m1',
            '00000000-0000-4000-8000-0000000000s1',
            date_trunc('day', now()) + interval '1 day 9 hours',
            date_trunc('day', now()) + interval '1 day 13 hours')
  $sql$;
$$;

-- The rival's attempt, and whatever it failed with.
create or replace function pg_temp.rival_tries() returns text
language plpgsql as $try$
begin
  perform extensions.dblink_exec('rival', pg_temp.booking_sql());
  return 'SUCCEEDED';
exception when others then
  return sqlstate;
end;
$try$;

do $race$
begin
  -- A takes the seat and holds it.
  perform extensions.dblink_exec('booker', 'begin');
  perform extensions.dblink_exec('booker', pg_temp.booking_sql());

  -- B must not be able to decide anything while A is undecided.
  perform extensions.dblink_exec('rival', 'set lock_timeout = ''400ms''');
  perform set_config('deskilo.race.while_held', pg_temp.rival_tries(), false);

  perform extensions.dblink_exec('booker', 'commit');
  perform set_config('deskilo.race.after_commit', pg_temp.rival_tries(), false);
end;
$race$;

select is(
  current_setting('deskilo.race.while_held'),
  '55P03',
  'while the first booking is uncommitted the rival BLOCKS and times out '
  '— it cannot see the row, so the only thing that can stop it is the '
  'lock, which is exactly what serializes them');

select is(
  current_setting('deskilo.race.after_commit'),
  '23P01',
  'and once the first is committed the rival is refused outright: two '
  'sessions, one seat, exactly one winner');

-- Leave the connections tidy even though the database is thrown away.
do $close$
begin
  perform extensions.dblink_disconnect('booker');
  perform extensions.dblink_disconnect('rival');
end;
$close$;

select * from finish();
rollback;
