# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #1637 — the Stripe settlement matrix. Sourced by edge_payment_check.sh
# once phase 1 has proved the payer can open an intent, so it inherits the
# stack, the stateful stub, the payer and the workspace. Every scenario
# opens ITS OWN session through the real order handler, reads that session
# back from the stub (the amount, currency and reference the PROVIDER
# recorded), signs a real-shaped event with the workspace's webhook secret
# — HMAC-SHA256 over the raw bytes, as Stripe does — and posts it to the
# real, unmodified stripe-webhook handler. The ledger is then read back
# with SQL: status, credits, the posting the capture names, and a clean
# reconciliation.
#
# The handler pins no Stripe-Version; it reads id, payment_status,
# payment_intent and amount_total off the Checkout Session, which is the
# shape these fixtures carry. Q-018 (PayPal) and Q-019 (Mollie/Wero) add a
# sibling file each; this one says nothing about them.
export STRIPE_API_VERSION="2025-08-27.basil"   # read by the event builder below

WEBHOOK_SECRET="whsec_local_$RUN"
sql "update public.payment_credentials
        set config = config || '{\"webhook_secret\": \"$WEBHOOK_SECRET\"}'
      where workspace_id = '$WS' and provider = 'stripe'" >/dev/null \
  || fail "could not set the webhook secret"

# ── fixtures: one session per scenario, through the real order handler ─
open_session() {
  [ "$(call -H "Authorization: Bearer $PAYER_JWT")" = "200" ] \
    || fail "$1: the order handler refused: $(cat "$WORK/out")"
  json "['order_id']" < "$WORK/out"
}
LOST="cs_test_${RUN}_1"              # phase 1's session: no webhook ever comes
PAID=$(open_session paid)
ASYNC=$(open_session async)
FAILED=$(open_session failed)
DUP=$(open_session duplicate)
EXPIRED=$(open_session expired)
BADSIG=$(open_session bad-signature)
AMOUNT=$(open_session wrong-amount)
RACE=$(open_session race)

