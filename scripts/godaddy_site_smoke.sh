#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Smoke the preserved GoDaddy server and its actual package, without touching a host.
set -euo pipefail
site=${1:?usage: godaddy_site_smoke.sh site-dir source-sha}
source_sha=${2:?usage: godaddy_site_smoke.sh site-dir source-sha}
[[ "$source_sha" =~ ^[0-9a-f]{40}$ ]] || { echo 'invalid source SHA' >&2; exit 1; }
site=$(cd "$site" && pwd)
scratch=$(mktemp -d -t deskilo-godaddy-smoke.XXXXXX)
log="$scratch/server.log"
PORT=0 node "$site/server.js" > "$log" 2>&1 &
server=$!
cleanup() {
  kill "$server" 2>/dev/null || true
  wait "$server" 2>/dev/null || true
  rm -rf "$scratch"
}
trap cleanup EXIT
port=''
for _ in {1..100}; do
  port=$(sed -n 's/^DesKilo site on \([0-9][0-9]*\).*/\1/p' "$log" | head -1)
  [ -n "$port" ] && break
  kill -0 "$server" 2>/dev/null || { cat "$log" >&2; exit 1; }
  sleep 0.1
done
[ -n "$port" ] || { echo 'server did not become ready' >&2; exit 1; }
base="http://127.0.0.1:$port"
code=$(curl -sS --max-time 5 -o /dev/null -w '%{http_code}' "$base/")
[ "$code" = 302 ] || { echo "root: expected 302, got $code" >&2; exit 1; }
if ! curl -fsS --max-time 5 -D - -o /dev/null "$base/" | tr -d '\r' | grep -qi '^Location: /welcome/#top$'; then
  echo 'root redirect does not target the welcome page' >&2
  exit 1
fi
for path in /welcome/ /guide/en.html /guide/setup-en.html /setup.html /app/ /app/main.dart.js /app/money /healthz /BUILD.txt; do
  code=$(curl -sS --max-time 5 -o /dev/null -w '%{http_code}' "$base$path")
  echo "$path -> $code"
  [ "$code" = 200 ] || { echo "$path: expected 200, got $code" >&2; exit 1; }
done
curl -fsS --max-time 5 "$base/app/" > "$scratch/index.html"
if ! grep -Fq '<base href="/app/">' "$scratch/index.html"; then
  echo 'app base href is not /app/' >&2
  exit 1
fi
curl -fsS --max-time 5 "$base/app/money" > "$scratch/deep-link.html"
cmp -s "$scratch/index.html" "$scratch/deep-link.html" || { echo 'app deep link did not return the app entry' >&2; exit 1; }
if ! curl -fsS --max-time 5 "$base/BUILD.txt" | grep -Fxq "source: fdittgen-png/deskilo@$source_sha"; then
  echo 'package source SHA does not match the requested build' >&2
  exit 1
fi
[ "$(curl -fsS --max-time 5 "$base/healthz")" = ok ]
code=$(curl -sS --max-time 5 -o /dev/null -w '%{http_code}' "$base/app/asset-that-does-not-exist.js")
[ "$code" = 404 ] || { echo "missing asset: expected 404, got $code" >&2; exit 1; }
echo "GoDaddy package smoke passed for $source_sha; host deployment not checked."
