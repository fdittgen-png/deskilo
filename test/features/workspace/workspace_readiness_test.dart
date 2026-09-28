// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1636 — the settings name the next thing between a space and a first
// booking, list every section with its state, open where each is set
// up, and say nothing at all when the Get started help is switched off.
import 'package:deskilo/core/demo/data/local_setup_repository.dart';
import 'package:deskilo/core/instance/schema_compatibility.dart';
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
  int? serverSchema,
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
      recorder('/server'),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          localSetup: repo,
          schemaVersion: serverSchema == null
              ? null
              : FixedSchemaVersionSource(serverSchema),
        ),
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
    expect(
      find.text('All sections (2 of 5 ready)'),
      findsOneWidget,
      reason: 'the server runs this build\'s schema, so the backend is ready',
    );
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

  test('0295 words: who acts, why, and what is not applicable', () {
    final s = ReadinessSection.listFromJson([
      {
        'section': 'roles_validation',
        'state': 'needs_configuration',
        'required': true,
        'actor': 'owner',
        'reason': 'too_few_validators',
        'route': '/validation',
      },
      {
        'section': 'roles_validation',
        'state': 'not_applicable',
        'reason': 'no_policies',
      },
      {'section': 'recovery', 'state': 'unverified', 'actor': 'operator'},
      {'section': 'recovery', 'state': 'unavailable'},
      {'section': 'resources', 'state': 'needs_operator', 'required': true},
    ]);
    expect(s.map((e) => e.state), [
      ReadinessState.needsConfiguration,
      ReadinessState.notApplicable,
      ReadinessState.unverified,
      ReadinessState.unavailable,
      ReadinessState.needsOperator,
    ]);
    expect(s[0].area, ReadinessArea.rolesValidation);
    expect(s[0].reason, 'too_few_validators');
    expect(s[0].blocking, isTrue);
    expect(s[1].applicable, isFalse);
    expect(s[2].actor, ReadinessActor.operator);
    expect(s[3].actor, ReadinessActor.owner, reason: 'owner unless named');
    expect(s[3].blocking, isFalse);
    expect(s[4].blocking, isTrue, reason: 'an operator step still blocks');
    final used = ReadinessSection.listFromJson([
      {'section': 'first_booking', 'state': 'needs_configuration', 'route': '/reserve'},
    ]).single;
    expect(used.area, ReadinessArea.firstBooking);
    expect(used.blocking, isFalse, reason: 'being used is never a prerequisite');
  });

  test('0301 words: recovery evidence is a recorded export, recent or stale',
      () {
    final s = ReadinessSection.listFromJson([
      {
        'section': 'recovery',
        'state': 'ready',
        'actor': 'operator',
        'required': false,
        'reason': 'recent_export',
        'recorded_at': '2026-09-01T10:00:00+00:00',
        'route': '/workspace-settings',
      },
      {
        'section': 'recovery',
        'state': 'unverified',
        'actor': 'operator',
        'reason': 'stale_export',
        'recorded_at': '2026-05-01T10:00:00+00:00',
        'route': '/workspace-settings',
      },
      {
        'section': 'recovery',
        'state': 'unverified',
        'reason': 'no_evidence',
        'recorded_at': null,
        'route': '/workspace-settings',
      },
    ]);
    expect(s[0].state, ReadinessState.ready);
    expect(s[0].reason, 'recent_export');
    expect(s[0].recordedAt, DateTime.utc(2026, 9, 1, 10));
    expect(s[0].actor, ReadinessActor.operator);
    expect(s[0].blocking, isFalse);
    expect(s[1].state, ReadinessState.unverified);
    expect(s[1].reason, 'stale_export');
    expect(s[1].blocking, isFalse, reason: 'stale evidence is shown, not demanded');
    expect(s[2].recordedAt, isNull);
    expect(readinessReasonLabel(null, 'recent_export'),
        'A recent export is on record');
    expect(readinessReasonLabel(null, 'stale_export'),
        'The last recorded export is more than 90 days old');
  });

  test('the backend section follows the app\'s own schema check', () {
    expect(
      backendReadiness(SchemaCompatibility.current).state,
      ReadinessState.ready,
    );
    expect(
      backendReadiness(SchemaCompatibility.ahead).state,
      ReadinessState.ready,
    );
    final behind = backendReadiness(SchemaCompatibility.behind);
    expect(behind.state, ReadinessState.needsOperator);
    expect(behind.actor, ReadinessActor.operator);
    expect(behind.blocking, isTrue);
    for (final silent in [SchemaCompatibility.unknown, null]) {
      expect(backendReadiness(silent).state, ReadinessState.unverified);
      expect(
        backendReadiness(silent).blocking,
        isFalse,
        reason: 'offline is not a missing setup',
      );
    }
  });

  testWidgets('a server behind this build is the operator\'s blocker', (
    tester,
  ) async {
    final pushed = await _pump(
      tester,
      FakeLocalSetupRepository(readinessSections: _sections(seats: true)),
      serverSchema: requiredSchemaVersion - 1,
    );
    expect(
      find.text('Before a first booking: Server and database version'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('workspace-readiness-all')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('workspace-readiness-backend')),
        matching: find.textContaining('Who: The server operator'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('workspace-readiness-next')));
    await tester.pumpAndSettle();
    expect(pushed, ['/server']);
  });

  testWidgets('a policy nobody can satisfy says why; none is not counted', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeLocalSetupRepository(
        readinessSections: [
          ..._sections(seats: true),
          const ReadinessSection(
            area: ReadinessArea.rolesValidation,
            state: ReadinessState.notApplicable,
            required: false,
            route: '/validation',
            reason: 'no_policies',
          ),
        ],
      ),
    );
    expect(
      find.text('All sections (3 of 5 ready)'),
      findsOneWidget,
      reason: 'a section with nothing to set up is not a section to finish',
    );
    await tester.tap(find.byKey(const ValueKey('workspace-readiness-all')));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('workspace-readiness-rolesValidation'));
    expect(
      find.descendant(
        of: row,
        matching: find.text(
          'Not needed here · No request waits for a validator',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.byType(TextButton)),
      findsNothing,
    );
  });

  testWidgets('assistant access waits on an administrator, never on a booking',
      (tester) async {
    final assistant = ReadinessSection.listFromJson([
      {
        'section': 'assistant',
        'state': 'needs_operator',
        'required': false,
        'actor': 'administrator',
        'reason': 'eligibility_requested',
        'route': '/assistants',
      },
    ]).single;
    expect(assistant.area, ReadinessArea.assistant);
    expect(assistant.actor, ReadinessActor.administrator);
    expect(assistant.blocking, isFalse);
    await _pump(
      tester,
      FakeLocalSetupRepository(
        readinessSections: [..._sections(seats: true), assistant],
      ),
    );
    expect(
      find.text('Ready for a first booking'),
      findsOneWidget,
      reason: 'native use does not wait for assistant access',
    );
    await tester.tap(find.byKey(const ValueKey('workspace-readiness-all')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('workspace-readiness-assistant')),
        matching: find.text(
          'Waiting for someone else · Needed later · '
          'Your request waits for a database administrator · '
          'Who: A database administrator',
        ),
      ),
      findsOneWidget,
    );
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
