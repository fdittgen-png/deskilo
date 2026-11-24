// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4367 -- the cash drawer in the Demo: the float, a cash sale and a paid-out make the expected cash; a count that
// matches closes with no difference, a short count is refused without its reason and closed with it; and the twin keeps
// the server's blind-count and once-only rules.
import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/core/demo/data/demo_till_drawer.dart';
import 'package:deskilo/features/money/domain/till_drawer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../helpers/demo_till_drawer_journey.dart';

Future<String?> _code(Future<Object?> Function() act) async {
  try {
    await act();
    return null;
  } on PostgrestException catch (e) {
    return e.code;
  }
}

void main() {
  test('the journey: float, a cash sale, a paid-out, an exact close, a short close', () async {
    final f = await tillDrawerFacts();
    expect(f.saleNeededOpenTill, isTrue);
    // 100.00 float + 2.10 milk - 5.00 paid out
    expect(f.expectedBeforeClose, 10000 + 210 - 500);
    expect(f.exact.differenceMinor, 0);
    expect(f.exact.bankedMinor, 5000);
    expect(f.refusedWithout, DkCode.dkl13);
    expect(f.short.differenceMinor, -100);
    // the day: refused while a till is open, then one report with both sessions, and a second close of the day is refused
    expect(f.dayRefusedWhileOpen, DkCode.dkl14);
    expect(f.day.sessions.map((x) => x.till), ['Front counter', 'Market stall']);
    expect(f.day.differencesMinor, -100);
    expect(f.day.salesTotalMinor, 210);
    expect(f.day.salesByTender, {'cash': 210});
    expect(f.day.paidOutMinor, 500);
    expect(f.day.firstReceipt, f.day.lastReceipt);
    expect(f.day.sessions.last.differenceReason, 'a coin was lost');
    expect(f.dayRefusedAgain, DkCode.dkl14);
    expect(await tillDrawerJourney(), isTrue);
  });

  group('the twin keeps the server rules', () {
    late DemoTillDrawer drawer;
    setUp(() => drawer = DemoTillDrawer());

    test('one open session per till, and the same request answers the same session', () async {
      final a = await drawer.openSession('w', requestId: 'r1', tillId: 'demo-till-front', floatMinor: 100);
      final again = await drawer.openSession('w', requestId: 'r1', tillId: 'demo-till-front', floatMinor: 100);
      expect(again.sessionId, a.sessionId);
      expect(await _code(() => drawer.openSession('w', requestId: 'r2', tillId: 'demo-till-front', floatMinor: 100)), DkCode.dkl12);
    });

    test('the expected cash is refused while the session is open and counted blind, unless the finances may be seen', () async {
      final s = await drawer.openSession('w', requestId: 'r1', tillId: 'demo-till-front', floatMinor: 100);
      expect(await _code(() => drawer.expected('w', sessionId: s.sessionId)), DkCode.dkn01);
      drawer.canSeeFinances = () => true;
      expect((await drawer.expected('w', sessionId: s.sessionId)).expectedMinor, 100);
    });

    test('a reason off the list and a paid-out above the limit are refused; a count by denomination must add up', () async {
      final s = await drawer.openSession('w', requestId: 'r1', tillId: 'demo-till-front', floatMinor: 100);
      expect(await _code(() => drawer.cashEntry('w', requestId: 'e1', sessionId: s.sessionId, entry: const DrawerEntry(kind: 'paid_in', amountMinor: 5, reason: 'gift'))), DkCode.dkl13);
      drawer.rules = () => const DrawerSettings(blindCount: true, byDenomination: true, reasons: ['change'], paidOutLimitMinor: 50);
      expect(await _code(() => drawer.cashEntry('w', requestId: 'e2', sessionId: s.sessionId, entry: const DrawerEntry(kind: 'paid_out', amountMinor: 60, reason: 'change'))), DkCode.dkl13);
      expect(await _code(() => drawer.closeSession('w', requestId: 'c1', sessionId: s.sessionId, count: const DrawerCount(countedMinor: 100, bankedMinor: 0))), DkCode.dkl13);
      final closed = await drawer.closeSession(
        'w',
        requestId: 'c2',
        sessionId: s.sessionId,
        count: const DrawerCount(countedMinor: 100, denominations: Denominations({50: 2}), bankedMinor: 0),
      );
      expect(closed.differenceMinor, 0);
    });
  });
}
