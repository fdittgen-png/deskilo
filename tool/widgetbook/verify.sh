#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
export BOT=true CI=true FLUTTER_SUPPRESS_ANALYTICS=true DART_SUPPRESS_ANALYTICS=true
expected_flutter="$(cat ../../.flutter-version)"
catalog_flutter="$(flutter --version --machine | python3 -c 'import json,sys; print(json.load(sys.stdin)["frameworkVersion"])')"
if [[ "$catalog_flutter" != "$expected_flutter" ]]; then
  printf 'Expected Flutter %s, found %s\n' "$expected_flutter" "$catalog_flutter" >&2
  exit 1
fi
flutter pub get --enforce-lockfile
dart analyze --fatal-infos
flutter test --no-pub test/catalog_test.dart
flutter build web --no-pub --release --no-web-resources-cdn
