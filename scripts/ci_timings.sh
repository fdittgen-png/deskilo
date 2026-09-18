#!/usr/bin/env bash
# SPDX-License-Identifier: 0BSD
#
# #1446 C0 — what a pull-request run of the quality workflow costs, from
# the last N completed runs, by job and by step. Sample size and p50/p95
# are printed with the numbers; a cache hit is never compared with a cold
# run as a speedup, because the table does not label either.
#
#   scripts/ci_timings.sh [N]        # default 20
set -euo pipefail

REPO="${REPO:-fdittgen-png/deskilo}"
N=${1:-20}

runs=$(gh api "repos/${REPO}/actions/workflows/quality.yml/runs?event=pull_request&status=completed&per_page=${N}" \
  --jq '.workflow_runs[].id')
count=$(printf '%s\n' "$runs" | grep -c . || true)
echo "sample: ${count} completed pull-request runs of quality.yml"

all=$(for id in $runs; do
  gh api "repos/${REPO}/actions/runs/${id}/jobs?per_page=10" --jq '
    .jobs[] | select(.started_at != null and .completed_at != null) |
    {job: .name, conclusion: .conclusion,
     queue: ((.started_at | fromdate) - (.created_at | fromdate)),
     run: ((.completed_at | fromdate) - (.started_at | fromdate)),
     steps: [.steps[] | select(.started_at != null and .completed_at != null) |
             {name: .name, s: ((.completed_at | fromdate) - (.started_at | fromdate))}]}'
done | jq -s '.')

echo
echo "| job | n | success | queue p50 | queue p95 | run p50 | run p95 |"
echo "|---|---|---|---|---|---|---|"
jq -r '
  def pct(f): sort | .[ ((length - 1) * f | round) ];
  group_by(.job)[] |
  "| \(.[0].job) | \(length) | \(map(select(.conclusion == "success")) | length) | \(map(.queue) | pct(0.5))s | \(map(.queue) | pct(0.95))s | \(map(.run) | pct(0.5))s | \(map(.run) | pct(0.95))s |"
' <<< "$all"

echo
echo "steps of 20 s or more, median over the runs that ran them:"
jq -r '
  def median: sort | .[ ((length - 1) * 0.5 | round) ];
  [ .[] | .job as $j | .steps[] | {job: $j, name: .name, s: .s} ] |
  group_by(.job + "|" + .name)[] |
  select((map(.s) | median) >= 20) |
  "  \(.[0].job) · \(.[0].name): \(map(.s) | median)s (n=\(length))"
' <<< "$all"
