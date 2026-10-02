#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #1789 — the MCP races: the part of #1620 #1622 #1623 #1624 that needs
# two CONNECTIONS, which no pgTAP file can open (see concurrency_check.sh
# for why dblink is not an option on the local stack).
#
# Every case has the same shape:
#
#   A: begin; act as a user; <call>; signal; pg_sleep(HOLD); commit
#   B:        (after the signal) begin; act as a user; <call>; commit
#   C: a third psql counts the rows once both are done
#
# While A holds its transaction open, a third connection watches B in
# pg_stat_activity and must see it WAIT ON A LOCK. That is what proves the
# two calls overlapped: a guard that is a lock or a unique key makes the
# second session wait for the first, and a race that never waited was not
# a race. Then the counts:
#
#   1a  create_reservation_once (what MCP create_reservation binds), the
#       same request id from two sessions: one reservation, and B answers
#       A's reservation id instead of an error.
#       guard: reservation_requests primary key (0214).
#   1b  the same seat and hours under two different request ids, two
#       members: one booking and one refusal — the seat's exclusion
#       constraint.
#   2   request_invoice_void through mcp_execute_v1, one request id, two
#       sessions: one validation event, both answers name it.
#       guard: the request-id advisory lock in mcp_execute_v1 (0271).
#   3   request_subscription_change, the same: one pending event, both
#       answers name it, and the member's share is unchanged.
#   4   one person approves one event natively (A) and through MCP
#       respond_to_validation (B): one row in event_decisions, the event
#       still pending under its quorum of two.
#       guard: event_decisions_one_per_member (0017).
#
# The MCP intents that need their human are asked and confirmed in the
# fixture (scripts/db_race/fixture.sql), before the race.
#
# Red-first: `--drop-guards` removes the 1a and 4 guards before racing,
# and the run must then FAIL on their counts. It is how the proof was
# made on this PR, and how it can be repeated; it breaks the database it
# runs on, so it is for a disposable stack only and the job never uses it.
#
# The rows stay, named by run: every id carries this process's pid, so a
# second run builds a second fixture beside the first.
set -uo pipefail

DROP_GUARDS=0
if [ "${1:-}" = "--drop-guards" ]; then DROP_GUARDS=1; shift; fi
DB_URL=${1:?usage: db_race_check.sh [--drop-guards] <db url>}
HERE=$(cd "$(dirname "$0")" && pwd)
RUN="$$"
HOLD=4 # seconds A keeps its transaction open after its call
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
FAILED=0
export PGCONNECT_TIMEOUT=10
# Hard bounds: the server cancels a stuck statement, and `timeout` (where
# it exists) kills a stuck client.
LIMIT=()
command -v timeout >/dev/null 2>&1 && LIMIT=(timeout 60)

say() { printf '  %s\n' "$*"; }
bad() { echo "::error::db race: $*"; FAILED=$((FAILED + 1)); }
die() { echo "::error::db race: $*"; exit 1; }
q() {
  PGOPTIONS='-c statement_timeout=20s' ${LIMIT[@]+"${LIMIT[@]}"} \
    psql "$DB_URL" -qtAX -v ON_ERROR_STOP=1 -c "$1"
}
# Decimal digits are hex digits: the pid makes a valid, per-run uuid.
uid() { printf '00000000-0000-4000-8000-%08d%04d' "$RUN" "$1"; }

O=$(uid 1) B=$(uid 2) C=$(uid 3) D=$(uid 4) R=$(uid 5)
RQ1=$(uid 11) RQ2=$(uid 12) RQ3=$(uid 13) RQ4=$(uid 14) RQ1B_A=$(uid 15) RQ1B_B=$(uid 16)

echo "two sessions, one MCP intent (run $RUN)"

fixture=$(PGOPTIONS='-c statement_timeout=60s' ${LIMIT[@]+"${LIMIT[@]}"} \
  psql "$DB_URL" -qtAX -v ON_ERROR_STOP=1 \
  -v run="$RUN" -v o="$O" -v b="$B" -v c="$C" -v d="$D" -v r="$R" \
  -v rq2="$RQ2" -v rq3="$RQ3" -v rq4="$RQ4" \
  -f "$HERE/db_race/fixture.sql" 2>&1) || die "the fixture would not build. psql said: $fixture"
val() { printf '%s\n' "$fixture" | sed -n "s/^$1=//p" | head -1; }
I=$(val I) WS=$(val WS) SEAT=$(val SEAT) INV=$(val INV) EV=$(val EV)
M_B=$(val M_B) M_D=$(val M_D) M_R=$(val M_R)
AM_S=$(val AM_S) AM_E=$(val AM_E) PM_S=$(val PM_S) PM_E=$(val PM_E)
for v in I WS SEAT INV EV M_B M_D M_R AM_S AM_E PM_S PM_E; do
  [ -n "${!v}" ] || die "the fixture did not report $v. psql said: $fixture"
done
say "fixture: workspace $WS, seat $SEAT, invoice $INV, event $EV"

