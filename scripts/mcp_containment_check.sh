#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #1613/#1614 — the delegated-token boundary through the REAL PostgREST of
# the local stack, with signed tokens: a native session keeps its access;
# the same session's claims plus `client_id`, signed with the stack's JWT
# secret, reach `POST /rpc/mcp_execute_v1` and nothing else — no raw table,
# no business RPC, no OpenAPI root, no GraphQL.
set -uo pipefail
fail() { echo "::error::mcp containment: $*"; exit 1; }
env_of() { supabase status -o env | sed -n "s/^$1=\"\(.*\)\"$/\1/p"; }
API_URL="$(env_of API_URL)"; ANON_KEY="$(env_of ANON_KEY)"; SERVICE_KEY="$(env_of SERVICE_ROLE_KEY)"
JWT_SECRET="$(env_of JWT_SECRET)"
[ -n "$API_URL" ] && [ -n "$ANON_KEY" ] && [ -n "$SERVICE_KEY" ] || fail "supabase status did not report the local stack"
[ -n "$JWT_SECRET" ] || fail "supabase status reports no JWT_SECRET: a delegated token cannot be minted here"
json() { python3 -c "import json,sys; print(json.load(sys.stdin)$1)"; }
RUN="$$"
EMAIL="contain-$RUN@deskilo.test"
curl -s -X POST "$API_URL/auth/v1/admin/users" -H "apikey: $SERVICE_KEY" -H "Authorization: Bearer $SERVICE_KEY" \
  -H 'Content-Type: application/json' -d "{\"email\":\"$EMAIL\",\"password\":\"Contain-2026!\",\"email_confirm\":true}" >/dev/null
NATIVE=$(curl -s -X POST "$API_URL/auth/v1/token?grant_type=password" -H "apikey: $ANON_KEY" -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"Contain-2026!\"}" | json "['access_token']") || fail "the native sign-in failed"

# The same claims, plus the OAuth client, re-signed HS256 with the stack's secret.
DELEGATED=$(NATIVE="$NATIVE" SECRET="$JWT_SECRET" python3 -c '
import base64, hashlib, hmac, json, os
def b64(b): return base64.urlsafe_b64encode(b).rstrip(b"=").decode()
def unb64(s): return base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))
claims = json.loads(unb64(os.environ["NATIVE"].split(".")[1]))
claims["client_id"] = "claude-test"
head = b64(json.dumps({"alg": "HS256", "typ": "JWT"}).encode())
body = b64(json.dumps(claims).encode())
sig = b64(hmac.new(os.environ["SECRET"].encode(), f"{head}.{body}".encode(), hashlib.sha256).digest())
print(f"{head}.{body}.{sig}")')

code() {  # code <token> <method> <path> [body]
  curl -s -o /tmp/mcp-out -w '%{http_code}' -X "$2" "$API_URL$3" -H "apikey: $ANON_KEY" \
    -H "Authorization: Bearer $1" -H 'Content-Type: application/json' ${4:+-d "$4"}
}
expect() {  # expect <label> <want> <token> <method> <path> [body]
  local label="$1" want="$2"; shift 2
  local got; got=$(code "$@")
  [ "$got" = "$want" ] || fail "$label: expected $want, got $got: $(head -c 300 /tmp/mcp-out)"
  echo "$label: $got"
}
expect "native reads a table" 200 "$NATIVE" GET "/rest/v1/workspaces?select=id"
expect "delegated reads a table" 403 "$DELEGATED" GET "/rest/v1/workspaces?select=id"
expect "delegated calls a business RPC" 403 "$DELEGATED" POST "/rest/v1/rpc/request_refund" '{"p_invoice_id":"00000000-0000-4000-8000-000000000001"}'
expect "delegated reads the OpenAPI root" 403 "$DELEGATED" GET "/rest/v1/"
# GraphQL: refused by the guard (403), or not served at all where the
# stack does not expose the graphql schema (406, PGRST106). Anything that
# answers data is a breach.
got=$(code "$DELEGATED" POST "/graphql/v1" '{"query":"{ __typename }"}')
case "$got" in
  403) ;;
  406) grep -q PGRST106 /tmp/mcp-out || fail "delegated uses GraphQL: 406 without PGRST106: $(head -c 300 /tmp/mcp-out)" ;;
  *) fail "delegated uses GraphQL: expected 403 or an unexposed schema, got $got: $(head -c 300 /tmp/mcp-out)" ;;
esac
echo "delegated uses GraphQL: $got"
expect "delegated GETs the facade" 403 "$DELEGATED" GET "/rest/v1/rpc/mcp_execute_v1"
expect "delegated POSTs the facade" 200 "$DELEGATED" POST "/rest/v1/rpc/mcp_execute_v1" \
  '{"p_installation_id":"00000000-0000-4000-8000-000000000001","p_workspace_id":"00000000-0000-4000-8000-000000000002","p_operation":"get_capabilities","p_arguments":{},"p_request_id":null}'
grep -q '"status"' /tmp/mcp-out || fail "the facade did not answer an envelope: $(head -c 300 /tmp/mcp-out)"
echo "the facade answered: $(head -c 200 /tmp/mcp-out)"
echo "containment: a delegated token reaches the facade and nothing else"
