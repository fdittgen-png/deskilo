// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1636 — the settings name the next thing between a space and a first
// booking, list every section with its state, open where each is set
// up, and say nothing at all when the Get started help is switched off.
import 'package:deskilo/core/demo/data/local_setup_repository.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_readiness.dart';
import 'package:deskilo/features/workspace/presentation/widgets/workspace_readiness_card.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

List<ReadinessSection> _sections({bool seats = false}) => [
  const ReadinessSection(
    area: ReadinessArea.regionRules,
    state: ReadinessState.ready,
    required: true,
    route: '/availability',
  ),
  ReadinessSection(
    area: ReadinessArea.resources,
    state: seats ? ReadinessState.ready : ReadinessState.needsConfiguration,
    required: true,
    route: '/editor',
  ),
  const ReadinessSection(
    area: ReadinessArea.pricing,
    state: ReadinessState.needsConfiguration,
    required: false,
    route: '/billing',
  ),
  const ReadinessSection(
    area: ReadinessArea.recovery,
    state: ReadinessState.unverified,
    required: false,
    route: '/workspace-settings',
  ),
];

Future<List<String>> _pump(
  WidgetTester tester,
  FakeLocalSetupRepository repo, {
  Set<WorkspaceFeature>? features,
}) async {
  final pushed = <String>[];
  GoRoute recorder(String path) => GoRoute(
    path: path,
    builder: (_, _) {
      pushed.add(path);
      return const Scaffold();
    },
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(
          body: SingleChildScrollView(
            child: WorkspaceReadinessCard(workspaceId: 'ws'),
          ),
        ),
      ),
      recorder('/editor'),
      recorder('/billing'),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(localSetup: repo),
        if (features != null)
          enabledFeaturesSyncProvider.overrideWithValue(features),
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
  test('sections read the server words; only in-app routes survive', () {
    final s = ReadinessSection.listFromJson([
      {
        'section': 'resources',
        'state': 'needs_configuration',
        'required': true,
        'route': '/editor',
      },
      {'section': 'recovery', 'state': 'unverified', 'route': 'https://x'},
      {'section': 'weird', 'state': 'ready'},
      {
        'section': 'local_setup',
        'state': 'needs_configuration',
        'route': '/einvoice-config',
      },
    ]);
    expect(s.map((e) => e.area), [
      ReadinessArea.resources,
      ReadinessArea.recovery,
      ReadinessArea.unknown,
      ReadinessArea.localSetup,
    ]);
    expect(s.last.blocking, isFalse,
        reason: 'local setup never blocks a first booking');
    expect(s.last.route, '/einvoice-config');
    expect(s[0].blocking, isTrue);
    expect(s[1].required, isFalse);
    expect(s[1].route, '/workspace-settings');
  });

  test('the next step is a blocker first, never an unverified section', () {
    expect(nextReadinessStep(_sections())?.area, ReadinessArea.resources);
    expect(
      nextReadinessStep(_sections(seats: true))?.area,
      ReadinessArea.pricing,
    );
    expect(
      nextReadinessStep(const [
        ReadinessSection(
          area: ReadinessArea.recovery,
          state: ReadinessState.unverified,
          required: false,
          route: '/workspace-settings',
        ),
      ]),
      isNull,
    );
  });

  testWidgets('a blocker is named first and opens where it is set up', (
    tester,
  ) async {
    final pushed = await _pump(
      tester,
      FakeLocalSetupRepository(readinessSections: _sections()),
    );
    expect(
      find.text('Before a first booking: Bookable places on the floor plan'),
      findsOneWidget,
    );
    expect(find.text('All sections (1 of 4 ready)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('workspace-readiness-next')));
    await tester.pumpAndSettle();
    expect(pushed, ['/editor']);
  });

  testWidgets('no blocker left: ready for a first booking, then the rest', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeLocalSetupRepository(readinessSections: _sections(seats: true)),
    );
    expect(find.text('Ready for a first booking'), findsOneWidget);
    expect(find.text('Next: Membership plans and tariffs'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('workspace-readiness-all')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('workspace-readiness-recovery')),
      findsOneWidget,
    );
    expect(find.textContaining('Not verified yet'), findsOneWidget);
  });

  testWidgets('switched off with the Get started help, it shows nothing', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeLocalSetupRepository(readinessSections: _sections()),
      features: const {WorkspaceFeature.moneyTab},
    );
    expect(find.byKey(const ValueKey('workspace-readiness')), findsNothing);
  });

  testWidgets('nothing answered, nothing shown', (tester) async {
    await _pump(tester, FakeLocalSetupRepository());
    expect(find.byKey(const ValueKey('workspace-readiness')), findsNothing);
  });
}
