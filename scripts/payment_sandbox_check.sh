#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #1637 — the TEST-MODE runner. One real Checkout Session in a developer's
# Stripe TEST account, opened by the create-payment-order function DEPLOYED
# on a DISPOSABLE backend the developer names, paid by hand with a test
# card, settled by that backend's deployed stripe-webhook, read back from
# its ledger. It runs on explicit invocation only — never CI, never Demo —
# and records what happened as a dated evidence record in the #1634 shape
# (docs/product/evidence/), so `provider_sandbox` is a claim with a sha,
# a date and the component fingerprint behind it, or it is `unverified`.
#
#   STRIPE_TEST_SECRET_KEY=sk_test_… STRIPE_TEST_WEBHOOK_SECRET=whsec_… \
#   SANDBOX_URL=https://<ref>.supabase.co SANDBOX_ANON_KEY=… \
#   SANDBOX_SERVICE_ROLE_KEY=… SANDBOX_DB_URL=postgresql://… \
#   bash scripts/payment_sandbox_check.sh --provider stripe --backend <ref>
#
# Refused by construction, before any request leaves:
#   * a live key (sk_live_, rk_live_, pk_live_) — by prefix;
#   * a backend not named on the command line, or one the repository ships
#     as a default (every *.supabase.co host cited under lib/);
#   * a provider without a test-mode flow here (`unsupported`);
#   * a missing prerequisite (`not_run`) — never a pass.
# Exit codes: 0 pass · 1 fail · 2 refused · 3 not_run / unsupported.
# No secret is persisted: the record carries the sha, the date, the
# fingerprint, the outcome and the API version the account answered with;
# keys, webhook secrets and tokens are redacted from everything printed.
# The record and the fingerprint are the ones tool/capability_evidence.dart
# validates; the JSON line printed at the end is what capabilities.json
# takes verbatim.
#
# #1638 — PayPal: the SANDBOX origin only (api-m.sandbox.paypal.com), bound
# by the endpoint and not by the credential's shape; a PAYPAL_API_BASE
# pointing anywhere else is refused. The buyer approves in the browser
# with a sandbox buyer account; the deployed webhook captures and settles.
#   PAYPAL_SANDBOX_CLIENT_ID=… PAYPAL_SANDBOX_SECRET=… PAYPAL_SANDBOX_WEBHOOK_ID=… \
#   … bash scripts/payment_sandbox_check.sh --provider paypal --backend <ref>
#
# #1639 — Mollie and Wero: a `test_` key only (live_ is refused). Wero is
# checked against the methods the test profile actually offers; absent,
# the run is `unsupported`, never a pass and never a real payment.
#   MOLLIE_TEST_API_KEY=test_… … --provider mollie|wero --backend <ref>
set -uo pipefail

redact() {
  # No \b: BSD sed has none, and a key is a key wherever it stands.
  sed -E 's/(sk|rk|pk)_(live|test)_[A-Za-z0-9]+/\1_\2_[redacted]/g;
          s/whsec_[A-Za-z0-9_]+/whsec_[redacted]/g;
          s/(test|live)_[A-Za-z0-9]{12,}/\1_[redacted]/g;
          s/eyJ[A-Za-z0-9_-]{16,}/[token redacted]/g;
          s#postgres(ql)?://[^ ]+#postgres://[redacted]#g'
}

main() {
PROVIDER=""; BACKEND=""
while [ $# -gt 0 ]; do
  case "$1" in
    --provider) PROVIDER="${2:-}"; shift 2 ;;
    --backend) BACKEND="${2:-}"; shift 2 ;;
    *) echo "usage: $0 --provider <stripe|paypal|mollie|wero> --backend <project ref>"; exit 2 ;;
  esac
done
[ -n "$PROVIDER" ] && [ -n "$BACKEND" ] || { echo "refused: name the provider AND the disposable backend"; exit 2; }

