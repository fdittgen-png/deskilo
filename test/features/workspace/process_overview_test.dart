// SPDX-License-Identifier: 0BSD
//
// #1327 — the Features screen opens on one card per business process,
// and every card's state is the stored feature map read through the
// registry, said in words beside an icon; search reaches every level
// with its path, the filters narrow the cards, and a tapped feature
// lands on its switch, which writes the same delta as before.
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_process.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'features_screen_test.dart' show pumpFeatures;

/// One stored map that puts four processes in four different states:
///
/// * Integrations & automation — every feature on by default: Active.
/// * Space management — some default-off features: Partial.
/// * Calendar & coordination — all thirteen switched off: Available.
/// * Workspace & access — kiosk mode off holds its badges back while
///   their own switches stay on: Needs attention.
const _fixture = <String, dynamic>{
  'kioskMode': false,
  'calendarTab': false,
  'calendarHub': false,
  'calendarViews': false,
  'calendarValidations': false,
  'eventsTab': false,
  'validationScopes': false,
  'validationChain': false,
  'deletionRequests': false,
  'memberNotifications': false,
  'notificationGrouping': false,
  'richMessageRefs': false,
  'messageGestures': false,
  'messagesHub': false,
};

Finder _card(String key) => find.byKey(ValueKey('process-$key'));

Finder _inCard(String key, String text) =>
    find.descendant(of: _card(key), matching: find.text(text));

Future<FakeWorkspaceRepository> _pumpOverview(
  WidgetTester tester, {
  Size size = const Size(800, 4000),
}) => pumpFeatures(tester, featureFlags: _fixture, size: size, switches: false);

