#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #1456 — the gate over the journey benchmark's record
# (`tool/bench/journeys_bench_test.dart` → report/perf.psv).
#
# The property that matters, and the reason this script exists at all:
# **a missing measurement is a failure, not a skip**. `coverage_gate.sh`
# warned and returned for a layer with no measured lines, so two of its
# three floors passed by never being measured (#1446 R2). Every check
# below therefore fails when the row is absent, exactly as loudly as
# when the number is over budget.
#
# ## What is gated, and what is only reported
#
# Gated: the SHAPE of a journey — backend round trips, elements built,
# frames pumped, and the retry policy's worst case. Those are exact,
# identical on every machine, and they are what turns a 200 ms network
# into a two-second wait.
#
# Reported, never gated: the wall clock. It is measured on a headless
# Dart VM with no compositor; comparing it to a threshold would police
# the runner. It must be PRESENT and positive — an absent clock means
# the benchmark did not run — and that is all.
#
# Not here at all: cold start on a device, frame timing, transition
# milliseconds, API p95, server milliseconds — and for the onboarding
# recipes, device frame timing, how long a human or an e-mail takes, a
# real screen reader, and real participants. Those are declared unheld
# in the record, and this script fails if a declaration disappears:
# dropping the honest "not measured" is how a 2.5 s target nobody holds
# gets written down as if it were held.
set -uo pipefail

REC=${1:-report/perf.psv}
[ -f "$REC" ] || { echo "::error::$REC not found — run 'flutter test tool/bench' first"; exit 1; }
[ -s "$REC" ] || { echo "::error::$REC is empty — the benchmark produced no evidence"; exit 1; }
grep -q '^measure|' "$REC" || {
  echo "::error::$REC holds no measure| row — the benchmark ran but measured nothing"
  exit 1
}

fail=0
value_of() { awk -F'|' -v j="$1" -v m="$2" '$1=="measure" && $2==j && $3==m {print $4}' "$REC"; }

# journey metric min max — the budgets.
#
# Each ceiling is the value measured on 2026-09-20 at the `large` scale
# (20 rooms, 200 desks, 800 seats, 2 000 reservations) with room for a
# fixture or layout change, and each FLOOR is there because zero is not
# a triumph: a journey reporting no round trips has lost the seam it was
# measuring, not gained a cache.
#
# Measured: first-usable 7 trips / 1 737 elements / 14 frames; the
# transition 1 trip / 2 844 elements / 6 frames; the commit 4 trips /
# 0 sheet trips / 1 frame. The N+1 control in the benchmark drives the
# first-usable journey to 800-odd trips, which is what makes the 12
# below a guard rather than a decoration.
check() {
  local journey="$1" metric="$2" lo="$3" hi="$4"
  local v; v="$(value_of "$journey" "$metric")"
  if [ -z "$v" ]; then
    echo "::error::$journey.$metric was NOT MEASURED — the record has no row" \
      "for it. The journey moved, the benchmark died part-way, or the metric" \
      "was dropped; absent evidence is not a pass."
    fail=1
    return
  fi
  # A non-numeric value would make every comparison below error out and
  # read as "in range" — the same shape of hole as an absent row.
  case "$v" in ''|*[!0-9]*)
    echo "::error::$journey.$metric reads '$v', which is not a number — the record is malformed"
    fail=1
    return ;;
  esac
  if [ "$v" -lt "$lo" ] || [ "$v" -gt "$hi" ]; then
    echo "::error::$journey.$metric is $v, outside [$lo, $hi]"
    fail=1
  else
    echo "  $journey.$metric $v (budget $lo..$hi)"
  fi
}

# Reported only: present and positive, never compared to a threshold.
report() {
  local journey="$1" metric="$2"
  local v; v="$(value_of "$journey" "$metric")"
  case "$v" in ''|*[!0-9]*) v=0 ;; esac
  if [ "$v" -le 0 ]; then
    echo "::error::$journey.$metric is missing or zero — the benchmark did not" \
      "time this journey, so there is nothing to report"
    fail=1
  else
    echo "  $journey.$metric $v ms (reported, NOT a budget: this host, no compositor)"
  fi
}

echo "journey shape (gated):"
check reserve_first_usable trips     3    12
check reserve_first_usable elements  400  3500
check reserve_first_usable frames    2    40
check reserve_transition  trips      1    6
check reserve_transition  elements   400  5500
check reserve_transition  frames     1    30
# The sheet is local: it must ask the backend for nothing at all.
check booking_commit      sheet_trips 0   0
check booking_commit      trips      1    10
check booking_commit      elements   400  4000
check booking_commit      sheet_frames 1  20
check booking_commit      frames     1    20
# The retry component of a booking, read from kRetryDelays itself.
check booking_commit      retry_attempts_max 1 3
check booking_commit      retry_budget_ms    1 1500
check reserve_first_usable samples    5    9999
check reserve_transition   samples    5    9999
check booking_commit       samples    5    9999

