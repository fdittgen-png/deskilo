// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2869 (0545) — the guide's own actions on a step: an optional step is
// set aside for later and comes back with Undo, a step the server cannot
// verify is marked done, and a required step the server verifies offers
// neither — it has to be set up.
import 'package:deskilo/core/demo/data/local_setup_repository.dart';
import 'package:deskilo/features/workspace/domain/setup_status.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_guide_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Map<String, Object?> _step(
  String id, {
  required bool required,
  String state = 'needs_configuration',
  bool manual = false,
}) => {
  'step': id,
  'milestone': 'bookable',
  'required': required,
  'state': state,
  'route': '/workspace-settings',
  'manual': manual,
};

final _status = SetupStatus.fromJson({
  'steps': [
    _step('places', required: true),
    _step('services', required: false),
    _step('new_members', required: false, manual: true),
  ],
  'milestones': [
    {
      'milestone': 'bookable',
      'applies': true,
      'required': 1,
      'ready': 0,
      'reached': false,
    },
  ],
});

Future<FakeLocalSetupRepository> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository = FakeLocalSetupRepository(status: _status);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(localSetup: repository),
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SetupGuideScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('setup-guide-optional')));
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('an optional step is set aside for later, and Undo brings it '
      'back', (tester) async {
    final repository = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('setup-step-later-services')));
    await tester.pumpAndSettle();
    expect(repository.stepCalls, ['ack:services']);
    expect(find.byKey(const ValueKey('setup-guide-deferred')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('setup-guide-deferred')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setup-step-undo-services')));
    await tester.pumpAndSettle();
    expect(repository.stepCalls, ['ack:services', 'clear:services']);
    expect(find.byKey(const ValueKey('setup-guide-deferred')), findsNothing);
  });

  testWidgets('a step the server cannot verify is marked done', (tester) async {
    final repository = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('setup-step-done-new_members')));
    await tester.pumpAndSettle();
    expect(repository.stepCalls, ['ack:new_members']);
    expect(
      repository.status.steps.firstWhere((s) => s.step == 'new_members').state,
      SetupStepState.ready,
    );
  });

  testWidgets('a required step the server verifies offers no way around it', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byKey(const ValueKey('setup-step-later-places')), findsNothing);
    expect(find.byKey(const ValueKey('setup-step-done-places')), findsNothing);
  });

  testWidgets('the guide says how long the next milestone still takes', (
    tester,
  ) async {
    await _pump(tester);
    // Only the required open step counts: places, at its default 5 min.
    expect(find.byKey(const ValueKey('setup-guide-until')), findsOneWidget);
    expect(find.textContaining('About 5 min until'), findsOneWidget);
  });
}
