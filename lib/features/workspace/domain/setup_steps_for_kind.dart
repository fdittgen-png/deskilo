// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4223 — a business whose primary kind keeps places off (a practice, a
// salon) is not offered the steps that exist for places: the places
// themselves, the kiosk and badges, a first booking of a place. They are the
// steps whose feature is `placeBooking` or needs it. They come back when the
// business is of a kind that has places, or places are switched on; nothing is
// written and no stored choice is removed. Pure Dart.
import 'setup_status.dart';
import 'setup_steps.dart';
import 'workspace_feature.dart';

/// The ids of the catalogue's steps that exist for places.
final Set<String> setupStepsNeedingPlaces = {
  for (final step in setupSteps)
    if (step.feature case final feature?
        when feature == WorkspaceFeature.placeBooking ||
            feature == WorkspaceFeature.bookingPolicies ||
            requirementChain(feature).contains(WorkspaceFeature.placeBooking))
      step.id,
};

extension SetupStatusForKind on SetupStatus {
  /// This status without [ids] (the steps a business is not offered); the
  /// milestones are the server's own and stay as they are.
  SetupStatus withoutSteps(Set<String> ids) => SetupStatus(
    steps: [
      for (final s in steps)
        if (!ids.contains(s.step)) s,
    ],
    milestones: milestones,
  );
}
