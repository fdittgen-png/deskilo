// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The limits a member books within — how many places at once, how far
// ahead, the shortest and the longest booking — written key by key into
// booking_rules, every other rule kept. Only a limit that changed is sent,
// so a save never turns the server's own default into a stored value. The
// setup guide's limits step saves through this class; the availability
// screen writes each limit as it is picked.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/booking_policies.dart';
import '../domain/booking_rules_repository.dart';
import '../providers/workspace_providers.dart';

part 'save_booking_limits.g.dart';

class SaveBookingLimits {
  const SaveBookingLimits(this._rules);
  final BookingRulesRepository _rules;

  /// Stores the limits of [to] that differ from [from] for [workspaceId].
  /// A shortest booking longer than the longest would refuse every booking,
  /// and the server compares each bound on its own, so it is refused here
  /// before anything is sent. Throws whatever the repository throws.
  Future<void> save(
    String workspaceId, {
    required BookingPolicies from,
    required BookingPolicies to,
  }) async {
    if (!to.durationsAreCoherent) {
      throw ArgumentError.value(
        to.minDurationMinutes,
        'minDurationMinutes',
        'longer than the longest booking',
      );
    }
    if (to.simultaneousReservations != from.simultaneousReservations) {
      await _rules.setSimultaneousReservations(
        workspaceId,
        to.simultaneousReservations,
      );
    }
    for (final (key, before, after) in [
      (
        BookingPolicies.advanceHorizonDaysKey,
        from.advanceHorizonDays,
        to.advanceHorizonDays,
      ),
      (
        BookingPolicies.minDurationMinutesKey,
        from.minDurationMinutes,
        to.minDurationMinutes,
      ),
      (
        BookingPolicies.maxDurationMinutesKey,
        from.maxDurationMinutes,
        to.maxDurationMinutes,
      ),
    ]) {
      if (before != after) {
        await _rules.setBookingLimit(workspaceId, key, after);
      }
    }
  }
}

/// The booking limits' write.
@riverpod
SaveBookingLimits saveBookingLimits(Ref ref) =>
    SaveBookingLimits(ref.watch(workspaceRepositoryProvider));
