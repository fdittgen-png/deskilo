// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3102 (PERF-9) — one booking made on this device: the write refreshes
// the day's bookings at once, and the realtime echo of the same write
// must not fetch them a second time. An echo after the window, and a
// resync, still refresh. Counted on the demo reservation repository.
import 'dart:async';

import 'package:deskilo/app/realtime_invalidations.dart';
import 'package:deskilo/core/demo/data/reservation_repository.dart';
import 'package:deskilo/core/realtime/invalidation_map.dart';
import 'package:deskilo/core/realtime/realtime_providers.dart';
import 'package:deskilo/core/realtime/realtime_sync.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/core/ui/app_durations.dart';
import 'package:deskilo/features/events/providers/event_providers.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/widgets.dart';
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

class _Sync implements RealtimeSync {
  final feed = StreamController<String>();
  @override
  Stream<String> watch(String workspaceId) => feed.stream;
  @override
  Stream<String> watchAccount() => const Stream.empty();
}

class _Clock implements Clock {
  DateTime instant = DateTime.utc(2026, 10, 31, 9);
  @override
  DateTime now() => instant;
}

class _Counting extends FakeReservationRepository {
  int windows = 0;
  @override
  Future<List<Reservation>> fetchWindow(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  }) {
    windows++;
    return super.fetchWindow(workspaceId, from: from, to: to);
  }
}

void main() {
  late _Sync sync;
  late _Clock clock;
  late _Counting repo;
  late WidgetRef widgetRef;

  Future<void> start(WidgetTester tester) async {
    sync = _Sync();
    clock = _Clock();
    repo = _Counting();
    final container = ProviderContainer(
      overrides: [
        ...realtimeWiringFromApp,
        ...realtimeSyncOverrides(sync),
        clockProvider.overrideWithValue(clock),
        reservationRepositoryProvider.overrideWithValue(repo),
        currentWorkspaceProvider.overrideWith((ref) async => _ws),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            widgetRef = ref;
            ref
              ..watch(realtimeInvalidatorProvider(RealtimeTarget.workspace))
              ..watch(reservationsForDayProvider('2026-10-31'));
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    repo.windows = 0;
  }

  Future<void> echo(WidgetTester tester, String table, Duration after) async {
    clock.instant = clock.instant.add(after);
    sync.feed.add(table);
    await tester.pump(kRealtimeDebounce + const Duration(milliseconds: 10));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('one booking: one fetch of the day, not two', (tester) async {
    await start(tester);
    invalidateBookingData(widgetRef);
    await tester.pump();
    await tester.pump();
    await echo(tester, 'reservations', const Duration(milliseconds: 400));
    expect(repo.windows, 1);
  });

  testWidgets('an echo after the window, or a resync, still refreshes', (
    tester,
  ) async {
    await start(tester);
    invalidateBookingData(widgetRef);
    await tester.pump();
    await tester.pump();
    await echo(tester, 'reservations', AppDurations.ownEchoWindow);
    expect(repo.windows, 2);
    invalidateBookingData(widgetRef);
    await tester.pump();
    await tester.pump();
    await echo(tester, kResyncSignal, Duration.zero);
    expect(repo.windows, 4);
  });
}
