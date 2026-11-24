// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3556 — two invoices of the same house and month share one payment.
// Another month stays selected; another house cannot join. After a declared
// payment is taken back, the second house can be paid online. Every amount
// and claim is checked against the Demo stores before and after.
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:deskilo/features/money/providers/finance_overview_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/screens/demo_journeys.dart';
import '../helpers/screens/desk_calendar.dart' show goTo;

Future<void> _pumps(WidgetTester tester, [int times = 8]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _tap(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  // mid-screen, so the selection bar that appears after the first tick
  // cannot cover the row
  await Scrollable.ensureVisible(tester.element(f), alignment: 0.3);
  await tester.pump();
  await tester.tap(f);
  await _pumps(tester);
}

void main() {
  testWidgets(
    'Chiara pays two same-month invoices together, withdraws a payment, '
    'then pays another house online after taking its declaration back',
    (tester) async {
      final journey = await pumpDemo(
        tester,
        persona: DemoPersona.admin,
        openHub: false,
      );
      await goTo(tester, '/me/data?view=finances');
      await _pumps(tester, 10);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      FinanceOverview overview() =>
          container.read(financeOverviewProvider).requireValue;
      FinanceInvoice now(FinanceInvoice i) =>
          overview().invoices.firstWhere((x) => x.id == i.id);

      final before = overview();
      FinanceInvoice owed(String house, String period) =>
          before.invoices.firstWhere(
            (i) =>
                i.workspaceName == house &&
                i.period == period &&
                i.payable &&
                i.id != 'demo-usage-chiara-extra',
          );
      final march = owed('Atelier du Marché', '2026-03');
      final april = owed('Atelier du Marché', '2026-04');
      final extra = before.invoices.firstWhere(
        (i) => i.id == 'demo-usage-chiara-extra',
      );
      expect(extra.period, april.period);
      final camden = before.invoices.firstWhere(
        (i) => i.workspaceName == 'Camden Yard Cowork' && i.payable,
      );
      // what each row owes is what its invoice still owes
      for (final i in [march, extra, april, camden]) {
        expect(i.stillDueCents, i.totalCents - i.paidCents, reason: i.number);
      }

      await _tap(tester, 'finances-select-${march.id}');
      final pound = tester.widget<Checkbox>(
        find.byKey(ValueKey('finances-select-${camden.id}')),
      );
      expect(
        pound.onChanged,
        isNull,
        reason: 'another house, another currency',
      );
      await _tap(tester, 'finances-select-${extra.id}');
      await _tap(tester, 'finances-select-${april.id}');

      // March first; April follows
      await _tap(tester, 'finances-selection-pay');
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('finances-pay-then')))
            .data,
        contains('April 2026'),
      );
      await _tap(tester, 'finances-confirm-send');
      await _tap(tester, 'demo-provider-no-answer');
      expect(
        now(march).claimPaymentId,
        isNotNull,
        reason: 'March is in payment',
      );
      expect(now(march).payable, isFalse);
      expect(now(april).payable, isTrue, reason: 'April waits, still selected');

      await _tap(tester, 'finances-selection-pay');
      await _tap(tester, 'finances-confirm-send');
      await _tap(tester, 'demo-provider-pay');
      expect(now(april).state, FinanceState.paid);
      expect(now(april).stillDueCents, 0);

      // #4225 — the payment is in the Payments tab straight away, not only
      // after a pull to refresh
      await _tap(tester, 'finances-tab-payments');
      expect(find.textContaining('Online payment PAY-'), findsWidgets);
      await _tap(tester, 'finances-tab-outstanding');
      expect(now(extra).state, FinanceState.paid);
      expect(now(extra).stillDueCents, 0);
      final matches = journey.fixture.money.invoiceMatchesStore;
      expect(
        matches[april.id]!.paymentLedgerId,
        matches[extra.id]!.paymentLedgerId,
      );
      final payment = journey.fixture.money.ledger.singleWhere(
        (p) => p.id == matches[extra.id]!.paymentLedgerId,
      );
      expect(payment.amountCents, april.stillDueCents! + extra.stillDueCents!);

      await _tap(tester, 'finances-withdraw-${march.id}');
      await _tap(tester, 'finances-withdraw-yes');
      expect(now(march).payable, isTrue, reason: 'withdrawn: payable again');
      expect(now(march).stillDueCents, march.stillDueCents);
      await _tap(tester, 'finances-select-${camden.id}');
      await _tap(tester, 'finances-selection-declare');
      await _tap(tester, 'finances-confirm-send');
      final declared = now(camden);
      expect(
        (declared.inPayment, declared.claimPaymentId),
        (true, null),
        reason: 'it waits for Camden',
      );
      expect(
        declared.stillDueCents,
        camden.stillDueCents,
        reason: 'nothing is paid until Camden approves it',
      );
      expect(
        find.text('Declared paid · waits for Camden Yard Cowork'),
        findsOneWidget,
      );
      expect(declared.claimEventId, isNotNull, reason: 'hers to take back');

      // #4140 — taken back, paid online instead
      await _tap(tester, 'finances-take-back-${camden.id}');
      expect(
        find.textContaining('You said you paid ${camden.number}.'),
        findsOneWidget,
      );
      await _tap(tester, 'finances-withdraw-yes');
      final back = now(camden);
      expect(
        (back.inPayment, back.claimEventId, back.payable),
        (false, null, true),
        reason: 'taken back: nobody is asked, payable again',
      );
      expect(back.stillDueCents, camden.stillDueCents);
      await _tap(tester, 'finances-select-${camden.id}');
      await _tap(tester, 'finances-selection-pay');
      await _tap(tester, 'finances-confirm-send');
      await _tap(tester, 'demo-provider-pay');
      expect(now(camden).state, FinanceState.paid);
      expect(now(camden).stillDueCents, 0);
      expect(now(camden).claimEventId, isNull);
      expect(
        now(april).stillDueCents,
        0,
        reason: 'paying Camden preserves the other house’s settled invoices',
      );
    },
  );
}
