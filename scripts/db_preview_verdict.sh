#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #3751 — the verdict of the database preview (.github/workflows/
# db-preview.yml): one line per check, what to do when one failed, and a
# non-zero exit unless every check succeeded. A check that did not run
# (skipped after a failed replay, or an empty outcome) is not a success.
#
#   REPLAY POLICIES CONTRACT PGTAP   each step's outcome
#   FILES                            "true": a policy list or contract that
#                                    differs is a file to commit, not a failure
#   GITHUB_STEP_SUMMARY              optional; the same lines go to stdout
#   GITHUB_RUN_ID                    optional; named in the download line
set -uo pipefail

rc=0
out() {
  printf '%s\n' "$*"
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then printf '%s\n' "$*" >> "$GITHUB_STEP_SUMMARY"; fi
}
files=0
row() { # row <label> <outcome> <what to do when it is not a success> [file]
  if [ "$2" = "success" ]; then
    out "| $1 | ok | |"
  elif [ "${FILES:-}" = "true" ] && [ "$2" = "failure" ] && [ -n "${4:-}" ]; then
    out "| $1 | to commit | $3 |"
    files=1
  else
    out "| $1 | ${2:-not run} | $3 |"
    rc=1
  fi
}

out "### Database preview"
out ""
out "| Check | Result | When it is not ok |"
out "| --- | --- | --- |"
row "Migration replay" "${REPLAY:-}" "a migration does not apply onto an empty database: read the replay step"
row "Policies" "${POLICIES:-}" "commit \`policies.txt\` of the artifact as \`assets/instance/policies.txt\`" file
row "Effective contract" "${CONTRACT:-}" "commit \`contract.txt\` of the artifact as \`assets/instance/contract.txt\`, then run the preflight generators" file
row "Database tests" "${PGTAP:-}" "read \`pgtap.log\` of the artifact: the failing file and its plan are named there"
out ""
if [ "$rc" -eq 0 ] && [ "$files" -eq 1 ]; then
  out "The replay and the database tests succeeded; commit the files marked to commit: \`gh run download ${GITHUB_RUN_ID:-<run id>} -n database-preview -D <folder>\`"
elif [ "$rc" -eq 0 ]; then
  out "Every check succeeded: the pull request's database job will read the same tree the same way."
else
  out "The files are in the artifact: \`gh run download ${GITHUB_RUN_ID:-<run id>} -n database-preview -D <folder>\`"
fi
exit "$rc"
