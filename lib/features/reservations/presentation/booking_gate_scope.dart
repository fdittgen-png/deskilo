// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/booking_gate.dart';

/// #814 — the [BookingGate] of the active workspace from the live
/// providers, or null while the feature is off (every surface then
/// leaves the refusal to the server, as before). [watch] rebuilds the
/// caller when a parameter changes; callbacks read once.
BookingGate? bookingGateOf(WidgetRef ref, {bool watch = false}) {
  final features = watch
      ? ref.watch(enabledFeaturesSyncProvider)
      : ref.read(enabledFeaturesSyncProvider);
  if (!features.contains(WorkspaceFeature.bookingGate)) return null;
  final weekdays = watch
      ? ref.watch(openWeekdaysProvider).value
      : ref.read(openWeekdaysProvider).value;
  final closures = watch
      ? ref.watch(closureDaysProvider).value
      : ref.read(closureDaysProvider).value;
  final policies = watch
      ? ref.watch(bookingPoliciesProvider).value
      : ref.read(bookingPoliciesProvider).value;
  final granularity = watch
      ? ref.watch(bookingGranularityProvider).value
      : ref.read(bookingGranularityProvider).value;
  final hours = watch
      ? ref.watch(workHoursProvider).value
      : ref.read(workHoursProvider).value;
  final clock = watch ? ref.watch(clockProvider) : ref.read(clockProvider);
  // #1580 — while any of them is unresolved there is NO gate, rather
  // than a gate built out of invented values.
  //
  // The substitutes read as harmless and were not. `WorkHours.defaults`
  // is 08:00–17:00: in a space that opens at 07:00 it refused a legal
  // booking, and in one that closes at 22:00 it offered an illegal one —
  // so the same line produced both a false refusal and a false
  // permission, and "the server stays the authority" only covered the
  // second. A member cannot tell a real refusal from a placeholder.
  //
  // Null already means "this surface has no opinion, the server
  // decides", which is what every caller does when the feature is off,
  // and it is the truthful answer for "not loaded yet" too. Surfaces
  // that show availability ASK [bookingDataPending] and say they are
  // checking, instead of showing an answer they do not have.
  if (weekdays == null ||
      closures == null ||
      policies == null ||
      granularity == null ||
      hours == null) {
    return null;
  }
  return BookingGate(
    openWeekdays: weekdays,
    closures: closures,
    policies: policies,
    granularity: granularity,
    hours: hours,
    now: clock.now(),
  );
}

/// #1580 — the gate is switched on for this workspace but its data has
/// not all arrived.
///
/// Distinct from a null gate, which also covers "the feature is off":
/// off means there is nothing to wait for, pending means there is.
bool bookingDataPending(WidgetRef ref, {bool watch = false}) {
  final features = watch
      ? ref.watch(enabledFeaturesSyncProvider)
      : ref.read(enabledFeaturesSyncProvider);
  if (!features.contains(WorkspaceFeature.bookingGate)) return false;
  return !(watch
            ? ref.watch(openWeekdaysProvider)
            : ref.read(openWeekdaysProvider))
          .hasValue ||
      !(watch ? ref.watch(closureDaysProvider) : ref.read(closureDaysProvider))
          .hasValue ||
      !(watch
              ? ref.watch(bookingPoliciesProvider)
              : ref.read(bookingPoliciesProvider))
          .hasValue ||
      !(watch
              ? ref.watch(bookingGranularityProvider)
              : ref.read(bookingGranularityProvider))
          .hasValue ||
      !(watch ? ref.watch(workHoursProvider) : ref.read(workHoursProvider))
          .hasValue;
}
