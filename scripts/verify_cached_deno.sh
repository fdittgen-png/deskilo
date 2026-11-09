#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# #3473 -- the pinned Deno binary against its SHA-256, at the one path
# `denoland/setup-deno` installs it: <tool cache>/deno/<version>/<arch>/deno.
#
#   verify_cached_deno.sh clear <tool-cache dir>/deno <runner arch>
#       before setup-deno: the cache is kept ONLY if it holds the pinned binary
#       for THIS arch -- present, executable, with the pinned digest. Anything
#       else (a corrupted binary, no binary, a `.complete` marker without one,
#       another arch's directory only, a binary without its exec bit) clears the
#       whole directory, so setup-deno downloads a fresh Deno instead of
#       treating the marker as a hit and the job staying red on a cache that
#       can never heal (a cache key is immutable)
#   verify_cached_deno.sh check <tool-cache dir>/deno <runner arch>
#       after setup-deno: that binary must be the pinned one; a mismatch fails
#
# <runner arch> is `${{ runner.arch }}` (X64, ARM64): the tool cache names the
# directory x64 / arm64. The version and the digest are bumped here, with the
# composite action's cache key and `deno-version`.
set -euo pipefail
version=2.9.8
expected=368bca08999e02c6911b8f248167b582276b1f547db5712b6e736d7eda1dbda7

digest() {
  if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi
}

# pinned_binary <dir> <arch>: the path of this arch's binary, or failure
pinned_binary() {
  local arch
  arch=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')
  local bin="$1/$version/$arch/deno"
  [[ -f "$bin" && -x "$bin" ]] || return 1
  printf '%s' "$bin"
}

# is_pinned <dir> <arch>: present, executable, with the pinned digest
is_pinned() {
  local bin actual
  bin=$(pinned_binary "$1" "$2") || return 1
  actual=$(digest "$bin")
  [[ "${actual%% *}" == "$expected" ]]
}

main() {
  local mode=${1:?clear or check}
  local dir=${2:?the tool cache deno directory is required}
  local arch=${3:?the runner arch is required}
  case "$mode" in
    clear)
      [[ -e "$dir" ]] || return 0
      is_pinned "$dir" "$arch" && return 0
      echo "The cached Deno is not exactly the pinned $version binary for $arch; clearing it so a fresh one is downloaded" >&2
      rm -rf "$dir" ;;
    check)
      is_pinned "$dir" "$arch" || { echo "Deno checksum mismatch (or $version is not installed for $arch at $dir)" >&2; return 1; }
      "$(pinned_binary "$dir" "$arch")" --version ;;
    *) echo "usage: $0 clear|check <tool cache deno dir> <runner arch>" >&2; return 2 ;;
  esac
}

# sourced by the test (which swaps `expected` for a fixture's digest);
# executed by the workflow
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
