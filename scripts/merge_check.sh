#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #3717 -- the merge step's evidence in one command and one verdict line.
#
#   scripts/merge_check.sh <pr> [worktree-at-the-pr-head] [--contains <branch>]...
#
# Prints, for pull request <pr>:
#   scope     git diff --shortstat origin/master...<head>, to compare with the
#             scope the pull request names;
#   behind    how many master commits the head lacks;
#   gate      the body's "Gate: analyze ok · lint ok · <n> listed tests ok" line;
#   closes    every closing keyword in the title and body; an issue the
#             body closes and the title does not is refused (#3675:
#             scripts/closing_keywords.sh);
#   tools     tool or AI lines in the body or in commits since the guard's
#             cutoff (must be none);
#   contains  for each --contains <branch>: whether it is an ancestor of the head;
#   preflight with a worktree at the head: what `tool/preflight.dart --list`
#             names, and whether its generators left the tree clean.
# The last line is the verdict: OK, or the first reason it is not.
set -euo pipefail
pr="${1:?usage: merge_check.sh <pr> [worktree] [--contains <branch>]...}"
shift
worktree=""
contains=()
while [ $# -gt 0 ]; do
  case "$1" in
    --contains) contains+=("$2"); shift 2 ;;
    *) worktree="$1"; shift ;;
  esac
done
repo="${DESKILO_REPO:-fdittgen-png/deskilo}"
verdict="OK"
fail() { if [ "$verdict" = OK ]; then verdict="NOT OK: $1"; fi; }

branch=$(gh pr view "$pr" --repo "$repo" --json headRefName --jq .headRefName)
title=$(gh pr view "$pr" --repo "$repo" --json title --jq .title)
body_only=$(gh pr view "$pr" --repo "$repo" --json body --jq .body)
body=$(printf '%s\n%s' "$title" "$body_only")
git fetch -q origin master "$branch"
head="origin/$branch"

echo "scope:    $(git diff --shortstat "origin/master...$head")"
behind=$(git rev-list --count "$head..origin/master")
echo "behind:   $behind"

gate=$(printf '%s\n' "$body" | grep -E '^Gate: analyze ok · lint ok · [0-9]+ listed tests ok' || true)
echo "gate:     ${gate:-missing}"
[ -n "$gate" ] || fail "no Gate line in the body"

echo "closes:   $(printf '%s\n' "$body" | grep -ioE '(close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved) #[0-9]+' | tr '\n' ' ')"
# shellcheck source=scripts/closing_keywords.sh
source "$(dirname "$0")/closing_keywords.sh"
stray=$(stray_closes "$title" "$body_only" | sed 's/^/#/' | tr '\n' ' ' | sed 's/ $//')
[ -z "$stray" ] || fail "the body closes $stray, the title does not"

# One definition, one cutoff: the CI guard itself (#3872), fed the head, the
# merge base, the title and the body. Its exit 2 (a range it could not read)
# is a failure here too, never a pass.
guard_out=$(BASE=$(git merge-base origin/master "$head") HEAD=$(git rev-parse "$head") \
  PR_TITLE="$title" PR_BODY="$body_only" bash "$(dirname "$0")/tool_lines_check.sh" 2>&1) && guard_rc=0 || guard_rc=$?
tools=$(printf '%s\n' "$guard_out" | grep -c '^::error::' || true)
[ "$guard_rc" != 2 ] || tools=unreadable
echo "tools:    $tools"
[ "$guard_rc" = 0 ] || fail "tool lines in the body or the commits"

for b in ${contains[@]+"${contains[@]}"}; do
  git fetch -q origin "$b"
  if git merge-base --is-ancestor "origin/$b" "$head"; then
    echo "contains: $b yes"
  else
    echo "contains: $b NO"; fail "$b is not contained"
  fi
done

if [ -n "$worktree" ]; then
  if [ "$(git -C "$worktree" rev-parse HEAD)" != "$(git rev-parse "$head")" ]; then
    fail "the worktree is not at the pull request's head"
  fi
  echo "preflight:"
  (cd "$worktree" && dart run tool/preflight.dart --base origin/master --list) | sed 's/^/  /' \
    || fail "preflight --list did not run"
  dirty=$(git -C "$worktree" status --porcelain | wc -l | tr -d ' ')
  echo "generated: $dirty file(s) changed in the worktree"
  [ "$dirty" = 0 ] || fail "the worktree is not clean after the generators"
fi

echo "verdict:  $verdict"
[ "$verdict" = OK ]
