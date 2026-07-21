// SPDX-License-Identifier: 0BSD
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/locale/locale_controller.dart';
import 'package:deskilo/core/theme/theme_controller.dart';
import 'package:deskilo/core/trace/dev_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

/// In-memory [ThemeStore] so widget tests never touch SharedPreferences.
class InMemoryThemeStore implements ThemeStore {
  InMemoryThemeStore({this.mode});

  String? mode;

  @override
  Future<String?> read() async => mode;

  @override
  Future<void> write(String? mode) async => this.mode = mode;
}

/// In-memory [LocaleStore]; the app watches it, keep it off the channels.
class _InMemoryLocaleStore implements LocaleStore {
  String? code;

  @override
  Future<String?> read() async => code;

  @override
  Future<void> write(String? languageCode) async => code = languageCode;
}

/// In-memory [DevModeStore]; settings watches it, keep it off the channels.
class _InMemoryDevModeStore implements DevModeStore {
  bool enabled = false;

  @override
  Future<bool> read() async => enabled;

  @override
  Future<void> write(bool enabled) async => this.enabled = enabled;
}

Future<void> pumpSettings(
  WidgetTester tester, {
  required InMemoryThemeStore store,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(),
        themeStoreProvider.overrideWithValue(store),
        localeStoreProvider.overrideWithValue(_InMemoryLocaleStore()),
        devModeStoreProvider.overrideWithValue(_InMemoryDevModeStore()),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
}

/// The settings list builds lazily; the Theme tile sits below the fold of
/// the test viewport and does not exist until scrolled into view.
Future<void> revealThemeTile(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Theme'),
    80,
    scrollable: find.byType(Scrollable).first,
  );
  // scrollUntilVisible stops once the tile is BUILT (cache extent), which
  // can leave it a few px off-screen — ensureVisible finishes the job
  // (the #188 section headers push the tile further down).
  await tester.ensureVisible(find.text('Theme'));
  await tester.pumpAndSettle();
}

Finder themeTile() =>
    find.ancestor(of: find.text('Theme'), matching: find.byType(ListTile));

ThemeMode? appThemeMode(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode;

void main() {
  testWidgets(
      'settings shows the Theme tile with the current selection — '
      'system default when no override is stored', (tester) async {
    await pumpSettings(tester, store: InMemoryThemeStore());
    await revealThemeTile(tester);

    expect(find.byIcon(Icons.brightness_6_outlined), findsOneWidget);
    expect(
      find.descendant(of: themeTile(), matching: find.text('System default')),
      findsOneWidget,
    );
    expect(appThemeMode(tester), ThemeMode.system);
  });

  testWidgets('a stored override is shown and applied on start',
      (tester) async {
    await pumpSettings(tester, store: InMemoryThemeStore(mode: 'light'));

    expect(appThemeMode(tester), ThemeMode.light);
    await revealThemeTile(tester);
    expect(
      find.descendant(of: themeTile(), matching: find.text('Light')),
      findsOneWidget,
    );
  });

  testWidgets(
      'picking Dark flips the MaterialApp themeMode immediately and '
      'persists to the store', (tester) async {
    final store = InMemoryThemeStore();
    await pumpSettings(tester, store: store);
    expect(appThemeMode(tester), ThemeMode.system);

    await revealThemeTile(tester);
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();

    // The dialog offers system default plus the two explicit modes; scope
    // to the radios so tile subtitles behind the dialog never miscount.
    for (final label in ['System default', 'Light', 'Dark']) {
      expect(
        find.widgetWithText(RadioListTile<ThemeMode>, label),
        findsOneWidget,
      );
    }

    await tester.tap(find.widgetWithText(RadioListTile<ThemeMode>, 'Dark'));
    await tester.pumpAndSettle();

    // No restart: the dialog closed and the override is live + persisted.
    expect(appThemeMode(tester), ThemeMode.dark);
    expect(
      find.descendant(of: themeTile(), matching: find.text('Dark')),
      findsOneWidget, // now the tile subtitle
    );
    expect(store.mode, 'dark');
  });

  testWidgets(
      'System default returns to the platform brightness and clears '
      'the store', (tester) async {
    final store = InMemoryThemeStore(mode: 'dark');
    await pumpSettings(tester, store: store);
    expect(appThemeMode(tester), ThemeMode.dark);

    await revealThemeTile(tester);
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(RadioListTile<ThemeMode>, 'System default'),
    );
    await tester.pumpAndSettle();

    expect(appThemeMode(tester), ThemeMode.system);
    expect(store.mode, isNull);
  });
}
