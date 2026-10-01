#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #1232 — two sessions, one seat.
#
# Every file in supabase/tests/database runs in ONE transaction, and one
# transaction cannot observe a race. "Two members book the same seat,
# exactly one succeeds" is a statement about two CONNECTIONS.
#
# This was first attempted inside pgTAP with `dblink`, and it cannot be
# done there. `dblink_connect` refuses any connection the server did not
# actually authenticate with a password — the local stack trusts
# 127.0.0.1, so the password is ignored and the check fails — and
# `dblink_connect_u`, which lifts that rule, is superuser-only. The role
# `supabase test db` runs as is not a superuser: Supabase's `postgres`
# has `rolsuper = false`. Two real psql processes have neither problem.
#
# The shape proves SERIALIZATION rather than sequence:
#
#   A: begin; insert the booking; sleep; commit   -- holds it open
#   B: set lock_timeout; insert the same          -- must BLOCK, times out
#   A: commits
#   B: insert the same again                      -- refused outright
#
# The lock timeout is the assertion. If B had failed instantly with a
# conflict while A was uncommitted, the two would not be serialized at
# all — Postgres cannot see A's uncommitted row, so the only thing that
# can stop B is the lock. And if B had SUCCEEDED, the exclusion
# constraint would not be doing its job.
set -uo pipefail

DB_URL=${1:?usage: concurrency_check.sh <db url>}
WS=00000000-0000-4000-8000-00000000c001
MEMBER=00000000-0000-4000-8000-00000000c002
# The rival is a DIFFERENT member, and that is the whole point. With one
# member both attempts are refused by `enforce_one_place` — "at most 1 at
# a time" — which is a real guard and is not this one. Two members put
# the exclusion constraint on the seat in the way, which is the invariant
# under test.
RIVAL=00000000-0000-4000-8000-00000000c008
SEAT=00000000-0000-4000-8000-00000000c003

say() { printf '  %s\n' "$*"; }
fail() { cleanup 2>/dev/null || true; echo "::error::$*"; exit 1; }

psql_q() { psql "$DB_URL" -qtAX -v ON_ERROR_STOP=1 -c "$1"; }

echo "two sessions, one seat"

# `w`, `r`, `l`, `o` and `s` are not hex digits, and a uuid literal that
# contains one is refused at parse time — which is how the first run of
# this script spent a CI cycle. The ids below are valid hex and still
# readable: c001 is the workspace, c002 the member, c003 the seat.
fixture=$(psql "$DB_URL" -qX -v ON_ERROR_STOP=1 2>&1 <<SQL

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values ('00000000-0000-4000-8000-00000000c004',
        '00000000-0000-0000-0000-000000000000', 'authenticated',
        'authenticated', 'race@deskilo.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone,
                               created_by)
values ('$WS', 'Race', 'FR', 'EUR', 'Europe/Paris',
        '00000000-0000-4000-8000-00000000c004');
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values ('00000000-0000-4000-8000-00000000c009',
        '00000000-0000-0000-0000-000000000000', 'authenticated',
        'authenticated', 'rival@deskilo.test', '', now(), now(), now());
insert into public.members (id, workspace_id, user_id, is_owner, is_admin)
values ('$MEMBER', '$WS', '00000000-0000-4000-8000-00000000c004', true, true),
       ('$RIVAL', '$WS', '00000000-0000-4000-8000-00000000c009', false, false);
insert into public.levels (id, workspace_id, name)
values ('00000000-0000-4000-8000-00000000c005', '$WS', 'Ground');
insert into public.offices (id, workspace_id, level_id, name, x, y, w, h)
values ('00000000-0000-4000-8000-00000000c006', '$WS',
        '00000000-0000-4000-8000-00000000c005', 'Room', 0, 0, 10, 10);
insert into public.desks (id, workspace_id, office_id, x, y, w, h)
values ('00000000-0000-4000-8000-00000000c007', '$WS',
        '00000000-0000-4000-8000-00000000c006', 1, 1, 4, 2);
insert into public.seats (id, workspace_id, desk_id, x, y)
values ('$SEAT', '$WS', '00000000-0000-4000-8000-00000000c007', 1, 1);
SQL
) || fail "the fixture would not build. psql said: $fixture"

