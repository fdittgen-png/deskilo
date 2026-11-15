#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #4015 -- a pushed branch's test folders on a hosted runner, in one command
# and one verdict line.
#
#   scripts/branch_check.sh <branch> <test path>...
#
# Dispatches `Tools · Branch check` on <branch> with the paths, waits for the
# run and prints its verdict: one total line
# (`BRANCH CHECK: ok -- <n> passed, <m> skipped (<k> paths)` or
# `BRANCH CHECK: FAILED -- ...`) and, for a failure, each failing path's own
# line and the names of its failed tests. Each path runs on a runner of its
# own (#4044), so the wait is that of the slowest one.
# Exit 0 only when every test of every path passed; 2 for a wrong call; 3
# when the run could not be found or read.
#
# The branch must be pushed and contain the workflow (merge master once if it
# is older than #4015). The run gates nothing: the pull request's Quality run
# stays the gate.
set -uo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: scripts/branch_check.sh <branch> <test path>..." >&2
  exit 2
fi
branch=$1
shift
for p in "$@"; do
  if [[ ! "$p" =~ ^test/[A-Za-z0-9_./-]*$ || "$p" == *..* ]]; then
    echo "not a test path: $p" >&2
    exit 2
  fi
done

workflow=branch-check.yml
before=$(gh run list --workflow "$workflow" --branch "$branch" --limit 1 \
  --json databaseId --jq '.[0].databaseId // 0' 2>/dev/null || echo 0)
if ! gh workflow run "$workflow" --ref "$branch" -f paths="$*" >/dev/null; then
  echo "BRANCH CHECK: not dispatched (is the branch pushed, and does it contain $workflow?)" >&2
  exit 3
fi

# The dispatched run appears a few seconds later: the newest run of this
# branch that is not the one seen before.
run=""
for _ in $(seq 1 30); do
  sleep 4
  run=$(gh run list --workflow "$workflow" --branch "$branch" --limit 1 \
    --json databaseId --jq '.[0].databaseId // 0' 2>/dev/null || echo 0)
  if [ "$run" != "0" ] && [ "$run" != "$before" ]; then break; fi
  run=""
done
if [ -z "$run" ]; then
  echo "BRANCH CHECK: the dispatched run did not appear" >&2
  exit 3
fi
echo "run $run -- $(gh run view "$run" --json url --jq .url 2>/dev/null)"

gh run watch "$run" --interval 30 >/dev/null 2>&1
conclusion=$(gh run view "$run" --json conclusion --jq .conclusion 2>/dev/null)

# Each path's verdict step prints the lines its job summary shows.
lines=$(gh run view "$run" --log 2>/dev/null |
  sed -n 's/^.*\(BRANCH CHECK: .*\)$/\1/p; s/^.*Z \(- test\/.*\)$/\1/p' |
  awk '!seen[$0]++')
if [ -z "$lines" ]; then
  echo "BRANCH CHECK: FAILED -- no verdict in the log (conclusion: ${conclusion:-unknown}); gh run view $run --log-failed"
  exit 3
fi
asked=$(printf '%s\n' "$@" | sort -u | wc -l | tr -d ' ')
printf '%s\n' "$lines" | python3 "$(dirname "$0")/branch_check_total.py" "$asked" "${conclusion:-unknown}"