if [ "$DROP_GUARDS" = 1 ]; then
  q "alter table public.reservation_requests drop constraint reservation_requests_pkey;
     drop index public.event_decisions_one_per_member;" >/dev/null \
    || die "could not drop the guards"
  echo "::warning::db race: RED-FIRST RUN — reservation_requests_pkey and event_decisions_one_per_member dropped; cases 1a and 4 must fail"
fi

# The claims a session acts under, inside its transaction.
claims() { # claims <user> [client]
  local client=""
  [ -n "${2:-}" ] && client=",\"client_id\":\"$2\""
  printf "set local role authenticated;\nselect set_config('request.jwt.claims', '{\"sub\":\"%s\",\"role\":\"authenticated\",\"aal\":\"aal2\",\"amr\":[{\"method\":\"oauth\"}]%s}', true) is null;\n" \
    "$1" "$client"
}

# race <case> <sql for A> <sql for B> — sets A_RC, B_RC and WAITED;
# the sessions' output lands in $TMP/<case>.a and $TMP/<case>.b.
race() {
  local name=$1 sig="$TMP/$1.sig" app="race-b-$RUN-$1" holder rival i
  PGOPTIONS='-c statement_timeout=30s' ${LIMIT[@]+"${LIMIT[@]}"} \
    psql "$DB_URL" -qtAX -v ON_ERROR_STOP=1 >"$TMP/$name.a" 2>&1 <<SQL &
begin;
$2
\! touch $sig
select pg_sleep($HOLD);
commit;
SQL
  holder=$!
  # B starts only once A has made its call and is holding it open.
  i=0
  while [ ! -e "$sig" ] && kill -0 "$holder" 2>/dev/null && [ "$i" -lt 150 ]; do
    sleep 0.1; i=$((i + 1))
  done
  if [ ! -e "$sig" ]; then
    kill "$holder" 2>/dev/null
    wait "$holder"; A_RC=$?; B_RC=-1; WAITED=0
    bad "$name: session A never made its call: $(cat "$TMP/$name.a")"
    return 1
  fi
  PGAPPNAME="$app" PGOPTIONS='-c statement_timeout=30s -c lock_timeout=20s' ${LIMIT[@]+"${LIMIT[@]}"} \
    psql "$DB_URL" -qtAX -v ON_ERROR_STOP=1 >"$TMP/$name.b" 2>&1 <<SQL &
begin;
$3
commit;
SQL
  rival=$!
  # Watch B from a third connection while A is still open.
  WAITED=0; i=0
  while kill -0 "$rival" 2>/dev/null && [ "$i" -lt $((HOLD * 10)) ]; do
    if [ "$(q "select count(*) from pg_stat_activity
                where application_name = '$app' and wait_event_type = 'Lock'")" != 0 ]; then
      WAITED=1; break
    fi
    sleep 0.1; i=$((i + 1))
  done
  wait "$rival"; B_RC=$?
  wait "$holder"; A_RC=$?
  [ "$A_RC" = 0 ] || bad "$name: session A failed: $(cat "$TMP/$name.a")"
}
expect() { # expect <got> <want> <said when equal> <error otherwise>
  if [ "$1" = "$2" ]; then say "$3"; else bad "$4"; fi
}
answer() { sed -n 's/^ANSWER=//p' "$TMP/$1.$2" | head -1; }
waited() {
  if [ "$WAITED" = 1 ]; then say "$1: B waited on a lock while A held its transaction open"
  else bad "$1: B never waited on a lock while A was open — the two calls were not serialized. B said: $(cat "$TMP/$1.b")"; fi
}
live() { # live <where> — reservations of this run's workspace, still holding their seat
  q "select count(*) from public.reservations where workspace_id = '$WS' and seat_id = '$SEAT'
       and status in ('reserved', 'checked_in') and $1"
}
mcp() { # mcp <operation> <arguments json> <request id>
  printf "select 'ANSWER=' || coalesce(v->>'status', '?') || '|' || coalesce(v->'data'->>'event_id', '') || '|' || v::text
  from (select public.mcp_execute_v1('%s', '%s', '%s', '%s'::jsonb, '%s') v) s;" "$I" "$WS" "$1" "$2" "$3"
}

# ── 1a: identical booking intents ──────────────────────────────────────
echo "1a. the same booking intent from two sessions"
BOOK="$(claims "$D")
select 'ANSWER=' || public.create_reservation_once('$RQ1', '$WS', '$SEAT', null, null, null, '$AM_S', '$AM_E', false);"
race 1a "$BOOK" "$BOOK"
a=$(answer 1a a) b=$(answer 1a b)
waited 1a
if [ -n "$a" ] && [ "$a" = "$b" ]; then say "1a: both sessions answer reservation $a"
else bad "1a: A answered '${a:-nothing}', B answered '${b:-an error}' — an identical intent must answer the first booking. B said: $(cat "$TMP/1a.b")"; fi
n=$(live "starts_at = '$AM_S'")
expect "$n" 1 "1a: one reservation" "1a: $n reservations for one intent"
n=$(q "select count(*) from public.reservation_requests where workspace_id = '$WS' and client_request_id = '$RQ1'")
expect "$n" 1 "1a: one claim for the request id" "1a: $n claims for one request id"

