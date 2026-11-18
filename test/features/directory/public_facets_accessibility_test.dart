// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Published facts remain operable with a keyboard and readable in five
// languages on a narrow screen with large text and a dark theme.
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/features/directory/presentation/public_page_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

Finder key(String value) => find.byKey(ValueKey(value));
Future<void> tap(WidgetTester tester, String value) async {
  await tester.ensureVisible(key(value));
  await tester.tap(key(value));
  await tester.pumpAndSettle();
}

void main() {
  for (final locale in ['en', 'fr', 'de', 'es', 'it']) {
    testWidgets(
      'facts are readable and reachable at narrow large text in $locale',
      (tester) async {
        await pumpApp(
          tester,
          Theme(data: ThemeData.dark(), child: const PublicPageEditor()),
          locale: Locale(locale),
          size: const Size(320, 800),
          textScale: 1.8,
          overrides: standardTestOverrides(
            auth: FakeAuthRepository.signedIn(),
            directory: FakeDirectoryRepository(),
          ),
        );
        await tester.pumpAndSettle();
        await tap(tester, 'public-facet-accessibility-accessible_toilet');
        expect(
          tester
              .widget<CheckboxListTile>(
                key('public-facet-accessibility-accessible_toilet'),
              )
              .value,
          isTrue,
        );
        await tester.ensureVisible(
          key('public-page-editor-portal-save-preview'),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('keyboard toggles a labelled fact without a map', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpApp(
        tester,
        const PublicPageEditor(),
        size: const Size(1440, 1000),
        overrides: standardTestOverrides(
          auth: FakeAuthRepository.signedIn(),
          directory: FakeDirectoryRepository(),
        ),
      );
      await tester.pumpAndSettle();
      bool onWifi() =>
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<CheckboxListTile>()
              ?.key ==
          const ValueKey('public-facet-amenities-wifi');
      for (var i = 0; i < 40 && !onWifi(); i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
      }
      expect(onWifi(), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(key('public-facet-amenities-wifi'))
            .value,
        isTrue,
      );
      expect(find.bySemanticsLabel('Wi-Fi'), findsWidgets);
      expect(key('public-hours-note'), findsNothing);
      expect(key('public-hours-edit-availability'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
