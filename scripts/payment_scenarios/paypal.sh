# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #1638 — the PayPal settlement matrix. Sourced by edge_payment_check.sh
# after phase 1, so it inherits the stack, the payer, the workspace, the
# real order handler (started with PAYPAL_API_BASE on this stub's port)
# and the helpers. Every scenario opens ITS OWN order through the real
# order handler, reads the order back from the stateful local PayPal
# (paypal_stub.py), builds a real-shaped webhook event from what the
# PROVIDER recorded, and posts it to the real, unmodified paypal-webhook.
# The ledger and the stub's own capture count are then read back: zero
# side effects is asserted, not inferred from a status code.
#
# Verification here is the stub's (`sig-ok`): LOCAL protocol evidence,
# never proof of PayPal's live signatures. Nothing here speaks for Stripe
# or Mollie.
PP_PORT=54997
PP="http://127.0.0.1:$PP_PORT"
: > "$WORK/pp_hits"
python3 scripts/payment_scenarios/paypal_stub.py "$PP_PORT" "$WORK/pp_hits" "PP$RUN" &
PP_PID=$!
trap 'kill $STUB_PID $FN_PID $PP_PID 2>/dev/null; rm -rf "$WORK"' EXIT
for _ in $(seq 1 30); do curl -s -o /dev/null "$PP/v2/none" && break; sleep 0.5; done

