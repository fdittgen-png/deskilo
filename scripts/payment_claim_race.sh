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
#       approval";
#   (c) two online payments of the same invoice (two devices): the second
#       waits, then is refused;
#   (d) two overlapping claims of several invoices ({P, Q} held open,
#       {Q, R} after it): both lock their invoices sorted by id; the second
#       waits and is refused, and R stays free;
#   (e) the payment flow handing over a claim that lapsed (never handed,
#       past the window) held open; a new payment of its invoice waits, then
#       is opened;
#   (f) the reverse: the new payment held open; the hand-over waits, then
#       is refused and leaves the lapsed claim never handed;
#   (g) the boundary: the hand-over of a claim still inside the window held
#       open; a new payment of its invoice waits, then is refused (DKC06);
#   (h) #4140: the business confirming a declared payment held open; the
#       member taking it back waits on the event's lock, then is refused as
#       already decided (DKC13): the payment stands, credited;
#   (i) the reverse, which proves the decision's lock: the member taking it
#       back held open; the business's decision waits, then is refused as
#       already decided: withdrawn, nothing credited, its invoice free.
# Afterwards each claimed invoice is in exactly one open claim, R in none. Fresh ids per run;
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
-- X, Y, Z of one month for (a)-(c); P, Q, R of another for (d); S, T, U for (e)-(g);
-- H, I for (h), (i)
insert into public.invoices (workspace_id, member_id, issuer_member_id, number, period, title, lines, total_cents,
                             currency, member_name, workspace_name, issuer_name, signature, kind, issued_at)
select '$ws', p.id, o.id, 'CLAIM-' || m || '-' || k || '-' || substr('$ws', 1, 8), m, m, '[]', 1500,
       'EUR', 'P', 'W', 'O', repeat('s', 64), k, '2031-01-15'
  from public.members p, public.members o,
       (values ('2031-02', 'full'), ('2031-02', 'usage'), ('2031-02', 'subscription'),
               ('2031-03', 'full'), ('2031-03', 'usage'), ('2031-03', 'subscription'),
               ('2031-04', 'full'), ('2031-04', 'usage'), ('2031-04', 'subscription'),
               ('2031-05', 'full'), ('2031-06', 'full')) v(m, k)
 where p.user_id = '$payer' and o.user_id = '$owner';
