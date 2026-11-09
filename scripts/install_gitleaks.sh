#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Only a versioned, checksum-verified upstream archive may run in CI.
#
# #3473 -- an optional second argument is a directory the workflow caches: the
# VERIFIED archive is kept there, so a warm cache needs no download. A cached
# archive that fails its checksum is deleted and downloaded again (a cache key
# is immutable, so a corrupt entry must heal, never fail the job for good); a
# fresh download that fails it is refused.
set -euo pipefail

digest_of() {
  if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi
}

# obtain_archive <url> <cached file or ''> <expected sha256> <out file>
obtain_archive() {
  local url=$1 cached=$2 expected=$3 out=$4 actual
  if [[ -n "$cached" && -f "$cached" ]]; then
    cp "$cached" "$out"
    actual=$(digest_of "$out")
    [[ "${actual%% *}" == "$expected" ]] && return 0
    echo "The cached secret-scanner archive failed its checksum; downloading it again" >&2
    rm -f "$cached"
  fi
  curl -fsSL --retry 5 --retry-delay 5 --retry-all-errors "$url" -o "$out"
  actual=$(digest_of "$out")
  [[ "${actual%% *}" == "$expected" ]] || { echo "Secret-scanner checksum mismatch" >&2; return 1; }
  # only a verified archive is ever kept for the next run
  if [[ -n "$cached" ]]; then
    mkdir -p "$(dirname "$cached")"
    cp "$out" "$cached"
  fi
}

main() {
  local dest=${1:?destination directory required}
  local cache=${2:-}
  local version=8.30.1 platform expected
  case "$(uname -s)/$(uname -m)" in
    Linux/x86_64)
      platform=linux_x64
      expected=551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb ;;
    Darwin/arm64)
      platform=darwin_arm64
      expected=b40ab0ae55c505963e365f271a8d3846efbc170aa17f2607f13df610a9aeb6a5 ;;
    *) echo "Unsupported secret-scanner platform" >&2; exit 2 ;;
  esac
  local scratch
  scratch=$(mktemp -d)
  trap 'rm -rf "$scratch"' EXIT
  local archive="$scratch/gitleaks.tar.gz"
  local cached="${cache:+$cache/gitleaks_${version}_${platform}.tar.gz}"
  obtain_archive "https://github.com/gitleaks/gitleaks/releases/download/v$version/gitleaks_${version}_${platform}.tar.gz" "$cached" "$expected" "$archive"
  mkdir -p "$dest"
  tar -xzf "$archive" -C "$dest" gitleaks
  "$dest/gitleaks" version
}

# sourced by the test of the cache behaviour; executed by the workflow
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
