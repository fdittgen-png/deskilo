// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4373 -- the journey of the bakery selling offline in the reference business, through the Demo's own ports: the owner opens
// the front counter with a 150.00 float, the line is lost and three cash sales are made from the prices the till held, the
// connection returns and the sales are sent in order, a second send of the same batch records nothing twice, the drawer counted
// exactly, the day closed with them, and a sale sent into the closed session refused. Shared by the scenario checklist and the
// journey test.
import 'package:deskilo/features/money/domain/till_day.dart';
import 'package:deskilo/features/money/domain/till_drawer.dart';
import 'package:deskilo/features/money/domain/till_offline.dart';
import 'package:deskilo/features/money/domain/till_offline_queue.dart';
import 'package:deskilo/features/money/providers/till_drawer_providers.dart';
import 'package:deskilo/features/money/providers/till_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'demo_outbox_journeys.dart' show withDemoSession;

class _Mem implements OfflineStore {
  String? text;
  @override
  Future<String?> read() async => text;
  @override
  Future<void> write(String json) async => text = json;
  @override
  Future<void> wipe() async => text = null;
}

/// The facts the journey ends on, for the test to read.
typedef TillOfflineFacts = ({
  List<int> numbers,
  int totalMinor,
  int accepted,
  int replayed,
  int expectedMinor,
  DrawerClosed closed,
  DayReport day,
  String? sentIntoClosed,
  int waitingAfter,
});

Future<TillOfflineFacts> tillOfflineFacts() => withDemoSession((fixture, outbox, c) async {
  c.listen(currentWorkspaceProvider, (_, _) {});
  await c.read(currentWorkspaceProvider.future);
  final drawer = c.read(tillDrawerPortProvider);
  final port = c.read(tillOfflinePortProvider);
  const ws = 'ws-1';
  final opened = await drawer.openSession(ws, requestId: 'o-open', tillId: 'demo-till-front', floatMinor: 15000);

  var n = 0;
  final queue = TillOfflineQueue(store: _Mem(), newRequestId: () => 'offline-${++n}');
  await queue.cachePrices(const [
    OfflinePrice(itemId: 'demo-item-milk', name: 'Milk', unit: 'l', grossMinor: 210),
    OfflinePrice(itemId: 'demo-item-mugs', name: 'Mug', unit: 'piece', grossMinor: 890),
    OfflinePrice(itemId: 'demo-item-beans', name: 'Beans', unit: 'kg', grossMinor: 2400),
  ]);
  final t0 = DateTime.utc(2026, 11, 23, 7);
  await queue.goOffline(sessionId: opened.sessionId, now: t0);
  final made = <OfflineSale>[
    await queue.record(basket: const [OfflineBasketLine(itemId: 'demo-item-milk', quantity: '2')], cashGivenMinor: 500, now: t0.add(const Duration(minutes: 2))),
    await queue.record(basket: const [OfflineBasketLine(itemId: 'demo-item-mugs', quantity: '1')], cashGivenMinor: 1000, now: t0.add(const Duration(minutes: 5))),
    await queue.record(basket: const [OfflineBasketLine(itemId: 'demo-item-beans', quantity: '1')], cashGivenMinor: 2400, now: t0.add(const Duration(minutes: 9))),
  ];
  final total = made.fold<int>(0, (a, s) => a + s.totalMinor);

  final answer = (await queue.sync(port, workspaceId: ws, minorDigits: 2))!;
  await queue.backOnline();
  // the same batch sent again records nothing twice
  final again = await port.sync(ws, sessionId: opened.sessionId, offlineSince: t0, sales: made, minorDigits: 2);

  final cash = await drawer.expected(ws, sessionId: opened.sessionId);
  final closed = await drawer.closeSession(ws, requestId: 'o-close', sessionId: opened.sessionId, count: DrawerCount(countedMinor: cash.expectedMinor, bankedMinor: 0));
  final day = await drawer.closeDay(ws, requestId: 'o-day', businessDate: '2026-11-23');

  // the session is closed: a sale made offline afterwards is refused as a whole and records nothing
  final late = await queue.record(basket: const [OfflineBasketLine(itemId: 'demo-item-milk', quantity: '1')], cashGivenMinor: 210, now: t0.add(const Duration(hours: 9)));
  String? refused;
  try {
    await port.sync(ws, sessionId: opened.sessionId, offlineSince: t0, sales: [late], minorDigits: 2);
  } on PostgrestException catch (e) {
    refused = e.code;
  }
  return (
    numbers: [for (final s in made) s.seq],
    totalMinor: total,
    accepted: answer.acceptedCount,
    replayed: again.results.where((r) => r.replayed).length,
    expectedMinor: cash.expectedMinor,
    closed: closed,
    day: day,
    sentIntoClosed: refused,
    waitingAfter: queue.pendingCount,
  );
});

/// The scenario check: three sales numbered 1-3, all accepted, none twice, the drawer exact, the day closed with them.
Future<bool> tillOfflineJourney() async {
  final f = await tillOfflineFacts();
  return f.numbers.length == 3 &&
      f.accepted == 3 &&
      f.replayed == 3 &&
      f.expectedMinor == 15000 + f.totalMinor &&
      f.closed.differenceMinor == 0 &&
      f.day.sessions.length == 1 &&
      f.sentIntoClosed == 'DKL12';
}
