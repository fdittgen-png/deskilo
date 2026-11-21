#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Findings are a review report; unreadable inputs or tool failures still fail.
set -euo pipefail
scanner=${1:?path to the pinned zizmor executable required}
out=${2:-report/workflow-security}
mkdir -p "$out"
rm -f "$out/summary.md" "$out/findings.json"
"$scanner" --version > "$out/version.txt"
git rev-parse HEAD > "$out/revision.txt"
git status --porcelain > "$out/working-tree.txt"
"$scanner" --offline --strict-collection --persona=regular --no-exit-codes \
  --format=json-v1 . > "$out/findings.json"
# The summary and its difference from the stored baseline
# (WORKFLOW_AUDIT_WRITE_BASELINE=1 records the current counts, in a reviewed change).
python3 "$(dirname "$0")/workflow_audit_summary.py" "$out" .github/workflow-audit-baseline.json \
  ${WORKFLOW_AUDIT_WRITE_BASELINE:+--write-baseline}