# The onboarding recipes (#1456, 22 September). Correctness first: a
# recipe whose run did not assert its authorized screen or domain result
# records success 0 and fails here, whatever its numbers. Then the shape,
# measured 2026-09-29 against the suite's fakes:
#
#  * trips: the ceiling IS the reading, so one extra request is red —
#    the counts are exact and the same on every machine;
#  * a route shown that is not a stop of the recipe, a field the app
#    made the person type again, the same unchanged confirmation twice:
#    zero, always;
#  * at most one loading episode on the way in; a second is a duplicate
#    loading screen;
#  * tap → acknowledgement within 5 frames and → completion within 10,
#    with providers that answer at once: more is a dwell the app added.
#    Frames are 16 ms pumps of FAKE time, a count, not a frame rate.
#
# Waits (a human, an e-mail) are pinned as COUNTS: they must be declared,
# never folded into app time. Their durations are unheld below.
recipe() {
  local r="$1" trips="$2"; shift 2
  check "$r" success 1 1
  check "$r" trips 1 "$trips"
  check "$r" route_flashes 0 0
  check "$r" loading_episodes 0 1
  check "$r" fields_reentered 0 0
  check "$r" duplicate_confirmations 0 0
  check "$r" entry_frames 1 10
  check "$r" samples 5 9999
  local b
  for b in "$@"; do
    check "$r" "${b}_ack_frames" 1 5
    check "$r" "${b}_ack_semantic_frames" 1 5
    check "$r" "${b}_done_frames" 1 10
  done
}

echo "onboarding recipes (gated: correctness, then shape):"
recipe returning_entry           10
recipe first_signup              2  sign_up
recipe invitation_join           9  join
recipe owner_first_booking       14 create book
recipe byo_signin                11 verify sign_in
recipe pending_leave_return      8  request withdraw
recipe wizard_keyboard_back_edit 5  create
check first_signup              waits_email      1 1
check first_signup              required_confirmations 1 1
check byo_signin                waits_human      1 1
check invitation_join           waits_human      1 1
# The link fills the field: nothing is typed on the way to Join.
check invitation_join           fields_entered   0 0
check pending_leave_return      back_corrections 2 2
check wizard_keyboard_back_edit back_corrections 1 1
check wizard_keyboard_back_edit user_edits       1 1

echo "wall clock (reported):"
for j in reserve_first_usable reserve_transition booking_commit \
    returning_entry first_signup invitation_join owner_first_booking \
    byo_signin pending_leave_return wizard_keyboard_back_edit; do
  report "$j" wall_p50_ms
  report "$j" wall_p95_ms
done

# The conditions. A number without them is not evidence.
echo "conditions:"
for key in sha build_mode host dataset backend samples; do
  v="$(awk -F'|' -v k="$key" '$1=="condition" && $2==k {print $3}' "$REC")"
  if [ -z "$v" ]; then
    echo "::error::the record does not say its $key — a latency number whose" \
      "hardware, dataset or build mode is unknown cannot be compared to anything"
    fail=1
  else
    echo "  $key: $v"
  fi
done

# The honest absences, still declared.
echo "declared UNMEASURED (no device here):"
for id in cold_start_device frame_timing_device transition_ms_device api_p95 server_ms \
    onboarding_frame_timing_device onboarding_wait_durations screen_reader_device \
    onboarding_participants; do
  reason="$(awk -F'|' -v k="$id" '$1=="unheld" && $2==k {print $3}' "$REC")"
  if [ -z "$reason" ]; then
    echo "::error::the record no longer declares '$id' unmeasured. Either it is" \
      "now measured — in which case it belongs above, with a budget and the" \
      "hardware it was measured on — or the declaration was dropped, which" \
      "would let a number that was never taken read as one that was."
    fail=1
  else
    echo "  $id: $reason"
  fi
done

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "## Journey latency (#1456)"
    echo
    echo "Shape budgets held; wall clock reported. Cold start, frame timing,"
    echo "transition milliseconds, API p95 and server time remain UNMEASURED —"
    echo "they need a real device and a real backend. The onboarding recipes'"
    echo "waits are counted, not timed; no participant has run them."
    echo
    echo '```'
    grep '^measure|' "$REC" | awk -F'|' '{printf "%-22s %-20s %s\n", $2, $3, $4}'
    echo '```'
  } >> "$GITHUB_STEP_SUMMARY"
fi

exit "$fail"
