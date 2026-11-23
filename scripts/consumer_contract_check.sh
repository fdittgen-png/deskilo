#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #3731 (K4) — the released apps still work on the schema after all migrations.
#
#   bash scripts/consumer_contract_check.sh "$DB_URL"
#
# For every contracts/consumer/releases/*.json (each extracted from its release tag by
# tool/consumer_contract.dart), every function the release calls must still exist and accept the parameters it
# sends, and every table and column it reads or writes must still be there. A failure names the object and the last
# migration that defines it.
#
# It first proves it can fail: a planted contract (a parameter and a table that do not exist) must be reported, or
# the check itself is broken and the step fails.
set -euo pipefail
DB_URL="${1:?usage: consumer_contract_check.sh DB_URL}"
here="$(cd "$(dirname "$0")/.." && pwd)"
body="$here/scripts/consumer_contract_check.sql"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

check() { # $1 = contract JSON file; prints one failure per line
  { printf 'with c as (select $cc$'; cat "$1"; printf '$cc$::jsonb as j),\n'; grep -v '^--' "$body"; } > "$tmp/q.sql"
  psql "$DB_URL" -v ON_ERROR_STOP=1 -At -F $'\t' -f "$tmp/q.sql"
}

last_definer() { # $1 = object name: the last migration that creates it
  grep -lE "(function|table|view)[[:space:]]+(if not exists[[:space:]]+)?public\.$1\b" "$here"/supabase/migrations/*.sql 2>/dev/null \
    | sort | tail -1 | xargs -r basename
}

cat > "$tmp/planted.json" <<'EOF'
{"functions": {"deskilo_schema_version": [["p_consumer_contract_planted"]]}, "optional": [],
 "tables": {"consumer_contract_planted_table": null}}
EOF
planted="$(check "$tmp/planted.json" | wc -l | tr -d ' ')"
if [ "$planted" != 2 ]; then
  echo "::error::consumer contract self-test: a planted parameter and table gave $planted findings, not 2 — the check is broken"
  exit 1
fi

shopt -s nullglob
files=("$here"/contracts/consumer/releases/*.json)
if [ ${#files[@]} -eq 0 ]; then
  echo "::error::no release contract in contracts/consumer/releases"
  exit 1
fi
rc=0
for f in "${files[@]}"; do
  rel="$(basename "$f" .json)"
  out="$(check "$f")"
  if [ -z "$out" ]; then
    echo "consumer contract $rel: every call and column it uses is still served"
    continue
  fi
  rc=1
  while IFS=$'\t' read -r msg obj; do
    echo "::error::release $rel — $msg (last defined in $(last_definer "$obj"))"
  done <<< "$out"
done
exit $rc
