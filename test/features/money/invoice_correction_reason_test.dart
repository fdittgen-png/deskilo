// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2440 — a Spanish correction names its reason (RD 1619/2012 art. 15):
// the issue form asks for R1-R5 only when the server says it is missing,
// holds the submit button until one is chosen, and sends the code.
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/screens/invoices.dart';

void main() {
  testWidgets('the form asks for the correction reason and sends it', (
    tester,
  ) async {
    final money = FakeMoneyRepository()..invoiceMissing = ['correction_reason'];
    money.ledger.add(
      LedgerEntry(
        id: 'ledger-1',
        memberId: 'member-1',
        kind: LedgerKind.charge,
        category: LedgerCategory.service,
        amountCents: 450,
        description: 'Coffee x3',
        period: currentTestPeriod(),
        createdAt: kTestNow,
      ),
    );
    await pumpInvoices(tester, money: money);
    await tester.tap(find.byKey(const ValueKey('invoice-create-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-member-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flo').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-period-next')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('invoice-correction-reason')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('invoice-submit')))
          .onPressed,
      isNull,
      reason: 'the server would refuse it without a reason',
    );

    await tester.tap(find.byKey(const ValueKey('invoice-correction-reason')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('R2 -').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('invoice-missing-essentials')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('invoice-submit')));
    await tester.pumpAndSettle();
    expect(money.invoices, hasLength(1));
    expect(money.lastCorrectionReason, 'R2');
  });
}
