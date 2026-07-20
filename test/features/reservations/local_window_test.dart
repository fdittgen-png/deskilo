// SPDX-License-Identifier: MIT
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_reservation_repository.dart';

const _workspace = Workspace(
  id: 'ws-1',
  name: 'Test Space',
  countryCode: 'DE',
  currencyCode: 'EUR',
  timezone: 'Europe/Berlin',
  inviteCode: 'GOODCODE22',
);

class _WindowRecorder extends FakeReservationRepository {
  DateTime? from;
  DateTime? to;

  @override
  Future<List<Reservation>> fetchWindow(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  }) {
    this.from = from;
    this.to = to;
    return super.fetchWindow(workspaceId, from: from, to: to);
  }
}

void main() {
  // #119: the July calendar in a UTC+2 zone queried June because the keys
  // and windows went through UTC. Keys and windows are LOCAL wall-clock.
  test('month key comes from local date components', () {
    expect(monthKeyOf(DateTime(2026, 7, 1)), '2026-07');
    expect(monthKeyOf(DateTime(2026, 12, 31, 23, 59)), '2026-12');
  });

  test('day key comes from local date components', () {
    expect(dayKeyOf(DateTime(2026, 7, 9, 0, 30)), '2026-07-09');
    expect(dayKeyOf(DateTime(2026, 7, 9, 23, 45)), '2026-07-09');
  });

  test('the month window is the local month, not the UTC month', () async {
    final repo = _WindowRecorder();
    final container = ProviderContainer(
      overrides: [
        reservationRepositoryProvider.overrideWithValue(repo),
        currentWorkspaceProvider.overrideWith((ref) async => _workspace),
      ],
    );
    addTearDown(container.dispose);

    await container.read(reservationsForMonthProvider('2026-07').future);

    expect(repo.from, DateTime(2026, 7, 1));
    expect(repo.to, DateTime(2026, 8, 1));
  });

  test('the day window is the local day', () async {
    final repo = _WindowRecorder();
    final container = ProviderContainer(
      overrides: [
        reservationRepositoryProvider.overrideWithValue(repo),
        currentWorkspaceProvider.overrideWith((ref) async => _workspace),
      ],
    );
    addTearDown(container.dispose);

    await container.read(reservationsForDayProvider('2026-07-09').future);

    expect(repo.from, DateTime(2026, 7, 9));
    expect(repo.to, DateTime(2026, 7, 10));
  });

  group('dayKeysForWindow', () {
    test('a window inside one local day touches a single key', () {
      final start = DateTime(2026, 7, 20, 9);
      final end = DateTime(2026, 7, 20, 13);
      expect(dayKeysForWindow(start, end), ['2026-07-20']);
    });

    test('a full workspace-day window straddling the local midnight touches '
        'BOTH keys (the Reserve-hub miss)', () {
      // A full day stored as Jul 20 00:00 Europe/Paris = Jul 19 22:00Z →
      // Jul 20 22:00Z. In a UTC test env dayKeyOf(start) is the 19th, so a
      // single-key read (dayKeyOf(start)) would miss the 20th's bookings.
      final start = DateTime.utc(2026, 7, 19, 22);
      final end = DateTime.utc(2026, 7, 20, 22);
      expect(dayKeysForWindow(start, end), ['2026-07-19', '2026-07-20']);
    });

    test('the end boundary is exclusive — a window ending at midnight does '
        'not spill into the next day', () {
      final start = DateTime(2026, 7, 20);
      final end = DateTime(2026, 7, 21); // exactly next local midnight
      expect(dayKeysForWindow(start, end), ['2026-07-20']);
    });
  });
}
