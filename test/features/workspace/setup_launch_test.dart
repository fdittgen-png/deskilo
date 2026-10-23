// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2876 — the Launch review: a space with one mandatory condition failing
// cannot go live and the page names the step; going live asks first and
// cancelling changes nothing; the readiness report lists every milestone
// with its evidence, on the page and in the configuration PDF.
import 'package:deskilo/core/demo/data/local_setup_repository.dart';
import 'package:deskilo/features/workspace/domain/launch_review.dart';
import 'package:deskilo/features/workspace/domain/setup_status.dart';
import 'package:deskilo/features/workspace/domain/workspace_config_report.dart';
import 'package:deskilo/features/workspace/presentation/launch_report.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_launch_screen.dart';
import 'package:deskilo/features/workspace/presentation/workspace_configuration_report_strings.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

SetupStatus _status({required bool placesDone, bool operator = false}) =>
    SetupStatus.fromJson({
      'steps': [
        {
          'step': 'basics',
          'milestone': 'bookable',
          'required': true,
          'state': 'ready',
          'route': '/workspace-settings',
        },
        {
          'step': 'places',
          'milestone': 'bookable',
          'required': true,
          'state': placesDone ? 'ready' : 'needs_configuration',
          'route': '/editor',
        },
        {
          'step': 'public_page',
          'milestone': 'live',
          'required': false,
          'state': 'ready',
          'route': '/settings/public-page',
        },
        {
          'step': 'online_payments',
          'milestone': 'money',
          'required': false,
          'state': operator ? 'needs_operator' : 'not_applicable',
          'route': '/payment-config',
        },
      ],
      'milestones': [
        {
          'milestone': 'bookable',
          'applies': true,
          'required': 2,
          'ready': placesDone ? 2 : 1,
          'reached': placesDone,
        },
        {
          'milestone': 'invoice',
          'applies': false,
          'required': 4,
          'ready': 0,
          'reached': false,
        },
      ],
    });

Future<List<String>> _pump(
  WidgetTester tester,
  SetupStatus status, {
  bool testSpace = false,
}) async {
  final pushed = <String>[];
  GoRoute target(String path) => GoRoute(
    path: path,
    builder: (_, _) {
      pushed.add(path);
      return const Scaffold();
    },
  );
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SetupLaunchScreen()),
      target('/editor'),
      target('/workspace-settings'),
      target('/deployment'),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          localSetup: FakeLocalSetupRepository(status: status),
        ),
        // The shared fixture is a real (prod) space; going live is a test
        // space's action.
        if (testSpace)
          currentWorkspaceProvider.overrideWith(
            (ref) async =>
                (await ref.watch(myWorkspacesProvider.future)).first
                    .copyWith(environment: 'dev'),
          ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return pushed;
}

