# ADR 0012 — F-Droid via an interchangeable push package

**Status:** accepted · **Date:** 2026-08-29

## Context

ADR 0011 dropped F-Droid to put notifications first: FCM became the sole
transport, and FCM's Android library pulls in Google Play Services,
which F-Droid's scanner refuses outright. The owner now wants the app on
F-Droid again — WITHOUT touching the store builds or their behaviour.

The app was already structured for an unconfigured Firebase: the
connector answers "unavailable" and everything falls back to local
notifications and the in-app inbox. What blocked F-Droid was not
behaviour but the mere presence of the library in the dependency graph.

## Decision

Push becomes a local package with one door and two keys:

- `packages/deskilo_push` — Firebase Cloud Messaging. The root
  `pubspec.yaml` points here; the store builds are unchanged.
- `packages/deskilo_push_foss` — the SAME package name and API, no
  transport. `initialize` answers false, exactly as an unconfigured
  Firebase does.

F-Droid's recipe (`fdroid/de.deskilo.app.yml`) rewrites one pubspec line
to pick the second. The app itself never imports Firebase; lint tests
pin that, pin the two APIs byte-for-byte on the interface, and pin the
FOSS package free of anything Google. A CI job builds the FOSS APK and
asserts no `com/google/android/gms` or `firebase` class reaches the dex.

## Consequences

- Store builds: identical dependency set (Firebase merely moved into a
  path package), identical behaviour. No regression surface.
- F-Droid build: local notifications and the inbox; the Settings push
  row says the build has no push transport rather than "not configured".
- Versioning: F-Droid follows `v<version>-fdroid.<n>` tags with its own
  versionCode series, independent of the store trains' wall-clock
  numbers.
- Submission to fdroiddata is an outward-facing act and stays the
  owner's: the recipe is ready, the first tag is not cut here.
