// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1564 — the device preferences a Demo session owns.
//
// ADR 0028 put Demo at the repository seam, and the repositories were
// the only thing it overrode. A preference is not a repository, so every
// per-device store kept resolving to its `SharedPreferences` impl inside
// the Demo scope — and the demonstration was writing to the real app's
// memory.
//
// It was worse than sharing. `DefaultWorkspaceId.build` reads the
// signed-in state from the OVERRIDDEN auth repository, so in Demo it
// answers "signed in", asks the fixture for the server default, gets
// null, and writes that null through `DefaultWorkspaceStore` — where a
// null write is `prefs.remove`. Merely tapping "Explore the demo
// workspace" deleted the member's real default profile. Editing Settings
// → Server inside Demo repointed the real app at the next start.
//
// So a session owns a copy of each store. It is a COPY rather than a
// reader of the device's values on purpose: a demonstration starts from
// the canonical dataset, not from whatever this phone happens to
// remember, and nothing it changes may travel the other way. The stores
// live on the fixture, which settles the lifetime for free — they
// survive a persona switch (same fixture), come back canonical on Reset
// (new fixture) and are dropped on Leave (the fixture is dropped).
import 'package:deskilo/app/shell/shell_bar_visibility.dart';
import 'package:deskilo/core/locale/locale_controller.dart';
import 'package:deskilo/core/navigation/navigation_style.dart';
import 'package:deskilo/core/storage/entry_intent_store.dart';
import 'package:deskilo/core/storage/help_hint_store.dart';
import 'package:deskilo/core/storage/note_seen_store.dart';
import 'package:deskilo/core/storage/notification_filter_store.dart';
import 'package:deskilo/core/theme/theme_controller.dart';
import 'package:deskilo/features/reservations/providers/default_period_controller.dart';

import 'default_level_store.dart';
import 'stores.dart';

/// In-memory [LocaleStore] (#147) — the language override a session
/// picks lasts as long as the session.
class InMemoryLocaleStore implements LocaleStore {
  String? languageCode;

  @override
  Future<String?> read() async => languageCode;

  @override
  Future<void> write(String? code) async => languageCode = code;
}

/// In-memory [ThemeStore] (#160).
class InMemoryThemeStore implements ThemeStore {
  String? mode;

  @override
  Future<String?> read() async => mode;

  @override
  Future<void> write(String? next) async => mode = next;
}

/// In-memory [NavigationStyleStore] (#969), so no widget test and no
/// Demo session touches SharedPreferences.
class InMemoryNavigationStyleStore implements NavigationStyleStore {
  InMemoryNavigationStyleStore({this.style});
  String? style;
  @override
  Future<String?> read() async => style;
  @override
  Future<void> write(String? style) async => this.style = style;
}

/// #1173 — one of the two shell flags (bar swiped away, swipe hint seen).
class InMemoryShellFlagStore implements ShellFlagStore {
  InMemoryShellFlagStore([this.value = false]);

  bool value;

  /// How many times the flag was written — the proof a choice persists.
  int writes = 0;

  @override
  Future<bool> read() async => value;

  @override
  Future<void> write(bool next) async {
    value = next;
    writes++;
  }
}

/// Every per-device preference one Demo session keeps to itself.
///
/// The set is not a judgement call: `demo_scope_test` reads the app's
/// own source for providers built on a `Prefs…Store` and fails until
/// each one is here and in `demoOverrides`, so a NEW preference cannot
/// quietly write to the device from inside a demonstration.
class DemoDevicePrefs {
  final InMemoryLocaleStore locale = InMemoryLocaleStore();
  final InMemoryThemeStore theme = InMemoryThemeStore();
  final InMemoryNavigationStyleStore navigationStyle =
      InMemoryNavigationStyleStore();

  /// The bar starts shown and the coach mark starts SEEN — a visitor who
  /// is being shown the product should not also be shown a gesture hint.
  final InMemoryShellFlagStore shellBarHidden = InMemoryShellFlagStore();
  final InMemoryShellFlagStore shellSwipeCoach = InMemoryShellFlagStore(true);

  final InMemoryFrontCameraStore frontCamera = InMemoryFrontCameraStore();
  final InMemoryActiveWorkspaceStore activeWorkspace =
      InMemoryActiveWorkspaceStore();
  final InMemoryDefaultWorkspaceStore defaultWorkspace =
      InMemoryDefaultWorkspaceStore();
  final InMemoryDefaultLevelStore defaultLevel = InMemoryDefaultLevelStore();
  final InMemoryDefaultPeriodStore defaultPeriod = InMemoryDefaultPeriodStore();
  final InMemoryNotificationFilterStore notificationFilters =
      InMemoryNotificationFilterStore();
  final InMemoryHelpHintStore helpHints = InMemoryHelpHintStore();
  final InMemoryNoteSeenStore noteSeen = InMemoryNoteSeenStore();

  /// #780 — which Supabase instance the device talks to. The one a
  /// visitor could change from Settings → Server, and the one the real
  /// app reads at start-up: the reason this file exists.
  final InMemoryBackendSettingsStore backend = InMemoryBackendSettingsStore();

  /// #1650 — what the person came to do. A visitor's errand inside the
  /// demonstration is the demonstration's; the live draft is neither
  /// read nor spent by entering it.
  final InMemoryEntryIntentStore entryIntent = InMemoryEntryIntentStore();

  /// The file cache is device state too — the real store writes to the
  /// device filesystem, and a demonstration's synthetic rows have no
  /// business in it.
  final InMemoryCacheStore cache = InMemoryCacheStore();
}
