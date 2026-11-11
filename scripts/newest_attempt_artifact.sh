#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #3663 -- which attempt's rows to read. A re-run of only the failed jobs does
# not run the jobs that passed again, so their rows exist only under the
# earlier attempt's number. Given the artifact names of the run on stdin (one
# per line), a name prefix and the current attempt, print the NEWEST
# `<prefix>-attempt-N` with N <= the current attempt; exit 1 when no attempt
# produced it.
#
#   gh api .../artifacts --jq '.artifacts[].name' \
#     | scripts/newest_attempt_artifact.sh quality-code 2
set -uo pipefail

prefix=${1:?prefix}
current=${2:?current attempt}
best=-1
while IFS= read -r name; do
  case "$name" in
    "$prefix"-attempt-*)
      n=${name##*-attempt-}
      case "$n" in
        ''|*[!0-9]*) continue ;;
      esac
      if [ "$n" -le "$current" ] && [ "$n" -gt "$best" ]; then best=$n; fi ;;
  esac
done
[ "$best" -ge 0 ] || exit 1
echo "$prefix-attempt-$best"
