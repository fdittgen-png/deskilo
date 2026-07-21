// SPDX-License-Identifier: 0BSD
//
// In-app help: the wiki user guide compiled into offline assets by
// tool/build_help.dart and rendered natively. The screen is reachable
// from Settings for every member, follows the app language, and the
// compiled assets stay free of raw wiki HTML. Widget tests inject small
// markdown through the helpContent seam — decoding the real screenshot
// assets would leave image timers pending.
import 'dart:io';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/help/presentation/screens/help_screen.dart';
import 'package:deskilo/features/help/providers/help_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../helpers/mock_providers.dart';

const _fakeGuide = '# User Guide\n\n'
    '## 1. Getting started\n\nWelcome to the help.\n\n'
    '## 2. Booking\n\nTap a free seat.\n';

Override _helpOverride() => helpContentProvider.overrideWith(
      (ref, languageCode) async => _fakeGuide,
    );

void main() {
  setUpAll(() {
    // markdown_widget wraps blocks in VisibilityDetector (TOC tracking),
    // whose batching timer would otherwise survive the test body.
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('help opens from settings and renders the bundled guide',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...standardTestOverrides(), _helpOverride()],
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-help')));
    await tester.pumpAndSettle();

    expect(find.byType(HelpScreen), findsOneWidget);
    expect(find.textContaining('Getting started', findRichText: true),
        findsWidgets);

    // The table of contents opens from the app bar and lists the sections.
    await tester.tap(find.byKey(const ValueKey('help-toc-button')));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);
    expect(find.textContaining('Booking', findRichText: true), findsWidgets);
  });

  testWidgets('a plain member reaches /help directly (no guard)',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...standardTestOverrides(), _helpOverride()],
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push('/help');
    await tester.pumpAndSettle();

    expect(find.byType(HelpScreen), findsOneWidget);
  });

  test('every supported locale maps to its own asset, others fall back', () {
    expect(helpAssetFor('fr'), 'assets/help/fr.md');
    expect(helpAssetFor('de'), 'assets/help/de.md');
    expect(helpAssetFor('es'), 'assets/help/es.md');
    expect(helpAssetFor('it'), 'assets/help/it.md');
    expect(helpAssetFor('en'), 'assets/help/en.md');
    expect(helpAssetFor('pt'), 'assets/help/en.md');
  });

  test('compiled help assets exist for all locales and contain no wiki HTML',
      () {
    for (final locale in helpLocales) {
      final file = File('assets/help/$locale.md');
      expect(file.existsSync(), isTrue, reason: 'missing $locale.md');
      final text = file.readAsStringSync();
      expect(text, startsWith('#'));
      // The compile step must have rewritten every HTML img and <p> tag.
      expect(text.contains('<img'), isFalse, reason: '$locale: raw <img>');
      expect(text.contains('<p>'), isFalse, reason: '$locale: raw <p>');
      // Images resolve into the bundled asset folder, and each referenced
      // image actually ships.
      expect(text, contains('![](assets/help/images/'));
      final refs = RegExp(r'!\[\]\((assets/help/images/[^)]+)\)')
          .allMatches(text)
          .map((m) => m[1]!);
      for (final ref in refs) {
        expect(File(ref).existsSync(), isTrue, reason: '$locale: $ref missing');
      }
    }
  });
}
