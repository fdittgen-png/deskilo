# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #1639 — the Mollie and Wero settlement matrix. Sourced by
# edge_payment_check.sh after phase 1: same stack, payer, workspace and
# helpers; the real order handler was started with MOLLIE_API_BASE on this
# stub's port. Mollie and Wero get SEPARATE credentials and SEPARATE
# payments: that Mollie settles says nothing about Wero, and each is
# asserted on its own. The callback is the CLASSIC one — a form body with
# the payment id — and it is only a notification: the real mollie-webhook
# fetches the payment back from the stateful stub with the intent's own
# key, and only a payment that is the intent's, in every field, settles.
MO_PORT=54996
MO="http://127.0.0.1:$MO_PORT"
: > "$WORK/mo_hits"
python3 scripts/payment_scenarios/mollie_stub.py "$MO_PORT" "$WORK/mo_hits" "MO$RUN" &
MO_PID=$!
trap 'kill $STUB_PID $FN_PID $MO_PID 2>/dev/null; rm -rf "$WORK"' EXIT
for _ in $(seq 1 30); do curl -s -o /dev/null "$MO/v2/none" && break; sleep 0.5; done

MOLLIE_KEY="test_mollie$RUN"
WERO_KEY="test_wero$RUN"
sql "insert into public.payment_credentials (workspace_id, provider, config) values
       ('$WS', 'mollie', '{\"api_key\": \"$MOLLIE_KEY\", \"return_url\": \"https://example.test/return\"}'),
       ('$WS', 'wero',   '{\"api_key\": \"$WERO_KEY\",   \"return_url\": \"https://example.test/return\"}')" >/dev/null \
  || fail "could not configure Mollie and Wero"

open_payment() {  # open_payment <provider> <label>
  BODY="{\"workspace_id\":\"$WS\",\"provider\":\"$1\",\"member_id\":\"$MEMBER\",\"amount_cents\":2500,\"period\":\"2026-09\",\"currency\":\"EUR\"}"
  [ "$(call -H "Authorization: Bearer $PAYER_JWT")" = "200" ] \
    || fail "$2: the order handler refused: $(cat "$WORK/out")"
  json "['order_id']" < "$WORK/out"
}
M_PAID=$(open_payment mollie paid);      W_PAID=$(open_payment wero wero-paid)
M_OPEN=$(open_payment mollie open);      M_AUTH=$(open_payment mollie authorized)
M_CANCEL=$(open_payment mollie canceled); M_EXPIRE=$(open_payment mollie expired)
M_FAIL=$(open_payment mollie failed);    W_METHOD=$(open_payment wero wrong-method)
M_CUR=$(open_payment mollie wrong-currency); M_AMT=$(open_payment mollie wrong-amount)
M_BAD=$(open_payment mollie malformed);  M_MODE=$(open_payment mollie wrong-mode)
M_REF=$(open_payment mollie wrong-reference); M_DOWN=$(open_payment mollie outage)
M_FOREIGN=$(open_payment mollie foreign-key); M_DUP=$(open_payment mollie duplicate)
M_RACE=$(open_payment mollie race);      M_LOST=$(open_payment mollie lost)

payment() { curl -s "$MO/_test/payments/$1"; }
set_payment() { curl -s -X POST "$MO/_test/set/$1" -d "$2" >/dev/null; }

# ── creation: each method, its own key, the callback on THIS backend ──
created() {  # created <payment> → "method value currency reference mode webhook"
  payment "$1" | python3 -c 'import json,sys; p=json.load(sys.stdin); a=p["amount"]
print(p["method"] or "-", a["value"], a["currency"], p["metadata"]["reference"], p["mode"], p["webhookUrl"])'
}
ref_of() { sql "select reference from public.payment_intents where order_id = '$1'"; }
HOOK="$API_URL/functions/v1/mollie-webhook"
[ "$(created "$M_PAID")" = "- 25.00 EUR $(ref_of "$M_PAID") test $HOOK" ] \
  || fail "the Mollie payment was created as '$(created "$M_PAID")'"
[ "$(created "$W_PAID")" = "wero 25.00 EUR $(ref_of "$W_PAID") test $HOOK" ] \
  || fail "the Wero payment was created as '$(created "$W_PAID")'"
[ "$(sql "select provider from public.payment_intents where order_id = '$W_PAID'")" = "wero" ] \
  || fail "the Wero intent is not a wero intent"
grep -q "^POST /v2/payments$" "$WORK/mo_hits" || fail "the order handler never reached Mollie"
echo "creation: Mollie without a method, Wero with method=wero, each under its own test key, callback $HOOK"