# ── 1b: two intents, one seat ──────────────────────────────────────────
echo "1b. two different intents for the same seat and hours"
race 1b "$(claims "$R")
select 'ANSWER=' || public.create_reservation_once('$RQ1B_A', '$WS', '$SEAT', null, null, null, '$PM_S', '$PM_E', false);" \
  "$(claims "$C")
select 'ANSWER=' || public.create_reservation_once('$RQ1B_B', '$WS', '$SEAT', null, null, null, '$PM_S', '$PM_E', false);"
waited 1b
[ -n "$(answer 1b a)" ] || bad "1b: the first intent did not book: $(cat "$TMP/1b.a")"
if [ "$B_RC" != 0 ] && [ -z "$(answer 1b b)" ]; then say "1b: the rival is refused: $(grep -m1 ERROR "$TMP/1b.b")"
else bad "1b: the rival was not refused. It said: $(cat "$TMP/1b.b")"; fi
n=$(live "starts_at = '$PM_S'")
expect "$n" 1 "1b: one booking" "1b: $n bookings of one seat for the same hours"

# ── 2: identical void requests ─────────────────────────────────────────
echo "2. the same invoice void from two sessions"
VOID="$(claims "$O" claude-test)
$(mcp request_invoice_void "{\"invoice_id\":\"$INV\",\"reason\":\"duplicate\"}" "$RQ2")"
race 2 "$VOID" "$VOID"
waited 2
a=$(answer 2 a) b=$(answer 2 b)
if [ "${a%%|*}" = pending_validation ] && [ -n "$(cut -d'|' -f2 <<<"$a")" ] \
   && [ "$(cut -d'|' -f1-2 <<<"$a")" = "$(cut -d'|' -f1-2 <<<"$b")" ]; then
  say "2: both sessions answer event $(cut -d'|' -f2 <<<"$a")"
else bad "2: A answered '${a:-nothing}', B answered '${b:-nothing}' — both must name the one pending event. B said: $(cat "$TMP/2.b")"; fi
n=$(q "select count(*) from public.events where workspace_id = '$WS' and type = 'invoice_void' and payload->>'invoice_id' = '$INV'")
expect "$n" 1 "2: one validation event" "2: $n void events for one request"
n=$(q "select count(*) from public.invoices where id = '$INV' and voided_at is null")
[ "$n" = 1 ] || bad "2: the invoice was voided while its quorum of two was still open"

# ── 3: identical subscription changes ──────────────────────────────────
echo "3. the same subscription change from two sessions"
SUB="$(claims "$O" claude-test)
$(mcp request_subscription_change "{\"member_id\":\"$M_R\",\"pct\":60}" "$RQ3")"
race 3 "$SUB" "$SUB"
waited 3
a=$(answer 3 a) b=$(answer 3 b)
if [ "${a%%|*}" = pending_validation ] && [ -n "$(cut -d'|' -f2 <<<"$a")" ] \
   && [ "$(cut -d'|' -f1-2 <<<"$a")" = "$(cut -d'|' -f1-2 <<<"$b")" ]; then
  say "3: both sessions answer event $(cut -d'|' -f2 <<<"$a")"
else bad "3: A answered '${a:-nothing}', B answered '${b:-nothing}' — both must name the one pending event. B said: $(cat "$TMP/3.b")"; fi
n=$(q "select count(*) from public.events where workspace_id = '$WS' and type = 'subscription_change' and subject_member_id = '$M_R'")
expect "$n" 1 "3: one pending event" "3: $n subscription events for one request"
n=$(q "select subscription_pct from public.members where id = '$M_R'")
expect "$n" 100 "3: no effect while it waits" "3: the share is $n while its change is still pending"

# ── 4: one person, two channels, one decision ──────────────────────────
echo "4. a native approval racing the MCP one, by the same person"
race 4 "$(claims "$B")
select public.respond_to_event('$EV', true);
select 'ANSWER=native';" \
  "$(claims "$B" claude-test)
$(mcp respond_to_validation "{\"event_id\":\"$EV\",\"accept\":true}" "$RQ4")"
waited 4
say "4: the MCP answer: $(answer 4 b | cut -d'|' -f1)"
n=$(q "select count(*) from public.event_decisions where event_id = '$EV' and member_id = '$M_B'")
expect "$n" 1 "4: the person counts once" "4: $n decisions by one person on one event"
n=$(q "select status from public.events where id = '$EV'")
expect "$n" pending "4: the event still waits for its second person" "4: the event is '$n' after one person's approval under a quorum of two"
n=$(q "select subscription_pct from public.members where id = '$M_D'")
[ "$n" = 100 ] || bad "4: the change applied (share $n) on one person's approval"

if [ "$FAILED" -gt 0 ]; then
  echo "db race: $FAILED assertion(s) failed"
  exit 1
fi
echo "two sessions, one MCP intent: every race has one winner"
