#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #2561 C2 -- the physical topology fixture: P (personal), W-A and W-B
# (workspace) as three separate Supabase stacks, each with its own
# Postgres, Auth and Storage containers, project id, ports, data volumes
# and JWT secret.
#
#   W-A  the job's one replayed stack (.github/actions/local-stack, no
#        workdir); the ordinary database disciplines share it.
#   P    a stack of its own, started by the same action with a workdir.
#   W-B  a second stack of its own, likewise.
#
# This script never starts a stack (test/lint/local_stack_harness_test.dart
# keeps every start in the composite action). It prepares the two
# project directories, seeds the minimal fixtures through each stack's
# own Auth admin API and database, writes the target descriptor the Dart
# consumer reads, and stops what it prepared.
#
#   prepare   project directories for P and W-B (distinct ids, ports, secrets)
#   seed      users, the equal-id workspace at W-A and W-B, one reservation each,
#             and at W-A the invoice-preview fixture (#2585: a member, a
#             stranger of another workspace, seeded money)
#   down      stop P and W-B, remove the W-A fixture rows
#
# Every operation names its target explicitly and refuses anything that is
# not a disposable local stack of this job. The descriptor holds the local
# stacks' throwaway keys and is never uploaded.
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
DIR=${TOPOLOGY_DIR:-${RUNNER_TEMP:-/tmp}/deskilo-topology}
FILE=$DIR/topology.json
PASSWORD='Topology-2026-fixture'
# Equal local workspace id on W-A and W-B: the collision the harness exists for.
WS=00000000-0000-4000-8000-0000000e0001

fail() { echo "::error::topology: $*"; exit 1; }
say() { printf '  %s\n' "$*"; }

# status <workdir|-> -> KEY="value" lines of one stack
status() {
  if [ "$1" = - ]; then supabase status -o env; else supabase status --workdir "$1" -o env; fi
}
val() { sed -n "s/^$1=\"\(.*\)\"$/\1/p"; }

# A target is local and disposable or it is refused, before any seed.
local_only() {
  case "$1" in
    http://127.0.0.1:*|http://localhost:*) ;;
    *) fail "refusing $2: $1 is not a local stack of this job" ;;
  esac
}

# An ES256 signing key (a JWK set of one) from openssl alone.
new_signing_key() {
  local pem; pem=$(mktemp)
  openssl ecparam -name prime256v1 -genkey -noout -out "$pem" || return 1
  python3 - "$pem" "$1" <<'PY' || { rm -f "$pem"; return 1; }
import base64, json, re, subprocess, sys, uuid
text = subprocess.run(['openssl', 'ec', '-in', sys.argv[1], '-text', '-noout'],
                      capture_output=True, text=True, check=True).stdout
def block(name):
    m = re.search(name + r':\s*((?:[0-9a-f]{2}:?\s*)+)', text)
    return bytes.fromhex(re.sub(r'[^0-9a-f]', '', m.group(1)))
d = block('priv').lstrip(b'\x00').rjust(32, b'\x00')
pub = block('pub')
assert pub[0] == 4 and len(pub) == 65, 'unexpected public key'
b64 = lambda b: base64.urlsafe_b64encode(b).rstrip(b'=').decode()
jwk = {'kty': 'EC', 'kid': str(uuid.uuid4()), 'use': 'sig', 'key_ops': ['sign', 'verify'],
       'alg': 'ES256', 'ext': True, 'crv': 'P-256', 'd': b64(d), 'x': b64(pub[1:33]), 'y': b64(pub[33:])}
json.dump([jwk], open(sys.argv[2], 'w'))
PY
  rm -f "$pem"
}

prepare() {
  rm -rf "$DIR"
  mkdir -p "$DIR"
  for spec in p:54420 wb:54520; do
    name=${spec%%:*}; base=${spec##*:}
    mkdir -p "$DIR/$name/supabase"
    ln -s "$ROOT/supabase/migrations" "$DIR/$name/supabase/migrations"
    cat > "$DIR/$name/supabase/config.toml" <<TOML
project_id = "deskilo_topology_$name"

[db]
port = $((base + 2))
shadow_port = $base
major_version = 17

[db.migrations]
enabled = true

[auth]
enabled = true
site_url = "http://127.0.0.1:3000"
enable_signup = true
jwt_secret = "$(openssl rand -hex 32)"
signing_keys_path = "./signing_keys.json"

[auth.email]
enable_signup = true
enable_confirmations = true

[storage]
enabled = true

[api]
enabled = true
port = $((base + 1))
schemas = ["public"]
extra_search_path = ["public", "extensions"]

[studio]
enabled = false

[inbucket]
enabled = false

[analytics]
enabled = false

[realtime]
enabled = false

[edge_runtime]
enabled = false
TOML
    # The CLI signs user tokens with a signing key it ships as a default,
    # so a secret alone leaves every local stack accepting the others'
    # tokens (run 39015390424). Each stack gets a key of its own.
    new_signing_key "$DIR/$name/supabase/signing_keys.json" || fail "$name: no signing key could be generated"
  done
  say "prepared P and W-B under $DIR"
}

mkuser() { # api service email -> user id
  curl -sf -X POST "$1/auth/v1/admin/users" -H "apikey: $2" -H "Authorization: Bearer $2" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"$3\",\"password\":\"$PASSWORD\",\"email_confirm\":true}" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])'
}

