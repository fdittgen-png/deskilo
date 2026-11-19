// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Public facts stay readable in every interface language at narrow large
// text, tablet and desktop sizes; keyboard users can open a card without a map.
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/presentation/directory_row.dart';
import 'package:deskilo/features/directory/presentation/public_workspace_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _place = PublicWorkspace('atelier', 'https://host.example', '', {
  'name': 'Atelier du Marché',
  'description': 'Desks and meeting rooms above the market square.',
  'address': '4 place du Marché, 34120 Pézenas',
  'amenities': [
    'wifi',
    'meeting_room',
    'kitchen',
    'printer',
    'parking',
    'bike_parking',
  ],
  'accessibility': ['step_free_entrance', 'accessible_toilet', 'lift'],
  'opening_hours': {
    'weekdays': [1, 2, 3, 4, 5],
    'start_minutes': 480,
    'end_minutes': 1080,
    'timezone': 'Europe/Paris',
  },
});

void main() {
  for (final locale in ['en', 'fr', 'de', 'es', 'it']) {
    testWidgets('card and page fit narrow large text in $locale', (
      tester,
    ) async {
      var viewed = false;
      await pumpApp(
        tester,
        Theme(
          data: ThemeData.dark(),
          child: Scaffold(
            body: SingleChildScrollView(
              child: DirectoryRow(
                workspace: _place,
                selected: false,
                onView: () => viewed = true,
                onLocate: () {},
              ),
            ),
          ),
        ),
        locale: Locale(locale),
        size: const Size(320, 800),
        textScale: 1.8,
        overrides: standardTestOverrides(),
      );
      await tester.pumpAndSettle();
      final view = find.byKey(
        const ValueKey('directory-view-https://host.example/atelier'),
      );
      await tester.ensureVisible(view);
      await tester.tap(view);
      expect(viewed, isTrue);
      expect(tester.takeException(), isNull);
      await pumpApp(
        tester,
        Theme(
          data: ThemeData.dark(),
          child: const PublicWorkspaceView(workspace: _place, preview: true),
        ),
        locale: Locale(locale),
        size: const Size(320, 800),
        textScale: 1.8,
        overrides: standardTestOverrides(),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('public-profile-hours')),
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [768.0, 1440.0]) {
    testWidgets('public section headings remain semantic at $width', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpApp(
          tester,
          const PublicWorkspaceView(workspace: _place, preview: true),
          size: Size(width, 1400),
          overrides: standardTestOverrides(),
        );
        await tester.pumpAndSettle();
        final headings = tester.widgetList<Semantics>(
          find.descendant(
            of: find.byKey(const ValueKey('public-profile-accessibility')),
            matching: find.byType(Semantics),
          ),
        );
        expect(headings.any((s) => s.properties.header == true), isTrue);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('keyboard reaches View after the card facts', (tester) async {
    var viewed = false;
    await pumpApp(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: DirectoryRow(
            workspace: _place,
            selected: false,
            onView: () => viewed = true,
            onLocate: () {},
          ),
        ),
      ),
      size: const Size(1440, 1200),
      overrides: standardTestOverrides(),
    );
    await tester.pumpAndSettle();
    bool onView() =>
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<FilledButton>()
            ?.key ==
        const ValueKey('directory-view-https://host.example/atelier');
    for (var i = 0; i < 12 && !onView(); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
    }
    expect(onView(), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(viewed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
