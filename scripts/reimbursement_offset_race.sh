#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# #4203 -- a member's claim is consumed once. A reimbursement and an invoice
# offset of the SAME remaining claim both take the business's advisory lock
# and then the obligation's row, and both compare the revision they read; so
# the second waits for the first and then meets it ("stale revision"), never
# passes beside it. A single pgTAP transaction cannot show a race, so each
# contender is its own psql process on CI's disposable database. Claim 120.00;
# 50.00 reimbursed and 30.00 offset against an independent 120.00 invoice
# first: the claim has 40.00 left, the invoice 90.00 due, 50.00 paid out.
#   (A) the reimbursement of the last 40.00 held open; the offset of the same
#       40.00 waits on the lock, then is refused as stale: 40.00 more paid out,
#       the invoice still owes 90.00;
#   (B) the reverse, on a second claim and invoice: the offset held open; the
#       reimbursement waits, then is refused: the invoice owes 50.00, nothing
#       more is paid out.
# Afterwards each claim holds exactly three allocations (50, 30, 40) adding to
# its 120.00, the loser left no cash, allocation or ledger row, and each
# winner replayed under its request id answers without a new row while a
# changed payload under it is refused. A holder that never took its lock or a
# contender that never waited fails the script: nothing here can pass empty.
# Fresh ids per run; invoices cannot be deleted (invoices_no_mutation, 0183),
# so the cleanup removes what it can and a failure is a warning.
set -euo pipefail
url=${1:?usage: reimbursement_offset_race.sh DATABASE_URL}
uid() { uuidgen | tr 'A-Z' 'a-z'; }
owner=$(uid); claimant=$(uid); e1=$(uid); e2=$(uid)
scratch=$(mktemp -d)
cleanup() {
  local original_status=$?
  if [[ -n "${ws:-}" ]]; then
    psql "$url" -X -q -v ON_ERROR_STOP=1 >/dev/null 2>&1 <<SQL ||
delete from public.workspaces where id = '$ws';
SQL
      echo "::warning::reimbursement offset race fixture cleanup failed" >&2
  fi
  rm -rf "$scratch"
  exit "$original_status"
}
trap cleanup EXIT
fixture=$(psql "$url" -X -qAt -v ON_ERROR_STOP=1 <<SQL | tail -1
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', u || '@offset-race.test', '', now(), now(), now()
  from unnest(array['$owner','$claimant']::uuid[]) u;
begin;
select set_config('request.jwt.claims', '{"sub":"$owner","role":"authenticated","aal":"aal2"}', true);
set local role authenticated;
select public.create_workspace('Offset race', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null) as ws \gset
reset role;
commit;
update public.workspaces
   set feature_flags = coalesce(feature_flags, '{}'::jsonb)
       || '{"services": true, "supplyExpenses": true, "purchases": true, "invoicing": true,
          "numberSequences": true, "vatManagement": true, "vatDeclarations": true, "inputVat": true}',
       street = '1 rue du Pilote', city = 'Pezenas', postal_code = '34120',
       vat_regime = 'vat_registered', vat_id = 'FR12345678901'
 where id = :'ws';
insert into public.members (workspace_id, user_id, is_owner, is_admin, status, subscription_pct, joined_at, customer_capacity)
values (:'ws', '$claimant', false, false, 'active', 1, '2026-01-01', 'consumer') returning id as mc \gset
insert into public.vat_rates (workspace_id, label, percent, is_default) values (:'ws', 'Synthetic standard', 20, true);
delete from public.fee_bands where workspace_id = :'ws';
update public.profiles set first_name = 'Synthetic', last_name = 'Client', country_code = 'FR',
       street = '2 rue du Test', city = 'Pezenas', postal_code = '34120' where id = '$claimant';
insert into public.events (id, workspace_id, type, action, actor_member_id, subject_member_id, payload, status, decided_at) values
 ('$e1', :'ws', 'expense', 'submitted', :'mc', :'mc', '{"amount_cents": 12000, "category": "cleaning", "note": "Cleaning"}', 'confirmed', now() - interval '2 days'),
 ('$e2', :'ws', 'expense', 'submitted', :'mc', :'mc', '{"amount_cents": 12000, "category": "cleaning", "note": "Cleaning two"}', 'confirmed', now() - interval '2 days');
insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, event_id, created_at) values
 (:'ws', :'mc', 'credit', 'expense', 12000, 'Cleaning', '2031-02', '$e1', now() - interval '1 day'),
 (:'ws', :'mc', 'credit', 'expense', 12000, 'Cleaning two', '2031-02', '$e2', now() - interval '1 day');
insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, vat_percent) values
 (:'ws', :'mc', 'charge', 'adjustment', 12000, 'Supply A', '2031-03', 20),
 (:'ws', :'mc', 'charge', 'adjustment', 12000, 'Supply B', '2031-04', 20);
select o.id as o1 from public.purchase_obligations o join public.purchase_sources s on s.purchase_id = o.purchase_id where s.source_id = '$e1' \gset
select o.id as o2 from public.purchase_obligations o join public.purchase_sources s on s.purchase_id = o.purchase_id where s.source_id = '$e2' \gset
begin;
select set_config('request.jwt.claims', '{"sub":"$owner","role":"authenticated","aal":"aal2"}', true);
set local role authenticated;
select public.create_invoice(:'ws', :'mc', '2031-03') as i1 \gset
select public.create_invoice(:'ws', :'mc', '2031-04') as i2 \gset
reset role;
commit;
\echo :ws :o1 :o2 :i1 :i2
SQL
)
read -r ws o1 o2 i1 i2 <<<"$fixture"
for v in "$ws" "$o1" "$o2" "$i1" "$i2"; do
  [[ "$v" =~ ^[0-9a-f-]{36}$ ]] || { echo "::error::fixture incomplete: '$fixture'" >&2; exit 1; }
