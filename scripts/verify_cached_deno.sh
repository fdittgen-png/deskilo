#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# #3473 -- the pinned Deno binary against its SHA-256, at the one path
# `denoland/setup-deno` installs it: <tool cache>/deno/<version>/<arch>/deno.
#
#   verify_cached_deno.sh clear <tool-cache dir>/deno   before setup-deno: the
#       cache is kept ONLY if it holds exactly the pinned binary with the
#       pinned digest. Anything else -- a corrupted binary, no binary at all, a
#       `.complete` marker without one (setup-deno would take it for a hit and
#       skip the download for good) -- clears the whole directory, so setup-deno
#       downloads a fresh Deno instead of the job staying red on a cache that
#       can never heal (a cache key is immutable)
#   verify_cached_deno.sh check <tool-cache dir>/deno   after setup-deno: the
#       binary at that path must be the pinned one; a mismatch fails the job
#
# The version and the digest are bumped here, with the composite action's
# cache key and `deno-version`.
set -euo pipefail
mode=${1:?clear or check}
dir=${2:?the tool cache deno directory is required}
version=2.9.8
expected=368bca08999e02c6911b8f248167b582276b1f547db5712b6e736d7eda1dbda7

digest() {
  if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi
}

# the pinned binary: <dir>/<version>/<arch>/deno (exactly one arch directory)
pinned_binary() {
  local found=() f
  for f in "$dir/$version"/*/deno; do
    [[ -f "$f" ]] && found+=("$f")
  done
  [[ ${#found[@]} -eq 1 ]] || return 1
  printf '%s' "${found[0]}"
}

matches() {
  local actual
  actual=$(digest "$1")
  [[ "${actual%% *}" == "$expected" ]]
}

case "$mode" in
  clear)
    [[ -e "$dir" ]] || exit 0
    if bin=$(pinned_binary) && matches "$bin"; then
      exit 0
    fi
    echo "The cached Deno is not exactly the pinned $version binary; clearing it so a fresh one is downloaded" >&2
    rm -rf "$dir" ;;
  check)
    bin=$(pinned_binary) || { echo "Deno $version is not installed at $dir" >&2; exit 1; }
    matches "$bin" || { echo "Deno checksum mismatch" >&2; exit 1; }
    "$bin" --version ;;
  *) echo "usage: $0 clear|check <tool cache deno dir>" >&2; exit 2 ;;
esac
