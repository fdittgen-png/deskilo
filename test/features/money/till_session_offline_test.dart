// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4373 (CS11) -- the till session selling offline against a server that goes away and comes back: a call with no answer puts the
// till offline, it sells for cash from the prices it held and records each sale under the next number of its session, and when the
// connection returns the sales are sent in order and the answer is shown. A line with no price is not sold, cash short of the total
// is refused, a send the server refuses as a whole keeps the sales on the device, a store that cannot be read stops offline selling,
// and a business that does not sell offline is told, as before, that the pricing failed.
import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/features/money/domain/counter_receipt_document.dart';
import 'package:deskilo/features/money/domain/counter_till.dart';
import 'package:deskilo/features/money/domain/till_offline.dart';
import 'package:deskilo/features/money/domain/till_offline_queue.dart';
import 'package:deskilo/features/money/presentation/till_offline_mode.dart';
import 'package:deskilo/features/money/presentation/till_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

class _Mem implements OfflineStore {
  String? text;
  @override
  Future<String?> read() async => text;
  @override
  Future<void> write(String json) async => text = json;
  @override
  Future<void> wipe() async => text = null;
}

class _Server implements TillPort, TillOfflinePort {
  bool down = false;
  Exception? refuseSync;
  final Set<int> refuseSeq = {};
  final List<OfflineSale> received = [];

  @override
  Future<TillReadiness> readiness(String workspaceId) async {
    if (down) throw StateError('no connection');
    return const TillReadiness(country: 'FR', fiscalObligation: 'none', ready: true, operations: []);
  }

  @override
  Future<CounterReceiptDocument> receipt(String workspaceId, String receiptId) => throw UnimplementedError();

  @override
  Future<TillDraft> draft(String workspaceId, {required String requestId, required List<TillLine> lines, String? receiptId, int? expectedRevision, String? tillId}) async {
    if (down) throw StateError('no connection');
    final gross = 100 * lines.length;
    return TillDraft(
      receiptId: receiptId ?? 'r-1',
      revision: (expectedRevision ?? 0) + 1,
      totals: TillTotals(netMinor: gross, taxMinor: 0, grossMinor: gross, currency: 'EUR'),
      lines: [for (final l in lines) TillPricedLine(label: l.name, grossMinor: 100, quantity: l.quantity)],
      issueReceipt: 'supported',
    );
  }

  @override
  Future<TillSold> finalize(String workspaceId, {required String requestId, required String receiptId, required int expectedRevision, required List<TillTender> tenders}) =>
      throw UnimplementedError();