sql "insert into public.payment_credentials (workspace_id, provider, config)
     values ('$WS', 'paypal', '{\"client_id\": \"pp_client_stub\", \"secret\": \"pp_secret_stub\", \"env\": \"sandbox\",
                                \"return_url\": \"https://example.test/return\", \"webhook_id\": \"WH-$RUN\"}')" >/dev/null \
  || fail "could not configure PayPal"
BODY="{\"workspace_id\":\"$WS\",\"provider\":\"paypal\",\"member_id\":\"$MEMBER\",\"amount_cents\":2500,\"period\":\"2026-09\",\"currency\":\"EUR\"}"

open_order() {
  [ "$(call -H "Authorization: Bearer $PAYER_JWT")" = "200" ] \
    || fail "$1: the order handler refused: $(cat "$WORK/out")"
  json "['order_id']" < "$WORK/out"
}
PAID=$(open_order paid);          UNAPPROVED=$(open_order unapproved)
DENIED=$(open_order denied);      BADSIG=$(open_order bad-signature)
OUTAGE=$(open_order outage);      MISMATCH=$(open_order mismatch)
DUP=$(open_order duplicate);      RACE=$(open_order race)
LOSTREPLY=$(open_order lost-reply); REORDER=$(open_order reorder)
LOST=$(open_order lost-webhook)

order() { curl -s "$PP/_test/orders/$1"; }
recorded=$(order "$PAID" | python3 -c 'import json,sys; o=json.load(sys.stdin); a=o["amount"]; print(round(float(a["value"])*100), a["currency_code"], o["custom_id"], o["intent"])')
stored=$(sql "select amount_cents || ' ' || currency || ' ' || reference from public.payment_intents where order_id = '$PAID'")
[ "$recorded" = "$stored CAPTURE" ] || fail "PayPal recorded '$recorded', the intent says '$stored' (intent CAPTURE)"
echo "provider record equals the intent: $recorded"

# ── the real webhook handler takes the port over ─────────────────────
kill "$FN_PID" 2>/dev/null; wait "$FN_PID" 2>/dev/null
SUPABASE_URL="$API_URL" SUPABASE_SERVICE_ROLE_KEY="$SERVICE_KEY" PAYPAL_API_BASE="$PP" \
  deno run --allow-net --allow-env --allow-read --allow-import \
  supabase/functions/paypal-webhook/index.ts > "$WORK/wh.log" 2>&1 &
FN_PID=$!
for _ in $(seq 1 90); do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$FN" || true)
  [ "$code" = "405" ] && break
  sleep 1
done
[ "$code" = "405" ] || { cat "$WORK/wh.log"; fail "the paypal webhook did not start"; }

# event <order> <type> [value] [currency] [custom_id] → $WORK/event.json,
# built from the provider's record of the order.
event() {
  order "$1" | EV_TYPE="$2" EV_VALUE="${3:-}" EV_CUR="${4:-}" EV_REF="${5:-}" python3 -c '
import json, os, sys
o = json.load(sys.stdin)
amount = dict(o["amount"])
if os.environ["EV_VALUE"]: amount["value"] = os.environ["EV_VALUE"]
if os.environ["EV_CUR"]: amount["currency_code"] = os.environ["EV_CUR"]
ref = os.environ["EV_REF"] or o["custom_id"]
t = os.environ["EV_TYPE"]
if t == "CHECKOUT.ORDER.APPROVED":
    res = {"id": o["id"], "status": "APPROVED", "intent": "CAPTURE",
           "purchase_units": [{"custom_id": ref, "amount": amount}]}
else:
    res = {"id": o["capture_id"], "status": "COMPLETED" if t.endswith("COMPLETED") else "DECLINED",
           "amount": amount, "custom_id": ref,
           "supplementary_data": {"related_ids": {"order_id": o["id"]}}}
print(json.dumps({"id": "WH-" + o["id"] + "-" + t, "event_type": t, "resource_type": "capture",
                  "resource": res}), end="")' > "$WORK/event.json"
}
post() {  # post [signature] [out-file] → HTTP code
  local sig="${1:-sig-ok}" out="${2:-$WORK/wh}"
  curl -s -o "$out" -w '%{http_code}' -X POST "$FN" -H 'Content-Type: application/json' \
    -H 'paypal-transmission-id: t-1' -H 'paypal-transmission-time: 2026-09-26T10:00:00Z' \
    -H 'paypal-cert-url: https://api.sandbox.paypal.test/cert' -H 'paypal-auth-algo: SHA256withRSA' \
    -H "paypal-transmission-sig: $sig" --data-binary @"$WORK/event.json"
}
expect_post() {  # expect_post <label> <code> [signature]
  local code; code=$(post "${3:-sig-ok}")
  [ "$code" = "$2" ] || { tail -20 "$WORK/wh.log"; fail "$1: the webhook answered $code, expected $2: $(cat "$WORK/wh")"; }
}
approve() { curl -s -X POST "$PP/_test/approve/$1" >/dev/null; }

status_of() { sql "select status from public.payment_intents where provider = 'paypal' and order_id = '$1'"; }
credits() { sql "select count(*) from public.ledger_entries where workspace_id = '$WS' and kind = 'credit' and category = 'payment'"; }
captures() { order "$1" | json "['captures']"; }
associated() {
  sql "select count(*) from public.payment_intents i join public.ledger_entries l on l.id = i.ledger_entry_id
        where i.order_id = '$1' and l.member_id = i.member_id and l.amount_cents = i.amount_cents
          and l.period = i.period and i.capture_id = 'CAP-' || i.order_id"
}
check_state() {  # check_state <label> <order> <status> <credits> <provider captures>
  [ "$(status_of "$2")" = "$3" ] || fail "$1: expected $3, found $(status_of "$2")"
  [ "$(credits)" = "$4" ] || fail "$1: expected $4 payment credit(s), found $(credits)"
  [ "$(captures "$2")" = "$5" ] || fail "$1: expected $5 capture(s) at PayPal, found $(captures "$2")"
  if [ "$3" = "captured" ]; then
    [ "$(associated "$2")" = "1" ] || fail "$1: the capture does not name a matching posting"
  fi
  echo "$1: $3, $4 credit(s), $5 provider capture(s)"
}

# 1. Approved by the buyer → the webhook captures and settles from the
#    capture reply; the COMPLETED event that follows credits nothing more.
approve "$PAID"; event "$PAID" CHECKOUT.ORDER.APPROVED
expect_post approved 200
check_state "approved → captured" "$PAID" captured 1 1
event "$PAID" PAYMENT.CAPTURE.COMPLETED
expect_post completed-after 200
check_state "completed after capture" "$PAID" captured 1 1

# 2. An APPROVED event for an order the buyer never approved: PayPal
#    refuses the capture, nothing is credited, the intent stays pending.
event "$UNAPPROVED" CHECKOUT.ORDER.APPROVED
expect_post unapproved 500
check_state "not approved at PayPal" "$UNAPPROVED" created 1 0

# 3. Denied capture → failed.
event "$DENIED" PAYMENT.CAPTURE.DENIED
expect_post denied 200
check_state "denied" "$DENIED" failed 1 0

# 4. A bad signature: refused before any capture.
approve "$BADSIG"; event "$BADSIG" CHECKOUT.ORDER.APPROVED
expect_post bad-signature 400 sig-forged
check_state "bad signature" "$BADSIG" created 1 0

# 5. The verifier is down: not a verification. 500, no capture.
approve "$OUTAGE"; curl -s -X POST "$PP/_test/verify-outage" -d '{"on":true}' >/dev/null
event "$OUTAGE" CHECKOUT.ORDER.APPROVED
expect_post verifier-outage 500
curl -s -X POST "$PP/_test/verify-outage" -d '{"on":false}' >/dev/null
check_state "verification outage" "$OUTAGE" created 1 0

# 6. An approved order whose amount, currency or reference is not the
#    intent's: refused BEFORE capture. A COMPLETED in another currency
#    never settles either.
approve "$MISMATCH"
event "$MISMATCH" CHECKOUT.ORDER.APPROVED 24.00;          expect_post wrong-amount 409
event "$MISMATCH" CHECKOUT.ORDER.APPROVED "" USD;         expect_post wrong-currency 409
event "$MISMATCH" CHECKOUT.ORDER.APPROVED "" "" PAY-OTHER; expect_post wrong-reference 409
event "$MISMATCH" PAYMENT.CAPTURE.COMPLETED "" USD;       expect_post completed-wrong-currency 500
event "$MISMATCH" PAYMENT.CAPTURE.COMPLETED "not-a-number"; expect_post completed-malformed 500
check_state "mismatched order" "$MISMATCH" created 1 0

# 7. The same approval delivered twice: one capture, one credit.
approve "$DUP"; event "$DUP" CHECKOUT.ORDER.APPROVED
expect_post dup-1 200; expect_post dup-2 200
check_state "duplicate approval" "$DUP" captured 2 1

# 8. Two deliveries of one approval AT ONCE.
approve "$RACE"; event "$RACE" CHECKOUT.ORDER.APPROVED
post sig-ok "$WORK/race1" > "$WORK/code1" & r1=$!
post sig-ok "$WORK/race2" > "$WORK/code2" & r2=$!
wait "$r1" "$r2"
[ "$(cat "$WORK/code1")$(cat "$WORK/code2")" = "200200" ] \
  || fail "the race answered $(cat "$WORK/code1")/$(cat "$WORK/code2")"
check_state "concurrent approval" "$RACE" captured 3 1

# 9. The capture happened at PayPal and its reply was lost: nothing is
#    credited yet (the money moved, the answer did not arrive); the
#    redelivered approval asks with the SAME request id, gets the FIRST
#    capture back, and credits once. PayPal captured once.
approve "$LOSTREPLY"; curl -s -X POST "$PP/_test/drop-capture-reply/$LOSTREPLY" >/dev/null
event "$LOSTREPLY" CHECKOUT.ORDER.APPROVED
expect_post lost-reply 500
check_state "capture reply lost" "$LOSTREPLY" created 3 1
expect_post lost-reply-redelivered 200
check_state "capture reply lost, redelivered" "$LOSTREPLY" captured 4 1

# 10. Order changed: the order was captured by another path before our
#     approval handling ran. The webhook reads the order back instead of
#     capturing again, and settles what it says; the late COMPLETED adds
#     nothing.
approve "$REORDER"; curl -s -X POST "$PP/_test/capture-elsewhere/$REORDER" >/dev/null
event "$REORDER" CHECKOUT.ORDER.APPROVED
expect_post reordered 200
check_state "already captured, read back" "$REORDER" captured 5 1
event "$REORDER" PAYMENT.CAPTURE.COMPLETED
expect_post reordered-completed 200
check_state "late completed" "$REORDER" captured 5 1

# 11. An order nobody opened: acknowledged, nothing moves.
printf '{"id":"WH-nobody","event_type":"CHECKOUT.ORDER.APPROVED","resource":{"id":"NOBODY-1","purchase_units":[]}}' > "$WORK/event.json"
expect_post unknown-order 200
[ "$(credits)" = "5" ] || fail "an unknown order moved money"
echo "unknown order: acknowledged, no credit"

# 12. The order whose webhook never arrives is still pending, not paid.
check_state "lost webhook" "$LOST" created 5 0

capture_calls=$(grep -c '/capture$' "$WORK/pp_hits" || true)
echo "capture requests the handler sent: $capture_calls"

as_owner() {
  sql "select set_config('request.jwt.claims', json_build_object('sub', '$PAYER', 'role', 'authenticated')::text, true);
       $1" | tail -1
}
findings=$(as_owner "select count(*) from public.reconcile_workspace('$WS')") \
  || fail "reconcile_workspace could not be asked (see psql's error above)"
[ -n "$findings" ] || fail "reconcile_workspace answered nothing"
[ "$findings" = "0" ] || fail "reconcile_workspace reports $findings finding(s): $(as_owner "select string_agg(\"check\", '; ') from public.reconcile_workspace('$WS')")"
echo "reconciliation: clean; 11 orders, 5 captured once each, 1 failed, 5 pending, 5 credits"