# The provider's record of a session equals the intent it was opened for.
session() { curl -s "http://127.0.0.1:$STUB_PORT/v1/checkout/sessions/$1"; }
recorded=$(session "$PAID" | python3 -c 'import json,sys; s=json.load(sys.stdin); print(s["amount_total"], s["currency"], s["client_reference_id"])')
stored=$(sql "select amount_cents || ' ' || lower(currency) || ' ' || reference
                from public.payment_intents where order_id = '$PAID'")
[ "$recorded" = "$stored" ] || fail "the provider recorded '$recorded', the intent says '$stored'"
echo "provider record equals the intent: $recorded"

# ── the real webhook handler takes the port over ─────────────────────
kill "$FN_PID" 2>/dev/null; wait "$FN_PID" 2>/dev/null
SUPABASE_URL="$API_URL" SUPABASE_SERVICE_ROLE_KEY="$SERVICE_KEY" \
  deno run --allow-net --allow-env --allow-read --allow-import \
  supabase/functions/stripe-webhook/index.ts > "$WORK/wh.log" 2>&1 &
FN_PID=$!
for _ in $(seq 1 90); do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$FN" || true)
  [ "$code" = "405" ] && break
  sleep 1
done
[ "$code" = "405" ] || { cat "$WORK/wh.log"; fail "the webhook handler did not start"; }

# event <session> <type> <payment_status> [amount_total] → $WORK/event.json,
# built from the provider's record of the session.
event() {
  session "$1" | EV_TYPE="$2" EV_STATUS="$3" EV_AMOUNT="${4:-}" python3 -c '
import json, os, sys
s = json.load(sys.stdin)
s["payment_status"] = os.environ["EV_STATUS"]
if os.environ["EV_AMOUNT"]: s["amount_total"] = int(os.environ["EV_AMOUNT"])
print(json.dumps({"id": "evt_" + s["id"] + "_" + os.environ["EV_TYPE"], "object": "event",
                  "api_version": os.environ["STRIPE_API_VERSION"], "type": os.environ["EV_TYPE"],
                  "data": {"object": s}}), end="")' > "$WORK/event.json"
}
# post [secret] [out-file] → HTTP code; the signature covers the raw bytes sent.
post() {
  local secret="${1:-$WEBHOOK_SECRET}" out="${2:-$WORK/wh}" ts sig
  ts=$(date +%s)
  sig=$({ printf '%s.' "$ts"; cat "$WORK/event.json"; } | openssl dgst -sha256 -hmac "$secret" | sed 's/^.* //')
  curl -s -o "$out" -w '%{http_code}' -X POST "$FN" -H 'Content-Type: application/json' \
    -H "Stripe-Signature: t=$ts,v1=$sig" --data-binary @"$WORK/event.json"
}
deliver() {  # deliver <label> <session> <type> <payment_status> [amount] → expects 200
  local label="$1"; shift
  event "$@"
  local code; code=$(post)
  [ "$code" = "200" ] || { cat "$WORK/wh.log"; fail "$label: the webhook answered $code: $(cat "$WORK/wh")"; }
}

# ── what the ledger says ─────────────────────────────────────────────
status_of() { sql "select status from public.payment_intents where order_id = '$1'"; }
credits() { sql "select count(*) from public.ledger_entries where workspace_id = '$WS' and kind = 'credit' and category = 'payment'"; }
# The capture names ONE posting that matches it in member, amount and period.
associated() {
  sql "select count(*) from public.payment_intents i join public.ledger_entries l on l.id = i.ledger_entry_id
        where i.order_id = '$1' and l.member_id = i.member_id and l.amount_cents = i.amount_cents
          and l.period = i.period and i.capture_id = 'pi_' || i.order_id"
}
check_state() {  # check_state <label> <session> <status> <credits so far>
  [ "$(status_of "$2")" = "$3" ] || fail "$1: expected $3, found $(status_of "$2")"
  [ "$(credits)" = "$4" ] || fail "$1: expected $4 payment credit(s) in the ledger, found $(credits)"
  if [ "$3" = "captured" ]; then
    [ "$(associated "$2")" = "1" ] || fail "$1: the capture does not name a matching posting"
  fi
  echo "$1: $3, $4 credit(s)"
}

# 1. completed + paid → captured, one credit, associated.
deliver paid "$PAID" checkout.session.completed paid
check_state "completed+paid" "$PAID" captured 1

# 2. completed + unpaid does NOT credit; the later async success credits once,
#    and its redelivery credits nothing more.
deliver unpaid "$ASYNC" checkout.session.completed unpaid
check_state "completed+unpaid" "$ASYNC" created 1
deliver async "$ASYNC" checkout.session.async_payment_succeeded paid
check_state "async_payment_succeeded" "$ASYNC" captured 2
[ "$(post)" = "200" ] || fail "async redelivery refused"
check_state "async_payment_succeeded redelivered" "$ASYNC" captured 2

# 3. completed + unpaid, then the money never comes.
deliver unpaid "$FAILED" checkout.session.completed unpaid
deliver failed "$FAILED" checkout.session.async_payment_failed unpaid
check_state "async_payment_failed" "$FAILED" failed 2

# 4. The same paid event delivered twice.
deliver dup "$DUP" checkout.session.completed paid
[ "$(post)" = "200" ] || fail "duplicate delivery refused"
check_state "duplicate delivery" "$DUP" captured 3

# 5. Expiry.
deliver expired "$EXPIRED" checkout.session.expired unpaid
check_state "expired" "$EXPIRED" failed 3

# 6. A paid event under the wrong secret: refused, nothing moves.
event "$BADSIG" checkout.session.completed paid
[ "$(post whsec_somebody_else)" = "400" ] || fail "a bad signature was not refused: $(cat "$WORK/wh")"
check_state "bad signature" "$BADSIG" created 3

# 7. A paid event whose amount is not the intent's: the settlement raises,
#    the handler answers 500 so Stripe retries, nothing is credited.
event "$AMOUNT" checkout.session.completed paid 2400
[ "$(post)" = "500" ] || fail "a wrong amount was accepted: $(cat "$WORK/wh")"
check_state "wrong amount" "$AMOUNT" created 3

# 8. A session nobody opened: acknowledged, nothing to settle.
session_json='{"id":"cs_test_nobody","object":"checkout.session","payment_status":"paid","amount_total":2500}'
printf '{"id":"evt_nobody","object":"event","type":"checkout.session.completed","data":{"object":%s}}' "$session_json" > "$WORK/event.json"
[ "$(post)" = "200" ] || fail "an unknown session was not acknowledged"
[ "$(credits)" = "3" ] || fail "an unknown session moved money"
echo "unknown session: acknowledged, no credit"

# 9. Two deliveries of one paid event AT ONCE, through two connections into
#    the handler: the row lock serialises them and exactly one credits.
event "$RACE" checkout.session.completed paid
post "$WEBHOOK_SECRET" "$WORK/race1" > "$WORK/code1" & r1=$!
post "$WEBHOOK_SECRET" "$WORK/race2" > "$WORK/code2" & r2=$!
wait "$r1" "$r2"
[ "$(cat "$WORK/code1")$(cat "$WORK/code2")" = "200200" ] \
  || fail "the race answered $(cat "$WORK/code1")/$(cat "$WORK/code2")"
check_state "concurrent delivery" "$RACE" captured 4

# 10. The session whose webhook never arrives is still pending, not paid.
check_state "lost webhook" "$LOST" created 4

# The books agree with themselves: no captured intent without its posting.
# reconcile_workspace answers whoever may see the finances, so it is asked
# AS THE OWNER — the impersonation phase 1 already uses — and a query that
# errors is a failure in its own words, never an empty count read as one.
as_owner() {
  sql "select set_config('request.jwt.claims', json_build_object('sub', '$PAYER', 'role', 'authenticated')::text, true);
       $1" | tail -1
}
findings=$(as_owner "select count(*) from public.reconcile_workspace('$WS')") \
  || fail "reconcile_workspace could not be asked (see psql's error above)"
[ -n "$findings" ] || fail "reconcile_workspace answered nothing"
[ "$findings" = "0" ] || fail "reconcile_workspace reports $findings finding(s): $(as_owner "select string_agg(\"check\", '; ') from public.reconcile_workspace('$WS')")"
echo "reconciliation: clean; 9 sessions, 4 captured, 2 failed, 3 pending, 4 credits"
