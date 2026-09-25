#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #1446 C2 — the final word of a job or of the run: green only when
# EVERY named outcome is exactly `success`.
#
#   scripts/job_gate.sh "Tests=success" "Coverage=failure" ...
#
# `skipped`, `cancelled`, an empty outcome and a word it has never seen
# are all red — a step that did not run is not a step that passed, and a
# gate given nothing to gate has nothing to be green about. The inline
# loops this replaces failed only on `*=failure`, so a required step
# that was skipped read as green.
set -uo pipefail

if [ $# -eq 0 ]; then
  echo "::error::the gate was given no outcomes — nothing ran, or nothing was named"
  exit 1
fi
status=0
for pair in "$@"; do
  name="${pair%%=*}"
  outcome="${pair#*=}"
  [ "$pair" = "$name" ] && outcome=""
  echo "$name = ${outcome:-(no outcome)}"
  if [ "$outcome" != "success" ]; then
    echo "::error::'$name' did not succeed: ${outcome:-no outcome was recorded}"
    status=1
  fi
done
exit "$status"
