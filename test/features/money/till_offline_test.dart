// SPDX-License-Identifier: AGPL-3.0-or-later
// #4373 (CS11): the till's offline queue — totals from the cached prices, a gapless sequence per session, the refusals the device
// makes itself, sending in order under the same request ids, a failed connection losing nothing, and what is stored.
import 'package:deskilo/features/money/domain/till_offline.dart';
import 'package:deskilo/features/money/domain/till_offline_queue.dart';
import 'package:flutter_test/flutter_test.dart';

class _Mem implements OfflineStore {
  String? text;
  int wipes = 0;
  @override
  Future<String?> read() async => text;
  @override
  Future<void> write(String json) async => text = json;
  @override
  Future<void> wipe() async {
    text = null;
    wipes++;
  }
}

class _Port implements TillOfflinePort {
  final List<List<OfflineSale>> sent = [];
  bool fail = false;
  Set<int> refuseSeq = {};
  final List<String> sessions = [];
  String? failSession;
  @override
  Future<OfflineSyncAnswer> sync(String workspaceId, {required String sessionId, required DateTime offlineSince, required List<OfflineSale> sales, required int minorDigits}) async {
    if (fail || sessionId == failSession) throw StateError('no connection');
    sessions.add(sessionId);
    sent.add(sales);
    return OfflineSyncAnswer(
      results: [
        for (final s in sales)
          OfflineSaleResult(seq: s.seq, requestId: s.requestId, accepted: !refuseSeq.contains(s.seq), reason: refuseSeq.contains(s.seq) ? 'price' : '', number: 'R-${s.seq}', replayed: false),
      ],
      gaps: const [],
    );
  }

  @override
  Future<OfflineList> list(String workspaceId, {required String sessionId}) async => const OfflineList(sales: [], gaps: []);
}