SHA=$(git rev-parse HEAD)
DATE=$(date -u +%F)
ID="payments.$PROVIDER"
RECORD="docs/product/evidence/$ID-sandbox-$DATE.md"
CAPABILITY_COMPONENT=$(python3 -c '
import json, sys
for c in json.load(open("docs/product/capabilities.json"))["capabilities"]:
    if c["id"] == sys.argv[1]: print(" ".join(c["component"]))' "$ID")
[ -n "$CAPABILITY_COMPONENT" ] || { echo "refused: $ID is not in docs/product/capabilities.json"; exit 2; }

# The component's version, exactly as tool/capability_evidence/render.dart
# computes it: every file under the component paths, sorted, path then bytes.
fingerprint() {
  local files
  files=$(for p in $CAPABILITY_COMPONENT; do
    if [ -d "$p" ]; then find "$p" -type f; else echo "$p"; fi
  done | LC_ALL=C sort)
  { for f in $files; do printf '%s\n' "$f"; cat "$f"; done; } | shasum -a 256 | cut -c1-12
}
FINGERPRINT=$(fingerprint)

# record <outcome pass|fail|skipped> <result> <detail...>
record() {
  local outcome="$1" result="$2"; shift 2
  mkdir -p "$(dirname "$RECORD")"
  {
    echo "# $ID — $PROVIDER test-mode run"
    echo
    echo "A dated record for the \`provider_sandbox\` scope of \`$ID\` (#1634, #1637):"
    echo "the provider's TEST environment and a disposable backend, never a stub."
    echo
    echo "scope: provider_sandbox"
    echo "capability: $ID"
    echo "sha: $SHA"
    echo "date: $DATE"
    echo "outcome: $outcome"
    echo "result: $result"
    echo "fingerprint: $FINGERPRINT"
    echo "provider: $PROVIDER (test mode)"
    echo "api_version: ${API_VERSION:-n/a}"
    echo "runner: scripts/payment_sandbox_check.sh"
    echo
    echo "$*"
  } > "$RECORD"
  echo "record: $RECORD ($outcome / $result)"
  echo "capabilities.json evidence entry:"
  printf '{"scope": "provider_sandbox", "ref": "%s", "sha": "%s", "date": "%s", "outcome": "%s", "fingerprint": "%s"}\n' \
    "$RECORD" "${SHA:0:12}" "$DATE" "$outcome" "$FINGERPRINT"
}

case "$PROVIDER" in
  stripe|paypal|mollie|wero) ;;
  *) record skipped unsupported "No test-mode flow exists for $PROVIDER in this runner; nothing was exercised."; exit 3 ;;
esac

# ── refusals ──────────────────────────────────────────────────────────
case "${STRIPE_TEST_SECRET_KEY:-}" in
  sk_live_*|rk_live_*|pk_live_*) echo "refused: a LIVE key was given; this runner takes test keys only"; exit 2 ;;
esac
case "${MOLLIE_TEST_API_KEY:-}" in
  live_*) echo "refused: a LIVE Mollie key was given; this runner takes test_ keys only"; exit 2 ;;
esac
PAYPAL_SANDBOX_ORIGIN="https://api-m.sandbox.paypal.com"
case "${PAYPAL_API_BASE:-$PAYPAL_SANDBOX_ORIGIN}" in
  "$PAYPAL_SANDBOX_ORIGIN") ;;
  *) echo "refused: PAYPAL_API_BASE is not the PayPal sandbox origin"; exit 2 ;;
esac
for host in $(grep -rhoE '[a-z]{20}\.supabase\.co' lib | sort -u); do
  [ "$host" = "$BACKEND.supabase.co" ] && { echo "refused: $BACKEND is a backend the app ships as a default, not a disposable one"; exit 2; }
done
case "${SANDBOX_URL:-}" in
  "") ;;
  "https://$BACKEND.supabase.co"|"https://$BACKEND.supabase.co/") ;;
  *) echo "refused: SANDBOX_URL is not the backend named on the command line ($BACKEND)"; exit 2 ;;
esac

# ── prerequisites: absent means not_run ───────────────────────────────
missing=""
case "$PROVIDER" in
  stripe) PROVIDER_VARS="STRIPE_TEST_SECRET_KEY STRIPE_TEST_WEBHOOK_SECRET" ;;
  paypal) PROVIDER_VARS="PAYPAL_SANDBOX_CLIENT_ID PAYPAL_SANDBOX_SECRET PAYPAL_SANDBOX_WEBHOOK_ID" ;;
  mollie|wero) PROVIDER_VARS="MOLLIE_TEST_API_KEY" ;;
esac
for v in $PROVIDER_VARS SANDBOX_URL SANDBOX_ANON_KEY SANDBOX_SERVICE_ROLE_KEY SANDBOX_DB_URL; do
  [ -n "${!v:-}" ] || missing="$missing $v"
done
for tool in curl psql python3; do command -v "$tool" >/dev/null || missing="$missing $tool"; done
if [ -n "$missing" ]; then
  record skipped not_run "Not run: missing$missing. No request was made and nothing is claimed."
  echo "not_run: missing$missing"
  exit 3
