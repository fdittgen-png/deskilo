#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# A different credential in an allowlisted fixture must still fail; a removed
# credential must remain detectable in the PR's commit range.
set -euo pipefail
scanner=${GITLEAKS_BIN:?pinned scanner path required}
config="$(pwd)/.gitleaks.toml"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
git -C "$scratch" init --quiet
git -C "$scratch" config user.name "Scanner fixture"
git -C "$scratch" config user.email "scanner@example.test"
mkdir -p "$scratch/test/features/money"
file="$scratch/test/features/money/accounting_connection_test.dart"
printf 'baseline\n' > "$file"
git -C "$scratch" add .
git -C "$scratch" commit --quiet -m baseline
base=$(git -C "$scratch" rev-parse HEAD)
prefix=ghp_
printf "token = '%s%s';\n" "$prefix" 'AbCdEf0123456789GhIjKlMnOpQrStUvWxYz' > "$file"
set +e
"$scanner" dir "$scratch" --config "$config" --redact=100 --no-banner --ignore-gitleaks-allow > "$scratch/scan.log" 2>&1
code=$?
set -e
[[ "$code" == 1 ]] || { echo "A new credential escaped the fixture exception" >&2; exit 1; }
git -C "$scratch" add test
git -C "$scratch" commit --quiet -m introduced
printf 'baseline\n' > "$file"
git -C "$scratch" add test
git -C "$scratch" commit --quiet -m removed
"$scanner" dir "$scratch/test" --config "$config" --redact=100 --no-banner --ignore-gitleaks-allow > "$scratch/scan.log" 2>&1
set +e
"$scanner" git "$scratch" --config "$config" --redact=100 --no-banner --ignore-gitleaks-allow --log-opts="$base..HEAD" > "$scratch/scan.log" 2>&1
code=$?
set -e
[[ "$code" == 1 ]] || { echo "The PR range missed a removed credential" >&2; exit 1; }
echo "Secret-scanner refusal and removed-credential checks passed"
