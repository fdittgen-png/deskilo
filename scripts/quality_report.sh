#!/usr/bin/env bash
# SPDX-License-Identifier: 0BSD
#
# #1244 — renders the quality table from the rows each discipline job
# wrote, and IS the gate: a red row fails the run, and the summary above
# it already says which discipline.
#
# #1446 C0 — the table is complete or it is red. `.github/quality-manifest.psv`
# names every row the report must contain; a row that is missing (the job
# died, a step was renamed, an artifact was lost) fails the run, and so
# does a row the manifest does not know. `skipped` passes only for a row
# the manifest marks conditional — one that legitimately waits on an
# earlier row of its job — never for a discipline that simply did not run.
#
# Rows arrive as `name|outcome|evidence`, one per line, in any number of
# `.psv` files under report/.
set -uo pipefail

DIR=${1:-report}
MANIFEST=${2:-.github/quality-manifest.psv}
OUT="$DIR/quality-report.md"
rows=$(cat "$DIR"/*.psv 2>/dev/null || true)

if [ -z "$rows" ]; then
  echo "::error::no discipline reported a row — every job died before writing one"
  exit 1
fi
[ -f "$MANIFEST" ] || { echo "::error::$MANIFEST not found — the report cannot know what is expected"; exit 1; }

status=0
expected=$(grep -vE '^[[:space:]]*(#|$)' "$MANIFEST" | cut -d'|' -f1)
conditional=$(grep -vE '^[[:space:]]*(#|$)' "$MANIFEST" | awk -F'|' '$4 == "conditional" {print $1}')

{
  echo '## DESKILO QUALITY REPORT'
  echo
  echo '| Discipline | | Evidence |'
  echo '|---|---|---|'
  printf '%s\n' "$rows" | while IFS='|' read -r name outcome detail; do
    case "$outcome" in
      success) mark='✅ PASS' ;;
      skipped)
        if printf '%s\n' "$conditional" | grep -qxF "$name"; then
          mark='⏭️ SKIPPED (waits on an earlier row)'
        else
          mark='❌ FAIL (did not run)'
        fi ;;
      *)       mark='❌ FAIL' ;;
    esac
    printf '| %s | %s | %s |\n' "$name" "$mark" "$detail"
  done
  echo
  echo '> Performance budgets are not a row yet. One exists — a 12-second'
  echo '> Android boot — and the rest are tracked in #1236.'
} | tee "$OUT"

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  cat "$OUT" >> "$GITHUB_STEP_SUMMARY"
fi

# Completeness: every expected row, exactly once, and nothing unexpected.
names=$(printf '%s\n' "$rows" | cut -d'|' -f1)
while read -r want; do
  [ -z "$want" ] && continue
  n=$(printf '%s\n' "$names" | grep -cxF "$want")
  if [ "$n" -eq 0 ]; then
    echo "::error::the report has no row for '$want' — its job died, its step was renamed, or its artifact was lost"
    status=1
  elif [ "$n" -gt 1 ]; then
    echo "::error::the report has $n rows for '$want'"
    status=1
  fi
done <<< "$expected"
while read -r have; do
  [ -z "$have" ] && continue
  if ! printf '%s\n' "$expected" | grep -qxF "$have"; then
    echo "::error::row '$have' is not in $MANIFEST — add it there, so the gate knows to wait for it"
    status=1
  fi
done <<< "$names"

# Outcomes: success, or skipped where the manifest allows it.
while IFS='|' read -r name outcome detail; do
  case "$outcome" in
    success) ;;
    skipped)
      if ! printf '%s\n' "$conditional" | grep -qxF "$name"; then
        echo "::error::'$name' did not run and is not conditional"
        status=1
      fi ;;
    *)
      echo "::error::'$name' regressed"
      status=1 ;;
  esac
done <<< "$rows"

if [ "$status" -ne 0 ]; then
  echo "::error::the report is red — the table above says which discipline, or which row is missing"
fi
exit "$status"
