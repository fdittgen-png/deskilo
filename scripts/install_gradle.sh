#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# The Gradle distribution the Android wrapper asks for, from a cache first and
# checked against the digest the repository pins (#3473).
#
# The wrapper checks `distributionSha256Sum` only when IT downloads the
# archive; a restored cache is never checked by it. So this script owns the
# check: the pinned archive is kept in a directory the workflow caches, its
# SHA-256 is compared with the one in gradle-wrapper.properties on EVERY run,
# and the wrapper's own directory for that distribution is rebuilt from the
# verified archive (an extracted tree restored from anywhere is discarded, so
# a mutated one never runs). A cached archive that fails its digest is deleted
# and downloaded again; a fresh download that fails it is refused.
#
# usage: install_gradle.sh <gradle-wrapper.properties> <GRADLE_USER_HOME> [cache dir]
set -euo pipefail

digest_of() {
  if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi
}

# property <name> <file>: the value, with the properties escape `\:` undone
property() {
  sed -n "s/^$1=//p" "$2" | tail -n 1 | sed 's/\\:/:/g' | tr -d '\r'
}

# wrapper_hash <url>: the directory name the wrapper derives from the URL
# (base 36 of the MD5 of the URL's bytes, as Gradle's PathAssembler does)
wrapper_hash() {
  python3 -c '
import hashlib, sys
n = int.from_bytes(hashlib.md5(sys.argv[1].encode()).digest(), "big")
a = "0123456789abcdefghijklmnopqrstuvwxyz"
s = ""
while n:
    n, r = divmod(n, 36)
    s = a[r] + s
print(s or "0")' "$1"
}

# obtain_archive <url> <cached file or ''> <expected sha256> <out file>
obtain_archive() {
  local url=$1 cached=$2 expected=$3 out=$4 actual
  if [[ -n "$cached" && -f "$cached" ]]; then
    cp "$cached" "$out"
    actual=$(digest_of "$out")
    [[ "${actual%% *}" == "$expected" ]] && return 0
    echo "The cached Gradle distribution failed its checksum; downloading it again" >&2
    rm -f "$cached"
  fi
  curl -fsSL --retry 5 --retry-delay 5 --retry-all-errors "$url" -o "$out"
  actual=$(digest_of "$out")
  [[ "${actual%% *}" == "$expected" ]] || { echo "Gradle distribution checksum mismatch" >&2; return 1; }
  # only a verified archive is ever kept for the next run
  if [[ -n "$cached" ]]; then
    mkdir -p "$(dirname "$cached")"
    cp "$out" "$cached"
  fi
}

main() {
  local props=${1:?gradle-wrapper.properties required}
  local home=${2:?GRADLE_USER_HOME required}
  local cache=${3:-}
  local url sha name stem hash dist scratch
  url=$(property distributionUrl "$props")
  sha=$(property distributionSha256Sum "$props")
  [[ -n "$url" ]] || { echo "No distributionUrl in $props" >&2; exit 2; }
  if [[ ! "$sha" =~ ^[0-9a-f]{64}$ ]]; then
    echo "$props has no distributionSha256Sum (64 hex): refusing an unpinned Gradle" >&2
    exit 2
  fi
  name=${url##*/}
  stem=${name%.zip}
  hash=$(wrapper_hash "$url")
  scratch=$(mktemp -d)
  # expanded NOW: an EXIT trap runs after main returns (see install_gitleaks.sh)
  trap "rm -rf '$scratch'" EXIT
  obtain_archive "$url" "${cache:+$cache/$sha-$name}" "$sha" "$scratch/$name"
  dist="$home/wrapper/dists/$stem/$hash"
  rm -rf "$dist"
  mkdir -p "$dist"
  cp "$scratch/$name" "$dist/$name"
  echo "Gradle distribution $name verified ($sha) in $dist"
}

# sourced by the test of the cache behaviour; executed by the workflow
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
