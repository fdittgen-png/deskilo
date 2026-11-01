#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Only a versioned, checksum-verified upstream archive may run in CI.
set -euo pipefail
dest=${1:?destination directory required}
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
curl -fsSL "https://github.com/gitleaks/gitleaks/releases/download/v$version/gitleaks_${version}_${platform}.tar.gz" -o "$archive"
if command -v sha256sum >/dev/null; then
  actual=$(sha256sum "$archive")
else
  actual=$(shasum -a 256 "$archive")
fi
[[ "${actual%% *}" == "$expected" ]] || { echo "Secret-scanner checksum mismatch" >&2; exit 1; }
mkdir -p "$dest"
tar -xzf "$archive" -C "$dest" gitleaks
"$dest/gitleaks" version
