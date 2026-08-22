// SPDX-License-Identifier: 0BSD
//
// #586 — the member's default reservation period: the choices derive
// from the workspace's booking configuration, the pick persists per
// workspace, and a stale preference is ignored once the configuration
// stops offering it.
import 'package:deskilo/features/reservations/domain/default_booking_period.dart';
import 'package:deskilo/features/reservations/providers/default_period_controller.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

void main() {
  test('the offered choices follow the workspace configuration', () {
    for (final dayBased in [
      BookingGranularity.halfDay,
      BookingGranularity.hours,
    ]) {
      expect(defaultPeriodChoicesFor(dayBased),
          DefaultBookingPeriod.values,
          reason: '$dayBased offers the canonical windows');
    }
    // Full-day: every booking IS the full day — nothing to choose.
    expect(defaultPeriodChoicesFor(BookingGranularity.fullDay), isEmpty);
    for (final free in [
      BookingGranularity.flexible,
      BookingGranularity.minutes5,
      BookingGranularity.minutes30,
    ]) {
      expect(defaultPeriodChoicesFor(free), isEmpty,
          reason: '$free picks freely — no day-window preference');
    }
  });

  test('defaultWindowFor maps the preference onto the canonical '
      'windows; no preference keeps the historical full day', () {
    final day = DateTime(2026, 5, 13);
    final morning = defaultWindowFor(DefaultBookingPeriod.morning, day);
    final afternoon =
        defaultWindowFor(DefaultBookingPeriod.afternoon, day);
    final full = defaultWindowFor(DefaultBookingPeriod.fullDay, day);
    final none = defaultWindowFor(null, day);
    expect(morning.end, afternoon.start);
    expect(full.start, morning.start);
    expect(full.end, afternoon.end);
    expect(none.start, full.start);
    expect(none.end, full.end);
  });

  test('the controller persists per workspace and drops a preference '
      'the current configuration no longer offers', () async {
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..bookingGranularities['ws-1'] = BookingGranularity.halfDay;
    final store = InMemoryDefaultPeriodStore();
    // The workspace resolution chain (auth stream → memberships →
    // active id) needs a pumping widget tree; pin it directly — this
    // test is about the CONTROLLER.
    final container = ProviderContainer(overrides: [
      ...standardTestOverrides(
        workspace: workspace,
        defaultPeriod: store,
      ),
      currentWorkspaceProvider.overrideWith(
        (ref) async => (await workspace.fetchMyWorkspaces()).first,
      ),
    ]);
    addTearDown(container.dispose);

    expect(await container.read(defaultPeriodProvider.future), isNull);

    await container
        .read(defaultPeriodProvider.notifier)
        .select(DefaultBookingPeriod.morning);
    expect(store.values['ws-1'], 'morning');
    expect(await container.read(defaultPeriodProvider.future),
        DefaultBookingPeriod.morning);

    // The owner reconfigures to a minute grid: the stored preference
    // no longer applies and reads back as null instead of leaking a
    // morning window into a 5-minute-grid booking.
    workspace.bookingGranularities['ws-1'] = BookingGranularity.minutes5;
    container
      ..invalidate(bookingGranularityProvider)
      ..invalidate(defaultPeriodProvider);
    expect(await container.read(defaultPeriodProvider.future), isNull);
    // The stored value survives untouched for a config roll-back.
    expect(store.values['ws-1'], 'morning');
  });

  test('the wire form survives unknown input', () {
    expect(DefaultBookingPeriod.fromWire('morning'),
        DefaultBookingPeriod.morning);
    expect(DefaultBookingPeriod.fromWire('full_day'),
        DefaultBookingPeriod.fullDay);
    expect(DefaultBookingPeriod.fromWire('wat'), isNull);
    expect(DefaultBookingPeriod.fromWire(null), isNull);
  });
}