fi
case "$PROVIDER" in
  stripe)
    case "$STRIPE_TEST_SECRET_KEY" in sk_test_*|rk_test_*) ;; *) echo "refused: the key is neither sk_test_ nor rk_test_"; exit 2 ;; esac ;;
  mollie|wero)
    case "$MOLLIE_TEST_API_KEY" in test_*) ;; *) echo "refused: the Mollie key is not a test_ key"; exit 2 ;; esac
    # The profile says which methods its TEST mode offers. Wero absent is
    # `unsupported`: a generic Mollie success proves nothing about Wero.
    methods=$(curl -s "https://api.mollie.com/v2/methods?testmode=true&amount%5Bvalue%5D=1.00&amount%5Bcurrency%5D=EUR" \
      -H "Authorization: Bearer $MOLLIE_TEST_API_KEY" | python3 -c 'import json,sys
try: print(" ".join(m["id"] for m in json.load(sys.stdin)["_embedded"]["methods"]))
except Exception: print("")')
    [ -n "$methods" ] || { echo "refused: the Mollie test profile did not answer with its methods"; exit 2; }
    if [ "$PROVIDER" = "wero" ] && ! printf ' %s ' "$methods" | grep -q ' wero '; then
      record skipped unsupported "Wero is not offered by this Mollie test profile (methods: $methods). Nothing was paid; Wero stays unverified."
      exit 3
    fi
    API_VERSION="mollie v2; methods: $methods" ;;
  paypal)
    # The credential must be accepted by the SANDBOX origin: a live pair is
    # refused there, whatever its shape.
    code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$PAYPAL_SANDBOX_ORIGIN/v1/oauth2/token" \
      -u "$PAYPAL_SANDBOX_CLIENT_ID:$PAYPAL_SANDBOX_SECRET" -d grant_type=client_credentials)
    [ "$code" = "200" ] || { echo "refused: the PayPal sandbox did not accept these credentials ($code)"; exit 2; }
    API_VERSION="paypal orders v2 (sandbox)" ;;
esac

# ── the run ───────────────────────────────────────────────────────────
WORK="$(mktemp -d -t deskilo-sandbox-XXXXXX)"
json() { python3 -c "import json,sys; print(json.load(sys.stdin)$1)"; }
sql() { psql "$SANDBOX_DB_URL" -v ON_ERROR_STOP=1 -At -c "$1"; }
RUN="$(date +%s)"
EMAIL="sandbox-payer-$RUN@deskilo.test"
cleanup() {
  # No secret stays on the disposable backend, and the fixture goes with it.
  [ -n "${WS:-}" ] && sql "delete from public.workspaces where id = '$WS'" >/dev/null 2>&1
  [ -n "${PAYER:-}" ] && curl -s -X DELETE "$SANDBOX_URL/auth/v1/admin/users/$PAYER" \
    -H "apikey: $SANDBOX_SERVICE_ROLE_KEY" -H "Authorization: Bearer $SANDBOX_SERVICE_ROLE_KEY" >/dev/null 2>&1
  rm -rf "$WORK"
}
trap cleanup EXIT
fail() { record fail fail "$*"; echo "fail: $*"; exit 1; }

PAYER=$(curl -s -X POST "$SANDBOX_URL/auth/v1/admin/users" \
  -H "apikey: $SANDBOX_SERVICE_ROLE_KEY" -H "Authorization: Bearer $SANDBOX_SERVICE_ROLE_KEY" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"Sandbox-$RUN!\",\"email_confirm\":true}" | json "['id']") \
  || fail "could not create the payer on the disposable backend"
JWT=$(curl -s -X POST "$SANDBOX_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $SANDBOX_ANON_KEY" -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"Sandbox-$RUN!\"}" | json "['access_token']") \
  || fail "the payer could not sign in"
