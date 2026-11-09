#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# #3473 -- the Supabase CLI for the database job, from a cache first and a
# checksum-verified release archive only on a miss. A release-CDN 504 can no
# longer red a required check once the cache is warm, and a corrupted cache is
# refused by the binary's own digest.
#
# usage: install_supabase_cli.sh <dest dir>
set -euo pipefail
version=2.118.0

# pin_for_platform: sets `asset`, `archive_sha` and `binary_sha`; a test of the
# whole flow replaces it with a fixture.
pin_for_platform() {
  case "$(uname -s)/$(uname -m)" in
    Linux/x86_64)
      asset="supabase_${version}_linux_amd64.tar.gz"
      archive_sha=f6089a86fb9d9221c958193a277338daddd6822f706929943812fa32e106c86d
      binary_sha=563ad5e20fdaa2e26235667d0de93c5d6e4eb31d58fa4a75b37eb20d06af54fa ;;
    *) echo "Unsupported Supabase CLI platform" >&2; exit 2 ;;
  esac
}
sha256_of() {
  if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi
}
verify() { # file expected-digest label
  local actual
  actual=$(sha256_of "$1")
  [[ "${actual%% *}" == "$2" ]] || { echo "$3 checksum mismatch" >&2; return 1; }
}

main() {
  local dest=${1:?destination directory required}
  pin_for_platform
  if [[ -x "$dest/supabase" ]] && verify "$dest/supabase" "$binary_sha" "Cached Supabase CLI" 2>/dev/null; then
    echo "Using the cached Supabase CLI $version"
  else
    rm -rf "$dest"
    local scratch
    scratch=$(mktemp -d)
    # expanded now: see install_gitleaks.sh (an EXIT trap outlives a local)
    trap "rm -rf '$scratch'" EXIT
    curl -fsSL --retry 5 --retry-delay 5 --retry-all-errors \
      "https://github.com/supabase/cli/releases/download/v$version/$asset" \
      -o "$scratch/$asset"
    verify "$scratch/$asset" "$archive_sha" "Supabase CLI archive"
    mkdir -p "$dest"
    tar -xzf "$scratch/$asset" -C "$dest"
    verify "$dest/supabase" "$binary_sha" "Supabase CLI binary"
  fi
  "$dest/supabase" --version
}

# sourced by the test of the whole flow; executed by the workflow
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
