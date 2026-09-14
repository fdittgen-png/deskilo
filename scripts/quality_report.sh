#!/usr/bin/env bash
# SPDX-License-Identifier: 0BSD
#
# #1244 — renders the quality table from the rows each discipline job
# wrote, and IS the gate: a red row fails the run, and the summary above
# it already says which discipline.
#
# Rows arrive as `name|outcome|evidence`, one per line, in any number of
# `.psv` files under report/. A job that died before writing one is
# itself a failure, which is why an empty set is an error rather than a
# clean table.
set -uo pipefail

DIR=${1:-report}
OUT="$DIR/quality-report.md"
rows=$(cat "$DIR"/*.psv 2>/dev/null || true)

if [ -z "$rows" ]; then
  echo "::error::no discipline reported a row — every job died before writing one"
  exit 1
fi

{
  echo '## DESKILO QUALITY REPORT'
  echo
  echo '| Discipline | | Evidence |'
  echo '|---|---|---|'
  printf '%s\n' "$rows" | while IFS='|' read -r name outcome detail; do
    case "$outcome" in
      success) mark='✅ PASS' ;;
      skipped) mark='⏭️ SKIPPED' ;;
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

if printf '%s\n' "$rows" | cut -d'|' -f2 | grep -qvE '^(success|skipped)$'; then
  echo "::error::a discipline regressed — the table above says which"
  exit 1
fi
