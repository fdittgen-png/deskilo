// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3102 (PERF-6) — the warm-up behind the splash, counted in round trips.
// Every read below waits until the test releases it; a round releases
// everything in flight together, so the number of rounds is the depth of
// the warm-up's dependency chain. The workspace list and the remembered
// choice are independent, and so are the levels and the rest of the hub's
// data; only the floor plan needs the levels. Three rounds, not four, and
// the day's bookings are asked for in the first round after the workspace.
import 'dart:async';

import 'package:deskilo/app/boot.dart';
import 'package:deskilo/core/cache/cache_store.dart';
import 'package:deskilo/core/demo/data/stores.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/features/plan/providers/floor_plan_providers.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
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

/// Reads in flight, each released by the test, by what was read.
final _inFlight = <(String, void Function())>[];

Future<T> _trip<T>(String what, T value) {
  final done = Completer<T>();
  _inFlight.add((what, () => done.complete(value)));
  return done.future;
}

class _Active extends ActiveWorkspaceId {
  @override
  Future<String?> build() => _trip('active', 'ws-a');
}

void main() {
  test('the warm-up is three round trips deep', () async {
    _inFlight.clear();
    final c = ProviderContainer(
      overrides: [
        cacheStoreProvider.overrideWithValue(InMemoryCacheStore()),
        authStateProvider.overrideWith((ref) => Stream.value('user-1')),
        myWorkspacesProvider.overrideWith(
          (ref) => _trip('workspaces', const [_ws]),
        ),
        activeWorkspaceIdProvider.overrideWith(_Active.new),
        levelsProvider.overrideWith(
          (ref) => _trip('levels', const [
            Level(id: 'l1', workspaceId: 'ws-a', name: 'L1', sortOrder: 0),
          ]),
        ),
        floorPlanProvider.overrideWith(
          (ref, id) => _trip(
            'plan',
            FloorPlan(
              levelId: id,
              offices: const [],
              desks: const [],
              seats: const [],
            ),
          ),
        ),
        reservationsForDayProvider.overrideWith(
          (ref, day) => _trip('day', const []),
        ),
        myMemberProvider.overrideWith((ref) => _trip<Member?>('member', null)),
        bookingGranularityProvider.overrideWith(
          (ref) => _trip('granularity', BookingGranularity.flexible),
        ),
      ],
    );
    addTearDown(c.dispose);
    // The app listens to the session from its root; a provider nobody
    // listens to is paused (Riverpod 3), and its stream never arrives.
    final auth = c.listen(authStateProvider, (_, _) {});
    addTearDown(auth.close);
    var warmed = false;
    final boot = c.listen(bootReadyProvider, (_, next) {
      if (!next.isLoading) warmed = true;
    });
    addTearDown(boot.close);
    final rounds = <List<String>>[];
    while (!warmed && rounds.length < 10) {
      await pumpEventQueue();
      if (_inFlight.isEmpty) continue;
      final round = List.of(_inFlight);
      _inFlight.clear();
      rounds.add([for (final (what, _) in round) what]..sort());
      for (final (_, release) in round) {
        release();
      }
    }
    expect(warmed, isTrue);
    expect(rounds, [
      ['active', 'workspaces'],
      ['day', 'granularity', 'levels', 'member'],
      ['plan'],
    ]);
  });
}
