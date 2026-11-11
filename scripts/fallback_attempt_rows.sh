#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #3663 -- for each row input the current attempt did not produce, take the
# newest earlier attempt of THIS run that did (see newest_attempt_artifact.sh),
# and say which attempt every input came from in report/attempts.txt, which the
# report prints. Needs `gh` and GH_TOKEN; writes `<id>=recovered` to
# $GITHUB_OUTPUT for each input it found.
#
#   scripts/fallback_attempt_rows.sh report dl_code:quality-code ...
#
# An input is given as `<id>:<prefix>`; only those listed are looked up (the
# workflow passes the ones whose current-attempt download failed).
set -uo pipefail

DIR=${1:?report directory}
shift
mkdir -p "$DIR"
[ $# -eq 0 ] && exit 0

names=$(gh api --paginate "repos/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID/artifacts" --jq '.artifacts[].name') || {
  echo "::warning::could not list the run's artifacts; earlier attempts' rows were not looked for"
  exit 0
}
for spec in "$@"; do
  id=${spec%%:*}
  prefix=${spec#*:}
  if name=$(printf '%s\n' "$names" | bash "$(dirname "$0")/newest_attempt_artifact.sh" "$prefix" "$GITHUB_RUN_ATTEMPT") \
    && gh run download "$GITHUB_RUN_ID" -n "$name" -D "$DIR"; then
    echo "$prefix|$name" >> "$DIR/attempts.txt"
    [ -n "${GITHUB_OUTPUT:-}" ] && echo "$id=recovered" >> "$GITHUB_OUTPUT"
    echo "::notice::$prefix rows read from the earlier attempt: $name"
  else
    echo "::warning::no attempt of this run produced $prefix"
  fi
done
