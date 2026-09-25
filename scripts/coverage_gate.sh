#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #1244 — coverage, by layer, because the repository-wide percentage was
# the weakest measure in the quality report and the only one gated.
#
# Measured 2026-09-14 over 62 320 lines:
#
#   domain/        88.9%    the invariants — the layer worth a real floor
#   presentation/  84.0%    the widgets
#   core/          78.3%    the shared machinery
#   data/           2.9%    the Supabase boundary
#   everything else 35.9%   mostly lib/l10n, which is GENERATED
#   TOTAL          66.0%
#
# So 66% understates the tested code badly: it is one number averaging a
# well-covered domain layer with ~20 000 lines of generated localisation.
# Raising the global floor would tighten the wrong screw — a PR adding a
# feature in five languages LOWERS it.
#
# `data/` deliberately has no floor. It is thin wrappers over PostgREST
# calls, and testing it against a fake proves the fake works. What tests
# that layer is `supabase/tests/database/` (#1226), which runs the real
# queries against a real database.
#
# #1446 R2 — a layer with no measured lines used to print a warning and
# return, so an LCOV missing `domain/` and `presentation/` entirely
# scored 100% and exited 0. A gate that passes when the evidence is
# absent is not a gate: the absence IS the failure, because the run that
# produced it was partial, the reporter truncated, or the layer moved.
set -uo pipefail

LCOV=${1:-coverage/lcov.info}
[ -f "$LCOV" ] || { echo "::error::$LCOV not found — run flutter test --coverage first"; exit 1; }
[ -s "$LCOV" ] || { echo "::error::$LCOV is empty — the coverage run produced no evidence"; exit 1; }
if ! grep -q '^SF:' "$LCOV"; then
  echo "::error::$LCOV has no SF: record — it is not an LCOV report, or it was truncated"
  exit 1
fi

# #1446 C3 — the SHAPE of the evidence is checked before any percentage
# is computed from it. The aggregation below sums whatever LF:/LH: lines
# it meets, so a report truncated mid-record, a record with two LF:
# lines or none, a count that is not a number, or more lines hit than
# exist all became a score: `LH:12 LF:10` printed "core 120.0%" and
# exited 0. A malformed report is not a low score and not a high one —
# it is no evidence, and the run ends here, before report/ is written.
validate_lcov() {
  awk -v file="$LCOV" '
    function bad(msg) {
      errors++
      if (errors <= 20) printf "::error::%s line %d: %s\n", file, NR, msg
    }
    /^SF:/ {
      if (in_record) bad("SF: while the record for " sf " is still open (no end_of_record)")
      in_record = 1; sf = substr($0, 4); lf = ""; lh = ""; next
    }
    /^L[FH]:/ {
      if (!in_record) bad($0 " outside any SF: record")
      v = substr($0, 4)
      if (v !~ /^[0-9]+$/) { bad($0 " is not a non-negative integer count"); next }
      if (substr($0, 1, 2) == "LF") { if (lf != "") bad("duplicate LF: for " sf); lf = v }
      else                          { if (lh != "") bad("duplicate LH: for " sf); lh = v }
      next
    }
    /^end_of_record$/ {
      if (!in_record) { bad("end_of_record without an open SF: record"); next }
      if (lf == "") bad("no LF: summary for " sf)
      if (lh == "") bad("no LH: summary for " sf)
      if (lf != "" && lh != "" && lh + 0 > lf + 0)
        bad("LH:" lh " exceeds LF:" lf " for " sf " — more lines hit than exist")
      in_record = 0; next
    }
    END {
      if (in_record) bad("the report ends inside the record for " sf " — truncated before its end_of_record")
      if (errors > 20) printf "::error::%s: ... and %d more\n", file, errors - 20
      if (errors) {
        printf "::error::%s is malformed (%d problem(s)) — no percentage was computed from it\n", file, errors
        exit 1
      }
    }' "$LCOV"
}
validate_lcov || exit 1

mkdir -p report
fail=0

# hit/found per file, then grouped by layer.
read_group() {
  awk -v want="$1" -F: '
    /^SF:/  { keep = (index($2, want) > 0) }
    /^LF:/  { if (keep) found += substr($0, 4) }
    /^LH:/  { if (keep) hit   += substr($0, 4) }
    END     { printf "%d %d\n", hit, found }' "$LCOV"
}

gate() {
  local name="$1" want="$2" floor="$3"
  read -r hit found <<< "$(read_group "$want")"
  if [ "${found:-0}" -eq 0 ]; then
    echo "::error::no lines matched $want — $name has NO coverage evidence." \
      "The layer moved, the run was partial, or the LCOV was truncated;" \
      "either way its ${floor}% floor was not measured, so it is not met."
    fail=1
    return
  fi
  local tenths=$(( hit * 1000 / found ))
  local pct="$(( tenths / 10 )).$(( tenths % 10 ))"
  if [ "$tenths" -lt "$(( floor * 10 ))" ]; then
    echo "::error::$name coverage ${pct}% is below its ${floor}% floor ($hit/$found lines)"
    fail=1
  else
    echo "  $name ${pct}% (floor ${floor}%, $hit/$found lines)"
  fi
  printf '%s %s %s\n' "$name" "$pct" "$floor" >> report/coverage-layers.txt
}

: > report/coverage-layers.txt
echo "coverage by layer:"

# The floors are the measured values rounded DOWN to leave a PR room to
# land without a coverage argument, and no further. They ratchet: raise
# one when the margin grows; never lower one to make a branch green.
gate domain       '/domain/'       85
gate presentation '/presentation/' 80
gate core         'lib/core/'      75

# The repository-wide gate stays where it was (#1060's 65%), because the
# number itself has not changed meaning — it is simply no longer the only
# thing anyone looks at.
read -r hit found <<< "$(read_group 'lib/')"
if [ "${found:-0}" -eq 0 ]; then
  echo "::error::no lines matched lib/ at all — the report measures nothing." \
    "That is a reporting failure, not a 0% score."
  exit 1
fi
tenths=$(( hit * 1000 / found ))
line="total $(( tenths / 10 )).$(( tenths % 10 ))% ($hit/$found lines); domain $(awk '$1=="domain"{print $2"%"}' report/coverage-layers.txt)"
echo "  $line"
printf '%s\n' "$line" > report/coverage-line.txt
if [ "$tenths" -lt 650 ]; then
  echo "::error::total coverage $(( tenths / 10 )).$(( tenths % 10 ))% is below the 65% gate"
  fail=1
fi

exit "$fail"
