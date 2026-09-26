#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #1446 C5a — a generated tree is what its generator writes, or the job
# is red and names the files.
#
#   scripts/generated_drift.sh '<generator command>' -- <pathspec>...
#
# Runs the generator, then lists every tracked file under the pathspecs
# whose content differs from HEAD and every untracked file the generator
# left there. Either list non-empty is exit 1. A generator that fails is
# exit 2 and NOTHING is compared: a diff over a tree the generator did not
# finish writing proves nothing either way. HARD RULE 3 (AGENT_RULES.md)
# said "zero drift on push" for two years; on 2026-09-25 master carried
# five `.g.dart` files a provider hash behind their sources, because the
# required job compiles what is committed and never regenerates.
set -uo pipefail

usage() { echo "usage: $0 '<generator command>' -- <pathspec>..." >&2; exit 64; }
GEN="${1:-}"; [ -n "$GEN" ] || usage
[ "${2:-}" = "--" ] || usage
shift 2
[ $# -gt 0 ] || usage

echo "\$ $GEN"
if ! bash -c "$GEN"; then
  echo "::error::generated_drift: the generator failed — nothing was compared"
  exit 2
fi

modified=$(git diff HEAD --name-only -- "$@")
new=$(git ls-files --others --exclude-standard -- "$@")
if [ -z "$modified" ] && [ -z "$new" ]; then
  echo "generated_drift: every file under $* is what the generator writes"
  exit 0
fi
echo "::error::generated_drift: the commit does not carry what '$GEN' writes — run it and commit:"
[ -z "$modified" ] || printf '%s\n' "$modified" | sed 's/^/  modified: /'
[ -z "$new" ] || printf '%s\n' "$new" | sed 's/^/  new:      /'
exit 1
