// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4223 — the steps that exist for places are the steps whose feature is
// `placeBooking` or needs it (or governs bookings); a business whose kind keeps
// places off is not offered them, in the list or under "Add more", and every
// other step stays. Nothing is written.
import 'package:deskilo/features/workspace/domain/setup_status.dart';
import 'package:deskilo/features/workspace/domain/setup_steps.dart';
import 'package:deskilo/features/workspace/domain/setup_steps_for_kind.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the steps for places are those of places, the kiosk and badges, a '
      'first booking of a place and the booking limits', () {
    expect(
      setupStepsNeedingPlaces,
      containsAll(['places', 'kiosk', 'limits', 'pricing']),
    );
    expect(
      [for (final s in setupSteps) if (s.alsoNeeds != null) s.id],
      ['pricing'],
      reason: 'the second feature is named on the pricing step alone (0815)',
    );
    for (final id in setupStepsNeedingPlaces) {
      final step = setupSteps.firstWhere((s) => s.id == id);
      expect(step.feature, isNotNull, reason: id);
    }
    // what a practice still does is not among them
    for (final id in ['basics', 'services', 'invite', 'member_rights']) {
      expect(setupStepsNeedingPlaces, isNot(contains(id)), reason: id);
    }
    expect(
      setupSteps
          .where((s) => s.feature == WorkspaceFeature.invoicing)
          .map((s) => s.id),
      everyElement(isNot(isIn(setupStepsNeedingPlaces))),
    );
  });

  test('a status without those steps keeps every other step and the server\'s '
      'milestones', () {
    final status = SetupStatus.fromJson({
      'steps': [
        for (final id in ['basics', 'places', 'kiosk', 'services'])
          {
            'step': id,
            'milestone': 'bookable',
            'required': id == 'basics',
            'state': 'needs_configuration',
            'route': '/setup/step/$id',
          },
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
    final shown = status.withoutSteps(setupStepsNeedingPlaces);
    expect(shown.steps.map((s) => s.step), ['basics', 'services']);
    expect(shown.milestones, status.milestones);
    expect(status.steps, hasLength(4), reason: 'the original is unchanged');
  });
}
