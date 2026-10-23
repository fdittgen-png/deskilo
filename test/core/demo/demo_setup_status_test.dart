// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2872 — the demo spaces show the setup guide at two ends: Pézenas has
// reached every milestone it chose, Leipzig is half way to its first
// booking and names what is next.
import 'package:deskilo/core/demo/seed/demo_flags.dart';
import 'package:deskilo/core/demo/seed/demo_setup_status.dart';
import 'package:deskilo/features/workspace/domain/setup_status.dart';
import 'package:deskilo/features/workspace/domain/setup_steps.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Pézenas has reached every milestone it chose', () {
    final s = demoSetupStatus(
      demoFeatureFlags,
      ready: {for (final step in setupSteps) step.id},
    );
    expect(s.nextMilestone, isNull);
    expect(s.milestones.where((m) => m.applies), isNotEmpty);
  });

  test('Leipzig is half way to bookings: member rights come next', () {
    final s = demoSetupStatus(
      demoSecondSpaceFeatureFlags,
      ready: demoSecondSpaceReadySteps,
    );
    expect(s.nextMilestone?.milestone, 'bookable');
    expect(s.nextStep?.step, 'member_rights');
    final first = s.steps.singleWhere((x) => x.step == 'first_booking');
    expect(first.state, SetupStepState.blocked);
    expect(first.blockedBy, ['member_rights']);
    expect(
      s.steps.singleWhere((x) => x.step == 'vat').state,
      SetupStepState.notApplicable,
      reason: 'a new space has no VAT',
    );
  });
}
