// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3102 (PERF-9) — the upcoming bookings were read for the window
// `now … now + 7 days`, so every read asked for a window nobody had asked
// for before and wrote one more cache file. The window is now whole days:
// reads within one day ask for the same window, and still return only
// what starts after now.
import 'package:deskilo/core/demo/data/reservation_repository.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _ws = Workspace(
  id: 'ws-a',
  name: 'ws-a',
  countryCode: 'DE',
  currencyCode: 'EUR',
  timezone: 'Europe/Berlin',
  inviteCode: 'GOODCODE22',
);

const _me = Member(
  id: 'member-1',
  workspaceId: 'ws-a',
  userId: 'user-1',
  isAdmin: false,
  isOwner: false,
  status: MemberStatus.active,
);

class _Clock implements Clock {
  DateTime instant = DateTime.utc(2026, 10, 31, 9);
  @override
  DateTime now() => instant;
}

class _Windows extends FakeReservationRepository {
  final windows = <(DateTime, DateTime)>{};

  @override
  Future<List<Reservation>> fetchWindow(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  }) {
    windows.add((from, to));
    return super.fetchWindow(workspaceId, from: from, to: to);
  }
}

void main() {
  test('10 reads in one day ask for one window', () async {
    final clock = _Clock();
    final repo = _Windows();
    final c = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(clock),
        reservationRepositoryProvider.overrideWithValue(repo),
        currentWorkspaceProvider.overrideWith((ref) async => _ws),
        myMemberProvider.overrideWith((ref) async => _me),
      ],
    );
    addTearDown(c.dispose);
    for (var i = 0; i < 10; i++) {
      clock.instant = clock.instant.add(const Duration(minutes: 7));
      c.invalidate(myUpcomingReservationsProvider);
      await c.read(myUpcomingReservationsProvider.future);
    }
    expect(repo.windows, hasLength(1));
  });
}
