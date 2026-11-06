#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# #3346 finding 3 — a payment credit is never both moved and matched. A single
# pgTAP transaction cannot show a race, so each contender is its own psql
# process on CI's disposable database:
#   (a) a MOVE held open; a match of the same credit must WAIT on the credit's
#       row lock, then be refused "was moved";
#   (b) a MATCH held open; a move of the same credit must WAIT, then be refused
#       "pays an invoice".
# Afterwards exactly one of move / match exists for each credit. Fresh ids per
# run; invoices cannot be deleted (invoices_no_mutation, 0183), so cleanup only
# removes what it can and a failure is a warning.
set -euo pipefail
url=${1:?usage: credit_move_match_race.sh DATABASE_URL}
uid() { uuidgen | tr 'A-Z' 'a-z'; }
ws=$(uid); owner=$(uid); payer=$(uid); receiver=$(uid)
scratch=$(mktemp -d)
cleanup() {
  local original_status=$?
  psql "$url" -X -q -v ON_ERROR_STOP=1 >/dev/null 2>&1 <<SQL ||
delete from public.invoice_matches where workspace_id = '$ws';
SQL
    echo "::warning::credit move race fixture cleanup failed" >&2
  rm -rf "$scratch"
  exit "$original_status"
}
trap cleanup EXIT
psql "$url" -X -q -v ON_ERROR_STOP=1 <<SQL
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', u || '@credit-race.test', '', now(), now(), now()
  from unnest(array['$owner','$payer','$receiver']::uuid[]) u;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags)
values ('$ws', 'Credit race', 'FR', 'EUR', 'Europe/Paris', '$owner', '{"moneyTab": true, "invoicing": true, "bankImport": true}');
insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
values ('$ws', '$owner', true, true, 'active', '2026-01-01'),
       ('$ws', '$payer', false, false, 'active', '2026-01-01'),
       ('$ws', '$receiver', false, false, 'active', '2026-01-01');
-- two credits on the payer (each raced once) and one invoice to match against
insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, occurred_on)
select '$ws', m.id, 'credit', 'payment', 1000 + n, 'Bank transfer ' || n, '2031-01', '2031-01-10'
  from public.members m, generate_series(1, 2) n where m.user_id = '$payer';
insert into public.invoices (workspace_id, member_id, issuer_member_id, number, period, title, lines, total_cents,
                             currency, member_name, workspace_name, issuer_name, signature, kind)
select '$ws', p.id, o.id, 'RACE-' || substr('$ws', 1, 8), '2031-02', '2031-02', '[]', 0, 'EUR', 'P', 'W', 'O', repeat('s', 64), 'full'
  from public.members p, public.members o where p.user_id = '$payer' and o.user_id = '$owner';
SQL
q() { psql "$url" -X -qAt -v ON_ERROR_STOP=1 -c "$1"; }
c1=$(q "select id from public.ledger_entries where workspace_id = '$ws' and amount_cents = 1001")
c2=$(q "select id from public.ledger_entries where workspace_id = '$ws' and amount_cents = 1002")
to=$(q "select id from public.members where workspace_id = '$ws' and user_id = '$receiver'")
inv=$(q "select id from public.invoices where workspace_id = '$ws'")
as_owner="select set_config('request.jwt.claims', '{\"sub\":\"$owner\",\"role\":\"authenticated\"}', true); set local role authenticated;"
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
# (a) a move held open; a match waits and is refused
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/a-holder" 2>&1 <<SQL &
begin;
$as_owner
select 'moved' from (select public.move_payment_credit_v1('$c1', '$to', 'race', '$(uid)')) m;
reset role;
\! touch '$scratch/a-ready'
select pg_sleep(4);
commit;
SQL
a=$!
wait_marker "$scratch/a-ready"
PGAPPNAME=credit-race-a psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/a-contender" 2>&1 <<SQL &
insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution, status, payment_ledger_id)
values ('$ws', '$inv', 1001, 'exact', 'confirmed', '$c1');
SQL
b=$!
wait_lock credit-race-a
wait "$a"
wait "$b" || true
grep -qx moved "$scratch/a-holder"
grep -q 'this credit was moved' "$scratch/a-contender"
# (b) a match held open; a move waits and is refused
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/b-holder" 2>&1 <<SQL &
begin;
insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution, status, payment_ledger_id)
values ('$ws', '$inv', 1002, 'exact', 'confirmed', '$c2');
\! touch '$scratch/b-ready'
select pg_sleep(4);
commit;
SQL
a=$!
wait_marker "$scratch/b-ready"
PGAPPNAME=credit-race-b psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/b-contender" 2>&1 <<SQL &
begin;
$as_owner
select public.move_payment_credit_v1('$c2', '$to', 'race', '$(uid)');
commit;
SQL
b=$!
wait_lock credit-race-b
wait "$a"
wait "$b" || true
grep -q 'this credit pays an invoice' "$scratch/b-contender"
# exactly one of move / match for each credit
for c in "$c1:moved" "$c2:matched"; do
  id=${c%%:*}; want=${c##*:}
  moves=$(q "select count(*) from public.ledger_credit_moves where from_credit_id = '$id'")
  matches=$(q "select count(*) from public.invoice_matches where payment_ledger_id = '$id'")
  if [[ "$want" == moved && "$moves$matches" != 10 ]] || [[ "$want" == matched && "$moves$matches" != 01 ]]; then
    echo "::error::credit $id: $moves move(s) and $matches match(es), expected only the $want one" >&2
    exit 1
  fi
done
echo "credit move/match race: a credit is moved or matched, never both"
