#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# #3336 L10 — the invoice path. The same receipted command (create_invoice_receipted_v1,
# one request id) fired from two real connections at once is ONE business act: both
# answer the same invoice, exactly one invoice exists, and it has exactly one
# provenance envelope (the envelope hook is an AFTER INSERT trigger, so a second
# insert would be a second row and a second stamp). A single pgTAP transaction
# cannot show it; each contender is its own psql process on CI's disposable database.
#   A holds the command open inside a transaction; B (same request id) must WAIT on
#   it and then answer the same invoice.
# Fresh ids per run; invoices cannot be deleted, so cleanup only warns.
set -euo pipefail
url=${1:?usage: receipted_replay_race.sh DATABASE_URL}
uid() { uuidgen | tr 'A-Z' 'a-z'; }
ws=$(uid); owner=$(uid); client=$(uid); req=$(uid)
scratch=$(mktemp -d)
cleanup() {
  local original_status=$?
  rm -rf "$scratch"
  exit "$original_status"
}
trap cleanup EXIT
wait_lock() {
  local i=0 result
  while (( i < 100 )); do
    result=$(psql "$url" -X -qAt -v ON_ERROR_STOP=1 -c "select count(*) from pg_stat_activity where application_name = '$1' and wait_event_type = 'Lock'")
    [[ "$result" != 0 ]] && return 0
    sleep 0.1; ((i+=1))
  done
  echo "::error::$1 never waited on the open command: this proved a replay, not a race" >&2
  return 1
}
psql "$url" -X -q -v ON_ERROR_STOP=1 <<SQL
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', u || '@receipt-race.test', '', now(), now(), now()
  from unnest(array['$owner','$client']::uuid[]) u;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, street, city, postal_code, vat_regime, vat_id, feature_flags)
values ('$ws', 'Receipt race', 'FR', 'EUR', 'Europe/Paris', '$owner', '1 rue du Pilote', 'Pézenas', '34120', 'vat_registered', 'FR12345678901',
        '{"moneyTab": true, "invoicing": true, "numberSequences": true}');
insert into public.members (workspace_id, user_id, is_owner, is_admin, joined_at) values ('$ws', '$owner', true, true, '2026-01-01');
insert into public.members (workspace_id, user_id, subscription_pct, joined_at, customer_capacity) values ('$ws', '$client', 1, '2026-01-01', 'consumer');
insert into public.vat_rates (workspace_id, label, percent, is_default) values ('$ws', 'Standard', 20, true);
delete from public.fee_bands where workspace_id = '$ws';
insert into public.fee_bands (workspace_id, from_pct, to_pct, fee_cents, overage_fee_cents) values ('$ws', 0, 100, 3500, 1000);
update public.profiles set first_name = 'Synthetic', last_name = 'Client', country_code = 'FR', street = '2 rue du Test', city = 'Pézenas', postal_code = '34120' where id = '$client';
insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, vat_percent)
select '$ws', m.id, 'charge', 'adjustment', 1000, 'Supply', '2026-09', 20 from public.members m where m.user_id = '$client';
SQL
member=$(psql "$url" -X -qAt -v ON_ERROR_STOP=1 -c "select id from public.members where workspace_id = '$ws' and user_id = '$client'")
as_owner="select set_config('request.jwt.claims', '{\"sub\":\"$owner\",\"role\":\"authenticated\"}', true); set local role authenticated;"
cmd="select public.create_invoice_receipted_v1('$ws', '$member', '2026-09', '$req');"
wait_marker() {
  local i=0
  while (( i < 100 )); do [[ -e "$1" ]] && return 0; sleep 0.1; ((i+=1)); done
  echo "::error::holder did not take its command" >&2; return 1
}
PGAPPNAME=receipt-race-a psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/a" 2>&1 <<SQL &
begin;
$as_owner
$cmd
reset role;
\! touch '$scratch/ready'
select pg_sleep(4);
commit;
SQL
a=$!
wait_marker "$scratch/ready"
PGAPPNAME=receipt-race-b psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/b" 2>&1 <<SQL &
begin;
$as_owner
$cmd
commit;
SQL
b=$!
# B must be seen WAITING on A's open command: otherwise this proved a replay,
# not a race (the holder sleeps 4 s, far longer than this poll).
wait_lock receipt-race-b
wait "$a"
wait "$b" || true
first=$(grep -Eo '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$scratch/a" | head -1)
second=$(grep -Eo '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$scratch/b" | head -1)
if [[ -z "$first" || "$first" != "$second" ]]; then
  echo "::error::the two contenders answered '$first' and '$second' (expected one invoice id)" >&2
  cat "$scratch/b" >&2
  exit 1
fi
n=$(psql "$url" -X -qAt -c "select count(*) from public.invoices where workspace_id = '$ws'")
e=$(psql "$url" -X -qAt -c "select count(*) from public.provenance_envelopes where result_kind = 'invoice' and workspace_id = '$ws'")
if [[ "$n$e" != 11 ]]; then
  echo "::error::$n invoice(s) and $e envelope(s) after one command fired twice (expected 1 and 1)" >&2
  exit 1
fi
echo "receipted replay race: one command, one invoice, one envelope"
