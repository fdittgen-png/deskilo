#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# #4492 (row 5) -- one invoice act asked twice at once is one act. The receipted commands (0463, 0464) make ONE request
# id one act; this is the other half: two sessions asking for the same act under TWO request ids (two people, or a
# second press that drew a new id). pgTAP 208 and 209 say it themselves: "NOT RUN here: two synchronized sessions".
#   (V) two sessions void one invoice: the holder voids and keeps its transaction open; the contender WAITS on the
#       invoice's row, then is refused: one void, one void event, one receipt (the holder's), none for the loser;
#   (R) two sessions refund one credit note: the contender WAITS on the invoice's one settlement row, then is
#       refused: one refund paid out, one settlement, one refund event;
#   (S) two sessions regroup the same two invoices into a settlement: the contender WAITS on the business's lock,
#       then is refused: one settlement invoice, and both sources name it.
# Each winner replayed under its request id answers without a second effect, and another text under that id is
# refused. A holder that never took its lock, or a contender that never waited, fails the script: nothing here can
# pass empty. A single pgTAP transaction cannot show a race, so each contender is its own psql process on CI's
# disposable database. Fresh ids per run; invoices cannot be deleted (invoices_no_mutation, 0183), so nothing is
# cleaned up: the database is disposable.
set -euo pipefail
url=${1:?usage: invoice_twice_race.sh DATABASE_URL}
uid() { uuidgen | tr 'A-Z' 'a-z'; }
ws=$(uid); owner=$(uid); client=$(uid)
scratch=$(mktemp -d)
cleanup() {
  local original_status=$?
  rm -rf "$scratch"
  exit "$original_status"
}
trap cleanup EXIT
. "$(dirname "${BASH_SOURCE[0]}")/lib/race.sh"
as_owner="select set_config('request.jwt.claims', '{\"sub\":\"$owner\",\"role\":\"authenticated\"}', true); set local role authenticated;"
psql "$url" -X -q -v ON_ERROR_STOP=1 <<SQL
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', u || '@invoice-twice.test', '', now(), now(), now()
  from unnest(array['$owner','$client']::uuid[]) u;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, street, city, postal_code, vat_regime, vat_id, feature_flags)
values ('$ws', 'Invoice twice', 'FR', 'EUR', 'Europe/Paris', '$owner', '1 rue du Pilote', 'Pézenas', '34120', 'vat_registered', 'FR12345678901',
        '{"moneyTab": true, "invoicing": true, "numberSequences": true, "invoiceSettlement": true}');
insert into public.members (workspace_id, user_id, is_owner, is_admin, joined_at) values ('$ws', '$owner', true, true, '2026-01-01');
insert into public.members (workspace_id, user_id, subscription_pct, joined_at, customer_capacity) values ('$ws', '$client', 1, '2026-01-01', 'consumer');
insert into public.vat_rates (workspace_id, label, percent, is_default) values ('$ws', 'Standard', 20, true);
delete from public.fee_bands where workspace_id = '$ws';
insert into public.fee_bands (workspace_id, from_pct, to_pct, fee_cents, overage_fee_cents) values ('$ws', 0, 100, 3500, 1000);
update public.profiles set first_name = 'Synthetic', last_name = 'Client', country_code = 'FR', street = '2 rue du Test', city = 'Pézenas', postal_code = '34120' where id = '$client';
insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, vat_percent)
select '$ws', m.id, 'charge', 'adjustment', x.amount, 'Supply', x.period, 20
  from public.members m, (values (1000, '2026-09'), (500, '2026-08'), (700, '2026-06')) x(amount, period)
 where m.workspace_id = '$ws' and m.user_id = '$client';
-- July: more received than supplied, so its invoice is a credit note.
insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
select '$ws', m.id, 'credit', 'payment', 5000, 'Advance', '2026-07' from public.members m where m.workspace_id = '$ws' and m.user_id = '$client';
-- no approval rule: every act here applies at once
delete from public.validation_policies where workspace_id = '$ws';
SQL
member=$(q "select id from public.members where workspace_id = '$ws' and user_id = '$client'")
issue() { q "$as_owner select public.create_invoice('$ws', '$member', '$1');" | tail -1; }
sep=$(issue 2026-09); aug=$(issue 2026-08); jul=$(issue 2026-07); jun=$(issue 2026-06)
for v in "$member" "$sep" "$aug" "$jul" "$jun"; do
  [[ "$v" =~ ^[0-9a-f-]{36}$ ]] || { echo "::error::fixture incomplete: '$v'" >&2; exit 1; }
