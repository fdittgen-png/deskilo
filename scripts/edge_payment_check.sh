#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #1450 — a member can actually start a payment.
#
# `create-payment-order` verified the caller's JWT and then opened the
# payment intent through the SERVICE-ROLE client. `open_payment_intent`
# asks `my_active_member` (0210), which reads `auth.uid()` — and a
# service-role call has no user. Every payment failed with
# intent_open_failed before any provider was contacted, while the SQL
# tests (which inject claims) and `deno check` (which reads types) were
# both green. Neither exercises how the handler COMPOSES its clients.
#
# So this runs the real handler, unmodified, under Deno on the runner,
# against the replayed database, with real users signed in through the
# local auth server:
#
#   * the service-role client cannot open an intent — the guard needs a
#     caller, which is exactly why the handler must pass one;
#   * no token → 401; another user paying someone else's bill → 403;
#     neither leaves an intent or reaches the provider;
#   * the member paying their own bill → 200 `created`, one intent with
#     the stub's order id, and exactly one provider request.
#
# The provider is a local stub on 127.0.0.1 (`STRIPE_API_BASE`): no
# request leaves the runner and no key is real.
#
# #1637 — `--settle <provider>` goes on from here: the same fixtures, the
# stateful stub in scripts/payment_scenarios/, the REAL webhook handler
# and a matrix of locally signed events, sourced from
# scripts/payment_scenarios/<provider>.sh. Only `stripe` exists; Q-018
# and Q-019 add theirs, and no file speaks for another provider.
set -uo pipefail

fail() { echo "::error::payment edge check: $*"; exit 1; }

SETTLE=""
case "${1:-}" in
  --settle) SETTLE="${2:?--settle needs a provider}"
            [ -f "scripts/payment_scenarios/$SETTLE.sh" ] || fail "no settlement scenarios for $SETTLE" ;;
  "") ;;
  *) fail "usage: $0 [--settle <provider>]" ;;
esac

env_of() { supabase status -o env | sed -n "s/^$1=\"\(.*\)\"$/\1/p"; }
API_URL="$(env_of API_URL)"
ANON_KEY="$(env_of ANON_KEY)"
SERVICE_KEY="$(env_of SERVICE_ROLE_KEY)"
DB_URL="$(env_of DB_URL)"
[ -n "$API_URL" ] && [ -n "$ANON_KEY" ] && [ -n "$SERVICE_KEY" ] && [ -n "$DB_URL" ] \
  || fail "supabase status did not report the local stack"

WORK="$(mktemp -d -t deskilo-pay-XXXXXX)"
STUB_PORT=54998
# Deno.serve() without options listens on 8000.
FN_PORT=8000
json() { python3 -c "import json,sys; print(json.load(sys.stdin)$1)"; }
sql() { psql "$DB_URL" -v ON_ERROR_STOP=1 -At -c "$1"; }

# Unique per invocation: the settlement pass follows this one on the same
# stack, and neither the users' e-mails nor the stub's session ids may
# collide with the first pass's rows.
RUN="$$"

# ── the provider stub ────────────────────────────────────────────────
: > "$WORK/hits"
python3 scripts/payment_scenarios/stripe_stub.py "$STUB_PORT" "$WORK/hits" "cs_test_$RUN" &
STUB_PID=$!

# ── the real handler ─────────────────────────────────────────────────
SUPABASE_URL="$API_URL" SUPABASE_ANON_KEY="$ANON_KEY" \
SUPABASE_SERVICE_ROLE_KEY="$SERVICE_KEY" \
STRIPE_API_BASE="http://127.0.0.1:$STUB_PORT" \
  deno run --allow-net --allow-env --allow-read --allow-import \
  supabase/functions/create-payment-order/index.ts > "$WORK/fn.log" 2>&1 &
FN_PID=$!
trap 'kill $STUB_PID $FN_PID 2>/dev/null; rm -rf "$WORK"' EXIT

FN="http://127.0.0.1:$FN_PORT"
for _ in $(seq 1 90); do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$FN" || true)
  [ "$code" = "405" ] && break
  sleep 1
done
[ "$code" = "405" ] || { cat "$WORK/fn.log"; fail "the handler did not start"; }