  @override
  Future<OfflineSyncAnswer> sync(String workspaceId, {required String sessionId, required DateTime offlineSince, required List<OfflineSale> sales, required int minorDigits}) async {
    if (down) throw StateError('no connection');
    if (refuseSync case final e?) throw e;
    received.addAll(sales);
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
  const bread = TillKey(id: 'bread', name: 'Baguette', unit: 'piece', grossMinor: 120);
  const milk = TillKey(id: 'milk', name: 'Milk', unit: 'l'); // no price on the device
  final t0 = DateTime.utc(2026, 11, 24, 7);
  var n = 0;

  Future<({TillSession session, _Server server, _Mem store, TillOfflineQueue queue})> make({bool offline = true}) async {
    final server = _Server();
    final store = _Mem();
    final queue = TillOfflineQueue(store: store, newRequestId: () => 'id-${++n}');
    final session = TillSession(port: server, workspaceId: 'w', requestIds: () => 'req-${++n}', callTimeout: const Duration(seconds: 1))..tillId = 'till-1';
    if (offline) {
      session.configureOffline(
        TillOfflineKit(queue: queue, port: server, currency: 'EUR', minorDigits: 2, now: () => t0, reconnectEvery: const Duration(days: 1)),
        sessionId: 'sess-1',
      );
      await session.cacheOfflinePrices(const [bread, milk]);
    }
    addTearDown(session.dispose);
    return (session: session, server: server, store: store, queue: queue);
  }

  Future<void> ring(TillSession s, TillKey k) => s.add(itemId: k.id, name: k.name, unit: k.unit);

  test('online it prices through the server and is not offline', () async {
    final x = await make();
    await ring(x.session, bread);
    expect(x.session.offline.value.active, false);
    expect(x.session.state.value.draft!.receiptId, 'r-1');
  });

  test('a call with no answer puts the till offline: the basket is priced from the device and only cash is taken', () async {
    final x = await make();
    x.server.down = true;
    await ring(x.session, bread);
    await ring(x.session, bread);
    expect(x.session.offline.value.active, true);
    final draft = x.session.state.value.draft!;
    expect(draft.receiptId, 'offline');
    expect(draft.totals.grossMinor, 240);
    expect(x.session.state.value.problem, isNull);
    await x.session.payCash(300);
    final sold = x.session.state.value.sold!;
    expect(sold.totals.grossMinor, 240);
    expect(x.session.state.value.change, 60);
    expect(x.session.offline.value.sale!.seq, 1);
    expect(x.session.offline.value.waiting, 1);
  });

  test('each offline sale takes the next number, and the next customer starts clean but offline', () async {
    final x = await make();
    x.server.down = true;
    await ring(x.session, bread);
    await x.session.payCash(120);
    x.session.next();
    expect(x.session.state.value.empty, true);
    expect(x.session.offline.value.active, true);
    expect(x.session.offline.value.sale, isNull);
    await ring(x.session, bread);
    await x.session.payCash(200);
    expect(x.session.offline.value.sale!.seq, 2);
    expect(x.session.offline.value.waiting, 2);
  });

  test('a line the device holds no price for is not sold offline, and nothing is recorded', () async {
    final x = await make();
    x.server.down = true;
    await ring(x.session, milk);
    expect(x.session.state.value.draft, isNull);
    expect(x.session.state.value.problem, isA<TillOfflineNoPrice>());
    expect(x.queue.pendingCount, 0);
  });

  test('cash short of the total is refused and nothing is recorded', () async {
    final x = await make();
    x.server.down = true;
    await ring(x.session, bread);
    await x.session.payCash(100);
    expect(x.session.state.value.problem, isA<TillCashShort>());
    expect(x.session.state.value.sold, isNull);
    expect(x.queue.pendingCount, 0);
  });

  test('while the connection is still down the till stays offline and keeps its sales', () async {
    final x = await make();
    x.server.down = true;
    await ring(x.session, bread);
    await x.session.payCash(120);
    await x.session.reconnect();
    expect(x.session.offline.value.active, true);
    expect(x.session.offline.value.syncing, false);
    expect(x.session.offline.value.waiting, 1);
    expect(x.server.received, isEmpty);
  });

  test('when the connection is back the sales are sent in order, the till is online, and the answer is shown', () async {
    final x = await make();
    x.server.down = true;
    await ring(x.session, bread);
    await x.session.payCash(120);
    x.session.next();
    await ring(x.session, bread);
    await x.session.payCash(120);
    x.session.next();
    x.server
      ..down = false
      ..refuseSeq.add(2);
    await x.session.reconnect();
    final status = x.session.offline.value;
    expect(status.active, false);
    expect(status.waiting, 0);
    expect(x.server.received.map((s) => s.seq), [1, 2]);
    expect(status.report!.accepted, 1);
    expect(status.report!.refused.single.reason, 'price');
    x.session.dismissOfflineReport();
    expect(x.session.offline.value.report, isNull);
  });

  test('a send the server refuses as a whole (a closed session) keeps the sales on the device and says so', () async {
    final x = await make();
    x.server.down = true;
    await ring(x.session, bread);
    await x.session.payCash(120);
    x.session.next();
    x.server
      ..down = false
      ..refuseSync = const PostgrestException(message: 'open the till first', code: DkCode.dkl12);
    await x.session.reconnect();
    final status = x.session.offline.value;
    expect(status.active, false);
    expect(status.waiting, 1);
    expect(status.report!.failure, isA<PostgrestException>());
    expect(status.report!.kept, 1);
  });

  test('a basket in progress when the connection returns is priced again by the server', () async {
    final x = await make();
    x.server.down = true;
    await ring(x.session, bread);
    x.server.down = false;
    await x.session.reconnect();
    expect(x.session.offline.value.active, false);
    expect(x.session.state.value.draft!.receiptId, 'r-1');
  });

  test('a store that cannot be read stops offline selling: the pricing fails as it did, and recovery drops the store', () async {
    final x = await make();
    x.store.text = '{"v": 9}';
    final fresh = TillOfflineQueue(store: x.store, newRequestId: () => 'id-${++n}');
    final session = TillSession(port: x.server, workspaceId: 'w', requestIds: () => 'req-${++n}')..tillId = 'till-1';
    addTearDown(session.dispose);
    session.configureOffline(TillOfflineKit(queue: fresh, port: x.server, currency: 'EUR', minorDigits: 2, now: () => t0, reconnectEvery: const Duration(days: 1)), sessionId: 'sess-1');
    await session.cacheOfflinePrices(const [bread]);
    expect(session.offline.value.unreadable, true);
    x.server.down = true;
    await ring(session, bread);
    expect(session.offline.value.active, false);
    expect(session.state.value.problem, isNotNull);
    await session.discardOfflineStore();
    expect(session.offline.value.unreadable, false);
    expect(x.store.text, isNull);
  });

  test('a business that does not sell offline is told that the pricing failed, and the till does not go offline', () async {
    final x = await make(offline: false);
    x.server.down = true;
    await ring(x.session, bread);
    expect(x.session.offline.value.active, false);
    expect(x.session.state.value.problem, isNotNull);
  });
}
