#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# #4492 (row 5) -- a probe, not a gate: what the commands WITHOUT a request identity or a revision do when the same
# request arrives twice (a second press, a retry after an answer that was lost) or a save rests on what was read
# before somebody else saved. It asserts nothing: each case prints one VERDICT line saying what the database holds
# afterwards, and a case whose fixture could not be built says so instead of passing. Run it on the replayed database
# of the preview (`gh workflow run db-preview.yml --ref <branch> -f race=twice_is_once_probe.sh`); it is in no
# required job, because a known open gap must not hold a pull request. When a command gains its request identity or
# its revision, its case moves into a race script with an assertion.
#   (G1) a carnet sold twice (`sell_credit`)            (G2) a package bought twice (`buy_package`)
#   (G3) an expense filed twice (`submit_expense`)      (G4) an expense distributed twice (`distribute_expense`)
#   (G5) the billing rules saved from what was read before another save (`set_billing_rules`)
# One connection is enough: nothing here needs two sessions to go wrong. Fresh ids per run; removing the business is
# tried and only warns (what a command booked may keep it), the database is disposable.
set -uo pipefail
url=${1:?usage: twice_is_once_probe.sh DATABASE_URL}
uid() { uuidgen | tr 'A-Z' 'a-z'; }
ws=$(uid); owner=$(uid); client=$(uid)
cleanup() {
  psql "$url" -X -q -v ON_ERROR_STOP=1 -c "delete from public.workspaces where id = '$ws'" >/dev/null 2>&1 ||
    echo "::warning::twice-is-once probe fixture cleanup failed" >&2
}
trap cleanup EXIT
sql() { psql "$url" -X -qAt -v ON_ERROR_STOP=1 -c "$1" 2>&1; }
as_owner="select set_config('request.jwt.claims', '{\"sub\":\"$owner\",\"role\":\"authenticated\"}', true); set local role authenticated;"
# act SQL: the command's answer as the owner, or the line of its refusal (never the context line under it)
act() {
  local out
  out=$(sql "$as_owner $1")
  if grep -q 'ERROR' <<<"$out"; then grep -m1 'ERROR' <<<"$out"; else tail -1 <<<"$out"; fi
}
verdict() { echo "VERDICT $1: $2"; echo "::notice::VERDICT $1: $2"; }
psql "$url" -X -q -v ON_ERROR_STOP=1 <<SQL || { echo "::error::the probe's business could not be built" >&2; exit 1; }
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', u || '@twice-probe.test', '', now(), now(), now()
  from unnest(array['$owner','$client']::uuid[]) u;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, street, city, postal_code, vat_regime, vat_id, feature_flags)
values ('$ws', 'Twice probe', 'FR', 'EUR', 'Europe/Paris', '$owner', '1 rue du Pilote', 'Pézenas', '34120', 'vat_registered', 'FR12345678901',
        '{"moneyTab": true, "invoicing": true, "carnets": true, "placeBooking": true, "expenseRepartition": true, "expenses": true}');
insert into public.members (workspace_id, user_id, is_owner, is_admin, joined_at, overage_policy) values ('$ws', '$owner', true, true, '2026-01-01', 'package');
insert into public.members (workspace_id, user_id, subscription_pct, joined_at, customer_capacity) values ('$ws', '$client', 1, '2026-01-01', 'consumer');
insert into public.vat_rates (workspace_id, label, percent, is_default) values ('$ws', 'Standard', 20, true);
insert into public.packages (workspace_id, name, days, price_cents) values ('$ws', 'Probe pack', 5, 5000);
insert into public.credit_products (workspace_id, name, half_days, price_cents) values ('$ws', 'Probe carnet', 10, 9000);
delete from public.validation_policies where workspace_id = '$ws';
SQL
member=$(sql "select id from public.members where workspace_id = '$ws' and user_id = '$client'")
pack=$(sql "select id from public.packages where workspace_id = '$ws'")
carnet=$(sql "select id from public.credit_products where workspace_id = '$ws'")
# twice CASE COMMAND COUNT_SQL WHAT: sends COMMAND twice, exactly as a second press or a retry would, and says what COUNT_SQL finds
twice() {
  local first second before after
  before=$(sql "$3")
  first=$(act "$2"); second=$(act "$2")
  after=$(sql "$3")
  if grep -q 'ERROR' <<<"$first"; then
    verdict "$1" "NOT RUN, the first request was refused: $first"
  elif grep -q 'ERROR' <<<"$second"; then
    verdict "$1" "HOLDS, the second request was refused ($second); $4: $before -> $after"
  elif [[ "$first" == "$second" ]]; then
    verdict "$1" "HOLDS, the second request answered the first's result; $4: $before -> $after"
  else
    verdict "$1" "DUPLICATE, both requests were accepted with two results; $4: $before -> $after"
  fi
}
twice G1 "select public.sell_credit('$ws', '$member', '$carnet');" \
  "select (select count(*) from public.member_credits where workspace_id = '$ws') || ' carnets, ' || (select count(*) from public.ledger_entries where workspace_id = '$ws' and member_id = '$member' and category = 'package') || ' charges'" \
  "carnets and charges of the customer"
twice G2 "select public.buy_package('$ws', '$pack');" \
  "select (select count(*) from public.quota_extensions where workspace_id = '$ws') || ' extensions, ' || (select count(*) from public.ledger_entries l join public.members m on m.id = l.member_id where l.workspace_id = '$ws' and m.user_id = '$owner' and l.category = 'package') || ' charges'" \
  "quota extensions and charges of the buyer"
twice G3 "select public.submit_expense('$ws', 1250, 'supplies', 'probe: the same expense');" \
  "select count(*) || ' expenses awaiting a decision' from public.events where workspace_id = '$ws' and type = 'expense'" \
  "expense requests"
twice G4 "select public.distribute_expense('$ws', 'Probe share', 2000, 'custom', '2026-11', jsonb_build_array(jsonb_build_object('member_id', '$member', 'amount_cents', 2000)));" \
  "select (select count(*) from public.expense_repartitions where workspace_id = '$ws') || ' distributions, ' || (select count(*) from public.ledger_entries where workspace_id = '$ws' and description = 'Probe share') || ' charges'" \
  "distributions and charges"
# (G5) A and B read the same rules; B saves its change, then A saves its own from what it read
basis=$(sql "select billing_rules from public.workspaces where id = '$ws'")
b=$(act "select public.set_billing_rules('$ws', '$basis'::jsonb || '{\"probe_b\": 2}'::jsonb);")
a=$(act "select public.set_billing_rules('$ws', '$basis'::jsonb || '{\"probe_a\": 9}'::jsonb);")
kept=$(sql "select case when billing_rules ? 'probe_a' then 'a' else '-' end || case when billing_rules ? 'probe_b' then 'b' else '-' end from public.workspaces where id = '$ws'")
if grep -q 'ERROR' <<<"$b"; then
  verdict G5 "NOT RUN, the first save was refused: $b"
elif grep -q 'ERROR' <<<"$a"; then
  verdict G5 "HOLDS, the save from stale data was refused ($a)"
else
  case "$kept" in
    a-) verdict G5 "LOST UPDATE, the save from stale data was accepted and the other person's change is gone (kept: $kept)";;
    ab) verdict G5 "HOLDS, both changes are present (kept: $kept)";;
    *) verdict G5 "UNCLEAR, kept: $kept";;
  esac
fi
echo "twice-is-once probe: five cases answered"
