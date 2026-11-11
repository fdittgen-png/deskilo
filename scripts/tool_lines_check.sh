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

rule_since=1794373200  # 2026-11-11T05:00:00Z: the rule's start; older commits are left as they are (owner 2026-11-11). Remove once no open branch predates it.
head=${HEAD:-HEAD}
base=${BASE:-}
# Anchored to the shapes a tool writes, never a bare phrase: the footer line
# ("Generated with [Tool]", with or without its robot), the trailer lines (a
# co-author trailer is recognised by the tool's address, not by a first name),
# the session trailer and a session link.
pattern='^[[:space:]]*(🤖[[:space:]]*)?generated with[[:space:]]+\[?(claude|codex|copilot|chatgpt|cursor)|^[[:space:]]*co-authored-by:.*<[^>]*@(anthropic\.com|openai\.com)>|^[[:space:]]*claude-session:|https?://claude\.ai/code/session'
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
# A range that cannot be read is a failure of its own, never a pass.
if ! shas=$(git rev-list "${range[@]}" 2>&1); then
  echo "::error::the commit range ${range[*]} cannot be read, so no commit message was checked: $shas"
  exit 2
fi
while IFS= read -r sha; do
  [ -n "$sha" ] || continue
  [ "$(git log -1 --format=%at "$sha")" -ge "$rule_since" ] || continue
  scan "commit ${sha:0:9}" "$(git log -1 --format=%B "$sha")"
done <<< "$shas"
[ -z "${PR_TITLE:-}" ] || scan "the pull request title" "$PR_TITLE"
[ -z "${PR_BODY:-}" ] || scan "the pull request text" "$PR_BODY"
exit $status