final _list = find
    .descendant(
      of: find.byKey(const ValueKey('setup-launch-list')),
      matching: find.byType(Scrollable),
    )
    .first;

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('the review', () {
    test('one required step open: cannot go live, and that step is named', () {
      final review = LaunchReview.from(_status(placesDone: false));
      expect(review.canGoLive, isFalse);
      expect(review.blockers.map((s) => s.step), ['places']);
    });

    test('every chosen milestone reached: can go live; a milestone not '
        'chosen does not count', () {
      final review = LaunchReview.from(_status(placesDone: true));
      expect(review.canGoLive, isTrue);
      expect(review.milestones.map((m) => m.status.milestone), ['bookable']);
    });

    test('the report lists every milestone with its evidence', () {
      final review = LaunchReview.from(_status(placesDone: false));
      final text = launchReportText(l10n, review);
      expect(text, contains(l10n.setupMilestoneName('bookable')));
      expect(text, contains(l10n.setupGuideProgress(1, 2)));
      expect(
        text,
        contains(
          '${l10n.setupStepTitle('basics')}: '
          '${l10n.setupStateName('ready')}',
        ),
      );
      expect(
        text,
        contains(
          '${l10n.setupStepTitle('places')}: '
          '${l10n.setupStateName('needsConfiguration')}',
        ),
      );
      expect(text, isNot(contains(l10n.setupMilestoneName('invoice'))));
    });

    test('the configuration PDF carries the same report under its heading', () {
      final lines = launchReportLines(
        l10n,
        LaunchReview.from(_status(placesDone: false)),
      );
      final data = workspaceConfigurationReportData(
        WorkspaceConfigDocument(
          strings: workspaceConfigurationStrings(l10n),
          workspaceName: 'S',
          generatedOnLabel: '',
          countryLabel: '',
          currencyCode: 'EUR',
          timezone: 'Europe/Paris',
          granularityLabel: '',
          members: const [],
          featureGroups: const [],
          openDaysLabel: '',
          closureLabels: const [],
          levels: const [],
          levelPrices: const {},
          hasCustomInvitationTemplate: false,
          readinessTitle: l10n.setupLaunchReportTitle,
          readiness: lines,
        ),
      );
      final rows = (data['configuration_rows']! as List)
          .cast<Map<String, Object?>>();
      final at = rows.indexWhere(
        (r) =>
            r['label'] == l10n.setupLaunchReportTitle && r['heading'] == true,
      );
      expect(at, isNonNegative);
      expect(rows[at + 1]['label'], l10n.setupMilestoneName('bookable'));
      expect(rows[at + 1]['detail'], lines.single.detail);
    });

    test('a step that is not used is not among the answers', () {
      final review = LaunchReview.from(_status(placesDone: true));
      expect(
        review.groups.expand((g) => g.steps).map((s) => s.step),
        isNot(contains('online_payments')),
      );
    });
  });

  testWidgets('blocked: the page names the step and its Fix opens it; no '
      'Go live button', (tester) async {
    final pushed = await _pump(tester, _status(placesDone: false));
    expect(find.byKey(const ValueKey('setup-launch-blocked')), findsOneWidget);
    expect(find.byKey(const ValueKey('setup-launch-go-live')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('setup-launch-fix-places')));
    await tester.pumpAndSettle();
    expect(pushed, ['/editor']);
  });

  testWidgets('ready: Go live asks first; cancelling changes nothing, '
      'confirming opens the deployment', (tester) async {
    final pushed = await _pump(
      tester,
      _status(placesDone: true),
      testSpace: true,
    );
    final goLive = find.byKey(const ValueKey('setup-launch-go-live'));
    expect(goLive, findsOneWidget);

    await tester.tap(goLive);
    await tester.pumpAndSettle();
    expect(find.text(l10n.setupLaunchGoLiveBody), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('setup-launch-confirm-no')));
    await tester.pumpAndSettle();
    expect(pushed, isEmpty);
    expect(find.byType(SetupLaunchScreen), findsOneWidget);

    await tester.tap(goLive);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setup-launch-confirm-yes')));
    await tester.pumpAndSettle();
    expect(pushed, ['/deployment']);
  });

  testWidgets('a real space that reached every milestone says it is live, '
      'with no Go live button', (tester) async {
    await _pump(tester, _status(placesDone: true));
    expect(find.text(l10n.setupLaunchIsLive), findsOneWidget);
    expect(find.byKey(const ValueKey('setup-launch-go-live')), findsNothing);
  });

  testWidgets('every answer has its Change link, and what is public is said', (
    tester,
  ) async {
    final pushed = await _pump(tester, _status(placesDone: true));
    expect(find.text(l10n.setupLaunchPublicOn), findsOneWidget);
    final change = find.byKey(const ValueKey('setup-launch-change-basics'));
    await tester.scrollUntilVisible(change, 200, scrollable: _list);
    await tester.pump();
    await tester.tap(change);
    await tester.pumpAndSettle();
    expect(pushed, ['/workspace-settings']);
  });

  List<String> copies(WidgetTester tester) {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    return copied;
  }

  testWidgets('the operator tasks are copied as text to forward', (
    tester,
  ) async {
    final copied = copies(tester);
    await _pump(tester, _status(placesDone: true, operator: true));
    await tester.tap(find.byKey(const ValueKey('setup-launch-copy-operator')));
    await tester.pump();
    expect(copied.single, contains(l10n.setupStepTitle('online_payments')));
  });

  testWidgets('the readiness report is copied with every milestone', (
    tester,
  ) async {
    final copied = copies(tester);
    await _pump(tester, _status(placesDone: true));
    final report = find.byKey(const ValueKey('setup-launch-report'));
    await tester.scrollUntilVisible(report, 200, scrollable: _list);
    await tester.pump();
    await tester.tap(report);
    await tester.pump();
    expect(copied.single, startsWith(l10n.setupLaunchReportTitle));
    expect(copied.single, contains(l10n.setupMilestoneName('bookable')));
  });
}