booking_for() {
  printf "insert into public.reservations
    (workspace_id, member_id, seat_id, starts_at, ends_at)
   values ('%s', '%s', '%s',
           date_trunc('day', now()) + interval '1 day 9 hours',
           date_trunc('day', now()) + interval '1 day 13 hours')" \
    "$WS" "$1" "$SEAT"
}
MINE=$(booking_for "$MEMBER")
THEIRS=$(booking_for "$RIVAL")

# A takes the seat and holds it for three seconds.
psql "$DB_URL" -qX -v ON_ERROR_STOP=1 \
  -c "begin; $MINE; select pg_sleep(3); commit;" >/dev/null 2>&1 &
holder=$!
sleep 1

# B, while A is undecided. `-q` keeps stdout clean; the SQLSTATE comes
# back on stderr, which is what we read.
blocked=$(psql "$DB_URL" -qX -c "set lock_timeout = '800ms'; $THEIRS" 2>&1 || true)
case "$blocked" in
  *"canceling statement due to lock timeout"*|*55P03*)
    say "while the first booking is uncommitted the rival BLOCKS and times out" ;;
  *)
    wait "$holder" || true
    fail "the rival was not blocked by an uncommitted booking. It said: $blocked
       Postgres cannot see the first session's uncommitted row, so the only
       thing that can stop the second is the lock. Nothing stopped it, which
       means the two are not serialized and two members can take one seat." ;;
esac

wait "$holder" || fail "the holding session did not commit"

after=$(psql "$DB_URL" -qX -c "$THEIRS" 2>&1 || true)
case "$after" in
  *"conflicting key value violates exclusion constraint"*|*23P01*)
    say "and once the first is committed the rival is refused outright" ;;
  *)
    fail "the rival booked the same seat and the same hours a second time.
       It said: ${after:-(nothing — it SUCCEEDED)}
       This is the app's central invariant: one seat, one booking." ;;
esac

# #1908 — cancel vs check-in on ONE reservation. A cancels and holds its
# transaction open; B checks in meanwhile. Without the row lock on the
# transitions' initial read, B read the committed `reserved`, waited only
# at its UPDATE and wrote `checked_in` over the cancellation. With it, B
# waits for A, then sees `cancelled` and is refused.
RES=00000000-0000-4000-8000-00000000c00a
psql_q "insert into public.reservations (id, workspace_id, member_id, seat_id, starts_at, ends_at)
        values ('$RES', '$WS', '$MEMBER', '$SEAT', now() - interval '10 minutes', now() + interval '2 hours')" \
  >/dev/null || fail "the #1908 fixture reservation would not build"
ACT="select set_config('request.jwt.claims', '{\"sub\":\"00000000-0000-4000-8000-00000000c004\",\"role\":\"authenticated\"}', true); set local role authenticated;"
psql "$DB_URL" -qX -v ON_ERROR_STOP=1 \
  -c "begin; $ACT select public.cancel_reservation('$RES'); select pg_sleep(3); commit;" >/dev/null 2>&1 &
canceller=$!
sleep 1
checkin=$(psql "$DB_URL" -qX -c "begin; $ACT select public.check_in_reservation('$RES'); commit;" 2>&1 || true)
wait "$canceller" || fail "the cancelling session did not commit"
final=$(psql_q "select status from public.reservations where id = '$RES'")
if [ "$final" = "cancelled" ]; then
  say "cancel vs check-in: the reservation stays cancelled (check-in said: $(echo "$checkin" | grep -o 'ERROR:.*' | head -1))"