void main() {
  var n = 0;
  TillOfflineQueue make(_Mem store) => TillOfflineQueue(store: store, newRequestId: () => 'req-${++n}');
  final t0 = DateTime.utc(2026, 11, 24, 7);
  const bread = OfflinePrice(itemId: 'bread', name: 'Baguette', unit: 'piece', grossMinor: 120);
  const kg = OfflinePrice(itemId: 'flour', name: 'Flour', unit: 'kg', grossMinor: 333);

  Future<TillOfflineQueue> ready(_Mem store) async {
    final q = make(store);
    await q.cachePrices(const [bread, kg]);
    await q.goOffline(sessionId: 's1', now: t0);
    return q;
  }

  test('majorText writes minor units as the decimal text the server reads', () {
    expect(majorText(120, 2), '1.20');
    expect(majorText(5, 2), '0.05');
    expect(majorText(1200, 3), '1.200');
    expect(majorText(7, 0), '7');
  });

  test('a basket is totalled from the cached prices, half up once per line, a weighed quantity exact', () async {
    final q = await ready(_Mem());
    final sale = await q.record(basket: const [OfflineBasketLine(itemId: 'bread', quantity: '2'), OfflineBasketLine(itemId: 'flour', quantity: '0.350')], cashGivenMinor: 500, now: t0);
    // 2 x 1.20 = 2.40; 0.350 x 3.33 = 1.1655 -> 1.17 (half up once)
    expect(sale.lines.map((l) => l.amountMinor), [240, 117]);
    expect(sale.totalMinor, 357);
    expect(sale.changeMinor, 143);
  });

  test('the sequence is gapless within a session and the sale goes to the server as the contract says', () async {
    final q = await ready(_Mem());
    final a = await q.record(basket: const [OfflineBasketLine(itemId: 'bread', quantity: '1')], cashGivenMinor: 120, now: t0);
    final b = await q.record(basket: const [OfflineBasketLine(itemId: 'bread', quantity: '3')], cashGivenMinor: 400, now: t0.add(const Duration(minutes: 2)));
    expect([a.seq, b.seq], [1, 2]);
    final json = b.toSyncJson(minorDigits: 2);
    expect(json['seq'], 2);
    expect(json['cash_given_minor'], 400);
    expect(json['change_minor'], 40);
    expect(json['occurred_at'], '2026-11-24T07:02:00.000Z');
    expect(((json['body']! as Map)['lines']! as List).single, {'item_id': 'bread', 'quantity': '3', 'unit_price': '1.20'});
  });

  test('the device refuses what the server would refuse and records nothing', () async {
    final q = await ready(_Mem());
    Future<OfflineRefusal> why(List<OfflineBasketLine> basket, int cash) async {
      try {
        await q.record(basket: basket, cashGivenMinor: cash, now: t0);
      } on OfflineRecordRefused catch (e) {
        return e.refusal;
      }
      throw StateError('recorded');
    }

    expect(await why(const [], 100), OfflineRefusal.empty);
    expect(await why(const [OfflineBasketLine(itemId: 'unknown', quantity: '1')], 100), OfflineRefusal.noPrice);
    expect(await why(const [OfflineBasketLine(itemId: 'bread', quantity: '0')], 100), OfflineRefusal.badQuantity);
    expect(await why(const [OfflineBasketLine(itemId: 'bread', quantity: '1')], 119), OfflineRefusal.cashShort);
    expect(q.pending, isEmpty);
    final ok = await q.record(basket: const [OfflineBasketLine(itemId: 'bread', quantity: '1')], cashGivenMinor: 120, now: t0);
    expect(ok.seq, 1, reason: 'a refused attempt takes no number');
  });

  test('the sales are sent in order, each with the request id it was made under, and leave the device once answered', () async {
    final store = _Mem();
    final q = await ready(store);
    for (var i = 0; i < 3; i++) {
      await q.record(basket: const [OfflineBasketLine(itemId: 'bread', quantity: '1')], cashGivenMinor: 120, now: t0.add(Duration(minutes: i)));
    }
    final ids = q.pending.map((s) => s.requestId).toList();
    final port = _Port()..refuseSeq = {2};
    final answer = (await q.sync(port, workspaceId: 'w', minorDigits: 2))!;
    expect(port.sent.single.map((s) => s.requestId), ids);
    expect(answer.acceptedCount, 2);
    expect(answer.refused.single.seq, 2);
    expect(answer.refused.single.reason, 'price');
    expect(q.pending, isEmpty);
    expect(q.offlineSince, isNull);
    expect(store.text, isNot(contains('request_id')), reason: 'no sale stays on the device once the server answered');
  });

  test('a connection that fails loses nothing: the same request ids go again, the sequence goes on', () async {
    final store = _Mem();
    final q = await ready(store);
    await q.record(basket: const [OfflineBasketLine(itemId: 'bread', quantity: '1')], cashGivenMinor: 120, now: t0);
    final port = _Port()..fail = true;
    await expectLater(q.sync(port, workspaceId: 'w', minorDigits: 2), throwsStateError);
    expect(q.pending, hasLength(1));
    final again = make(store);
    await again.load();
    expect(again.pending.single.requestId, q.pending.single.requestId, reason: 'the queue survives a restart');
    port.fail = false;
    expect((await again.sync(port, workspaceId: 'w', minorDigits: 2))!.acceptedCount, 1);
    await again.goOffline(sessionId: 's1', now: t0);
    final next = await again.record(basket: const [OfflineBasketLine(itemId: 'bread', quantity: '1')], cashGivenMinor: 120, now: t0);
    expect(next.seq, 2, reason: 'the numbers of one session are never reused after a sync');
  });

  test('a new till session starts at 1 and sets nothing of the old one aside', () async {
    final q = await ready(_Mem());
    await q.record(basket: const [OfflineBasketLine(itemId: 'bread', quantity: '1')], cashGivenMinor: 120, now: t0);
    await q.goOffline(sessionId: 's2', now: t0);
    final sale = await q.record(basket: const [OfflineBasketLine(itemId: 'bread', quantity: '1')], cashGivenMinor: 120, now: t0);
    expect(sale.seq, 1);
    // the unsent sale of the first session is still on the device, and still the cash in its drawer
    expect(q.hasPending, true);
    expect(q.pendingKeptMinor, 240);
  });

  test('a session the till left keeps its sales and sends them to that session, in order, when the connection returns', () async {
    final q = await ready(_Mem());
    await q.record(basket: const [OfflineBasketLine(itemId: 'bread', quantity: '1')], cashGivenMinor: 120, now: t0);
    await q.goOffline(sessionId: 's2', now: t0);
    await q.record(basket: const [OfflineBasketLine(itemId: 'bread', quantity: '2')], cashGivenMinor: 240, now: t0);
    final port = _Port();
    final answer = await q.sync(port, workspaceId: 'w', minorDigits: 2);
    expect(answer!.acceptedCount, 2);
    expect(port.sessions, ['s1', 's2']);
    expect(q.hasPending, false);
  });

  test('a session the server refuses as a whole keeps its sales and does not hold the others back', () async {
    final q = await ready(_Mem());
    await q.record(basket: const [OfflineBasketLine(itemId: 'bread', quantity: '1')], cashGivenMinor: 120, now: t0);
    await q.goOffline(sessionId: 's2', now: t0);
    await q.record(basket: const [OfflineBasketLine(itemId: 'bread', quantity: '2')], cashGivenMinor: 240, now: t0);
    final port = _Port()..failSession = 's1';
    await expectLater(q.sync(port, workspaceId: 'w', minorDigits: 2), throwsStateError);
    expect(port.sessions, ['s2']);
    expect(q.hasPending, true);
    await q.goOffline(sessionId: 's1', now: t0);
    expect(q.pending.map((s) => s.seq), [1]);
  });

  test('every sale names its device, the same name across restarts, and two devices both number from 1', () async {
    final store = _Mem();
    final a = await ready(store);
    final first = await a.record(basket: const [OfflineBasketLine(itemId: 'bread', quantity: '1')], cashGivenMinor: 120, now: t0);
    expect(first.toSyncJson(minorDigits: 2)['device_id'], a.deviceId);
    final again = make(store);
    await again.load();
    expect(again.deviceId, a.deviceId);
    final other = await ready(_Mem());
    final second = await other.record(basket: const [OfflineBasketLine(itemId: 'bread', quantity: '1')], cashGivenMinor: 120, now: t0);
    expect([first.seq, second.seq], [1, 1]);
    expect(other.deviceId, isNot(a.deviceId));
  });

  test('a store that cannot be read is never written over: the sales in it stay until someone decides', () async {
    final store = _Mem()..text = '{"v": 9, "lanes": []}';
    final q = make(store);
    await expectLater(q.load(), throwsA(isA<OfflineStoreUnreadable>()));
    await expectLater(q.goOffline(sessionId: 's1', now: t0), throwsA(isA<OfflineStoreUnreadable>()));
    expect(store.text, '{"v": 9, "lanes": []}');
    store.text = 'not json at all';
    await expectLater(make(store).cachePrices(const [bread]), throwsA(isA<OfflineStoreUnreadable>()));
    expect(store.text, 'not json at all');
    await q.discardUnreadable();
    expect(store.text, isNull);
    await q.cachePrices(const [bread]);
    expect(q.prices.keys, ['bread']);
  });

  test('what the first release stored (one session, no device) is read, and its sales take this device\'s name', () async {
    final store = _Mem()
      ..text =
          '{"v":1,"session_id":"s1","offline_since":"2026-11-24T07:00:00.000Z","next_seq":2,"prices":[{"item_id":"bread","name":"Baguette","unit":"piece","gross_minor":120}],'
          '"sales":[{"seq":1,"request_id":"r1","occurred_at":"2026-11-24T07:01:00.000Z","lines":[{"item_id":"bread","name":"Baguette","quantity":"1","unit_minor":120}],"cash_given_minor":120,"change_minor":0}]}';
    final q = make(store);
    await q.load();
    expect(q.sessionId, 's1');
    expect(q.pending.single.deviceId, q.deviceId);
    final next = await q.record(basket: const [OfflineBasketLine(itemId: 'bread', quantity: '1')], cashGivenMinor: 120, now: t0);
    expect(next.seq, 2);
  });

  test('more than 200 sales go in batches, in order', () async {
    final q = await ready(_Mem());
    for (var i = 0; i < 205; i++) {
      await q.record(basket: const [OfflineBasketLine(itemId: 'bread', quantity: '1')], cashGivenMinor: 120, now: t0);
    }
    final port = _Port();
    await q.sync(port, workspaceId: 'w', minorDigits: 2);
    expect(port.sent.map((b) => b.length), [200, 5]);
    expect(port.sent.expand((b) => b).map((s) => s.seq), List.generate(205, (i) => i + 1));
  });

  test('the sync answer and the owner list read as the server writes them', () {
    final a = OfflineSyncAnswer.fromJson({
      'results': [
        {'seq': 1, 'request_id': 'a', 'state': 'accepted', 'receipt_id': 'r', 'number': 'N1', 'reason': null, 'replayed': true},
        {'seq': 2, 'request_id': 'b', 'state': 'refused', 'receipt_id': null, 'number': null, 'reason': 'too_long', 'replayed': false},
      ],
      'gaps': [3],
      'accepted': 1,
      'refused': 1,
    });
    expect(a.acceptedCount, 1);
    expect(a.results.first.replayed, true);
    expect(a.refused.single.reason, 'too_long');
    expect(a.gaps, [3]);
    final l = OfflineList.fromJson({
      'sales': [
        {'seq': 2, 'state': 'refused', 'reason': 'price', 'receipt_id': null, 'number': null, 'total_minor': null, 'cash_given_minor': 500, 'change_minor': 20, 'occurred_at': '2026-11-24T07:00:00Z', 'fiscal': 'not_signed'},
      ],
      'gaps': <int>[],
    });
    expect(l.refused.single.keptMinor, 480);
  });
}
