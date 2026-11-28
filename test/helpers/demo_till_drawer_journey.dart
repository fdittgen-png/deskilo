// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4367 — the journey of the till's cash drawer in the reference business, through the Demo's own ports: the owner opens
// a till with its float, sells for cash on it, pays money out, counts the drawer and closes it, once exact and once with a
// difference that is closed only with its reason. Shared by the scenario checklist and the journey test.
import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/features/money/domain/counter_till.dart';
import 'package:deskilo/features/money/domain/till_day.dart';
import 'package:deskilo/features/money/domain/till_drawer.dart';
import 'package:deskilo/features/money/providers/till_drawer_providers.dart';
import 'package:deskilo/features/money/providers/till_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'demo_outbox_journeys.dart' show withDemoSession;

/// The facts the journey ends on, for the test to read.
typedef TillDrawerFacts = ({
  int expectedBeforeClose,
  DrawerClosed exact,
  DrawerClosed short,
  String? refusedWithout,
  bool saleNeededOpenTill,
  String? dayRefusedWhileOpen,
  DayReport day,
  String? dayRefusedAgain,
});

Future<TillDrawerFacts> tillDrawerFacts() => withDemoSession((fixture, outbox, c) async {
  c.listen(currentWorkspaceProvider, (_, _) {});
  await c.read(currentWorkspaceProvider.future);
  final drawer = c.read(tillDrawerPortProvider);
  final till = c.read(tillPortProvider);
  const ws = 'ws-1';
  final front = (await drawer.tills(ws)).firstWhere((t) => t.id == 'demo-till-front');
  const milk = [TillLine(itemId: 'demo-item-milk', name: 'Milk', quantity: '1', unit: 'l')];

  // a sale needs an open till
  var needed = false;
  try {
    await till.draft(ws, requestId: 'j-draft-0', lines: milk, tillId: front.id);
  } on PostgrestException catch (e) {
    needed = e.code == DkCode.dkl12;
  }

  final opened = await drawer.openSession(ws, requestId: 'j-open', tillId: front.id, floatMinor: 10000);
  final draft = await till.draft(ws, requestId: 'j-draft', lines: milk, tillId: front.id);
  await till.finalize(
    ws,
    requestId: 'j-sale',
    receiptId: draft.receiptId,
    expectedRevision: draft.revision,
    tenders: [TillTender(kind: 'cash', amountMinor: draft.totals.grossMinor)],
  );
  await drawer.cashEntry(ws, requestId: 'j-out', sessionId: opened.sessionId, entry: const DrawerEntry(kind: 'paid_out', amountMinor: 500, reason: 'expense'));
  final cash = await drawer.expected(ws, sessionId: opened.sessionId);
  final exact = await drawer.closeSession(ws, requestId: 'j-close', sessionId: opened.sessionId, count: DrawerCount(countedMinor: cash.expectedMinor, bankedMinor: 5000));

  final market = await drawer.openSession(ws, requestId: 'j-open-2', tillId: 'demo-till-market', floatMinor: 5000);
  String? refused;
  try {
    await drawer.closeSession(ws, requestId: 'j-close-2', sessionId: market.sessionId, count: const DrawerCount(countedMinor: 4900, bankedMinor: 0));
  } on PostgrestException catch (e) {
    refused = e.code;
  }
  String? dayWhileOpen;
  try {
    await drawer.closeDay(ws, requestId: 'j-day-0', businessDate: '2026-11-23');
  } on PostgrestException catch (e) {
    dayWhileOpen = e.code;
  }
  final short = await drawer.closeSession(
    ws,
    requestId: 'j-close-3',
    sessionId: market.sessionId,
    count: const DrawerCount(countedMinor: 4900, differenceReason: 'counting_error', bankedMinor: 0),
  );
  final day = await drawer.closeDay(ws, requestId: 'j-day', businessDate: '2026-11-23');
  String? again;
  try {
    await drawer.closeDay(ws, requestId: 'j-day-2', businessDate: '2026-11-23');
  } on PostgrestException catch (e) {
    again = e.code;
  }
  return (
    expectedBeforeClose: cash.expectedMinor,
    exact: exact,
    short: short,
    refusedWithout: refused,
    saleNeededOpenTill: needed,
    dayRefusedWhileOpen: dayWhileOpen,
    day: day,
    dayRefusedAgain: again,
  );
});

/// The scenario check: the exact close has no difference, the short one is refused without a reason and closed with it.
Future<bool> tillDrawerJourney() async {
  final f = await tillDrawerFacts();
  return f.saleNeededOpenTill &&
      f.exact.differenceMinor == 0 &&
      f.exact.expectedMinor == f.expectedBeforeClose &&
      f.refusedWithout == DkCode.dkl13 &&
      f.short.differenceMinor == -100 &&
      f.dayRefusedWhileOpen == DkCode.dkl14 &&
      f.day.sessions.length == 2 &&
      f.day.differencesMinor == -100 &&
      f.dayRefusedAgain == DkCode.dkl14;
}

/// A cash sale at the counter: the receipt is numbered and its total is the milk's price.
Future<bool> tillSaleJourney() => withDemoSession((fixture, outbox, c) async {
  c.listen(currentWorkspaceProvider, (_, _) {});
  await c.read(currentWorkspaceProvider.future);
  final till = c.read(tillPortProvider);
  final draft = await till.draft('ws-1', requestId: 's-draft', lines: const [TillLine(itemId: 'demo-item-milk', name: 'Milk', quantity: '1', unit: 'l')]);
  final sold = await till.finalize(
    'ws-1',
    requestId: 's-sale',
    receiptId: draft.receiptId,
    expectedRevision: draft.revision,
    tenders: [TillTender(kind: 'cash', amountMinor: draft.totals.grossMinor)],
  );
  return sold.number.isNotEmpty && sold.totals.grossMinor == 210;
});
