// SPDX-License-Identifier: 0BSD
//
// #606 — contextual help hints: the dismissible card renders at the top
// of its surface, the X persists the dismissal across rebuilds, "Learn
// more" deep-links into /help with the surface's localized topic, the
// Settings row restores every dismissed hint, and the formHelpHints
// flag OFF removes hints and the Settings row alike.
import 'dart:io';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/help/help_hint.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo/core/storage/help_hint_store.dart';
import 'package:deskilo/features/help/presentation/screens/help_screen.dart';
import 'package:deskilo/features/help/providers/help_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../helpers/mock_providers.dart';

Override _helpOverride() => helpContentProvider.overrideWith(
      (ref, languageCode) async => '# User Guide\n\n## 1. Intro\n\nHi.\n',
    );

Future<void> _pumpApp(
  WidgetTester tester, {
  HelpHintStore? store,
  Map<String, dynamic> featureFlags = const {},
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          helpHints: store,
          workspace:
              FakeWorkspaceRepository.withWorkspace(featureFlags: featureFlags),
        ),
        _helpOverride(),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    // markdown_widget wraps blocks in VisibilityDetector (TOC tracking),
    // whose batching timer would otherwise survive the test body.
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('the hint renders on the reserve hub (top of content)',
      (tester) async {
    await _pumpApp(tester);
    expect(find.byKey(const ValueKey('help-hint-reserve')), findsOneWidget);
    expect(
      find.textContaining('tap a free seat'),
      findsOneWidget,
    );
  });

  testWidgets('the hint renders on the events feed too', (tester) async {
    await _pumpApp(tester);
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push('/events');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('help-hint-events')), findsOneWidget);
  });

  testWidgets('X dismisses the hint and the dismissal survives a rebuild',
      (tester) async {
    final store = InMemoryHelpHintStore();
    await _pumpApp(tester, store: store);
    expect(find.byKey(const ValueKey('help-hint-reserve')), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('help-hint-dismiss-reserve')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('help-hint-reserve')), findsNothing);
    expect(store.dismissed, contains('reserve'));

    // A fresh app boot with the SAME device store keeps it hidden —
    // and other hints stay untouched.
    await _pumpApp(tester, store: store);
    expect(find.byKey(const ValueKey('help-hint-reserve')), findsNothing);
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push('/events');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('help-hint-events')), findsOneWidget);
  });

  testWidgets('"Learn more" opens /help carrying the localized topic',
      (tester) async {
    await _pumpApp(tester);
    await tester.tap(
      find.byKey(const ValueKey('help-hint-learn-more-reserve')),
    );
    await tester.pumpAndSettle();

    // The route landed on the help screen with the hub's topic — the
    // deep link the guide jump consumes. No heading matches the fake
    // guide, which is exactly the never-crash path.
    expect(find.byType(HelpScreen), findsOneWidget);
    expect(
      tester.widget<HelpScreen>(find.byType(HelpScreen)).topic,
      'Reserve hub',
    );
  });

  testWidgets('Settings → "Show help hints again" restores dismissed hints',
      (tester) async {
    final store = InMemoryHelpHintStore()..dismissed = {'reserve'};
    await _pumpApp(tester, store: store);
    expect(find.byKey(const ValueKey('help-hint-reserve')), findsNothing);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-restore-hints')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('settings-restore-hints')));
    await tester.pumpAndSettle();
    expect(store.dismissed, isEmpty);

    // Back on the hub the hint greets again.
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('help-hint-reserve')), findsOneWidget);
  });

  testWidgets('flag OFF hides every hint and the Settings restore row',
      (tester) async {
    await _pumpApp(tester, featureFlags: {'formHelpHints': false});
    expect(find.byKey(const ValueKey('help-hint-reserve')), findsNothing);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-help')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('settings-restore-hints')),
      findsNothing,
    );
  });

  test('every hint id resolves a non-empty text and topic (fallbacks)', () {
    for (final id in HelpHintId.values) {
      expect(HelpHint.text(null, id).trim(), isNotEmpty,
          reason: '${id.name} has no fallback text');
      expect(HelpHint.topic(null, id).trim(), isNotEmpty,
          reason: '${id.name} has no fallback topic');
    }
  });

  test('every localized topic matches a heading of its language\'s guide — '
      'the deep link must land in all five languages', () {
    for (final locale in helpLocales) {
      final l10n = lookupAppLocalizations(Locale(locale));
      final headings = File('assets/help/$locale.md')
          .readAsLinesSync()
          .where((line) => line.startsWith('#'))
          .map((line) => line.replaceFirst(RegExp(r'^#+\s*'), ''))
          .toList();
      for (final id in HelpHintId.values) {
        final topic = HelpHint.topic(l10n, id).toLowerCase();
        expect(
          headings.any((h) => h.toLowerCase().contains(topic)),
          isTrue,
          reason: '$locale: topic "$topic" of ${id.name} matches no '
              'heading in assets/help/$locale.md',
        );
      }
    }
  });
}
