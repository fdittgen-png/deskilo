#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# #3335 O2 — two real connections, one e-invoice dispatch. A single pgTAP
# transaction cannot show a race, so each contender is its own psql process
# on CI's disposable database.
#   1. A holds the claim's row lock inside an open transaction; B (a request
#      with another owner) must WAIT on that lock, then find the dispatch
#      already claimed.
#   2. Eight claims fired together on one prepared record: exactly one wins,
#      and the record is at generation 1.
set -euo pipefail
url=${1:?usage: einvoice_claim_race.sh DATABASE_URL}
# fresh ids per run: invoices cannot be deleted (invoices_no_mutation, 0183),
# so a rerun on the same database must not collide with an earlier fixture
uid() { uuidgen | tr 'A-Z' 'a-z'; }
ws=$(uid)
owner=$(uid)
scratch=$(mktemp -d)
# Only the transmissions (and their artifacts, by cascade) are removable; the
# disposable database drops the rest. A cleanup failure is a warning and never
# turns a held race red.
cleanup() {
  local original_status=$?
  psql "$url" -X -q -v ON_ERROR_STOP=1 >/dev/null 2>&1 <<SQL ||
delete from public.invoice_transmissions where workspace_id = '$ws';
SQL
    echo "::warning::e-invoice race fixture cleanup failed" >&2
  rm -rf "$scratch"
  exit "$original_status"
}
trap cleanup EXIT
psql "$url" -X -q -v ON_ERROR_STOP=1 <<SQL
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values ('$owner','00000000-0000-0000-0000-000000000000','authenticated','authenticated','einvoice-race@deskilo.test','',now(),now(),now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by)
values ('$ws','E-invoice race','FR','EUR','Europe/Paris','$owner');
insert into public.members (workspace_id, user_id, is_owner, is_admin) values ('$ws','$owner',true,true);
insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency, member_name, workspace_name, issuer_name, signature)
select '$ws', m.id, m.id, 'RACE-1', 'x', '[]'::jsonb, 100, 'EUR', 'M', 'W', 'M', 'sig' from public.members m where m.workspace_id = '$ws';
SQL
prepare() {
  psql "$url" -X -qAt -v ON_ERROR_STOP=1 <<SQL
select (public.prepare_einvoice_v1('$ws', i.id, 'generic', '$1', 'prod', '$owner', 'T', 'facturX', 'h1', 'f.pdf', 'application/pdf', '', '', '\x01'::bytea))->>'id'
  from public.invoices i where i.workspace_id = '$ws';
SQL
}
wait_marker() {
  local i=0
  while (( i < 100 )); do
    [[ -e "$1" ]] && return 0
    sleep 0.1
    ((i+=1))
  done
  echo "::error::holder did not take its claim" >&2; return 1
}
wait_lock() {
  local i=0 result
  while (( i < 100 )); do
    result=$(psql "$url" -X -qAt -v ON_ERROR_STOP=1 -c "select count(*) from pg_stat_activity where application_name = '$1' and wait_event_type = 'Lock'")
    [[ "$result" != 0 ]] && return 0
    sleep 0.1
    ((i+=1))
  done
  echo "::error::contender did not wait on a lock: $1" >&2; return 1
}
# 1. a holder, then a contender that must wait for it
t1=$(prepare government)
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/holder" 2>&1 <<SQL &
begin;
select public.claim_einvoice_dispatch_v1('$t1', gen_random_uuid(), 150)->>'claimed';
\! touch '$scratch/ready'
select pg_sleep(4);
commit;
SQL
a=$!
wait_marker "$scratch/ready"
PGAPPNAME=einvoice-race-b psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/contender" 2>&1 <<SQL &
select public.claim_einvoice_dispatch_v1('$t1', gen_random_uuid(), 150)->>'claimed';
SQL
b=$!
wait_lock einvoice-race-b
wait "$a"; wait "$b"
grep -qx true "$scratch/holder"
grep -qx false "$scratch/contender"
# 2. eight at once on a fresh record: one winner, generation 1
t2=$(prepare customer)
pids=()
for n in 1 2 3 4 5 6 7 8; do
  psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/c$n" 2>&1 <<SQL &
select public.claim_einvoice_dispatch_v1('$t2', gen_random_uuid(), 150)->>'claimed';
SQL
  pids+=($!)
done
for p in "${pids[@]}"; do wait "$p"; done
winners=$(cat "$scratch"/c? | grep -cx true || true)
if [[ "$winners" != 1 ]]; then
  echo "::error::$winners of 8 simultaneous claims won (expected exactly 1)" >&2
  exit 1
fi
gen=$(psql "$url" -X -qAt -v ON_ERROR_STOP=1 -c "select generation from public.invoice_transmissions where id = '$t2'")
[[ "$gen" == 1 ]] || { echo "::error::generation $gen after one winner" >&2; exit 1; }
echo "e-invoice claim race: one owner per record"
