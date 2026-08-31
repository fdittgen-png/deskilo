// SPDX-License-Identifier: 0BSD
//
// #606 — contextual help hints: the dismissible card renders at the top
// of its surface, the X persists the dismissal across rebuilds, "Learn
// more" deep-links into /help with the surface's localized topic, the
// Settings row restores every dismissed hint, and the formHelpHints
// flag OFF removes hints and the Settings row alike.
// #610 — the hints are tip carousels: 3–5 tips per surface, chevrons +
// indicator + swiping, a fresh visit opens on the tip after the last
// shown one (rotating), manual paging updates that memory, and every
// tip's Learn more lands on its own guide section.
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
          workspace: FakeWorkspaceRepository.withWorkspace(
            featureFlags: featureFlags,
          ),
        ),
        _helpOverride(),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// The carousel's compact "2/5" position indicator for [id].
String _position(WidgetTester tester, String id) =>
    tester.widget<Text>(find.byKey(ValueKey('help-hint-pos-$id'))).data!;

void main() {
  setUpAll(() {
    // markdown_widget wraps blocks in VisibilityDetector (TOC tracking),
    // whose batching timer would otherwise survive the test body.
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('the hint renders on the reserve hub (top of content)', (
    tester,
  ) async {
    await _pumpApp(tester);
    expect(find.byKey(const ValueKey('help-hint-reserve')), findsOneWidget);
    expect(find.textContaining('tap a free seat'), findsOneWidget);
    // The carousel indicator says where we are — first visit, tip 1.
    expect(_position(tester, 'reserve'), '1/5');
  });

  testWidgets('the next visit opens on the NEXT tip, rotating past the end', (
    tester,
  ) async {
    final store = InMemoryHelpHintStore();
    await _pumpApp(tester, store: store);
    expect(_position(tester, 'reserve'), '1/5');
    // Showing tip 1 recorded it as the last shown.
    expect(store.positions['reserve'], 0);

    // A fresh app boot with the SAME device store teaches the next tip.
    // (Tear the tree down first — a visit begins with a fresh screen.)
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpApp(tester, store: store);
    expect(_position(tester, 'reserve'), '2/5');
    expect(find.textContaining('Week and Month views'), findsOneWidget);
    expect(store.positions['reserve'], 1);

    // A stored index past the end (an older, longer tip list) rotates
    // back to the start instead of crashing.
    store.positions['reserve'] = 99;
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpApp(tester, store: store);
    expect(_position(tester, 'reserve'), '1/5');
  });

  testWidgets('chevrons page forward and backward, wrapping, and persist', (
    tester,
  ) async {
    final store = InMemoryHelpHintStore();
    await _pumpApp(tester, store: store);
    expect(_position(tester, 'reserve'), '1/5');

    await tester.tap(find.byKey(const ValueKey('help-hint-next-reserve')));
    await tester.pumpAndSettle();
    expect(_position(tester, 'reserve'), '2/5');
    expect(find.textContaining('Week and Month views'), findsOneWidget);
    // Manual paging updates the rotation memory.
    expect(store.positions['reserve'], 1);

    await tester.tap(find.byKey(const ValueKey('help-hint-prev-reserve')));
    await tester.pumpAndSettle();
    expect(_position(tester, 'reserve'), '1/5');
    expect(store.positions['reserve'], 0);

    // Backward from tip 1 wraps to the last tip — the indicator keeps
    // the position obvious.
    await tester.tap(find.byKey(const ValueKey('help-hint-prev-reserve')));
    await tester.pumpAndSettle();
    expect(_position(tester, 'reserve'), '5/5');
    expect(store.positions['reserve'], 4);
  });

  testWidgets('swiping the card pages too, in sync with the indicator', (
    tester,
  ) async {
    final store = InMemoryHelpHintStore();
    await _pumpApp(tester, store: store);

    await tester.drag(
      find.byKey(const ValueKey('help-hint-pager-reserve')),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();
    expect(_position(tester, 'reserve'), '2/5');
    expect(store.positions['reserve'], 1);

    await tester.drag(
      find.byKey(const ValueKey('help-hint-pager-reserve')),
      const Offset(400, 0),
    );
    await tester.pumpAndSettle();
    expect(_position(tester, 'reserve'), '1/5');
    expect(store.positions['reserve'], 0);
  });

  testWidgets('the hint renders on the events feed too', (tester) async {
    await _pumpApp(tester);
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push('/events');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('help-hint-events')), findsOneWidget);
  });

  testWidgets('X dismisses the hint and the dismissal survives a rebuild', (
    tester,
  ) async {
    final store = InMemoryHelpHintStore();
    await _pumpApp(tester, store: store);
    expect(find.byKey(const ValueKey('help-hint-reserve')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('help-hint-dismiss-reserve')));
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

  testWidgets('"Learn more" opens /help carrying the localized topic', (
    tester,
  ) async {
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

  testWidgets('a tip with its own topic deep-links to that guide section', (
    tester,
  ) async {
    await _pumpApp(tester);
    // Page to tip 3 — the QR-scan tip, which carries its own topic.
    await tester.tap(find.byKey(const ValueKey('help-hint-next-reserve')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('help-hint-next-reserve')));
    await tester.pumpAndSettle();
    expect(_position(tester, 'reserve'), '3/5');

    await tester.tap(
      find.byKey(const ValueKey('help-hint-learn-more-reserve')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HelpScreen), findsOneWidget);
    expect(
      tester.widget<HelpScreen>(find.byType(HelpScreen)).topic,
      'Scan a space code',
    );
  });

  testWidgets('Settings → "Show help hints again" restores dismissed hints', (
    tester,
  ) async {
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

  testWidgets('flag OFF hides every hint and the Settings restore row', (
    tester,
  ) async {
    await _pumpApp(tester, featureFlags: {'formHelpHints': false});
    expect(find.byKey(const ValueKey('help-hint-reserve')), findsNothing);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-help')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('settings-restore-hints')), findsNothing);
  });

  test('every hint id resolves a non-empty text and topic (fallbacks)', () {
    for (final id in HelpHintId.values) {
      expect(
        HelpHint.text(null, id).trim(),
        isNotEmpty,
        reason: '${id.name} has no fallback text',
      );
      expect(
        HelpHint.topic(null, id).trim(),
        isNotEmpty,
        reason: '${id.name} has no fallback topic',
      );
    }
  });

  test('every surface carries 3–5 tips, tip 1 being the #606 how-to', () {
    for (final id in HelpHintId.values) {
      final tips = HelpHint.tips(null, id);
      expect(
        tips.length,
        inInclusiveRange(3, 5),
        reason: '${id.name} has ${tips.length} tips',
      );
      expect(
        tips.first.text,
        HelpHint.text(null, id),
        reason: '${id.name}: tip 1 must stay the original hint',
      );
      for (final tip in tips) {
        expect(
          tip.text.trim(),
          isNotEmpty,
          reason: '${id.name} has an empty tip',
        );
      }
    }
  });

  test('every HelpDot topic getter matches a heading of its language\'s '
      'guide (#763)', () async {
    const dotTopics = [
      'helpTopicLegalIdentity', 'helpTopicEinvoice', 'helpTopicVat',
      'helpTopicReportEditor', 'helpTopicDocumentLibrary',
      'helpTopicWorkspaceId', 'helpTopicSettings', 'helpTopicKiosk',
      'helpTopicBilling', 'helpTopicWorkingHours', 'helpTopicBookingPolicies',
      'helpTopicBookingLimits',
    ];
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = await AppLocalizations.delegate.load(locale);
      final headings = File('assets/help/${locale.languageCode}.md')
          .readAsLinesSync()
          .where((l) => l.startsWith('#'))
          .toList();
      final topics = {
        'helpTopicLegalIdentity': l10n.helpTopicLegalIdentity,
        'helpTopicEinvoice': l10n.helpTopicEinvoice,
        'helpTopicVat': l10n.helpTopicVat,
        'helpTopicReportEditor': l10n.helpTopicReportEditor,
        'helpTopicDocumentLibrary': l10n.helpTopicDocumentLibrary,
        'helpTopicWorkspaceId': l10n.helpTopicWorkspaceId,
        'helpTopicSettings': l10n.helpTopicSettings,
        'helpTopicKiosk': l10n.helpTopicKiosk,
        'helpTopicBilling': l10n.helpTopicBilling,
        'helpTopicWorkingHours': l10n.helpTopicWorkingHours,
        'helpTopicBookingPolicies': l10n.helpTopicBookingPolicies,
        'helpTopicBookingLimits': l10n.helpTopicBookingLimits,
      };
      expect(topics.keys, containsAll(dotTopics));
      topics.forEach((key, topic) {
        expect(
          headings.any(
            (h) => h.toLowerCase().contains(topic.toLowerCase()),
          ),
          isTrue,
          reason: '$key "$topic" (${locale.languageCode}) matches no '
              'guide heading — the /help jump would land nowhere',
        );
      });
    }
  });

  test('every localized tip topic matches a heading of its language\'s '
      'guide — each Learn more must land in all five languages', () {
    for (final locale in helpLocales) {
      final l10n = lookupAppLocalizations(Locale(locale));
      final headings = File('assets/help/$locale.md')
          .readAsLinesSync()
          .where((line) => line.startsWith('#'))
          .map((line) => line.replaceFirst(RegExp(r'^#+\s*'), ''))
          .toList();
      bool lands(String topic) =>
          headings.any((h) => h.toLowerCase().contains(topic.toLowerCase()));
      for (final id in HelpHintId.values) {
        // The surface's default topic…
        expect(
          lands(HelpHint.topic(l10n, id)),
          isTrue,
          reason:
              '$locale: topic "${HelpHint.topic(l10n, id)}" of '
              '${id.name} matches no heading in assets/help/$locale.md',
        );
        // …and every tip's own topic (falling back to the surface's).
        final tips = HelpHint.tips(l10n, id);
        for (var i = 0; i < tips.length; i++) {
          final topic = tips[i].topic ?? HelpHint.topic(l10n, id);
          expect(
            lands(topic),
            isTrue,
            reason:
                '$locale: topic "$topic" of ${id.name} tip ${i + 1} '
                'matches no heading in assets/help/$locale.md',
          );
        }
      }
    }
  });
}
