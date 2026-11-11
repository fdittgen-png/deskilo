#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Verify the immutable upstream archive before extracting or running it.
set -euo pipefail

dest=${1:?destination directory required}
version=1.32.0
case "$(uname -s)/$(uname -m)" in
  Linux/x86_64)
    platform=x86_64-unknown-linux-gnu
    expected=bb110cc765eca9cd7efb2e284a956be5974c60027b0970f16397d86208a9957b ;;
  Darwin/arm64)
    platform=aarch64-apple-darwin
    expected=6efed18c4539a663fd3c851a2be9533fd8456c4e646d9416206da059154a0d3c ;;
  *) echo "Unsupported workflow-scanner platform" >&2; exit 2 ;;
esac
zizmor_tmp=$(mktemp -d)
trap 'rm -rf "$zizmor_tmp"' EXIT
archive="$zizmor_tmp/zizmor.tar.gz"
curl -fsSL --retry 3 --connect-timeout 15 --max-time 90 \
  "https://github.com/zizmorcore/zizmor/releases/download/v$version/zizmor-$platform.tar.gz" \
  -o "$archive"
if command -v sha256sum >/dev/null; then
  actual=$(sha256sum "$archive")
else
  actual=$(shasum -a 256 "$archive")
fi
[[ "${actual%% *}" == "$expected" ]] || { echo "Workflow-scanner checksum mismatch" >&2; exit 1; }
mkdir -p "$dest"
tar -xzf "$archive" -C "$dest" zizmor
"$dest/zizmor" --version
