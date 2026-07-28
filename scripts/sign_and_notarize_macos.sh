#!/usr/bin/env bash
# SPDX-License-Identifier: 0BSD
#
# Sign a Flutter macOS release build with Developer ID, package it as a
# DMG, notarise it and staple the ticket — the difference between a
# download that opens on a double-click and one macOS refuses outright
# ("Apple n'a pas pu confirmer que DesKilo ne contenait pas de logiciel
# malveillant"). Since macOS 15 there is no right-click → Open escape
# hatch any more, so for a downloaded app notarisation is not polish.
#
# Expects, in the environment:
#   IDENTITY   the Developer ID Application identity, already in the keychain
#   ASC_KEY    path to the App Store Connect .p8
#   ASC_KEY_ID / ASC_ISSUER_ID
#   VERSION    e.g. 0.1.0
set -euo pipefail

APP="build/macos/Build/Products/Release/DesKilo.app"
ENTITLEMENTS="macos/Runner/Release.entitlements"
OUT_DIR="build/macos/dmg"
DMG="$OUT_DIR/DesKilo-$VERSION.dmg"

[ -d "$APP" ] || { echo "::error::$APP not found — did the build run?" >&2; exit 1; }

echo "── Signing with: $IDENTITY"

# Nested code FIRST, outermost LAST: a signature covers what is inside it,
# so signing the bundle before its frameworks invalidates the bundle.
# (`--deep` would do this in one go and is deprecated precisely because it
# guesses at what deserves which entitlements.)
while IFS= read -r -d '' nested; do
  echo "   · $(basename "$nested")"
  codesign --force --timestamp --options runtime \
    --sign "$IDENTITY" "$nested"
done < <(find "$APP/Contents/Frameworks" \
              -maxdepth 1 \( -name "*.framework" -o -name "*.dylib" \) \
              -print0 2>/dev/null || true)

# Helper executables and XPC services, if any plugin ships them.
while IFS= read -r -d '' helper; do
  echo "   · $(basename "$helper")"
  codesign --force --timestamp --options runtime \
    --sign "$IDENTITY" "$helper"
done < <(find "$APP/Contents" -type d \( -name "*.xpc" -o -name "*.app" \) \
              -not -path "$APP" -print0 2>/dev/null || true)

codesign --force --timestamp --options runtime \
  --entitlements "$ENTITLEMENTS" --sign "$IDENTITY" "$APP"

# Verify before spending a notarisation round-trip on a bad signature.
codesign --verify --strict --verbose=2 "$APP"

echo "── Packaging the DMG"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
mkdir -p "$OUT_DIR"
hdiutil create -volname "DesKilo $VERSION" -srcfolder "$STAGE" \
  -ov -format UDZO "$DMG"
rm -rf "$STAGE"

# The DMG is signed too: the ticket is stapled to it, and an unsigned
# container makes Gatekeeper suspicious of contents it has already cleared.
codesign --force --timestamp --sign "$IDENTITY" "$DMG"

echo "── Notarising (Apple decides; this waits for the verdict)"
xcrun notarytool submit "$DMG" \
  --key "$ASC_KEY" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID" \
  --wait --timeout 30m

# Stapling writes the ticket INTO the DMG, so the first launch works
# offline — without it, a machine with no network sees an unnotarised app.
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

# What a user's Mac will conclude, asserted here rather than discovered
# after the download.
spctl --assess --type open --context context:primary-signature -vv "$DMG"

echo "DMG_PATH=$DMG" >> "${GITHUB_ENV:-/dev/null}"
echo "── Notarised: $DMG"
