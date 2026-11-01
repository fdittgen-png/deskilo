// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2578 — what the client asks the server for, on the edges: an evolution
// whose periods cross both Paris clock changes and a leap day asks for
// bounds that meet exactly; a floor that exists only in the history is not
// asked for but never lost (it is the remainder); two workspaces that reuse
// the same local ids are never confused by the coordinator.
import 'dart:async';

import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/features/plan/providers/floor_plan_providers.dart';
import 'package:deskilo/features/workspace/data/bi_query_coordinator.dart';
import 'package:deskilo/features/workspace/domain/bi_batch.dart';
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/domain/bi_result.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/providers/bi_providers.dart';
import 'package:deskilo/features/workspace/providers/kpi_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SeatCapacityKpi _seat(num reserved, num offered) => seatCapacityFromJson({
  'seats': 5,
  'physical_seat_hours': 1000,
  'offered_seat_hours': offered,
  'reserved_seat_hours': reserved,
  'reserved_outside_offered_seat_hours': 0,
  'overlapping_seat_hours': 0,
  'rooms_without_seats': 0,
  'offered_room_hours': 0,
  'reserved_room_hours': 0,
  'from': '2026-01-01T00:00:00Z',
  'to': '2026-02-01T00:00:00Z',
  'quality': const <String>[],
  'reasons': const <String>[],
  'history_since': '2026-01-01T00:00:00Z',
  'computed_at': '2026-03-15T10:00:00Z',
});

class _Reader implements KpiBatchReader {
  _Reader(this.answer);

  final BiBatchEntry Function(String workspaceId, BiBatchRequest r) answer;
  final calls = <List<BiBatchRequest>>[];
  Completer<void>? hold;

  @override
  Future<List<BiBatchEntry>> read(
    String workspaceId,
    List<BiBatchRequest> requests,
  ) async {
    calls.add(requests);
    await hold?.future;
    return [for (final r in requests) answer(workspaceId, r)];
  }
}

ProviderContainer _container(KpiBatchReader reader) => ProviderContainer(
  overrides: [
    biBatchReaderProvider.overrideWithValue(reader),
    clockProvider.overrideWithValue(FixedClock(DateTime.utc(2030))),
  ],
);

Future<List<BiBatchRequest>> _askedBySeries(
  BiPeriod end,
  int count,
  BiGrain grain,
) async {
  final reader = _Reader((_, r) => BiBatchEntry.seat(r.key, _seat(1, 2)));
  final container = _container(reader);
  addTearDown(container.dispose);
  await container.read(
    biModuleSeriesProvider(
      'ws',
      'capacity.seat_utilisation',
      grain,
      end,
      count,
    ).future,
  );
  return reader.calls.single;
}

