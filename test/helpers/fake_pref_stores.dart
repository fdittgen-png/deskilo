// SPDX-License-Identifier: 0BSD
//
// In-memory stores for the per-device preferences (#969, #970, #1173),
// so no widget test touches SharedPreferences and every provider that
// watches them resolves at once.
//
// #1564 moved the classes themselves into `lib/core/demo/data/`, beside
// the other in-memory stores, because the Demo environment has to mount
// them in production code: a preference written from inside a
// demonstration was reaching the real app. The suite reaches them
// through this import exactly as before.
export 'package:deskilo/core/demo/data/device_prefs.dart'
    show InMemoryNavigationStyleStore, InMemoryShellFlagStore;
