#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# A clean final tree does not excuse a secret introduced then removed in a PR.
set -euo pipefail
scanner=${GITLEAKS_BIN:?pinned scanner path required}
config="$(git rev-parse --show-toplevel)/.gitleaks.toml"
base=${1:-}
head=${2:-}
# Export actual source contents, including new files, without ignored build
# caches. Tracked files are scanned even if their path matches .gitignore.
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
git ls-files -z --cached --others --exclude-standard | tar -c --null -T - -f "$scratch/source.tar"
mkdir "$scratch/tree"
tar -xf "$scratch/source.tar" -C "$scratch/tree"
(cd "$scratch/tree"; "$scanner" dir . --config "$config" --redact=100 --no-banner --ignore-gitleaks-allow)
if [[ -n "$base" || -n "$head" ]]; then
  [[ "$base" =~ ^[0-9a-f]{40}$ && "$head" =~ ^[0-9a-f]{40}$ ]] || {
    echo "The PR scan requires both exact commit SHAs" >&2; exit 2;
  }
  git cat-file -e "$base^{commit}"
  git cat-file -e "$head^{commit}"
  "$scanner" git . --config "$config" --redact=100 --no-banner --ignore-gitleaks-allow --log-opts="$base..$head"
elif [[ "${GITHUB_EVENT_NAME:-}" == pull_request ]]; then
  echo "The PR range is missing; refusing an incomplete scan" >&2
  exit 2
fi
