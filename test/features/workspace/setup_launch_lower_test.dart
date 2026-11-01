// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3076 — the check page offers to open at the nearest milestone reached
// when the goal is not: the same opening after the same confirmation, never
// the default, absent when nothing is reached or when the goal is.
import 'package:deskilo/core/demo/data/local_setup_repository.dart';
import 'package:deskilo/features/workspace/domain/launch_review.dart';
import 'package:deskilo/features/workspace/domain/setup_status.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_launch_screen.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

/// Goal = invoice; `bookable` is reached or not, `invoice` never is.
SetupStatus _status({required bool bookableReached}) => SetupStatus.fromJson({
  'steps': [
    {
      'step': 'places',
      'milestone': 'bookable',
      'required': true,
      'state': bookableReached ? 'ready' : 'needs_configuration',
      'route': '/editor',
    },
    {
      'step': 'invoicing',
      'milestone': 'invoice',
      'required': true,
      'state': 'needs_configuration',
      'route': '/money/sales',
    },
  ],
  'milestones': [
    {
      'milestone': 'bookable',
      'applies': true,
      'required': 1,
      'ready': bookableReached ? 1 : 0,
      'reached': bookableReached,
    },
    {
      'milestone': 'invoice',
      'applies': true,
      'required': 1,
      'ready': 0,
      'reached': false,
    },
  ],
});

Future<List<String>> _pump(
  WidgetTester tester,
  SetupStatus status, {
  bool testSpace = true,
}) async {
  final pushed = <String>[];
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SetupLaunchScreen()),
      for (final path in ['/editor', '/money/sales', '/deployment'])
        GoRoute(
          path: path,
          builder: (_, _) {
            pushed.add(path);
            return const Scaffold();
          },
        ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          localSetup: FakeLocalSetupRepository(status: status),
        ),
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

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final lower = find.byKey(const ValueKey('setup-launch-open-lower'));

  test('the rule: the highest milestone reached with nothing stopping it', () {
    expect(
      LaunchReview.from(_status(bookableReached: true))
          .openableBelowGoal
          ?.status
          .milestone,
      'bookable',
    );
    expect(
      LaunchReview.from(_status(bookableReached: false)).openableBelowGoal,
      isNull,
    );
  });

  testWidgets('goal not reached, a lower milestone reached: the action names '
      'it, asks first, and opens the same deployment', (tester) async {
    final pushed = await _pump(tester, _status(bookableReached: true));
    expect(lower, findsOneWidget);
    expect(
      find.text(l10n.setupLaunchOpenLower(l10n.setupMilestoneName('bookable'))),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('setup-launch-go-live')), findsNothing);

    await tester.tap(lower);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setup-launch-confirm-no')));
    await tester.pumpAndSettle();
    expect(pushed, isEmpty);

    await tester.tap(lower);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setup-launch-confirm-yes')));
    await tester.pumpAndSettle();
    expect(pushed, ['/deployment']);
  });

  testWidgets('nothing reached: no such action', (tester) async {
    await _pump(tester, _status(bookableReached: false));
    expect(lower, findsNothing);
  });

  testWidgets('a space that is already live is not offered it', (tester) async {
    await _pump(tester, _status(bookableReached: true), testSpace: false);
    expect(lower, findsNothing);
  });
}