else
  fail "a check-in overwrote a concurrent cancellation: the reservation is '$final'.
       The transition read its state without the row lock (#1908)."
fi

# #1908 B — a seat and its whole office, two connections. A books the
# seat and holds; B books the whole office for overlapping hours. Without
# the hierarchy guard both pass their checks; with it B waits for A's
# lock, then sees the seat and is refused.
SPAN="date_trunc('day', now()) + interval '2 days 9 hours', date_trunc('day', now()) + interval '2 days 12 hours'"
psql "$DB_URL" -qX -v ON_ERROR_STOP=1 \
  -c "begin; insert into public.reservations (workspace_id, member_id, seat_id, starts_at, ends_at) values ('$WS', '$MEMBER', '$SEAT', $SPAN); select pg_sleep(3); commit;" >/dev/null 2>&1 &
seat_holder=$!
sleep 1
whole=$(psql "$DB_URL" -qX -c "insert into public.reservations (workspace_id, member_id, office_id, starts_at, ends_at) values ('$WS', '$RIVAL', '00000000-0000-4000-8000-00000000c006', $SPAN)" 2>&1 || true)
wait "$seat_holder" || fail "the seat session did not commit"
both=$(psql_q "select count(*) from public.reservations where workspace_id = '$WS' and starts_at = date_trunc('day', now()) + interval '2 days 9 hours'")
if [ "$both" = "1" ]; then
  say "seat vs whole office: one booking, the whole office refused ($(echo "$whole" | grep -o 'ERROR:.*' | head -1))"
else
  fail "a seat and its whole office were both booked for the same hours ($both rows). #1908"
fi

# #1908 — one member, two seats, the same hours, two connections: the
# member lock makes the one-place rule see the first booking.
SEAT2=00000000-0000-4000-8000-00000000c00b
psql_q "insert into public.seats (id, workspace_id, desk_id, x, y) values ('$SEAT2', '$WS', '00000000-0000-4000-8000-00000000c007', 2, 1)" >/dev/null \
  || fail "the second seat would not build"
SPAN3="date_trunc('day', now()) + interval '3 days 9 hours', date_trunc('day', now()) + interval '3 days 12 hours'"
psql "$DB_URL" -qX -v ON_ERROR_STOP=1 \
  -c "begin; insert into public.reservations (workspace_id, member_id, seat_id, starts_at, ends_at) values ('$WS', '$RIVAL', '$SEAT', $SPAN3); select pg_sleep(3); commit;" >/dev/null 2>&1 &
first=$!
sleep 1
second=$(psql "$DB_URL" -qX -c "insert into public.reservations (workspace_id, member_id, seat_id, starts_at, ends_at) values ('$WS', '$RIVAL', '$SEAT2', $SPAN3)" 2>&1 || true)
wait "$first" || fail "the first booking did not commit"
mine=$(psql_q "select count(*) from public.reservations where member_id = '$RIVAL' and starts_at = date_trunc('day', now()) + interval '3 days 9 hours'")
if [ "$mine" = "1" ]; then
  say "one member, two seats at once: one booking ($(echo "$second" | grep -o 'ERROR:.*' | head -1))"
else
  fail "one member holds $mine places for the same hours — the one-place rule raced. #1908"
fi

# Tidy up, so a second run on the same database fails on the property
# rather than on a primary key.
#
# In dependency order and quietly. `protect_last_owner` refuses to let a
# workspace lose its last owner, and `workspaces_created_by_fkey` holds
# the user the workspace was created by — so deleting the workspace
# before its reservations, or the user before the workspace, prints an
# alarming wall of red on a run that passed. Both of those triggers are
# doing their job; the cleanup simply has to go in the right order and
# say nothing when it does.
cleanup() {
  psql "$DB_URL" -qtAX >/dev/null 2>&1 <<SQL
delete from public.reservations where workspace_id = '$WS';
delete from public.seats where workspace_id = '$WS';
delete from public.desks where workspace_id = '$WS';
delete from public.offices where workspace_id = '$WS';
delete from public.levels where workspace_id = '$WS';
delete from public.events where workspace_id = '$WS';
delete from public.workspaces where id = '$WS';
delete from auth.users where id in
  ('00000000-0000-4000-8000-00000000c004',
   '00000000-0000-4000-8000-00000000c009');
SQL
}
cleanup

echo "two sessions, one seat: exactly one winner"
