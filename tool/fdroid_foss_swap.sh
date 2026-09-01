#!/usr/bin/env bash
# SPDX-License-Identifier: 0BSD
#
# #809 — turn the checkout into the LIBRE flavour, lockfile included.
#
# The app depends on the local package `deskilo_push`, which exists twice
# under packages/ with the same name and API: the Firebase one the stores
# ship, and a twin with no transport at all. Swapping the path in
# pubspec.yaml is the whole difference between the two builds.
#
# WHY THE LOCKFILE IS PATCHED TOO. `flutter pub get --enforce-lockfile`
# is what makes a build reproducible — it refuses to resolve anything the
# lock does not already pin. Swapping the path changes the dependency
# GRAPH, not just a path: the libre twin pulls no Firebase, so seven
# firebase_* packages and _flutterfire_internals stop being depended on
# and pub rejects the lock as unsatisfiable. Removing exactly those
# entries makes the lock describe the libre build, and every other
# version stays pinned to the byte.
#
# This script is the SINGLE definition of that swap: fdroiddata's recipe
# calls it and so does our own fdroid-foss gate, so the build we test can
# never drift from the build F-Droid makes.
#
# GNU sed (Linux). It runs on CI runners and on F-Droid's builder, never
# on a developer's mac.
set -euo pipefail

if [ ! -f pubspec.yaml ] || [ ! -f pubspec.lock ]; then
  echo "run me from the repository root" >&2
  exit 1
fi

sed -i 's|    path: packages/deskilo_push$|    path: packages/deskilo_push_foss|' pubspec.yaml
sed -i 's|path: "packages/deskilo_push"|path: "packages/deskilo_push_foss"|' pubspec.lock

# Drop the resolved entries the libre twin no longer pulls. Each is a
# two-space-indented key whose block runs until the next such key.
awk '
  /^  (firebase_[a-z_]+|_flutterfire_internals):$/ { skip = 1 }
  /^  [a-z_0-9]+:$/ && !/^  (firebase_|_flutterfire_internals)/ { skip = 0 }
  !skip
' pubspec.lock > pubspec.lock.libre
mv pubspec.lock.libre pubspec.lock

# Fail loudly rather than quietly shipping Firebase in a libre build.
if grep -q 'packages/deskilo_push"' pubspec.lock; then
  echo "lockfile still points at the Firebase package" >&2
  exit 1
fi
if grep -qE '^  (firebase_|_flutterfire_internals)' pubspec.lock; then
  echo "lockfile still pins Firebase packages" >&2
  exit 1
fi
echo "libre flavour: push transport swapped, lockfile patched"
