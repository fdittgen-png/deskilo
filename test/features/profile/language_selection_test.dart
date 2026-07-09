// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/locale/locale_controller.dart';
import 'package:deskilo/core/trace/dev_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

/// In-memory [LocaleStore] so widget tests never touch SharedPreferences.
class InMemoryLocaleStore implements LocaleStore {
  InMemoryLocaleStore({this.code});

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
  required InMemoryLocaleStore store,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(),
        localeStoreProvider.overrideWithValue(store),
        devModeStoreProvider.overrideWithValue(_InMemoryDevModeStore()),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'settings shows the Language tile with the current selection — '
      'system default when no override is stored', (tester) async {
    await pumpSettings(tester, store: InMemoryLocaleStore());

    expect(find.byIcon(Icons.language), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('System default'), findsOneWidget);
  });

  testWidgets('a stored override is shown as its endonym', (tester) async {
    await pumpSettings(tester, store: InMemoryLocaleStore(code: 'fr'));

    // The whole app already runs in French, tile included.
    expect(find.text('Langue'), findsOneWidget);
    expect(find.text('Français'), findsOneWidget);
  });

  testWidgets(
      'picking Deutsch flips the MaterialApp locale immediately and '
      'persists to the store', (tester) async {
    final store = InMemoryLocaleStore();
    await pumpSettings(tester, store: store);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();

    // The dialog offers system default plus all five endonyms.
    expect(find.text('System default'), findsNWidgets(2));
    for (final endonym in [
      'Deutsch',
      'English',
      'Français',
      'Español',
      'Italiano',
    ]) {
      expect(find.text(endonym), findsOneWidget);
    }

    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();

    // No restart: the settings screen now renders in German.
    expect(find.text('Einstellungen'), findsOneWidget);
    expect(find.text('Sprache'), findsOneWidget);
    expect(find.text('Deutsch'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
    expect(store.code, 'de');
  });

  testWidgets(
      'System default returns to the platform locale and clears the store',
      (tester) async {
    final store = InMemoryLocaleStore(code: 'de');
    await pumpSettings(tester, store: store);
    expect(find.text('Einstellungen'), findsOneWidget);

    await tester.tap(find.text('Sprache'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Systemstandard'));
    await tester.pumpAndSettle();

    // The test platform locale is en_US, so English is back.
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Einstellungen'), findsNothing);
    expect(store.code, isNull);
  });
}
