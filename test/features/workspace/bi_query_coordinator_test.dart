// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2578 — the query coordinator: each distinct figure is computed once, a
// caller's requests leave together, nothing is kept after the answer, and a
// failure reaches every waiter.
import 'dart:async';

import 'package:deskilo/features/workspace/data/bi_query_coordinator.dart';
import 'package:deskilo/features/workspace/domain/bi_batch.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:flutter_test/flutter_test.dart';

FinanceSummaryKpi _fin(String month) => financeSummaryFromJson({
  'from': month,
  'to': month,
  'currency': 'EUR',
  'invoiced_minor': '100',
  'credit_notes_minor': '0',
  'collected_minor': '50',
  'invoices': 1,
  'matches': 1,
  'quality': const <String>[],
  'reasons': const <String>[],
  'last_change_at': '2026-03-14T09:00:00Z',
  'computed_at': '2026-03-15T10:00:00Z',
});

BiBatchRequest _req(
  String key,
  String month, {
  String metric = 'finance.invoiced',
}) => BiBatchRequest.finance(
  key: key,
  metricId: metric,
  fromMonth: month,
  toMonth: month,
);

class _Reader implements KpiBatchReader {
  final calls = <List<BiBatchRequest>>[];
  Exception? failWith;
  Completer<void>? hold;

  @override
  Future<List<BiBatchEntry>> read(
    String workspaceId,
    List<BiBatchRequest> requests,
  ) async {
    calls.add(requests);
    await hold?.future;
    if (failWith != null) throw failWith!;
    return [
      for (final r in requests) BiBatchEntry.finance(r.key, _fin(r.fromMonth!)),
    ];
  }
}

/// One full turn of the event loop: the coordinator's flush has run.
Future<void> _turn() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test('callers of one turn leave in one batch, each figure once', () async {
    final inner = _Reader();
    final c = BiQueryCoordinator(inner);
    final a = c.read('w', [_req('0', '2026-01'), _req('1', '2026-02')]);
    final b = c.read('w', [_req('x', '2026-02'), _req('y', '2026-03')]);
    final ra = await a;
    final rb = await b;
    expect(inner.calls, hasLength(1));
    expect(inner.calls.single, hasLength(3), reason: '2026-02 asked once');
    expect([for (final e in ra) e.key], ['0', '1']);
    expect([for (final e in rb) e.key], ['x', 'y']);
    expect(rb.first.financeSummary!.fromMonth, '2026-02');
    expect(c.batchesSent, 1);
  });

  test('a figure in flight is awaited, not asked again', () async {
    final inner = _Reader()..hold = Completer<void>();
    final c = BiQueryCoordinator(inner);
    final first = c.read('w', [_req('0', '2026-01')]);
    await _turn();
    final second = c.read('w', [_req('k', '2026-01'), _req('j', '2026-04')]);
    await _turn();
    inner.hold!.complete();
    expect((await first).single.key, '0');
    expect([for (final e in await second) e.key], ['k', 'j']);
    expect(inner.calls, hasLength(2));
    expect(inner.calls.last.map((r) => r.fromMonth), ['2026-04']);
  });

  test('nothing is kept: the same figure later is asked again', () async {
    final inner = _Reader();
    final c = BiQueryCoordinator(inner);
    await c.read('w', [_req('0', '2026-01')]);
    await c.read('w', [_req('0', '2026-01')]);
    expect(inner.calls, hasLength(2));
  });

  test('another workspace or metric is another figure', () async {
    final inner = _Reader();
    final c = BiQueryCoordinator(inner);
    await Future.wait([
      c.read('w1', [_req('0', '2026-01')]),
      c.read('w2', [_req('0', '2026-01')]),
      c.read('w1', [_req('0', '2026-01', metric: 'finance.collected')]),
    ]);
    expect(inner.calls, hasLength(2), reason: 'w1 batch and w2 batch');
    expect(inner.calls.expand((x) => x), hasLength(3));
  });

  test('a refusal reaches every waiter of the batch', () async {
    final inner = _Reader()..failWith = const KpiForbidden();
    final c = BiQueryCoordinator(inner);
    final a = c.read('w', [_req('0', '2026-01')]);
    final b = c.read('w', [_req('0', '2026-02')]);
    await expectLater(a, throwsA(isA<KpiForbidden>()));
    await expectLater(b, throwsA(isA<KpiForbidden>()));
    inner.failWith = null;
    expect(
      (await c.read('w', [_req('0', '2026-01')])).single.ok,
      isTrue,
      reason: 'a failure is not remembered',
    );
  });

  test('callers are packed whole under the batch bound', () async {
    final inner = _Reader();
    final c = BiQueryCoordinator(inner);
    String m(int i) =>
        '${2000 + i ~/ 12}-${(i % 12 + 1).toString().padLeft(2, '0')}';
    final a = c.read('w', [for (var i = 0; i < 40; i++) _req('$i', m(i))]);
    final b = c.read('w', [for (var i = 20; i < 80; i++) _req('$i', m(i))]);
    await Future.wait([a, b]);
    expect(
      inner.calls.length,
      2,
      reason: '40 + 40 new would be 80, over the bound of 60',
    );
  });
}
