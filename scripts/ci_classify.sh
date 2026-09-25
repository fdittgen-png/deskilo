#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #1446 C2 — the ONE invocation of the change classifier. The quality
# workflow and the web workflow both call this through
# .github/actions/classify-change, so there is one decision about what a
# pull request requires and no second path list to drift from it.
#
#   scripts/ci_classify.sh --event <event> --base <sha> --out <dir> [--repo <dir>]
#
# Writes <dir>/changes.nul (the complete diff, NUL-delimited, renames
# under both names) and <dir>/classification.txt, and appends one
# `<discipline>=<verdict>` line per discipline to $GITHUB_OUTPUT.
#
# Fail-closed by construction:
#   - a base that cannot be resolved     -> --no-base, everything required
#   - a diff git could not write         -> --diff-problem, everything required
#   - a classifier that exits nonzero    -> this script exits nonzero, no
#                                           verdict; every consumer treats a
#                                           missing verdict as `required`
#   - a verdict file missing a line      -> exit 1, same
# Nothing here can produce `not_applicable` without the classifier
# saying so in classification.txt, which rides the run as an artifact.
set -euo pipefail

EVENT=""; BASE=""; OUT=""; REPO="."
while [ $# -gt 0 ]; do
  case "$1" in
    --event) EVENT="$2"; shift 2 ;;
    --base)  BASE="$2";  shift 2 ;;
    --out)   OUT="$2";   shift 2 ;;
    --repo)  REPO="$2";  shift 2 ;;
    *) echo "::error::unknown argument $1"; exit 2 ;;
  esac
done
[ -n "$EVENT" ] && [ -n "$OUT" ] || { echo "::error::usage: --event <event> --base <sha> --out <dir> [--repo <dir>]"; exit 2; }
# The classifier as a seam, so a test can prove what happens when it dies.
TOOL="${CI_CLASSIFY_TOOL:-tool/ci_classify.dart}"

mkdir -p "$OUT"
flags=()
if [ "$EVENT" = "pull_request" ]; then
  if [ -z "$BASE" ] || ! git -C "$REPO" cat-file -e "$BASE^{commit}" 2>/dev/null; then
    echo "the base commit '${BASE:-(none)}' cannot be resolved: the diff cannot be trusted"
    flags+=(--no-base)
  elif ! git -C "$REPO" diff --name-status -z "$BASE" HEAD > "$OUT/changes.nul"; then
    echo "git diff $BASE..HEAD failed: the change list is incomplete"
    flags+=(--diff-problem "git diff --name-status $BASE HEAD exited nonzero")
  fi
fi

dart run "$TOOL" --event "$EVENT" --changes "$OUT/changes.nul" \
  ${flags[@]+"${flags[@]}"} --out "$OUT/classification.txt"

# The verdict file is what every consumer reads: one line per discipline,
# each verdict one of the two words the workflows compare against. A
# classifier that exited 0 without writing it is caught here — the first
# run of this script on a broken classifier passed, because `grep -c` on
# a missing file printed nothing and `[ "" -ne 1 ]` is not true.
if [ ! -s "$OUT/classification.txt" ]; then
  echo "::error::the classifier exited 0 but wrote no $OUT/classification.txt"
  exit 1
fi
for discipline in database web; do
  n=$(grep -cE "^$discipline\|(required|not_applicable)\|" "$OUT/classification.txt" || true)
  if [ "${n:-0}" -ne 1 ]; then
    echo "::error::classification.txt carries $n verdict lines for '$discipline', expected exactly one"
    exit 1
  fi
done
