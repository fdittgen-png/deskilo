#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# ADR 0003 guard: no Google Play Services, no Firebase, no GMS-dependent
# plugins anywhere in the dependency graph or the Android build.
# Runs in CI; exits non-zero on any hit.
set -euo pipefail
cd "$(dirname "$0")/.."

PATTERN='firebase|google_mobile_ads|google_sign_in|com\.google\.gms|com\.google\.firebase|google_mlkit|play_core|in_app_review|com\.google\.android\.play'

fail=0
for file in pubspec.yaml pubspec.lock \
            android/app/build.gradle.kts android/build.gradle.kts \
            android/settings.gradle.kts; do
  if grep -Eiq "$PATTERN" "$file"; then
    echo "GMS/Firebase reference found in $file:" >&2
    grep -Ein "$PATTERN" "$file" >&2
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "audit_no_gms: FAILED — ADR 0003 forbids Google services in any flavor." >&2
  exit 1
fi
echo "audit_no_gms: clean"