# ── the real webhook handler takes the port over ─────────────────────
kill "$FN_PID" 2>/dev/null; wait "$FN_PID" 2>/dev/null
SUPABASE_URL="$API_URL" SUPABASE_SERVICE_ROLE_KEY="$SERVICE_KEY" MOLLIE_API_BASE="$MO" \
  deno run --allow-net --allow-env --allow-read --allow-import \
  supabase/functions/mollie-webhook/index.ts > "$WORK/wh.log" 2>&1 &
FN_PID=$!
for _ in $(seq 1 90); do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$FN" || true)
  [ "$code" = "405" ] && break
  sleep 1
done
[ "$code" = "405" ] || { cat "$WORK/wh.log"; fail "the mollie webhook did not start"; }

callback() {  # callback <payment> [out] → HTTP code (classic: form body id=…)
  curl -s -o "${2:-$WORK/wh}" -w '%{http_code}' -X POST "$FN" \
    -H 'Content-Type: application/x-www-form-urlencoded' --data "id=$1"
}
expect_cb() {  # expect_cb <label> <payment> <code>
  local code; code=$(callback "$2")
  [ "$code" = "$3" ] || { tail -20 "$WORK/wh.log"; fail "$1: the webhook answered $code, expected $3: $(cat "$WORK/wh")"; }
}
status_of() { sql "select status from public.payment_intents where order_id = '$1'"; }
credits() { sql "select count(*) from public.ledger_entries where workspace_id = '$WS' and kind = 'credit' and category = 'payment'"; }
associated() {
  sql "select count(*) from public.payment_intents i join public.ledger_entries l on l.id = i.ledger_entry_id
        where i.order_id = '$1' and l.member_id = i.member_id and l.amount_cents = i.amount_cents
          and l.period = i.period and i.capture_id = i.order_id"
}
check_state() {  # check_state <label> <payment> <status> <credits>
  [ "$(status_of "$2")" = "$3" ] || fail "$1: expected $3, found $(status_of "$2")"
  [ "$(credits)" = "$4" ] || fail "$1: expected $4 payment credit(s), found $(credits)"
  if [ "$3" = "captured" ]; then
    [ "$(associated "$2")" = "1" ] || fail "$1: the capture does not name a matching posting"
  fi
  echo "$1: $3, $4 credit(s)"
}

# 1. Paid → captured once, for each method separately.
set_payment "$M_PAID" '{"status":"paid","method":"creditcard"}'
expect_cb mollie-paid "$M_PAID" 200
check_state "mollie paid" "$M_PAID" captured 1
set_payment "$W_PAID" '{"status":"paid"}'
expect_cb wero-paid "$W_PAID" 200
check_state "wero paid" "$W_PAID" captured 2
[ "$(sql "select l.description from public.ledger_entries l join public.payment_intents i on i.ledger_entry_id = l.id where i.order_id = '$W_PAID'")" = "wero online payment" ] \
  || fail "the Wero credit is not labelled wero"

# 2. Not paid yet: open and authorized settle nothing and fail nothing.
expect_cb open "$M_OPEN" 200
check_state "open" "$M_OPEN" created 2
set_payment "$M_AUTH" '{"status":"authorized"}'
expect_cb authorized "$M_AUTH" 200
check_state "authorized is not paid" "$M_AUTH" created 2

# 3. Canceled, expired, failed → failed, no credit.
for pair in "canceled:$M_CANCEL" "expired:$M_EXPIRE" "failed:$M_FAIL"; do
  st="${pair%%:*}"; id="${pair#*:}"
  set_payment "$id" "{\"status\":\"$st\"}"
  expect_cb "$st" "$id" 200
  check_state "$st" "$id" failed 2
done

# 4. A paid payment that is not the intent's, field by field: refused,
#    nothing credited. Each fixture varies ONE thing.
set_payment "$W_METHOD" '{"status":"paid","method":"ideal"}'
expect_cb wero-wrong-method "$W_METHOD" 409
set_payment "$M_CUR"  '{"status":"paid","amount":{"currency":"USD","value":"25.00"}}'
expect_cb wrong-currency "$M_CUR" 409
set_payment "$M_AMT"  '{"status":"paid","amount":{"currency":"EUR","value":"24.00"}}'
expect_cb wrong-amount "$M_AMT" 409
set_payment "$M_BAD"  '{"status":"paid","amount":{"currency":"EUR","value":"25,00 EUR"}}'
expect_cb malformed-amount "$M_BAD" 409
set_payment "$M_MODE" '{"status":"paid","mode":"live"}'
expect_cb wrong-mode "$M_MODE" 409
set_payment "$M_REF"  '{"status":"paid","metadata":{"reference":"PAY-SOMEONE-ELSE"}}'
expect_cb wrong-reference "$M_REF" 409
for id in "$W_METHOD" "$M_CUR" "$M_AMT" "$M_BAD" "$M_MODE" "$M_REF"; do
  check_state "mismatch $id" "$id" created 2
