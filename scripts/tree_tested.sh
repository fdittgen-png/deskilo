#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #3670 -- has a pull request already tested this exact tree green? Given
# the candidate runs on stdin (one per line: run number, tree hash of the
# run's head commit, conclusion; separated by a tab), print the number of
# the first run whose tree equals the one asked for and whose conclusion is
# `success`; exit 1 when there is none (a different tree, or only failed or
# cancelled runs): the full run happens then.
#
#   scripts/tree_candidates.sh | scripts/tree_tested.sh "$(git rev-parse HEAD^{tree})"
set -uo pipefail

tree=${1:?tree hash}
while IFS=$'\t' read -r run candidate conclusion; do
  if [ "$candidate" = "$tree" ] && [ "$conclusion" = "success" ]; then
    echo "$run"
    exit 0
  fi
done
exit 1