void main() {
  setUp(() => WorkspaceTime.install('Europe/Paris'));
  tearDown(WorkspaceTime.reset);

  group('series bounds', () {
    test('March to October in one series: both clock changes, no gap and no '
        'overlap between neighbours', () async {
      final asked = await _askedBySeries(
        const BiPeriod(BiGrain.month, 2026, 10),
        8,
        BiGrain.month,
      );
      expect(asked.first.from!.toUtc(), DateTime.utc(2026, 2, 28, 23));
      expect(asked.last.to!.toUtc(), DateTime.utc(2026, 10, 31, 23));
      for (var i = 1; i < asked.length; i++) {
        expect(asked[i].from, asked[i - 1].to, reason: 'period $i');
      }
      final hours = [for (final r in asked) r.to!.difference(r.from!).inHours];
      expect(hours[0], 31 * 24 - 1, reason: 'March 2026 loses an hour');
      expect(hours[7], 31 * 24 + 1, reason: 'October 2026 gains an hour');
    });

    test('a leap February is 29 days between its neighbours', () async {
      final asked = await _askedBySeries(
        const BiPeriod(BiGrain.month, 2028, 3),
        3,
        BiGrain.month,
      );
      expect(asked[1].from!.toUtc(), DateTime.utc(2028, 1, 31, 23));
      expect(asked[1].to!.toUtc(), DateTime.utc(2028, 2, 29, 23));
      expect(asked[1].to!.difference(asked[1].from!).inDays, 29);
      expect(asked[2].from, asked[1].to);
    });

    test('a common February is 28 days', () async {
      final asked = await _askedBySeries(
        const BiPeriod(BiGrain.month, 2027, 2),
        1,
        BiGrain.month,
      );
      expect(asked.single.to!.difference(asked.single.from!).inDays, 28);
    });

    test('quarters and years of a leap year meet at the same instants', () {
      final q = [
        for (var i = 1; i <= 4; i++)
          biInterval(BiPeriod(BiGrain.quarter, 2028, i)),
      ];
      final year = biInterval(const BiPeriod(BiGrain.year, 2028, 1));
      expect(q.first.from, year.from);
      expect(q.last.to, year.to);
      for (var i = 1; i < q.length; i++) {
        expect(q[i].from, q[i - 1].to);
      }
      expect(
        q.first.to.difference(q.first.from).inHours,
        91 * 24 - 1,
        reason: 'Q1 2028: 91 days, the March change takes an hour',
      );
    });
  });

  group('a floor that exists only in the history', () {
    test('is not asked for, and its share stays in the remainder', () async {
      // The total covers the whole period, including a floor that was
      // closed since; the groups are today's floors only.
      final reader = _Reader(
        (_, r) => BiBatchEntry.seat(
          r.key,
          r.levelId == null ? _seat(50, 100) : _seat(20, 40),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          biBatchReaderProvider.overrideWithValue(reader),
          clockProvider.overrideWithValue(FixedClock(DateTime.utc(2030))),
          levelsProvider.overrideWith(
            (ref) async => const [
              Level(id: 'now', workspaceId: 'ws', name: 'Today', sortOrder: 0),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);
      final result = await container.read(
        biModuleResultProvider(
          'ws',
          'capacity.seat_utilisation',
          const BiQueryContext(groupBy: 'level'),
        ).future,
      );
      expect(reader.calls.single.map((r) => r.levelId), [
        null,
        'now',
      ], reason: 'the closed floor is not a request');
      expect(result.groups.map((g) => g.key), ['now', BiRow.remainderKey]);
      final rest = result.groups.last.current;
      expect(rest.numerator, 30);
      expect(rest.denominator, 60);
      expect(rest.reasons, contains('outside_current_groups'));
    });
  });

  group('two workspaces with the same local ids', () {
    BiBatchRequest level(String key) => BiBatchRequest.capacity(
      key: key,
      from: DateTime.utc(2026, 2, 28, 23),
      to: DateTime.utc(2026, 3, 31, 22),
      levelId: 'lv-1',
    );

    SeatCapacityKpi seatOf(BiBatchEntry e) => e.seatCapacity!;

    test('asked in the same turn, each gets its own answer', () async {
      final inner = _Reader(
        (ws, r) => BiBatchEntry.seat(
          r.key,
          ws == 'W-A' ? _seat(10, 100) : _seat(90, 100),
        ),
      );
      final c = BiQueryCoordinator(inner, batchMax: () => 60);
      final both = await Future.wait([
        c.read('W-A', [level('0')]),
        c.read('W-B', [level('0')]),
      ]);
      expect(inner.calls, hasLength(2), reason: 'one batch per workspace');
      expect(seatOf(both[0].single).reservedSeatHours, 10);
      expect(seatOf(both[1].single).reservedSeatHours, 90);
    });

    test('a figure in flight for one is not awaited by the other', () async {
      final inner = _Reader(
        (ws, r) => BiBatchEntry.seat(
          r.key,
          ws == 'W-A' ? _seat(10, 100) : _seat(90, 100),
        ),
      );
      final hold = inner.hold = Completer<void>();
      final c = BiQueryCoordinator(inner, batchMax: () => 60);
      final a = c.read('W-A', [level('0')]);
      await Future<void>.delayed(Duration.zero);
      final b = c.read('W-B', [level('0')]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(
        inner.calls,
        hasLength(2),
        reason: 'W-B asked while W-A in flight',
      );
      hold.complete();
      expect(seatOf((await a).single).reservedSeatHours, 10);
      expect(seatOf((await b).single).reservedSeatHours, 90);
    });
  });
}
