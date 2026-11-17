// SPDX-License-Identifier: AGPL-3.0-or-later
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
  testWidgets('owner selects facts, saves, edits description and reopens', (
    tester,
  ) async {
    final repository = FakeDirectoryRepository();
    await pumpApp(
      tester,
      const PublicPageEditor(),
      size: const Size(390, 844),
      overrides: standardTestOverrides(
        auth: FakeAuthRepository.signedIn(),
        directory: repository,
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'public-facet-amenities-wifi');
    await tap(tester, 'public-facet-accessibility-step_free_entrance');
    await tap(tester, 'public-page-editor-portal-save-preview');
    await tester.pageBack();
    await tester.pumpAndSettle();
    final description = key('public-page-editor-text-field-description');
    await tester.ensureVisible(description);
    await tester.enterText(description, 'Only this changes');
    await tap(tester, 'public-page-editor-portal-save-preview');
    await tester.pageBack();
    await tester.pumpAndSettle();
    final stored =
        repository.pages['ws-1']!['document'] as Map<String, Object?>;
    expect(stored['amenities'], ['wifi']);
    expect(stored['accessibility'], ['step_free_entrance']);
    expect(stored['description'], 'Only this changes');
    expect(
      tester.widget<CheckboxListTile>(key('public-facet-amenities-wifi')).value,
      isTrue,
    );
    await tap(tester, 'public-facet-amenities-wifi');
    await tap(tester, 'public-page-editor-portal-save-preview');
    expect(
      (repository.pages['ws-1']!['document'] as Map)['amenities'],
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a business without places edits and clears its hours note', (
    tester,
  ) async {
    final repository = FakeDirectoryRepository()
      ..placeBooking = ((_) => false)
      ..timezoneOf = ((_) => 'Europe/Berlin');
    final workspace = FakeWorkspaceRepository.withWorkspace(
      featureFlags: {'placeBooking': false},
    );
    await pumpApp(
      tester,
      const PublicPageEditor(),
      size: const Size(768, 1024),
      overrides: standardTestOverrides(
        auth: FakeAuthRepository.signedIn(),
        workspace: workspace,
        directory: repository,
      ),
    );
    await tester.pumpAndSettle();
    expect(key('public-hours-edit-availability'), findsNothing);
    await tester.ensureVisible(key('public-hours-note'));
    await tester.enterText(key('public-hours-note'), 'By appointment');
    await tap(tester, 'public-page-editor-portal-save-preview');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      (repository.pages['ws-1']!['document'] as Map)['opening_hours'],
      'By appointment',
    );
    await tester.ensureVisible(key('public-hours-note'));
    await tester.enterText(key('public-hours-note'), '');
    await tap(tester, 'public-page-editor-portal-save-preview');
    expect(
      (await repository.ownPage('ws-1'))['document'],
      isNot(contains('opening_hours')),
    );
    expect(tester.takeException(), isNull);
  });

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
