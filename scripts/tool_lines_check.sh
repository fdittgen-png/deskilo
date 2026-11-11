#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #3677 -- no tool or AI mention in a commit message or in a pull request's
# title and text (docs/AGENT_RULES.md). Reads the commits of BASE..HEAD and,
# when set, PR_TITLE and PR_BODY from the environment; names the commit or the
# text and the line, exit 1 on any. A zero or empty BASE (a new branch) reads
# only HEAD's message.
#
#   BASE=<sha> HEAD=<sha> PR_TITLE=... PR_BODY=... scripts/tool_lines_check.sh
set -uo pipefail

head=${HEAD:-HEAD}
base=${BASE:-}
pattern='generated with|co-authored-by:.*(claude|anthropic|copilot|chatgpt|codex)|claude-session:|claude\.ai/code|noreply@anthropic\.com|^🤖'
status=0

scan() { # label, text
  local hit
  hit=$(printf '%s\n' "$2" | grep -inE "$pattern" | head -3) || true
  if [ -n "$hit" ]; then
    while IFS= read -r line; do
      echo "::error::$1 carries a tool line: $line"
    done <<< "$hit"
    status=1
  fi
}

if [ -z "$base" ] || [ "${base//0/}" = "" ]; then
  range=("$head" -1)
else
  range=("$base..$head")
fi
while IFS= read -r sha; do
  [ -n "$sha" ] || continue
  scan "commit ${sha:0:9}" "$(git log -1 --format=%B "$sha")"
done < <(git rev-list "${range[@]}")
[ -z "${PR_TITLE:-}" ] || scan "the pull request title" "$PR_TITLE"
[ -z "${PR_BODY:-}" ] || scan "the pull request text" "$PR_BODY"
exit $status
