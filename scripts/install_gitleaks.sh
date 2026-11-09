#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Only a versioned, checksum-verified upstream archive may run in CI.
set -euo pipefail
dest=${1:?destination directory required}
# #3473 -- an optional directory the workflow caches: the verified archive is
# kept there, so a warm cache needs no download (and the checksum below is
# checked on the cached copy as well).
cache=${2:-}
version=8.30.1
case "$(uname -s)/$(uname -m)" in
  Linux/x86_64)
    platform=linux_x64
    expected=551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb ;;
  Darwin/arm64)
    platform=darwin_arm64
    expected=b40ab0ae55c505963e365f271a8d3846efbc170aa17f2607f13df610a9aeb6a5 ;;
  *) echo "Unsupported secret-scanner platform" >&2; exit 2 ;;
esac
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
archive="$scratch/gitleaks.tar.gz"
cached="${cache:+$cache/gitleaks_${version}_${platform}.tar.gz}"
if [[ -n "$cached" && -f "$cached" ]]; then
  cp "$cached" "$archive"
else
  curl -fsSL --retry 5 --retry-delay 5 --retry-all-errors "https://github.com/gitleaks/gitleaks/releases/download/v$version/gitleaks_${version}_${platform}.tar.gz" -o "$archive"
fi
if command -v sha256sum >/dev/null; then
  actual=$(sha256sum "$archive")
else
  actual=$(shasum -a 256 "$archive")
fi
[[ "${actual%% *}" == "$expected" ]] || { echo "Secret-scanner checksum mismatch" >&2; exit 1; }
# only a verified archive is ever kept for the next run
if [[ -n "$cached" && ! -f "$cached" ]]; then
  mkdir -p "$cache"
  cp "$archive" "$cached"
fi
mkdir -p "$dest"
tar -xzf "$archive" -C "$dest" gitleaks
"$dest/gitleaks" version