done
. "$(dirname "${BASH_SOURCE[0]}")/lib/race.sh"
as_owner="select set_config('request.jwt.claims', '{\"sub\":\"$owner\",\"role\":\"authenticated\",\"aal\":\"aal2\"}', true); set local role authenticated;"
# reimburse OBLIGATION CENTS REVISION REQUEST / offset OBLIGATION INVOICE CENTS REVISION REQUEST
reimburse() { echo "$as_owner select 'consumed' from (select public.record_member_reimbursement_v1('$ws', '$1', $2, $3, '$4', current_date - 1, 'bank_transfer', 'race ref')) x;"; }
offset() { echo "$as_owner select 'consumed' from (select public.offset_member_claim_v1('$ws', '$1', '$2', $3, $4, '$5', '')) x;"; }
run() { q "$1" >/dev/null; }
revision() { q "select revision from public.purchase_obligations where id = '$1'"; }
# the rows a command writes: ledger / outgoing payments / allocations
counts() {
  q "select (select count(*) from public.ledger_entries where workspace_id = '$ws') || '/'
      || (select count(*) from public.outgoing_payments where workspace_id = '$ws') || '/'
      || (select count(*) from public.purchase_settlement_allocations where workspace_id = '$ws')"
}
delta() { local a b c d e f; IFS=/ read -r a b c <<<"$1"; IFS=/ read -r d e f <<<"$2"; echo "$((d - a))/$((e - b))/$((f - c))"; }
allocs() { q "select count(*) || '/' || coalesce(sum(amount_cents), 0) from public.purchase_settlement_allocations where workspace_id = '$ws' and obligation_id = '$1'"; }
due() { q "select public.invoice_still_due_cents('$1')"; }
paid_out() { q "select coalesce(sum(p.amount_cents), 0) from public.outgoing_payments p
                 join public.purchase_settlement_allocations a on a.payment_id = p.id and a.workspace_id = p.workspace_id
                where p.workspace_id = '$ws' and a.obligation_id = '$1'"; }

# the seed of each claim: 50.00 reimbursed, then 30.00 offset against its invoice
seed() { # OBLIGATION INVOICE -> prints "reimbursement-delta offset-delta"
  local before after r o
  before=$(counts); run "$(reimburse "$1" 5000 "$(revision "$1")" "$(uid)")"; after=$(counts); r=$(delta "$before" "$after")
  before=$after;    run "$(offset "$1" "$2" 3000 "$(revision "$1")" "$(uid)")"; after=$(counts); o=$(delta "$before" "$after")
  echo "$r $o"
}
seed "$o1" "$i1" >/dev/null
read -r r_delta o_delta <<<"$(seed "$o2" "$i2")"
expect "a reimbursement writes one cash-out row and one allocation" "${r_delta#*/}" "1/1"
for pair in "$o1:$i1" "$o2:$i2"; do
  expect "seed of ${pair%%:*}: the claim has 40.00 left, the invoice 90.00 due" "$(allocs "${pair%%:*}")/$(due "${pair##*:}")/$(paid_out "${pair%%:*}")" "2/8000/9000/5000"
done

wait_marker() {
  local i=0
  while (( i < 100 )); do [[ -e "$1" ]] && return 0; sleep 0.1; ((i+=1)); done
  echo "::error::holder did not take its lock" >&2; return 1
}
wait_lock() {
  local i=0 result
  while (( i < 100 )); do
    result=$(q "select count(*) from pg_stat_activity where application_name = '$1' and wait_event_type = 'Lock'")
    [[ "$result" != 0 ]] && return 0
    sleep 0.1; ((i+=1))
  done
  echo "::error::contender did not wait on a lock: $1" >&2; return 1
}
# race NAME HOLDER-SQL CONTENDER-SQL: the holder commits its consumption; the
# contender waits for it and is refused as stale
race() {
  psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/$1-holder" 2>&1 <<SQL &
begin;
$2
reset role;
\! touch '$scratch/$1-ready'
select pg_sleep(4);
commit;
SQL
  local holder=$!
  wait_marker "$scratch/$1-ready"
  PGAPPNAME="offset-race-$1" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/$1-contender" 2>&1 <<SQL &
begin;
$3
commit;
SQL
  local contender=$!
  wait_lock "offset-race-$1"
  wait "$holder"
  wait "$contender" || true
  grep -qx consumed "$scratch/$1-holder" || { echo "::error::race $1: the holder did not consume" >&2; cat "$scratch/$1-holder" >&2; exit 1; }
  if ! grep -q "stale revision" "$scratch/$1-contender"; then
    echo "::error::race $1: the second call did not answer 'stale revision'" >&2
    cat "$scratch/$1-contender" >&2
    exit 1
  fi
}

# (A) the reimbursement of the last 40.00 wins; the offset of the same 40.00 loses
rev=$(revision "$o1"); win=$(uid); lose=$(uid); before=$(counts)
race A "$(reimburse "$o1" 4000 "$rev" "$win")" "$(offset "$o1" "$i1" 4000 "$rev" "$lose")"
expect "A: the claim is consumed once: three allocations adding to 120.00" "$(allocs "$o1")" "3/12000"
expect "A: only the reimbursement wrote rows" "$(delta "$before" "$(counts)")" "$r_delta"
expect "A: the invoice still owes 90.00" "$(due "$i1")" "9000"
expect "A: 90.00 was paid out" "$(paid_out "$o1")" "9000"
before=$(counts)
run "$(reimburse "$o1" 4000 "$rev" "$win")"
expect "A: the winner replayed under its request id writes nothing" "$(delta "$before" "$(counts)")" "0/0/0"
refused=$(q "$as_owner select public.record_member_reimbursement_v1('$ws', '$o1', 3999, $rev, '$win', current_date - 1, 'bank_transfer', 'race ref');" 2>&1 || true)
grep -q "already used for a different request" <<<"$refused" || {
  echo "::error::A: a changed payload under the winner's request id was not refused: $refused" >&2; exit 1
}

# (B) the reverse, on the second claim: the offset wins, the reimbursement loses
rev=$(revision "$o2"); win=$(uid); lose=$(uid); before=$(counts)
race B "$(offset "$o2" "$i2" 4000 "$rev" "$win")" "$(reimburse "$o2" 4000 "$rev" "$lose")"
expect "B: the claim is consumed once: three allocations adding to 120.00" "$(allocs "$o2")" "3/12000"
expect "B: only the offset wrote rows" "$(delta "$before" "$(counts)")" "$o_delta"
expect "B: the invoice owes 50.00" "$(due "$i2")" "5000"
expect "B: nothing more was paid out" "$(paid_out "$o2")" "5000"
before=$(counts)
run "$(offset "$o2" "$i2" 4000 "$rev" "$win")"
expect "B: the winner replayed under its request id writes nothing" "$(delta "$before" "$(counts)")" "0/0/0"
refused=$(q "$as_owner select public.offset_member_claim_v1('$ws', '$o2', '$i2', 3999, $rev, '$win', '');" 2>&1 || true)
grep -q "already used for a different request" <<<"$refused" || {
  echo "::error::B: a changed payload under the winner's request id was not refused: $refused" >&2; exit 1
}
echo "reimbursement and offset race: the last 40.00 of a claim is consumed once, in both orders"
