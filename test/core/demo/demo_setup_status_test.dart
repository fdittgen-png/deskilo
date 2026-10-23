// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2872 — the demo spaces show the setup guide at two ends, read from what
// each space's fixture holds: Pézenas has every step that applies to it,
// Leipzig takes bookings and has not yet set its prices. The levels and
// the acknowledgements are each space's own.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/seed/demo_second_space_seed.dart';
import 'package:deskilo/features/workspace/domain/local_setup.dart';
import 'package:deskilo/features/workspace/domain/setup_level_change.dart';
import 'package:deskilo/features/workspace/domain/setup_levels.dart';
import 'package:deskilo/features/workspace/domain/setup_status.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/local_setup_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The demo's setup repository over a fresh [fixture], as the guide reads it.
LocalSetupRepository _guideOver(DemoFixture fixture) {
  final container = ProviderContainer(overrides: demoOverrides(fixture));
  addTearDown(container.dispose);
  return container.read(localSetupRepositoryProvider);
}

SetupStepState _state(SetupStatus s, String step) =>
    s.steps.singleWhere((x) => x.step == step).state;

void main() {
  test('Pézenas holds every step that applies to it', () async {
    final s = await _guideOver(DemoFixture.build()).setupStatus('ws-1');
    expect(
      {
        for (final x in s.steps)
          if (x.state != SetupStepState.notApplicable &&
              x.state != SetupStepState.ready)
            x.step: x.state,
      },
      isEmpty,
    );
    expect(s.nextMilestone, isNull);
    expect(s.milestones.where((m) => m.applies), hasLength(4));
    expect(
      _state(s, 'assistant'),
      SetupStepState.notApplicable,
      reason: 'the demo has no assistant endpoint',
    );
  });

  test('Leipzig takes bookings, and its prices come next', () async {
    final s = await _guideOver(DemoFixture.build())
        .setupStatus(demoSecondSpaceId);
    final reached = {
      for (final m in s.milestones)
        if (m.applies) m.milestone: m.reached,
    };
    expect(reached, {
      'bookable': true,
      'money': false,
      'invoice': false,
      'live': false,
    });
    expect(s.nextMilestone?.milestone, 'money');
    expect(s.nextStep?.step, 'pricing');
    final payment = s.steps.singleWhere((x) => x.step == 'payment_methods');
    expect(payment.state, SetupStepState.blocked);
    expect(payment.blockedBy, ['pricing']);
    expect(
      _state(s, 'first_booking'),
      SetupStepState.ready,
      reason: 'members already book in Leipzig',
    );
    expect(
      _state(s, 'vat'),
      SetupStepState.notApplicable,
      reason: 'a small business exempt from VAT has no VAT step',
    );
  });

  test('a level changed in Leipzig is Leipzig\'s, and its guide follows', () async {
    final fixture = DemoFixture.build();
    final guide = _guideOver(fixture);
    Set<WorkspaceFeature> on(String id) => resolveEnabledFeatures(
      fixture.workspaces.workspaces.singleWhere((w) => w.id == id).featureFlags,
    );
    final pezenas = currentSetupLevels(on('ws-1'));
    expect(_state(await guide.setupStatus(demoSecondSpaceId), 'kiosk'),
        SetupStepState.notApplicable);

    // The kiosk belongs to the measured bookings level.
    final change = planSetupLevels(
      stored: on(demoSecondSpaceId),
      current: currentSetupLevels(on(demoSecondSpaceId)),
      chosen: {
        ...currentSetupLevels(on(demoSecondSpaceId)),
        SetupProcess.bookings: 'measured',
      },
    );
    await fixture.secondSpace.workspaces.setFeatureFlags(
      demoSecondSpaceId,
      change.flags,
      expected: change.expected,
    );

    expect(currentSetupLevels(on(demoSecondSpaceId))[SetupProcess.bookings],
        'measured');
    expect(currentSetupLevels(on('ws-1')), pezenas,
        reason: 'Pézenas keeps its own levels');
    expect(
      _state(await guide.setupStatus(demoSecondSpaceId), 'kiosk'),
      SetupStepState.needsConfiguration,
      reason: 'the kiosk now applies, and Leipzig has no tablet yet',
    );
  });

  test('Later and Mark as done are each space\'s own, and refused where the '
      'server refuses them', () async {
    final guide = _guideOver(DemoFixture.build());
    await guide.acknowledgeStep(demoSecondSpaceId, 'recovery');
    await guide.acknowledgeStep(demoSecondSpaceId, 'new_members');
    var leipzig = await guide.setupStatus(demoSecondSpaceId);
    expect(_state(leipzig, 'recovery'), SetupStepState.deferred);
    expect(_state(leipzig, 'new_members'), SetupStepState.ready);
    final pezenas = await guide.setupStatus('ws-1');
    expect(_state(pezenas, 'recovery'), SetupStepState.ready);

    await guide.clearStepAcknowledgement(demoSecondSpaceId, 'new_members');
    leipzig = await guide.setupStatus(demoSecondSpaceId);
    expect(_state(leipzig, 'new_members'), SetupStepState.needsConfiguration);
    expect(_state(leipzig, 'recovery'), SetupStepState.deferred);

    await expectLater(
      guide.acknowledgeStep(demoSecondSpaceId, 'pricing'),
      throwsStateError,
      reason: 'a required step the server verifies cannot be set aside',
    );
    await expectLater(
      guide.acknowledgeStep('ws-1', 'recovery'),
      throwsStateError,
      reason: 'a step with nothing left to do cannot be set aside',
    );
  });

  test('a reset starts the guide over', () async {
    final guide = _guideOver(DemoFixture.build());
    await guide.acknowledgeStep(demoSecondSpaceId, 'recovery');
    final fresh = _guideOver(DemoFixture.build());
    expect(
      _state(await fresh.setupStatus(demoSecondSpaceId), 'recovery'),
      SetupStepState.needsConfiguration,
    );
  });
}
