// SPDX-License-Identifier: 0BSD
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../../core/time/work_hours.dart';
import '../../workspace/domain/booking_granularity.dart';
import '../../workspace/domain/booking_policies.dart';
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
  return BookingGate(
    // Unknown while loading counts as open — the server stays the
    // authority, exactly as the hub's closed-day banner reads it.
    openWeekdays: weekdays ?? const [1, 2, 3, 4, 5, 6, 7],
    closures: closures ?? const [],
    policies: policies ?? const BookingPolicies(),
    granularity: granularity ?? BookingGranularity.flexible,
    hours: hours ?? WorkHours.defaults,
    now: clock.now(),
  );
}
