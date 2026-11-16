#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# #3556 — one open claim per invoice. A payment that names invoices locks
# them by id before it checks them, so a second payment naming one of them
# from another connection WAITS for the first and then meets it (DKC06),
# never passes beside it. A single pgTAP transaction cannot show a race, so
# each contender is its own psql process on CI's disposable database:
#   (a) an online payment held open; a declared payment of the same invoice
#       waits on the invoice's row lock, then is refused "is already in a
#       payment being processed";
#   (b) a declared payment held open; an online payment of the same invoice
#       waits, then is refused "is already in a declared payment awaiting
#       approval".
# Afterwards each invoice is in exactly one open claim. Fresh ids per run;
# invoices cannot be deleted (invoices_no_mutation, 0183), so cleanup only
# removes what it can and a failure is a warning.
set -euo pipefail
url=${1:?usage: payment_claim_race.sh DATABASE_URL}
uid() { uuidgen | tr 'A-Z' 'a-z'; }
ws=$(uid); owner=$(uid); payer=$(uid)
scratch=$(mktemp -d)
cleanup() {
  local original_status=$?
  psql "$url" -X -q -v ON_ERROR_STOP=1 >/dev/null 2>&1 <<SQL ||
delete from public.payment_intents where workspace_id = '$ws';
delete from public.events where workspace_id = '$ws';
SQL
    echo "::warning::payment claim race fixture cleanup failed" >&2
  rm -rf "$scratch"
  exit "$original_status"
}
trap cleanup EXIT
psql "$url" -X -q -v ON_ERROR_STOP=1 <<SQL
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', u || '@claim-race.test', '', now(), now(), now()
  from unnest(array['$owner','$payer']::uuid[]) u;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags)
values ('$ws', 'Claim race', 'FR', 'EUR', 'Europe/Paris', '$owner', '{"moneyTab": true, "invoicing": true, "onlinePayments": true}');
insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
values ('$ws', '$owner', true, true, 'active', '2026-01-01'),
       ('$ws', '$payer', false, false, 'active', '2026-01-01');
delete from public.validation_policies where workspace_id = '$ws';
-- two invoices of one month, each raced once
insert into public.invoices (workspace_id, member_id, issuer_member_id, number, period, title, lines, total_cents,
                             currency, member_name, workspace_name, issuer_name, signature, kind, issued_at)
select '$ws', p.id, o.id, 'CLAIM-' || k || '-' || substr('$ws', 1, 8), '2031-02', '2031-02', '[]', 1500,
       'EUR', 'P', 'W', 'O', repeat('s', 64), k, '2031-02-01'
  from public.members p, public.members o, unnest(array['full', 'usage']) k
 where p.user_id = '$payer' and o.user_id = '$owner';
SQL
q() { psql "$url" -X -qAt -v ON_ERROR_STOP=1 -c "$1"; }
member=$(q "select id from public.members where workspace_id = '$ws' and user_id = '$payer'")
x=$(q "select id from public.invoices where workspace_id = '$ws' and kind = 'full'")
y=$(q "select id from public.invoices where workspace_id = '$ws' and kind = 'usage'")
as_payer="select set_config('request.jwt.claims', '{\"sub\":\"$payer\",\"role\":\"authenticated\"}', true); set local role authenticated;"
online() { echo "select 'opened' from public.open_payment_intent('$ws', '$member', 'stripe', '2031-02', 1500, 'EUR', null, array['$1']::uuid[]);"; }
declared() { echo "select 'declared' from public.record_payment('$ws', '$member', 1500, '', 'transfer', null, null, array['$1']::uuid[]);"; }
wait_marker() {
  local i=0
  while (( i < 100 )); do [[ -e "$1" ]] && return 0; sleep 0.1; ((i+=1)); done
  echo "::error::holder did not take its lock" >&2; return 1
}
wait_lock() {
  local i=0 result
  while (( i < 100 )); do
    result=$(psql "$url" -X -qAt -v ON_ERROR_STOP=1 -c "select count(*) from pg_stat_activity where application_name = '$1' and wait_event_type = 'Lock'")
    [[ "$result" != 0 ]] && return 0
    sleep 0.1; ((i+=1))
  done
  echo "::error::contender did not wait on a lock: $1" >&2; return 1
}
# race NAME HOLDER-SQL CONTENDER-SQL HOLDER-WORD REFUSAL
race() {
  psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/$1-holder" 2>&1 <<SQL &
begin;
$as_payer
$2
reset role;
\! touch '$scratch/$1-ready'
select pg_sleep(4);
commit;
SQL
  local holder=$!
  wait_marker "$scratch/$1-ready"
  PGAPPNAME="claim-race-$1" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/$1-contender" 2>&1 <<SQL &
begin;
$as_payer
$3
commit;
SQL
  local contender=$!
  wait_lock "claim-race-$1"
  wait "$holder"
  wait "$contender" || true
  grep -qx "$4" "$scratch/$1-holder"
  if ! grep -q "$5" "$scratch/$1-contender"; then
    echo "::error::race $1: the second payment was not refused '$5'" >&2
    cat "$scratch/$1-contender" >&2
    exit 1
  fi
}
race a "$(online "$x")" "$(declared "$x")" opened 'is already in a payment being processed'
race b "$(declared "$y")" "$(online "$y")" declared 'is already in a declared payment awaiting approval'
# each invoice in exactly one open claim
for inv in "$x" "$y"; do
  n=$(q "select count(*) from public.open_claim_invoices('$ws') o where o.invoice_id = '$inv'")
  if [[ "$n" != 1 ]]; then
    echo "::error::invoice $inv is in $n open claims, expected exactly one" >&2
    exit 1
  fi
done
echo "payment claim race: an invoice is in one open claim, the second payment waits and is refused"
