// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2578 (C1) -- many figures in one read. A thirteen-period series is one
// read, not thirteen; the total and the compared period share it; a period
// the server could not answer is a gap and never a zero or a failure of the
// others; a refusal of the reader refuses everything; the fan-out for
// single-figure repositories keeps the same contract.
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/workspace/data/fan_out_batch_reader.dart';
import 'package:deskilo/features/workspace/domain/bi_batch.dart';
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/providers/bi_providers.dart';
import 'package:deskilo/features/workspace/providers/kpi_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SeatCapacityKpi _seat(num reserved, num offered, {List<String> quality = const []}) =>
    seatCapacityFromJson({
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
      'quality': quality,
      'reasons': const <String>[],
      'history_since': '2026-01-01T00:00:00Z',
      'computed_at': '2026-03-15T10:00:00Z',
    });

class _Reader implements KpiBatchReader {
  _Reader(this.answer);

  final BiBatchEntry Function(BiBatchRequest r) answer;
  final calls = <List<BiBatchRequest>>[];

  @override
  Future<List<BiBatchEntry>> read(String workspaceId, List<BiBatchRequest> requests) async {
    calls.add(requests);
    return [for (final r in requests) answer(r)];
  }
}

class _Seats implements KpiRepository {
  @override
  Future<SeatCapacityKpi> seatCapacity(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
    String? levelId,
  }) async {
    if (from.month == 2) throw const KpiUnavailable('no history');
    if (from.month == 3) throw const KpiForbidden();
    return _seat(10, 40);
  }
}

ProviderContainer _container(KpiBatchReader reader) => ProviderContainer(
  overrides: [
    biBatchReaderProvider.overrideWithValue(reader),
    clockProvider.overrideWithValue(FixedClock(DateTime(2026, 3, 15, 12))),
  ],
);

void main() {
  test('thirteen months are one read, oldest first, and the running month is provisional', () async {
    final reader = _Reader((r) => BiBatchEntry.seat(r.key, _seat(30, 100)));
    final container = _container(reader);
    addTearDown(container.dispose);
    final series = await container.read(
      biModuleSeriesProvider(
        'ws',
        'capacity.seat_utilisation',
        BiGrain.month,
        const BiPeriod(BiGrain.month, 2026, 3),
        13,
      ).future,
    );
    expect(reader.calls, hasLength(1), reason: 'one read for the whole series');
    expect(reader.calls.single, hasLength(13));
    expect(series.points, hasLength(13));
    expect(series.points.last.partial, isTrue);
    expect(series.points.first.partial, isFalse);
    expect(series.points.first.value, closeTo(0.3, 1e-9));
  });

  test('a period the server could not answer is a gap; the others keep their figures', () async {
    final reader = _Reader(
      (r) => r.key == '11'
          ? BiBatchEntry.failed(r.key, code: '22023', message: 'bad period')
          : BiBatchEntry.seat(r.key, _seat(20, 80)),
    );
    final container = _container(reader);
    addTearDown(container.dispose);
    final series = await container.read(
      biModuleSeriesProvider(
        'ws',
        'capacity.seat_utilisation',
        BiGrain.month,
        const BiPeriod(BiGrain.month, 2026, 3),
        13,
      ).future,
    );
    expect(series.points[11].value, isNull);
    expect(series.points[10].value, closeTo(0.25, 1e-9));
    expect(series.points[12].value, closeTo(0.25, 1e-9));
  });

  test('the module result asks once for the period and the compared period', () async {
    final reader = _Reader((r) => BiBatchEntry.seat(r.key, _seat(r.key.startsWith('0') ? 30 : 20, 100)));
    final container = _container(reader);
    addTearDown(container.dispose);
    final result = await container.read(
      biModuleResultProvider(
        'ws',
        'capacity.seat_utilisation',
        const BiQueryContext(comparison: BiComparison.previousPeriod),
      ).future,
    );
    expect(reader.calls, hasLength(1));
    expect(reader.calls.single.map((r) => r.key), ['0:0', '1:0']);
    expect(result.total.current.numerator, 30);
    expect(result.total.compared!.numerator, 20);
  });

  test('a failed request fails the module result with its reason, never a zero', () async {
    final reader = _Reader((r) => BiBatchEntry.failed(r.key, code: '22023', message: 'too long'));
    final container = _container(reader);
    addTearDown(container.dispose);
    await expectLater(
      container.read(
        biModuleResultProvider(
          'ws',
          'capacity.seat_utilisation',
          const BiQueryContext(),
        ).future,
      ),
      throwsA(isA<KpiUnavailable>()),
    );
  });

  test('the fan-out answers each request on its own and keeps the order', () async {
    final reader = FanOutBatchReader(_Seats());
    BiBatchRequest at(int month) => BiBatchRequest.capacity(
      key: 'm$month',
      from: DateTime.utc(2026, month),
      to: DateTime.utc(2026, month + 1),
    );
    await expectLater(
      reader.read('ws', [at(1), at(2)]).then(
        (e) => [for (final x in e) '${x.key}:${x.ok}'],
      ),
      completion(['m1:true', 'm2:false']),
    );
  });

  test('a refusal of the reader refuses the whole fan-out, not one gap', () async {
    final reader = FanOutBatchReader(_Seats());
    await expectLater(
      reader.read('ws', [
        BiBatchRequest.capacity(key: 'a', from: DateTime.utc(2026), to: DateTime.utc(2026, 2)),
        BiBatchRequest.capacity(key: 'm3', from: DateTime.utc(2026, 3), to: DateTime.utc(2026, 4)),
      ]),
      throwsA(isA<KpiForbidden>()),
    );
  });

  test('a request names only what the server accepts', () {
    final capacity = BiBatchRequest.capacity(
      key: 'k',
      from: DateTime.utc(2026, 9),
      to: DateTime.utc(2026, 10),
      levelId: 'l1',
    ).toJson();
    expect(capacity.keys, containsAll(['request_key', 'metric_id', 'from', 'to', 'level_id']));
    expect(capacity.containsKey('from_month'), isFalse);
    final finance = const BiBatchRequest.finance(
      key: 'f',
      metricId: 'finance.invoiced',
      fromMonth: '2026-08',
      toMonth: '2026-09',
    ).toJson();
    expect(finance, {
      'request_key': 'f',
      'metric_id': 'finance.invoiced',
      'from_month': '2026-08',
      'to_month': '2026-09',
    });
  });
}
