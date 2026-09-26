#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #1446 C0 — what a pull-request run of the quality workflow costs, from
# the last N completed runs, by job and by step. Sample size and p50/p95
# are printed with the numbers.
#
# #1446 C5 — two things the first version folded in silently:
#   * a CANCELLED job (a superseded push, since C4b cancels its
#     predecessor) is listed in the sample and left out of every
#     percentile — its duration is when it was killed, not what it costs;
#   * the cache state of the code job is read from its log and printed
#     per run, and the code job's run time is given per state, so a warm
#     and a cold run are two labelled samples rather than one blur.
#
#   scripts/ci_timings.sh [N]        # default 20
set -euo pipefail

REPO="${REPO:-fdittgen-png/deskilo}"
GH="${GH:-gh}"
N=${1:-20}
CODE_JOB='analyze · l10n gate · test · coverage'

sample=$("$GH" api "repos/${REPO}/actions/workflows/quality.yml/runs?event=pull_request&status=completed&per_page=${N}" \
  --jq '.workflow_runs[] | "\(.id) \(.head_sha[0:9]) \(.conclusion) attempt \(.run_attempt)"')
runs=$(printf '%s\n' "$sample" | cut -d' ' -f1)
count=$(printf '%s\n' "$runs" | grep -c . || true)
echo "sample: ${count} completed pull-request runs of quality.yml"

# Every job with a start and an end, its conclusion kept: the table below
# drops the cancelled ones, the listing keeps them.
all=$(for id in $runs; do
  "$GH" api "repos/${REPO}/actions/runs/${id}/jobs?per_page=10" --jq '
    .jobs[] | select(.started_at != null and .completed_at != null) |
    {id: .id, job: .name, conclusion: .conclusion,
     queue: ((.started_at | fromdate) - (.created_at | fromdate)),
     run_s: ((.completed_at | fromdate) - (.started_at | fromdate)),
     steps: [.steps[] | select(.started_at != null and .completed_at != null) |
             {name: .name, s: ((.completed_at | fromdate) - (.started_at | fromdate))}]}' \
    | jq -c --arg run "$id" '. + {run: $run}'
done | jq -s '.')

# The cache state of one code job, from its log: the SDK cache of
# flutter-action and the pub cache of actions/cache (exact key, a
# restore-key prefix, or nothing). `?` when the log could not be read.
cache_state() {
  local log
  log=$("$GH" api "repos/${REPO}/actions/jobs/$1/logs" 2>/dev/null) || { echo 'sdk:? pub:?'; return; }
  local sdk=miss pub=miss
  grep -q 'Cache hit for: flutter-' <<< "$log" && sdk=hit
  if grep -q 'Cache hit for: pub-' <<< "$log"; then pub=exact
  elif grep -q 'Cache hit for restore-key: pub-' <<< "$log"; then pub=partial
  fi
  echo "sdk:$sdk pub:$pub"
}

states=$(jq -r --arg job "$CODE_JOB" '.[] | select(.job == $job and .conclusion != "cancelled") | "\(.run) \(.id)"' <<< "$all" \
  | while read -r run id; do echo "$run $(cache_state "$id")"; done)

# The run ids, so every number below can be re-derived rather than
# believed (#1446 C0). Without them a table is a claim.
echo
echo "runs sampled (id, head, conclusion; the code job's cache state):"
printf '%s\n' "$sample" | while read -r id rest; do
  printf '  %s %s  %s\n' "$id" "$rest" "$(printf '%s\n' "$states" | awk -v r="$id" '$1 == r {print $2, $3}')"
done

echo
echo "| job | n | success | cancelled (not measured) | queue p50 | queue p95 | run p50 | run p95 |"
echo "|---|---|---|---|---|---|---|---|"
jq -r '
  def pct(f): sort | .[ ((length - 1) * f | round) ];
  group_by(.job)[] |
  (map(select(.conclusion != "cancelled"))) as $m |
  "| \(.[0].job) | \($m | length) | \($m | map(select(.conclusion == "success")) | length) | \(map(select(.conclusion == "cancelled")) | length) | \($m | map(.queue) | pct(0.5))s | \($m | map(.queue) | pct(0.95))s | \($m | map(.run_s) | pct(0.5))s | \($m | map(.run_s) | pct(0.95))s |"
' <<< "$all"

echo
echo "code job run time by cache state (median, n):"
jq -r --arg job "$CODE_JOB" --arg states "$states" '
  def median: sort | .[ ((length - 1) * 0.5 | round) ];
  ($states | split("\n") | map(select(length > 0) | split(" ") | {run: .[0], state: (.[1] + " " + .[2])})
    | map({key: .run, value: .state}) | from_entries) as $st |
  [ .[] | select(.job == $job and .conclusion != "cancelled") | {state: ($st[.run] // "sdk:? pub:?"), s: .run_s} ] |
  group_by(.state)[] | "  \(.[0].state): \(map(.s) | median)s (n=\(length))"
' <<< "$all"

echo
echo "steps of 20 s or more, median over the runs that ran them (cancelled jobs left out):"
jq -r '
  def median: sort | .[ ((length - 1) * 0.5 | round) ];
  [ .[] | select(.conclusion != "cancelled") | .job as $j | .steps[] | {job: $j, name: .name, s: .s} ] |
  group_by(.job + "|" + .name)[] |
  select((map(.s) | median) >= 20) |
  "  \(.[0].job) · \(.[0].name): \(map(.s) | median)s (n=\(length))"
' <<< "$all"
