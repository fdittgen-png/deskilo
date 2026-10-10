#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Rebuilds the screenshots of the welcome page (web/welcome/img) from the
# user and setup guide pipeline's demo captures
# (docs/wiki/images/<shot>.<lang>.<stamp>.jpg).
# The demo workspace "Atelier du Marché" holds invented people and figures
# only, so every capture here is safe to publish. Run it after the guide
# screenshots are regenerated:  tool/welcome_media.sh
set -euo pipefail
cd "$(dirname "$0")/.."

command -v cwebp >/dev/null || { echo "cwebp is required (brew install webp)" >&2; exit 1; }

src=docs/wiki/images
out=web/welcome/img
mkdir -p "$out"

# Keep this list in step with the data-shot attributes in web/welcome/index.html.
# A user-guide shot drops its "user-" prefix on the page; a setup-guide shot
# keeps its "setup-" prefix.
shots=(
  user-reserve-hub
  user-reserve-day-view
  user-reservations-booking-sheet
  user-workspace-code
  user-money-statement--top
  user-money-invoices-detail
  user-collaborate-accept
  user-collaborate-contact
  user-me-home
  user-space-editor-seat
  user-features-switches
  setup-before-template
  user-money-reports-editor
  user-advanced-record
  user-advanced-wizard
)

for shot in "${shots[@]}"; do
  for lang in en fr de es it; do
    # The newest stamp wins when several captures of one shot coexist.
    file=$(ls -t "$src/$shot.$lang."*.jpg 2>/dev/null | head -n 1 || true)
    [ -n "$file" ] || { echo "missing: $shot ($lang)" >&2; exit 1; }
    cwebp -quiet -q 82 -m 6 "$file" -o "$out/${shot#user-}.$lang.webp"
  done
done
echo "welcome media: ${#shots[@]} shots x 5 languages -> $out"