done

# 5. Mollie unavailable: a fetch that failed is not a status. 500, retry.
set_payment "$M_DOWN" '{"status":"paid"}'
curl -s -X POST "$MO/_test/outage" -d '{"on":true}' >/dev/null
expect_cb outage "$M_DOWN" 500
curl -s -X POST "$MO/_test/outage" -d '{"on":false}' >/dev/null
check_state "provider unavailable" "$M_DOWN" created 2
expect_cb outage-recovered "$M_DOWN" 200
check_state "provider back" "$M_DOWN" captured 3

# 6. The workspace's key no longer sees the payment (Mollie: 404 under
#    another key): not found is not paid.
set_payment "$M_FOREIGN" '{"status":"paid"}'
sql "update public.payment_credentials set config = config || '{\"api_key\": \"test_someone_else\"}'
      where workspace_id = '$WS' and provider = 'mollie'" >/dev/null
expect_cb foreign-key "$M_FOREIGN" 500
sql "update public.payment_credentials set config = config || '{\"api_key\": \"$MOLLIE_KEY\"}'
      where workspace_id = '$WS' and provider = 'mollie'" >/dev/null
check_state "payment not visible to the key" "$M_FOREIGN" created 3

# 7. Duplicate and concurrent callbacks credit once.
set_payment "$M_DUP" '{"status":"paid"}'
expect_cb dup-1 "$M_DUP" 200; expect_cb dup-2 "$M_DUP" 200
check_state "duplicate callback" "$M_DUP" captured 4
set_payment "$M_RACE" '{"status":"paid"}'
callback "$M_RACE" "$WORK/race1" > "$WORK/code1" & r1=$!
callback "$M_RACE" "$WORK/race2" > "$WORK/code2" & r2=$!
wait "$r1" "$r2"
[ "$(cat "$WORK/code1")$(cat "$WORK/code2")" = "200200" ] \
  || fail "the race answered $(cat "$WORK/code1")/$(cat "$WORK/code2")"
check_state "concurrent callback" "$M_RACE" captured 5

# 8. A later status cannot take confirmed money back.
set_payment "$M_PAID" '{"status":"failed"}'
expect_cb downgrade "$M_PAID" 200
check_state "paid then reported failed" "$M_PAID" captured 5

# 9. Not a classic callback: an unknown id is acknowledged and moves
#    nothing; a next-generation JSON event and a malformed id are refused.
expect_cb unknown-payment tr_nobody 200
code=$(curl -s -o "$WORK/wh" -w '%{http_code}' -X POST "$FN" -H 'Content-Type: application/json' \
  --data "{\"resource\":\"event\",\"type\":\"payment-link.paid\",\"entityId\":\"$M_LOST\"}")
[ "$code" = "400" ] || fail "a next-generation event answered $code: $(cat "$WORK/wh")"
code=$(curl -s -o "$WORK/wh" -w '%{http_code}' -X POST "$FN" -H 'Content-Type: application/x-www-form-urlencoded' --data "id=../payments")
[ "$code" = "400" ] || fail "a malformed id answered $code"
[ "$(credits)" = "5" ] || fail "a refused callback moved money"
echo "unknown id: acknowledged; next-generation JSON and malformed id: 400; no credit"

# 10. The payment whose callback never came is still pending.
check_state "lost callback" "$M_LOST" created 5

as_owner() {
  sql "select set_config('request.jwt.claims', json_build_object('sub', '$PAYER', 'role', 'authenticated')::text, true);
       $1" | tail -1
}
findings=$(as_owner "select count(*) from public.reconcile_workspace('$WS')") \
  || fail "reconcile_workspace could not be asked (see psql's error above)"
[ -n "$findings" ] || fail "reconcile_workspace answered nothing"
[ "$findings" = "0" ] || fail "reconcile_workspace reports $findings finding(s): $(as_owner "select string_agg(\"check\", '; ') from public.reconcile_workspace('$WS')")"
echo "reconciliation: clean; Mollie and Wero settled separately, 5 credits, mismatches and outages credited nothing"
