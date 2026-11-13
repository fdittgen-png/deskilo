#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #3670 -- the candidates tree_tested.sh reads: the latest Quality runs of
# pull-request heads, as "run number<TAB>tree of the head commit<TAB>conclusion".
# A lookup that fails prints nothing, so the full run happens.
#
# #3873 -- a pull-request run tests the merge of its head into the base AS IT
# WAS then, so the head's tree stands for the run only when the branch really
# was up to date: the first parent of the pushed commit (PUSHED_SHA, default
# GITHUB_SHA) must be an ancestor of, or equal to, the run's head (one
# `compare` call). A candidate that does not contain it is left out.
set -uo pipefail

repo=${GITHUB_REPOSITORY:?repository}
pushed=${PUSHED_SHA:-${GITHUB_SHA:?pushed commit}}
parent=$(gh api "repos/$repo/git/commits/$pushed" --jq '.parents[0].sha' 2>/dev/null) || exit 0
[ -n "$parent" ] && [ "$parent" != null ] || exit 0
gh api "repos/$repo/actions/workflows/quality.yml/runs?event=pull_request&status=completed&per_page=${CANDIDATE_RUNS:-60}" \
  --jq '.workflow_runs[] | [.run_number, .head_sha, .conclusion] | @tsv' 2>/dev/null |
while IFS=$'\t' read -r run sha conclusion; do
  [ "$conclusion" = "success" ] || continue
  state=$(gh api "repos/$repo/compare/$parent...$sha" --jq .status 2>/dev/null) || continue
  case "$state" in ahead | identical) ;; *) continue ;; esac
  tree=$(gh api "repos/$repo/git/commits/$sha" --jq .tree.sha 2>/dev/null) || continue
  printf '%s\t%s\t%s\n' "$run" "$tree" "$conclusion"
done
exit 0
