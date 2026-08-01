#!/usr/bin/env bash
# SPDX-License-Identifier: 0BSD
# ADR 0003 guard: no Google Play Services, no Firebase, no GMS-dependent
# plugins anywhere — in the dependency graph OR in the shipped bytecode.
#
# THREE LAYERS, any of which failing fails the audit:
#
#   A  declarations + resolved graph   pubspec.yaml, pubspec.lock, gradle
#   B  bytecode definitions            classes*.dex of a built artifact
#   C  strict references               the same dex — not even a DANGLING
#                                      reference to a proprietary type
#
# Layer C is the bar the F-Droid catalog scanner actually applies: it
# reads the shipped artifact and rejects a mere reference to a
# proprietary class, defined or not. A graph audit that satisfies you
# will not satisfy their scanner — Sparkilo's submission was rejected on
# exactly the references a declaration grep cannot see. Until now this
# script stopped at layer A.
#
#   audit_no_gms.sh                  # layer A only — the fast CI gate
#   audit_no_gms.sh --artifact PATH  # layers A + B/C on an .apk or .aab
#
# Run B/C on RELEASE artifacts only: only the release-mode shrinker
# removes the Flutter embedding's own dead references to optional store
# libraries, so a debug dex can never reach zero and would cry wolf.
set -euo pipefail
cd "$(dirname "$0")/.."

# Layer A: package coordinates as they appear in pubspec/gradle files.
PATTERN='firebase|google_mobile_ads|google_sign_in|com\.google\.gms|com\.google\.firebase|google_mlkit|play_core|in_app_review|com\.google\.android\.play'

# Layers B/C: the SAME families as JVM type descriptors — note the
# SLASHES and the leading L; this is how classes are named inside a dex.
# Deliberately NOT bare 'Lcom/google/': gson and guava are free Google
# code and legitimately present.
DEX_PATTERN='Lcom/google/(android/gms|firebase|mlkit|android/play)[A-Za-z0-9/$_]*;?'

artifact=""
if [ "${1:-}" = "--artifact" ]; then
  artifact="${2:?--artifact needs a path to an .apk or .aab}"
  if [ ! -f "$artifact" ]; then
    echo "audit_no_gms: artifact not found: $artifact" >&2
    exit 1
  fi
fi

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

if [ -n "$artifact" ]; then
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  # -j flattens paths so one loop covers both layouts: an APK keeps
  # classes*.dex at the root, an AAB nests them under base/dex/. Tolerate
  # a no-match exit here — the dex_count check below turns "no dex" into
  # its own honest failure instead of unzip's cryptic one.
  unzip -o -j -q "$artifact" '*.dex' -d "$tmp" 2>/dev/null || true
  dex_count=0
  for d in "$tmp"/*.dex; do
    [ -e "$d" ] || break
    dex_count=$((dex_count + 1))
    # The dex string table stores every referenced type descriptor in
    # plain text, so a binary grep sees definitions AND references —
    # layers B and C in one pass, no dexdump dependency.
    if hits=$(grep -aoE "$DEX_PATTERN" "$d" | sort -u) && [ -n "$hits" ]; then
      echo "proprietary type references in $(basename "$d") of $artifact:" >&2
      echo "$hits" >&2
      fail=1
    else
      echo "audit_no_gms: $(basename "$d") — zero proprietary references"
    fi
  done
  if [ "$dex_count" -eq 0 ]; then
    # An artifact with no dex is not a clean artifact, it is the wrong
    # file — silence here would read as a pass.
    echo "audit_no_gms: no classes*.dex found inside $artifact" >&2
    exit 1
  fi
fi

if [ "$fail" -ne 0 ]; then
  echo "audit_no_gms: FAILED — ADR 0003 forbids Google services in any flavor." >&2
  exit 1
fi
echo "audit_no_gms: clean${artifact:+ (incl. bytecode of $artifact)}"
