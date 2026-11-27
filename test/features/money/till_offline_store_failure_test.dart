// SPDX-License-Identifier: AGPL-3.0-or-later
// #4492 (row 5): a sale exists once or not at all. A sale the device could not store was not made (the till says so and the
// cashier rings it up again): it must not stay in the queue's memory and be sent later beside the second one. And the numbers
// the server finds missing in one session are still said when another session was sent after it.
import 'package:deskilo/features/money/domain/till_offline.dart';
import 'package:deskilo/features/money/domain/till_offline_queue.dart';
import 'package:flutter_test/flutter_test.dart';

class _Store implements OfflineStore {
  String? text;

  /// How many of the next writes fail.
  int failWrites = 0;
  @override
  Future<String?> read() async => text;
  @override
  Future<void> write(String json) async {
    if (failWrites > 0) {
      failWrites--;
      throw StateError('the device store did not write');
    }
    text = json;
  }

  @override
  Future<void> wipe() async => text = null;
}

class _Port implements TillOfflinePort {
  final List<OfflineSale> sent = [];
  final Map<String, List<int>> gapsOf = {};
  @override
  Future<OfflineSyncAnswer> sync(String workspaceId, {required String sessionId, required DateTime offlineSince, required List<OfflineSale> sales, required int minorDigits}) async {
    sent.addAll(sales);
    return OfflineSyncAnswer(
      results: [
        for (final s in sales) OfflineSaleResult(seq: s.seq, requestId: s.requestId, accepted: true, reason: '', number: 'R-${s.seq}', replayed: false),
      ],
      gaps: gapsOf[sessionId] ?? const [],
    );
  }

  @override
  Future<OfflineList> list(String workspaceId, {required String sessionId}) async => const OfflineList(sales: [], gaps: []);
}

void main() {
  var n = 0;
  final t0 = DateTime.utc(2026, 11, 27, 7);
  const bread = OfflinePrice(itemId: 'bread', name: 'Baguette', unit: 'piece', grossMinor: 120);
  const basket = [OfflineBasketLine(itemId: 'bread', quantity: '1')];

  Future<TillOfflineQueue> ready(_Store store) async {
    final q = TillOfflineQueue(store: store, newRequestId: () => 'req-${++n}');
    await q.cachePrices(const [bread]);
    await q.goOffline(sessionId: 's1', now: t0);
    return q;
  }

  test('a sale the device could not store is not queued: rung up again, one sale is sent, under the number the first would have had', () async {
    final store = _Store();
    final q = await ready(store);
    store.failWrites = 1;
    await expectLater(q.record(basket: basket, cashGivenMinor: 200, now: t0), throwsStateError);
    expect(q.pending, isEmpty, reason: 'the till showed no sale: nothing waits to be sent');
    expect(q.pendingKeptMinor, 0, reason: 'and no cash is counted as kept for it');

    final again = await q.record(basket: basket, cashGivenMinor: 200, now: t0);
    expect(again.seq, 1, reason: 'the number of a sale that was never made is not skipped');
    final port = _Port();
    await q.sync(port, workspaceId: 'w', minorDigits: 2);
    expect([for (final s in port.sent) s.requestId], [again.requestId], reason: 'one basket, one sale on the server');
  });

  test('what the device holds after a failed store is what a restart reads: the sale is in neither', () async {
    final store = _Store();
    final q = await ready(store);
    await q.record(basket: basket, cashGivenMinor: 120, now: t0);
    store.failWrites = 1;
    await expectLater(q.record(basket: basket, cashGivenMinor: 120, now: t0), throwsStateError);

    final restarted = TillOfflineQueue(store: store, newRequestId: () => 'req-${++n}');
    await restarted.load();
    await restarted.goOffline(sessionId: 's1', now: t0);
    expect([for (final s in restarted.pending) s.seq], [for (final s in q.pending) s.seq]);
    expect(q.pending, hasLength(1));
  });

  test('the numbers missing in one session are still said after another session was sent', () async {
    final store = _Store();
    final q = await ready(store);
    await q.record(basket: basket, cashGivenMinor: 120, now: t0);
    await q.goOffline(sessionId: 's2', now: t0);
    await q.record(basket: basket, cashGivenMinor: 120, now: t0);
    final port = _Port()..gapsOf['s1'] = [3];
    final answer = await q.sync(port, workspaceId: 'w', minorDigits: 2);
    expect(port.sent, hasLength(2));
    expect(answer!.gaps, [3], reason: 'the second session had no gap; the first one\'s is not dropped by its answer');
  });
}