void main() {
  testWidgets('one card per process, none of them a switch', (tester) async {
    await _pumpOverview(tester);

    for (final process in workspaceProcesses) {
      expect(_card(process.key), findsOneWidget, reason: process.key);
    }
    expect(
      find.byType(SwitchListTile),
      findsNothing,
      reason: 'the technical switches are the second view, not this one',
    );
  });

  testWidgets('each card says its state in words', (tester) async {
    await _pumpOverview(tester);

    expect(_inCard('integrations', 'Active'), findsOneWidget);
    expect(_inCard('spaceManagement', 'Partial'), findsOneWidget);
    expect(_inCard('coordination', 'Available'), findsOneWidget);
    expect(_inCard('workspaceAccess', 'Needs attention'), findsOneWidget);
    expect(
      find.descendant(
        of: _card('workspaceAccess'),
        matching: find.textContaining('wait for a switched-off prerequisite'),
      ),
      findsOneWidget,
      reason: 'the attention state says what is wrong',
    );
    expect(
      _inCard(
        'coordination',
        '0 of 3 subprocesses active · '
            '0 of 13 features on',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a card is one screen-reader node naming its state and counts', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpOverview(tester);

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'^Workspace & access\. Needs attention\. '
          r'\d+ of 2 subprocesses active\. \d+ of 16 features on',
        ),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('opening a card lists its subprocesses and what each feature '
      'is doing', (tester) async {
    await _pumpOverview(tester);

    await tester.tap(
      find.byKey(const ValueKey('process-header-workspaceAccess')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('process-detail-workspaceAccess')),
      findsOneWidget,
    );
    expect(_inCard('workspaceAccess', 'Physical access'), findsOneWidget);
    expect(
      _inCard('workspaceAccess', 'On, waiting for Kiosk mode'),
      findsWidgets,
    );
  });

  group('the filters', () {
    Future<Set<String>> shown(WidgetTester tester, String filter) async {
      await tester.tap(find.byKey(ValueKey('process-filter-$filter')));
      await tester.pumpAndSettle();
      return {
        for (final process in workspaceProcesses)
          if (_card(process.key).evaluate().isNotEmpty) process.key,
      };
    }

    testWidgets('Active keeps what is in use', (tester) async {
      await _pumpOverview(tester);
      final active = await shown(tester, 'active');
      expect(active, isNot(contains('coordination')));
      expect(active, containsAll(['integrations', 'spaceManagement']));
    });

    testWidgets('Available keeps what has something left to switch on', (
      tester,
    ) async {
      await _pumpOverview(tester);
      final available = await shown(tester, 'available');
      expect(available, isNot(contains('integrations')));
      expect(available, containsAll(['coordination', 'spaceManagement']));
    });

    testWidgets('Needs attention keeps only the held-back process', (
      tester,
    ) async {
      await _pumpOverview(tester);
      expect(await shown(tester, 'needsAttention'), {'workspaceAccess'});
      expect(await shown(tester, 'all'), {
        for (final p in workspaceProcesses) p.key,
      });
    });
  });

  group('search', () {
    testWidgets('finds a feature and shows the process and subprocess above '
        'it', (tester) async {
      await _pumpOverview(tester);
      await tester.enterText(
        find.byKey(const ValueKey('process-search')),
        'sign in with',
      );
      await tester.pumpAndSettle();

      final hit = find.byKey(const ValueKey('process-hit-feature-badgeSignIn'));
      expect(hit, findsOneWidget);
      expect(
        find.descendant(
          of: hit,
          matching: find.text('Workspace & access › Physical access'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a subprocess hit opens its process', (tester) async {
      await _pumpOverview(tester);
      await tester.enterText(
        find.byKey(const ValueKey('process-search')),
        'Physical access',
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('process-hit-subprocess-physicalAccess')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('process-detail-workspaceAccess')),
        findsOneWidget,
      );
    });

    testWidgets('nothing matching says so', (tester) async {
      await _pumpOverview(tester);
      await tester.enterText(
        find.byKey(const ValueKey('process-search')),
        'zzzznope',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('process-no-match')), findsOneWidget);
    });
  });

  testWidgets('a feature tapped on the overview lands on its switch, which '
      'writes the same delta as ever', (tester) async {
    final workspace = await pumpFeatures(tester, switches: false);

    await tester.tap(find.byKey(const ValueKey('process-header-integrations')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('process-feature-whatsappIntegration')),
    );
    await tester.pumpAndSettle();

    final tile = find.byKey(const ValueKey('feature-whatsappIntegration'));
    expect(tile, findsOneWidget);
    expect(
      find.byType(SwitchListTile),
      findsOneWidget,
      reason: 'the switches view opens already searched to that feature',
    );

    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(workspace.flagWrites.last, {'whatsappIntegration': false});
  });

  testWidgets('360 dp at twice the text size, cards open: nothing overflows', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpOverview(tester, size: const Size(360, 800));
    expect(tester.takeException(), isNull);

    for (final key in ['workspaceAccess', 'billingPayments']) {
      final header = find.byKey(ValueKey('process-header-$key'));
      await tester.ensureVisible(header);
      await tester.pumpAndSettle();
      await tester.tap(header);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: key);
    }
  });

  testWidgets('with reduced motion a card opens without an animation', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pumpOverview(tester);

    await tester.tap(find.byKey(const ValueKey('process-header-integrations')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('process-detail-integrations')),
      findsOneWidget,
      reason: 'the detail is there on the very next frame',
    );
    expect(
      find.descendant(
        of: _card('integrations'),
        matching: find.byType(AnimatedSize),
      ),
      findsNothing,
    );
  });

  group('#1329 — a process is switched through ONE preview, and the write '
      'is conditioned on what it showed', () {
    Future<void> tapKey(WidgetTester tester, String key) async {
      final finder = find.byKey(ValueKey(key));
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    testWidgets('Switch on shows the preview, and confirming writes the '
        'delta with the read-set; success is said after the refetch',
        (tester) async {
      final workspace = await _pumpOverview(tester);
      await tester.tap(find.byKey(const ValueKey('process-header-coordination')));
      await tester.pumpAndSettle();
      await tapKey(tester, 'process-on-coordination');

      expect(find.byKey(const ValueKey('process-change-sheet')), findsOneWidget);
      expect(find.byKey(const ValueKey('process-change-section-on')), findsOneWidget);
      expect(workspace.flagWrites, isEmpty, reason: 'nothing before confirm');

      await tapKey(tester, 'process-change-confirm');
      expect(workspace.flagWrites, hasLength(1));
      final written = workspace.flagWrites.single;
      expect(written['calendarHub'], isTrue);
      expect(written.values.every((bool v) => v), isTrue);
      final expected = workspace.flagExpectations.single!;
      expect(expected.keys, containsAll(written.keys),
          reason: 'the read-set covers every written key');
      expect(expected['calendarHub'], isFalse, reason: 'as it was read');
      expect(find.byKey(const ValueKey('process-change-sheet')), findsNothing);
      expect(find.textContaining('features changed.'), findsOneWidget);
    });

    testWidgets('a conflict writes nothing, refetches and shows the updated '
        'preview to confirm again — the old delta is never replayed',
        (tester) async {
      final workspace = await _pumpOverview(tester)..flagConflictNext = true;
      await tester.tap(find.byKey(const ValueKey('process-header-coordination')));
      await tester.pumpAndSettle();
      await tapKey(tester, 'process-on-coordination');
      await tapKey(tester, 'process-change-confirm');

      expect(workspace.flagWrites, isEmpty, reason: 'the conflict wrote nothing');
      expect(find.byKey(const ValueKey('process-change-conflict')), findsOneWidget);
      expect(find.byKey(const ValueKey('process-change-sheet')), findsOneWidget,
          reason: 'still open, on the refreshed preview');
      expect(find.textContaining('features changed.'), findsNothing);

      await tapKey(tester, 'process-change-confirm');
      expect(workspace.flagWrites, hasLength(1));
      expect(workspace.flagExpectations, hasLength(2),
          reason: 'the second attempt carried its own read-set');
    });

    testWidgets('a stale read-set on the fake is refused the way the server '
        'refuses it', (tester) async {
      final workspace = await _pumpOverview(tester);
      await tester.tap(find.byKey(const ValueKey('process-header-coordination')));
      await tester.pumpAndSettle();
      await tapKey(tester, 'process-on-coordination');
      // Someone else switches a prerequisite on behind the preview.
      workspace.workspaces[0] = workspace.workspaces[0].copyWith(
        featureFlags: {...workspace.workspaces[0].featureFlags, 'calendarHub': true},
      );
      await tapKey(tester, 'process-change-confirm');
      expect(workspace.flagWrites, isEmpty);
      expect(find.byKey(const ValueKey('process-change-conflict')), findsOneWidget);
    });

    testWidgets('switching off a prerequisite that others still need is '
        'refused first, and the owner chooses how', (tester) async {
      // Integrations is fully on: switching its whole process off orphans
      // nothing in the fixture, so ask for one subprocess whose feature
      // has a stored-on dependant elsewhere — find it from the registry.
      final workspace = await _pumpOverview(tester);
      final raw = resolveEnabledFeatures(workspace.workspaces[0].featureFlags);
      String? subKey;
      String? processKey;
      for (final process in workspaceProcesses) {
        for (final sub in process.subprocesses) {
          for (final feature in sub.capabilities) {
            if (!raw.contains(feature)) continue;
            final dependants = dependentFeatures(feature)
                .where((d) => raw.contains(d) && !sub.capabilities.contains(d));
            if (dependants.isNotEmpty) {
              subKey = sub.key;
              processKey = process.key;
              break;
            }
          }
          if (subKey != null) break;
        }
        if (subKey != null) break;
      }
      expect(subKey, isNotNull, reason: 'the fixture has an on prerequisite');

      await tester.tap(find.byKey(ValueKey('process-header-$processKey')));
      await tester.pumpAndSettle();
      await tapKey(tester, 'sub-off-$subKey');
      expect(find.byKey(const ValueKey('process-change-keep')), findsOneWidget);
      final confirm = tester.widget<FilledButton>(
          find.byKey(const ValueKey('process-change-confirm')));
      expect(confirm.onPressed, isNull, reason: 'refused until a choice is made');

      await tapKey(tester, 'process-change-keep');
      expect(find.byKey(const ValueKey('process-change-section-kept')), findsOneWidget);
      await tapKey(tester, 'process-change-confirm');
      final written = workspace.flagWrites.single;
      expect(written.values.every((bool v) => !v), isTrue);
      expect(written.keys,
          everyElement(isIn([for (final f in raw) f.dbKey])));
      for (final sub in workspaceProcesses.expand((p) => p.subprocesses)) {
        if (sub.key != subKey) continue;
        for (final f in sub.capabilities) {
          if (raw.contains(f) && !internalCapabilities.containsKey(f)) {
            expect(written[f.dbKey], isFalse);
          }
        }
      }
      // The stored dependants were not written.
      expect(workspace.flagExpectations.single!.length,
          greaterThan(written.length),
          reason: 'the read-set includes the dependants the delta leaves alone');
    });
  });
}
