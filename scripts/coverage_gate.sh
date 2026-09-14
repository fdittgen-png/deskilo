#!/usr/bin/env bash
# SPDX-License-Identifier: 0BSD
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
set -uo pipefail

LCOV=${1:-coverage/lcov.info}
[ -f "$LCOV" ] || { echo "::error::$LCOV not found — run flutter test --coverage first"; exit 1; }

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
    echo "::warning::no lines matched $want — the layer moved or the run was partial"
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
tenths=$(( hit * 1000 / found ))
line="total $(( tenths / 10 )).$(( tenths % 10 ))% ($hit/$found lines); domain $(awk '$1=="domain"{print $2"%"}' report/coverage-layers.txt)"
echo "  $line"
printf '%s\n' "$line" > report/coverage-line.txt
if [ "$tenths" -lt 650 ]; then
  echo "::error::total coverage $(( tenths / 10 )).$(( tenths % 10 ))% is below the 65% gate"
  fail=1
fi

exit "$fail"