done
expect "the fixture: July is a credit note, nothing is voided, matched or settled" \
  "$(q "select (select case when total_cents < 0 then 'credit' else 'debit' end from public.invoices where id = '$jul') || '/' || count(*) filter (where voided_at is not null or settled_by_invoice_id is not null) || '/' || (select count(*) from public.invoice_matches where workspace_id = '$ws') from public.invoices where workspace_id = '$ws'")" "credit/0/0"

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
# race NAME HOLDER CONTENDER: the holder runs its command and keeps its transaction open; the contender runs its own
# and must be seen waiting on a lock. Their output is in $scratch/NAME.a and $scratch/NAME.b.
race() {
  local name=$1 a b
  rm -f "$scratch/ready"
  psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/$name.a" 2>&1 <<SQL &
begin;
$as_owner
$2
reset role;
\! touch '$scratch/ready'
select pg_sleep(4);
commit;
SQL
  a=$!
  wait_marker "$scratch/ready" || { cat "$scratch/$name.a" >&2; exit 1; }
  PGAPPNAME="invoice-twice-$name" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/$name.b" 2>&1 <<SQL &
begin;
$as_owner
$3
commit;
SQL
  b=$!
  wait_lock "invoice-twice-$name" || { cat "$scratch/$name.b" >&2; exit 1; }
  wait "$a" || { echo "::error::the holder of $name failed" >&2; cat "$scratch/$name.a" >&2; exit 1; }
  wait "$b" || true
  grep -q 'ERROR' "$scratch/$name.b" || {
    echo "::error::$name: the second session was not refused" >&2; cat "$scratch/$name.b" >&2; exit 1
  }
  echo "$name: the second session waited, then was refused: $(grep -m1 'ERROR' "$scratch/$name.b")"
}
receipts() { q "select count(*) filter (where request_id = '$1' and state = 'applied') || '/' || count(*) filter (where request_id = '$2') from public.financial_command_receipts where workspace_id = '$ws'"; }
# replay COMMAND WANT: the winner's command again answers WANT; conflict COMMAND: another text under its id is refused
replay() {
  local answer
  answer=$(q "$as_owner $1" | tail -1)
  [[ "$answer" == *"$2"* ]] || { echo "::error::the replay answered '$answer', expected '$2'" >&2; exit 1; }
}
conflict() {
  local refused
  refused=$(q "$as_owner $1" 2>&1 || true)
  grep -q 'request conflict' <<<"$refused" || { echo "::error::another text under the winner's request id was not refused: $refused" >&2; exit 1; }
}

# (V) one invoice voided by two sessions
va=$(uid); vb=$(uid)
race void "select public.request_invoice_void_v1('$sep', '$va', 'race');" "select public.request_invoice_void_v1('$sep', '$vb', 'race');"
grep -q '"pending": false' "$scratch/void.a" || { echo "::error::the holder did not void" >&2; cat "$scratch/void.a" >&2; exit 1; }
voids() { q "select (select count(*) from public.invoices where id = '$sep' and voided_at is not null) || '/' || (select count(*) from public.events where workspace_id = '$ws' and type = 'invoice_void')"; }
expect "one void and one void event" "$(voids)" "1/1"
expect "one receipt, the holder's, and none for the loser" "$(receipts "$va" "$vb")" "1/0"
replay "select public.request_invoice_void_v1('$sep', '$va', 'race');" '"replayed": true'
expect "the replay voided nothing again" "$(voids)" "1/1"
conflict "select public.request_invoice_void_v1('$sep', '$va', 'another reason');"

# (R) one credit note refunded by two sessions
ra=$(uid); rb=$(uid)
race refund "select public.request_refund_v1('$jul', '$ra', 'race');" "select public.request_refund_v1('$jul', '$rb', 'race');"
grep -q '"pending": false' "$scratch/refund.a" || { echo "::error::the holder did not refund" >&2; cat "$scratch/refund.a" >&2; exit 1; }
refunds() { q "select (select count(*) from public.ledger_entries where workspace_id = '$ws' and category = 'refund') || '/' || (select count(*) from public.invoice_matches where invoice_id = '$jul') || '/' || (select count(*) from public.events where workspace_id = '$ws' and type = 'refund')"; }
expect "one refund paid out, one settlement of the credit note, one refund event" "$(refunds)" "1/1/1"
expect "one receipt, the holder's, and none for the loser" "$(receipts "$ra" "$rb")" "1/0"
replay "select public.request_refund_v1('$jul', '$ra', 'race');" '"replayed": true'
expect "the replay paid nothing out again" "$(refunds)" "1/1/1"
conflict "select public.request_refund_v1('$jul', '$ra', 'another note');"

# (S) the same two invoices regrouped by two sessions
sa=$(uid); sb=$(uid)
settle() { echo "select public.settle_invoices_v1('$ws', '$member', array['$aug', '$jun']::uuid[], '$1', '$2');"; }
race settle "$(settle "$sa" race)" "$(settle "$sb" race)"
made=$(grep -Eo '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$scratch/settle.a" | tail -1)
settled() { q "select (select count(*) from public.invoices where workspace_id = '$ws' and kind = 'settlement') || '/' || (select count(*) from public.invoices where id in ('$aug', '$jun') and settled_by_invoice_id = '$made')"; }
expect "one settlement invoice, and both sources name it" "$(settled)" "1/2"
expect "one receipt, the holder's, and none for the loser" "$(receipts "$sa" "$sb")" "1/0"
replay "$(settle "$sa" race)" "$made"
expect "the replay regrouped nothing again" "$(settled)" "1/2"
conflict "$(settle "$sa" 'another note')"
echo "invoice twice race: one void, one refund and one settlement, each asked by two sessions under two request ids"