# seed_workspace <db> <suffix a|b> <owner id> <timezone> <currency> -> window start, ISO UTC
seed_workspace() {
  local db=$1 x=$2 owner=$3 tz=$4 cur=$5
  psql "$db" -qX -v ON_ERROR_STOP=1 >/dev/null <<SQL || return 1
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by)
values ('$WS', 'Topology $x', 'FR', '$cur', '$tz', '$owner');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin)
values ('0000000e-0${x}02-4000-8000-0000000e0${x}02', '$WS', '$owner', true, true);
insert into public.levels (id, workspace_id, name)
values ('0000000e-0${x}05-4000-8000-0000000e0${x}05', '$WS', 'Ground');
insert into public.offices (id, workspace_id, level_id, name, x, y, w, h)
values ('0000000e-0${x}06-4000-8000-0000000e0${x}06', '$WS',
        '0000000e-0${x}05-4000-8000-0000000e0${x}05', 'Room', 0, 0, 10, 10);
insert into public.desks (id, workspace_id, office_id, x, y, w, h)
values ('0000000e-0${x}07-4000-8000-0000000e0${x}07', '$WS',
        '0000000e-0${x}06-4000-8000-0000000e0${x}06', 1, 1, 4, 2);
insert into public.seats (id, workspace_id, desk_id, x, y)
values ('0000000e-0${x}03-4000-8000-0000000e0${x}03', '$WS',
        '0000000e-0${x}07-4000-8000-0000000e0${x}07', 1, 1);
SQL
  psql "$db" -qtAX -v ON_ERROR_STOP=1 <<SQL | head -1
with r as (
  insert into public.reservations (id, workspace_id, member_id, seat_id, starts_at, ends_at)
  values ('0000000e-0${x}0a-4000-8000-0000000e0${x}0a', '$WS',
          '0000000e-0${x}02-4000-8000-0000000e0${x}02',
          '0000000e-0${x}03-4000-8000-0000000e0${x}03',
          date_trunc('day', now()) + interval '1 day 9 hours',
          date_trunc('day', now()) + interval '1 day 13 hours')
  returning starts_at)
select to_char(starts_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') from r;
SQL
}

# The invoice-preview fixture (#2585), W-A only: a workspace of its own, one
# member with money written here as plain numbers (35.00 fee + 10.00 supply
# in 2026-09; 35.00 fee - 50.00 advance in 2026-08; nothing before they
# joined), independent of the Dart decoder and of the SQL that computes it.
PWS=00000000-0000-4000-8000-000000258501
PMEMBER=00000000-0000-4000-8000-000000258502
seed_preview() { # db owner id, member id
  psql "$1" -qX -v ON_ERROR_STOP=1 >/dev/null <<SQL || return 1
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by,
                               street, city, postal_code, vat_regime, vat_id, feature_flags)
values ('$PWS', 'Preview 2585', 'FR', 'EUR', 'Europe/Paris', '$2', '1 rue du Pilote', 'Pezenas',
        '34120', 'vat_registered', 'FR12345678901', '{"invoicing":true,"numberSequences":true}');
insert into public.members (workspace_id, user_id, is_owner, is_admin, joined_at)
values ('$PWS', '$2', true, true, '2026-01-01');
insert into public.members (id, workspace_id, user_id, subscription_pct, joined_at, customer_capacity)
values ('$PMEMBER', '$PWS', '$3', 1, '2026-01-01', 'consumer');
insert into public.vat_rates (workspace_id, label, percent, is_default) values ('$PWS', 'Synthetic standard', 20, true);
delete from public.fee_bands where workspace_id = '$PWS';
insert into public.fee_bands (workspace_id, from_pct, to_pct, fee_cents, overage_fee_cents)
values ('$PWS', 0, 100, 3500, 1000);
update public.profiles set first_name = 'Synthetic', last_name = 'Client', country_code = 'FR',
       street = '2 rue du Test', city = 'Pezenas', postal_code = '34120' where id = '$3';
insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, vat_percent)
values ('$PWS', '$PMEMBER', 'charge', 'adjustment', 1000, 'Zero-rated supply', '2026-09', 0);
insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
values ('$PWS', '$PMEMBER', 'credit', 'payment', 5000, 'Advance', '2026-08');
SQL
}

