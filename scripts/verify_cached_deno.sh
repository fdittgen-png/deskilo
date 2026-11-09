#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# #3473 -- the pinned Deno binary against its SHA-256.
#
#   verify_cached_deno.sh clear <tool-cache dir>   before setup-deno: a cached
#       Deno that fails its digest is deleted, so setup-deno downloads a fresh
#       one instead of the job failing on a cache that can never heal (a cache
#       key is immutable)
#   verify_cached_deno.sh check <path to deno>     after setup-deno: the binary
#       about to run must be the pinned one; a mismatch fails the job
#
# The version and the digest are bumped here, with the composite action's
# cache key and `deno-version`.
set -euo pipefail
mode=${1:?clear or check}
target=${2:?directory or binary required}
expected=368bca08999e02c6911b8f248167b582276b1f547db5712b6e736d7eda1dbda7

digest() {
  if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi
}

case "$mode" in
  clear)
    bin=$(find "$target" -type f -name deno 2>/dev/null | head -1 || true)
    [[ -n "$bin" ]] || exit 0
    actual=$(digest "$bin")
    if [[ "${actual%% *}" != "$expected" ]]; then
      echo "The cached Deno failed its checksum; clearing it so a fresh one is downloaded" >&2
      rm -rf "$target"
    fi ;;
  check)
    actual=$(digest "$target")
    [[ "${actual%% *}" == "$expected" ]] || { echo "Deno checksum mismatch" >&2; exit 1; }
    "$target" --version ;;
  *) echo "usage: $0 clear|check ..." >&2; exit 2 ;;
esac