# ── two real users ───────────────────────────────────────────────────
user() {
  curl -s -X POST "$API_URL/auth/v1/admin/users" \
    -H "apikey: $SERVICE_KEY" -H "Authorization: Bearer $SERVICE_KEY" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"$1\",\"password\":\"Pay-check-2026!\",\"email_confirm\":true}" | json "['id']"
}
token() {
  curl -s -X POST "$API_URL/auth/v1/token?grant_type=password" \
    -H "apikey: $ANON_KEY" -H 'Content-Type: application/json' \
    -d "{\"email\":\"$1\",\"password\":\"Pay-check-2026!\"}" | json "['access_token']"
}
PAYER=$(user "payer-$RUN@deskilo.test") || fail "could not create the payer"
STRANGER=$(user "stranger-$RUN@deskilo.test") || fail "could not create the stranger"
PAYER_JWT=$(token "payer-$RUN@deskilo.test") || fail "the payer could not sign in"
STRANGER_JWT=$(token "stranger-$RUN@deskilo.test") || fail "the stranger could not sign in"

# A production workspace the payer owns, with Stripe configured.
WS=$(sql "select set_config('request.jwt.claims', json_build_object('sub', '$PAYER', 'role', 'authenticated')::text, false);
          select public.create_workspace('Pay check', 'FR', 'EUR', 'Europe/Paris', 'prod', false, null);" | tail -1) \
  || fail "could not create the workspace"
[ -n "$WS" ] || fail "could not create the workspace"
MEMBER=$(sql "select id from public.members where workspace_id = '$WS' and user_id = '$PAYER'")
[ -n "$MEMBER" ] || fail "the payer is not a member of their workspace"
sql "insert into public.payment_credentials (workspace_id, provider, config)
     values ('$WS', 'stripe', '{\"secret_key\": \"sk_test_stub\", \"return_url\": \"https://example.test/return\"}')" >/dev/null \
  || fail "could not configure the provider"

intents() { sql "select count(*) from public.payment_intents where workspace_id = '$WS'"; }
BODY="{\"workspace_id\":\"$WS\",\"provider\":\"stripe\",\"member_id\":\"$MEMBER\",\"amount_cents\":2500,\"period\":\"2026-09\",\"currency\":\"EUR\"}"
call() { curl -s -o "$WORK/out" -w '%{http_code}' -X POST "$FN" -H 'Content-Type: application/json' "$@" -d "$BODY"; }

# 1. The service role alone cannot open an intent: the guard needs a caller.
svc=$(curl -s -X POST "$API_URL/rest/v1/rpc/open_payment_intent" \
  -H "apikey: $SERVICE_KEY" -H "Authorization: Bearer $SERVICE_KEY" -H 'Content-Type: application/json' \
  -d "{\"p_workspace_id\":\"$WS\",\"p_member_id\":\"$MEMBER\",\"p_provider\":\"stripe\",\"p_period\":\"2026-09\",\"p_amount_cents\":2500,\"p_currency\":\"EUR\"}")
case "$svc" in *reference*) fail "a service-role call opened an intent with no caller: $svc";; esac
echo "service role without a caller: refused"

# 2. No token.
code=$(call)
[ "$code" = "401" ] || fail "no token answered $code: $(cat "$WORK/out")"

# 3. Somebody else paying the payer's bill.
code=$(call -H "Authorization: Bearer $STRANGER_JWT")
[ "$code" = "403" ] || fail "a stranger answered $code: $(cat "$WORK/out")"
[ "$(intents)" = "0" ] || fail "a refused call left an intent"
[ ! -s "$WORK/hits" ] || fail "a refused call reached the provider"
echo "no token: 401; someone else's bill: 403; no intent, no provider call"

# 4. The member paying their own bill.
code=$(call -H "Authorization: Bearer $PAYER_JWT")
out="$(cat "$WORK/out")"
[ "$code" = "200" ] || { cat "$WORK/fn.log"; fail "the payer answered $code: $out"; }
case "$out" in *'"status":"created"'*"cs_test_${RUN}_1"*) ;; *) fail "unexpected answer: $out";; esac
[ "$(intents)" = "1" ] || fail "expected one intent, found $(intents)"
[ "$(sql "select order_id from public.payment_intents where workspace_id = '$WS'")" = "cs_test_${RUN}_1" ] \
  || fail "the intent does not carry the provider's order id"
[ "$(wc -l < "$WORK/hits" | tr -d ' ')" = "1" ] || fail "expected exactly one provider request"
echo "the payer's own bill: created, one intent (cs_test_${RUN}_1), one provider request"

[ -n "$SETTLE" ] || exit 0
# shellcheck source=scripts/payment_scenarios/stripe.sh
. "scripts/payment_scenarios/$SETTLE.sh"