seed() {
  [ -d "$DIR/p" ] && [ -d "$DIR/wb" ] || fail "prepare has not run: $DIR"
  local run=$$
  declare -A API ANON SERVICE DB
  for spec in wa:- p:"$DIR/p" wb:"$DIR/wb"; do
    name=${spec%%:*}; wd=${spec#*:}
    out=$(status "$wd") || fail "$name: no running stack (supabase status failed)"
    API[$name]=$(val API_URL <<<"$out"); ANON[$name]=$(val ANON_KEY <<<"$out")
    SERVICE[$name]=$(val SERVICE_ROLE_KEY <<<"$out"); DB[$name]=$(val DB_URL <<<"$out")
    [ -n "${API[$name]}" ] && [ -n "${ANON[$name]}" ] && [ -n "${SERVICE[$name]}" ] && [ -n "${DB[$name]}" ] \
      || fail "$name: supabase status reports an incomplete stack"
    local_only "${API[$name]}" "$name"
  done
  [ "${API[wa]}" != "${API[p]}" ] && [ "${API[wa]}" != "${API[wb]}" ] && [ "${API[p]}" != "${API[wb]}" ] \
    || fail "two roles share one API address: ${API[wa]} ${API[p]} ${API[wb]}"

  p_user=$(mkuser "${API[p]}" "${SERVICE[p]}" "topology-p-$run@deskilo.test") || fail "P: user"
  a_user=$(mkuser "${API[wa]}" "${SERVICE[wa]}" "topology-a-$run@deskilo.test") || fail "W-A: user"
  a_stranger=$(mkuser "${API[wa]}" "${SERVICE[wa]}" "topology-a-stranger-$run@deskilo.test") || fail "W-A: stranger"
  b_user=$(mkuser "${API[wb]}" "${SERVICE[wb]}" "topology-b-$run@deskilo.test") || fail "W-B: user"

  pv_owner=$(mkuser "${API[wa]}" "${SERVICE[wa]}" "preview-owner-$run@deskilo.test") || fail "W-A: preview owner"
  pv_member=$(mkuser "${API[wa]}" "${SERVICE[wa]}" "preview-member-$run@deskilo.test") || fail "W-A: preview member"
  seed_preview "${DB[wa]}" "$pv_owner" "$pv_member" || fail "W-A: preview fixture"

  start=$(seed_workspace "${DB[wa]}" a "$a_user" Europe/Paris EUR) || fail "W-A: fixture"
  start_b=$(seed_workspace "${DB[wb]}" b "$b_user" America/New_York USD) || fail "W-B: fixture"
  [ "$start" = "$start_b" ] || fail "the two windows differ: $start $start_b"
  from=$(date -u -d "$start - 1 hour" +%Y-%m-%dT%H:%M:%SZ)
  to=$(date -u -d "$start + 5 hours" +%Y-%m-%dT%H:%M:%SZ)

  cat > "$FILE" <<JSON
{
  "run": "$run",
  "password": "$PASSWORD",
  "workspaceId": "$WS",
  "windowFrom": "$from",
  "windowTo": "$to",
  "p":  {"url": "${API[p]}",  "anon": "${ANON[p]}",  "service": "${SERVICE[p]}",
         "user": {"id": "$p_user", "email": "topology-p-$run@deskilo.test"}},
  "wa": {"url": "${API[wa]}", "anon": "${ANON[wa]}", "service": "${SERVICE[wa]}",
         "user": {"id": "$a_user", "email": "topology-a-$run@deskilo.test"},
         "stranger": {"id": "$a_stranger", "email": "topology-a-stranger-$run@deskilo.test"},
         "reservationId": "0000000e-0a0a-4000-8000-0000000e0a0a", "timezone": "Europe/Paris",
         "preview": {"workspaceId": "$PWS", "memberId": "$PMEMBER",
                     "member": {"id": "$pv_member", "email": "preview-member-$run@deskilo.test"}}},
  "wb": {"url": "${API[wb]}", "anon": "${ANON[wb]}", "service": "${SERVICE[wb]}",
         "user": {"id": "$b_user", "email": "topology-b-$run@deskilo.test"},
         "reservationId": "0000000e-0b0a-4000-8000-0000000e0b0a", "timezone": "America/New_York"}
}
JSON
  say "seeded: P ${API[p]}, W-A ${API[wa]}, W-B ${API[wb]} (descriptor $FILE)"
}

cleanup() {
  # The shared W-A stack is disposable with the job; its fixture rows go
  # anyway so a later step of this job never meets them.
  out=$(supabase status -o env 2>/dev/null) || out=
  db=$(val DB_URL <<<"$out")
  if [ -n "$db" ]; then
    psql "$db" -qX -c "delete from public.workspaces where id in ('$WS', '$PWS')" >/dev/null 2>&1 || true
  fi
  for name in p wb; do
    [ -d "$DIR/$name" ] && supabase stop --workdir "$DIR/$name" --no-backup >/dev/null 2>&1 || true
  done
  rm -f "$FILE"
}

case "${1:-}" in
  prepare) prepare ;;
  seed) seed ;;
  down) cleanup ;;
  *) echo "usage: topology_stacks.sh prepare|seed|down" >&2; exit 2 ;;
esac
