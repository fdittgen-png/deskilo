// SPDX-License-Identifier: 0BSD
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

/// The settings list outgrew the 800×600 test viewport; the Language tile
/// can sit below the fold (lazy list) or be only partially on-screen.
Future<void> revealTile(WidgetTester tester, String title) async {
  await tester.scrollUntilVisible(
    find.text(title),
    80,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.text(title));
  await tester.pumpAndSettle();
}

Finder languageTile(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(ListTile));

void main() {
  testWidgets(
      'settings shows the Language tile with the current selection — '
      'system default when no override is stored', (tester) async {
    await pumpSettings(tester, store: InMemoryLocaleStore());
    await revealTile(tester, 'Language');

    expect(find.byIcon(Icons.language), findsOneWidget);
    // Scoped: the Theme tile's subtitle also reads "System default".
    expect(
      find.descendant(
        of: languageTile('Language'),
        matching: find.text('System default'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a stored override is shown as its endonym', (tester) async {
    await pumpSettings(tester, store: InMemoryLocaleStore(code: 'fr'));
    await revealTile(tester, 'Langue');

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

    await revealTile(tester, 'Language');
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();

    // The dialog offers system default plus all five endonyms (scoped to
    // the radio — tile subtitles behind the dialog also carry the text).
    expect(
      find.widgetWithText(RadioListTile<String>, 'System default'),
      findsOneWidget,
    );
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

    await revealTile(tester, 'Sprache');
    await tester.tap(find.text('Sprache'));
    await tester.pumpAndSettle();
    // Scoped: the Theme tile's subtitle also reads "Systemstandard".
    await tester.tap(
      find.widgetWithText(RadioListTile<String>, 'Systemstandard'),
    );
    await tester.pumpAndSettle();

    // The test platform locale is en_US, so English is back.
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Einstellungen'), findsNothing);
    expect(store.code, isNull);
  });
}