WS=$(sql "select set_config('request.jwt.claims', json_build_object('sub', '$PAYER', 'role', 'authenticated')::text, false);
          select public.create_workspace('Sandbox $RUN', 'FR', 'EUR', 'Europe/Paris', 'prod', false, null);" | tail -1)
[ -n "$WS" ] || fail "could not create the fixture workspace"
MEMBER=$(sql "select id from public.members where workspace_id = '$WS' and user_id = '$PAYER'")
case "$PROVIDER" in
  stripe) CONFIG="json_build_object('secret_key', '$STRIPE_TEST_SECRET_KEY', 'webhook_secret', '$STRIPE_TEST_WEBHOOK_SECRET', 'return_url', 'https://example.test/return')" ;;
  paypal) CONFIG="json_build_object('client_id', '$PAYPAL_SANDBOX_CLIENT_ID', 'secret', '$PAYPAL_SANDBOX_SECRET', 'env', 'sandbox', 'webhook_id', '$PAYPAL_SANDBOX_WEBHOOK_ID', 'return_url', 'https://example.test/return')" ;;
  mollie|wero) CONFIG="json_build_object('api_key', '$MOLLIE_TEST_API_KEY', 'return_url', 'https://example.test/return')" ;;
esac
sql "insert into public.payment_credentials (workspace_id, provider, config) values ('$WS', '$PROVIDER', $CONFIG::jsonb)" >/dev/null \
  || fail "could not configure the test credentials"

code=$(curl -s -o "$WORK/out" -w '%{http_code}' -X POST "$SANDBOX_URL/functions/v1/create-payment-order" \
  -H "Authorization: Bearer $JWT" -H "apikey: $SANDBOX_ANON_KEY" -H 'Content-Type: application/json' \
  -d "{\"workspace_id\":\"$WS\",\"provider\":\"$PROVIDER\",\"member_id\":\"$MEMBER\",\"amount_cents\":100,\"period\":\"$(date -u +%Y-%m)\",\"currency\":\"EUR\"}")
[ "$code" = "200" ] || fail "the deployed order handler answered $code: $(cat "$WORK/out")"
SESSION=$(json "['order_id']" < "$WORK/out")
URL=$(json "['approve_url']" < "$WORK/out")
if [ "$PROVIDER" = "stripe" ]; then
  API_VERSION=$(curl -s -D - -o /dev/null "https://api.stripe.com/v1/checkout/sessions/$SESSION" \
    -u "$STRIPE_TEST_SECRET_KEY:" | sed -n 's/^[Ss]tripe-[Vv]ersion: *//p' | tr -d '\r')
fi
echo "$PROVIDER order $SESSION opened in test mode (${API_VERSION:-unknown API version})"
echo
echo "ACTION REQUIRED — pay it by hand, in a browser, in TEST mode:"
echo "  1. open $URL"
case "$PROVIDER" in
  stripe) echo "  2. card 4242 4242 4242 4242, any future expiry, any CVC, any postcode" ;;
  paypal) echo "  2. log in with a PayPal SANDBOX buyer account and approve; the deployed webhook captures" ;;
  mollie) echo "  2. pick any method on Mollie's test page and choose 'Paid'" ;;
  wero) echo "  2. on Mollie's Wero test page choose 'Paid'" ;;
esac
echo "  3. this runner waits up to ${PAYMENT_SANDBOX_WAIT:-600}s for the deployed webhook to settle it"
echo

status=""
for _ in $(seq 1 $(( ${PAYMENT_SANDBOX_WAIT:-600} / 5 ))); do
  status=$(sql "select status from public.payment_intents where provider = '$PROVIDER' and order_id = '$SESSION'")
  [ "$status" = "created" ] || break
  sleep 5
done
case "$status" in
  captured) ;;
  failed) fail "$PROVIDER reported the payment as failed, canceled or expired; the intent is marked failed and nothing was credited." ;;
  *) fail "the webhook never reached the backend within ${PAYMENT_SANDBOX_WAIT:-600}s: the intent is still pending, which is what the member would see." ;;
esac
credits=$(sql "select count(*) from public.ledger_entries l join public.payment_intents i on i.ledger_entry_id = l.id
                where i.order_id = '$SESSION' and l.amount_cents = i.amount_cents and l.period = i.period and l.member_id = i.member_id")
[ "$credits" = "1" ] || fail "captured, but the capture names $credits matching posting(s) instead of one"
findings=$(sql "select count(*) from public.reconcile_workspace('$WS')")
[ "$findings" = "0" ] || fail "reconcile_workspace reports $findings finding(s)"
record pass pass "One $PROVIDER order opened by the deployed create-payment-order, paid in the provider's test mode, settled once by the deployed webhook: captured, one associated posting, reconciliation clean. No real charge: test mode only."
echo "pass"
}

# Everything the runner prints goes through the redaction; the exit code
# is main's own, not the filter's.
main "$@" 2>&1 | redact
exit "${PIPESTATUS[0]}"
