#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #3670 -- the candidates tree_tested.sh reads: the latest Quality runs of
# pull-request heads, as "run number<TAB>tree of the head commit<TAB>conclusion".
# A lookup that fails prints nothing, so the full run happens.
set -uo pipefail

repo=${GITHUB_REPOSITORY:?repository}
gh api "repos/$repo/actions/workflows/quality.yml/runs?event=pull_request&status=completed&per_page=${CANDIDATE_RUNS:-60}" \
  --jq '.workflow_runs[] | [.run_number, .head_sha, .conclusion] | @tsv' 2>/dev/null |
while IFS=$'\t' read -r run sha conclusion; do
  [ "$conclusion" = "success" ] || continue
  tree=$(gh api "repos/$repo/git/commits/$sha" --jq .tree.sha 2>/dev/null) || continue
  printf '%s\t%s\t%s\n' "$run" "$tree" "$conclusion"
done
exit 0
