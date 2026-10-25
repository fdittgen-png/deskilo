// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2578 — every BI module is described by ONE metric definition: its
// version, unit, aggregation, date basis and coverage come from the KPI
// catalogue that the server's `kpi_registry()` copies, so the card, the
// batch answer and a saved view cannot each believe something else. A
// batched answer that names another version, unit, date basis or coverage
// than this client knows is incompatible, never a figure.
import 'dart:convert';

import 'package:deskilo/features/workspace/domain/bi_batch.dart';
import 'package:deskilo/features/workspace/domain/bi_modules.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _seatJson() => {
  'seats': 5,
  'physical_seat_hours': 1000,
  'offered_seat_hours': 120,
  'reserved_seat_hours': 20,
  'reserved_outside_offered_seat_hours': 0,
  'overlapping_seat_hours': 0,
  'rooms_without_seats': 0,
  'offered_room_hours': 0,
  'reserved_room_hours': 0,
  'from': '2026-01-01T00:00:00Z',
  'to': '2026-02-01T00:00:00Z',
  'quality': const <String>[],
  'reasons': const <String>[],
  'computed_at': '2026-03-15T10:00:00Z',
};

/// The answer the server gives for [metric]: the registry's own metadata.
Map<String, Object?> _answer(
  String metric, {
  Map<String, Object?> result = const {},
  Map<String, Object?> override = const {},
  bool ok = true,
}) {
  final d = kpiDefinitionOf(metric)!;
  return {
    'request_key': 'k',
    'metric_id': metric,
    'metric_version': d.version,
    'unit': d.unit,
    'date_basis': d.dateBasis.wire,
    'coverage': d.coverage.wire,
    'ok': ok,
    if (ok) 'result': result,
    if (!ok) 'code': '22023',
    ...override,
  };
}

final _capacity = BiBatchRequest.capacity(
  key: 'k',
  from: DateTime.utc(2026),
  to: DateTime.utc(2026, 2),
);

void main() {
  group('every module has its metric', () {
    for (final m in biModules) {
      test(m.id, () {
        final d = kpiDefinitionOf(m.id);
        expect(d, isNotNull, reason: 'a module shows a catalogued metric');
        expect(m.metric, same(d));
        expect(m.aggregation, d!.aggregation);
        expect(
          {for (final p in m.permissions) p.wireName},
          d.permissions.toSet(),
          reason: 'the module asks for what the server registry asks for',
        );
        expect(d.version, greaterThan(0));
        expect(d.unit, isNotEmpty);
      });
    }
  });

  test('collected is dated by the match, never by the bank', () {
    expect(
      kpiDefinitionOf('finance.collected')!.dateBasis,
      KpiDateBasis.paymentMatchedAt,
    );
    expect(
      kpiDefinitionOf('finance.invoiced')!.dateBasis,
      KpiDateBasis.invoiceMonth,
    );
  });

  test('a past period is labelled by what the source keeps', () {
    expect(
      kpiDefinitionOf('capacity.seat_utilisation')!.coverage,
      KpiCoverage.recordedHistory,
    );
    expect(
      kpiDefinitionOf('finance.invoiced')!.coverage,
      KpiCoverage.currentRecords,
    );
    for (final k in kpiCatalogue) {
      if (k.dateBasis == KpiDateBasis.currentState) {
        expect(k.coverage, KpiCoverage.currentStateOnly, reason: k.id);
      }
    }
  });

  test('the wire names are distinct and stable', () {
    expect(
      {for (final d in KpiDateBasis.values) d.wire}.length,
      KpiDateBasis.values.length,
    );
    expect(
      {for (final c in KpiCoverage.values) c.wire}.length,
      KpiCoverage.values.length,
    );
    expect(
      [for (final a in KpiAggregation.values) a.wire],
      ['ratio_of_sums', 'sum', 'last_at_cutoff'],
    );
  });

  test('the server registry carries the descriptor of every metric', () {
    final registry = jsonDecode(kpiRegistryJson()) as Map<String, dynamic>;
    expect(registry.keys.toSet(), {for (final k in kpiCatalogue) k.id});
    final seat = registry['capacity.seat_utilisation'] as Map;
    expect(seat['unit'], 'percent');
    expect(seat['aggregation'], 'ratio_of_sums');
    expect(seat['date_basis'], 'reservation_time');
    expect(seat['coverage'], 'recorded_history');
  });

  group('a batched answer', () {
    test('asks for the version this client knows', () {
      expect(_capacity.toJson()['metric_version'], 1);
    });

    test('of the known metric is the figure', () {
      final e = biBatchEntryFromJson(
        _capacity,
        _answer(_capacity.metricId, result: _seatJson()),
      );
      expect(e.ok, isTrue);
      expect(e.seatCapacity!.reservedSeatHours, 20);
    });

    for (final (field, value) in [
      ('metric_version', 2),
      ('unit', 'hours'),
      ('date_basis', 'invoice_month'),
      ('coverage', 'current_records'),
    ]) {
      test('with another $field is incompatible, never a figure', () {
        final e = biBatchEntryFromJson(
          _capacity,
          _answer(
            _capacity.metricId,
            result: _seatJson(),
            override: {field: value},
          ),
        );
        expect(e.ok, isFalse);
        expect(e.toError(), isA<KpiIncompatible>());
      });
    }

    test('from a server that names no descriptor stays readable', () {
      // A server before the descriptors echoed only the version.
      final e = biBatchEntryFromJson(_capacity, {
        'request_key': 'k',
        'metric_id': _capacity.metricId,
        'metric_version': 1,
        'ok': true,
        'result': _seatJson(),
      });
      expect(e.ok, isTrue);
    });

    test('that failed on its own keeps its own failure', () {
      final e = biBatchEntryFromJson(
        _capacity,
        _answer(_capacity.metricId, ok: false),
      );
      expect(e.ok, isFalse);
      expect(e.code, '22023');
      expect(e.toError(), isNot(isA<KpiIncompatible>()));
    });

    test('that is missing is a failure, never a zero', () {
      expect(biBatchEntryFromJson(_capacity, null).ok, isFalse);
    });
  });
}