SQL
. "$(dirname "${BASH_SOURCE[0]}")/lib/race.sh"
member=$(q "select id from public.members where workspace_id = '$ws' and user_id = '$payer'")
inv() { q "select id from public.invoices where workspace_id = '$ws' and period = '$1' and kind = '$2'"; }
x=$(inv 2031-02 full); y=$(inv 2031-02 usage); z=$(inv 2031-02 subscription)
p=$(inv 2031-03 full); qq=$(inv 2031-03 usage); r=$(inv 2031-03 subscription)
s=$(inv 2031-04 full); t=$(inv 2031-04 usage); u=$(inv 2031-04 subscription)
vh=$(inv 2031-05 full); vi=$(inv 2031-06 full)
as_payer="select set_config('request.jwt.claims', '{\"sub\":\"$payer\",\"role\":\"authenticated\"}', true); set local role authenticated;"
online() { echo "$as_payer select 'opened' from public.open_payment_intent('$ws', '$member', 'stripe', '${2:-2031-02}', 1500, 'EUR', null, array['$1']::uuid[]);"; }
online2() { echo "$as_payer select 'opened' from public.open_payment_intent('$ws', '$member', 'stripe', '2031-03', 3000, 'EUR', null, array['$1', '$2']::uuid[]);"; }
declared() { echo "$as_payer select 'declared' from public.record_payment('$ws', '$member', 1500, '', 'transfer', null, null, array['$1']::uuid[]);"; }
as_owner="select set_config('request.jwt.claims', '{\"sub\":\"$owner\",\"role\":\"authenticated\"}', true); set local role authenticated;"
# #4140 — a declared payment of one invoice, committed: its event's id
declaration() { q "$as_payer select public.record_payment('$ws', '$member', 1500, '', 'transfer', null, null, array['$1']::uuid[])" | tail -1; }
confirm() { echo "$as_owner select 'confirmed' from public.respond_to_event('$1', true);"; }
take_back() { echo "$as_payer select 'withdrawn' from public.withdraw_payment_declaration('$1');"; }
# the payment flow's hand-over (service_role only)
hand() { echo "set local role service_role; select case when public.hand_payment_intent('$1') then 'handed' else 'refused' end;"; }
# a claim of one invoice, never handed to its provider
claim() {
  psql "$url" -X -qAt -v ON_ERROR_STOP=1 <<SQL | tail -1
begin;
$as_payer
select id from public.open_payment_intent('$ws', '$member', 'stripe', '2031-04', 1500, 'EUR', null, array['$1']::uuid[]);
commit;
SQL
}
# ... and past the window
lapsed() {
  local id
  id=$(claim "$1")
  q "update public.payment_intents set created_at = now() - public.payment_resend_window('stripe') - interval '1 minute' where id = '$id'" >/dev/null
  echo "$id"
}
ls_=$(lapsed "$s"); lt=$(lapsed "$t"); lu=$(claim "$u")
dh=$(declaration "$vh"); di=$(declaration "$vi")
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
$3
commit;
SQL
  local contender=$!
  wait_lock "claim-race-$1"
  wait "$holder"
  wait "$contender" || true
  grep -qx "$4" "$scratch/$1-holder" || {
    echo "::error::race $1: the holder answered '$(tr '\n' ' ' <"$scratch/$1-holder")', expected '$4'" >&2
    exit 1
  }
  if ! grep -q "$5" "$scratch/$1-contender"; then
    echo "::error::race $1: the second call did not answer '$5'" >&2
    cat "$scratch/$1-contender" >&2
    exit 1
  fi
}
race a "$(online "$x")" "$(declared "$x")" opened 'is already in a payment being processed'
race b "$(declared "$y")" "$(online "$y")" declared 'is already in a declared payment awaiting approval'
race c "$(online "$z")" "$(online "$z")" opened 'is already in a payment being processed'
race d "$(online2 "$p" "$qq")" "$(online2 "$qq" "$r")" opened 'is already in a payment being processed'
race e "$(hand "$ls_")" "$(online "$s" 2031-04)" refused opened
race f "$(online "$t" 2031-04)" "$(hand "$lt")" opened refused
race g "$(hand "$lu")" "$(online "$u" 2031-04)" handed 'is already in a payment being processed'
race h "$(confirm "$dh")" "$(take_back "$dh")" confirmed 'this declaration was already decided'
race i "$(take_back "$di")" "$(confirm "$di")" withdrawn 'already decided'
# exactly one of the two: confirmed and credited once, or withdrawn and
# credited nothing
for want in "$dh:confirmed:1" "$di:withdrawn:0"; do
  id=${want%%:*}; rest=${want#*:}
  got=$(q "select e.status || ':' || (select count(*) from public.ledger_entries l where l.event_id = e.id) from public.events e where e.id = '$id'")
  if [[ "$got" != "$rest" ]]; then
    echo "::error::declaration $id ended $got, expected $rest" >&2
    exit 1
  fi
done
for id in "$ls_" "$lt"; do
  if [[ "$(q "select handed_at is null from public.payment_intents where id = '$id'")" != t ]]; then
    echo "::error::the lapsed claim $id was handed to its provider" >&2
    exit 1
  fi
done
# each claimed invoice in exactly one open claim; R, which only the refused
# payment named, in none
for want in "$x:1" "$y:1" "$z:1" "$p:1" "$qq:1" "$r:0" "$s:1" "$t:1" "$u:1" "$vh:0" "$vi:0"; do
  id=${want%%:*}; n=$(q "select count(*) from public.open_claim_invoices('$ws') o where o.invoice_id = '$id'")
  if [[ "$n" != "${want##*:}" ]]; then
    echo "::error::invoice $id is in $n open claims, expected ${want##*:}" >&2
    exit 1
  fi
done
echo "payment claim race: an invoice is in one open claim; the second payment waits and is refused, overlapping sets refused, a lapsed claim is never handed over beside a new payment, a claim handed inside the window holds its invoice; a declaration is either decided or taken back, never both"
