// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-f -- unknown is not none. While the money received and not
// assigned is still being read, nobody is known to hold any: the reminder
// queue shares nothing for anyone and the customer page offers no Remind.
// When the read lands, the pages follow it: the customer who paid is under
// "check first", never in the share lines.
import 'dart:async';

import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/money/application/payment_candidates.dart';
import 'package:deskilo/features/money/application/receivables.dart';
import 'package:deskilo/features/money/application/unassigned_money.dart';
import 'package:deskilo/features/money/domain/customer_statement.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoicing_live_pages.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoicing_reads.dart';
import 'package:deskilo/features/money/providers/customer_statement_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

Finder _key(String k) => find.byKey(ValueKey(k));

Receivable _late(String id, String customer) => Receivable(
  invoiceId: id,
  customerId: customer,
  customerName: customer,
  number: 'INV-$id',
  currency: 'EUR',
  totalMinor: 12000,
  openMinor: 12000,
  issuedOn: kTestNow.subtract(const Duration(days: 40)),
  dueOn: kTestNow.subtract(const Duration(days: 10)),
  stage: ReceivableStage.open,
  reminderDueLevel: 1,
);

final _annaPaid = UnassignedMoney(
  currency: 'EUR',
  paymentsOf: {
    'Anna': [
      PaymentLeft(
        entry: LedgerEntry(
          id: 'p1',
          memberId: 'Anna',
          kind: LedgerKind.credit,
          category: LedgerCategory.payment,
          amountCents: 12000,
          description: 'Transfer',
          period: '2026-03',
          createdAt: DateTime(2026, 3, 20),
        ),
        receivedCents: 12000,
        assignedCents: 0,
        leftCents: 12000,
      ),
    ],
  },
);

/// The server's snapshot (#3840): both customers owe 120.00 on one document;
/// Anna holds 120.00 not yet applied. It records the cutoffs it was asked.
class _Statements implements CustomerStatementReader {
  final asked = <DateTime>[];

  @override
  Future<CustomerStatement> read(
    String workspaceId,
    String memberId,
    DateTime asOf,
  ) async {
    asked.add(asOf);
    return CustomerStatement(
      memberId: memberId,
      asOf: asOf,
      currencies: statementCurrencies(
        lines: {
          'EUR': [
            StatementLine(
              invoiceId: memberId == 'Anna' ? 'a' : 'b',
              number: 'INV-x',
              totalCents: 12000,
              stillDueCents: 12000,
              state: StatementLineState.open,
              dueOn: kTestNow.subtract(const Duration(days: 10)),
            ),
          ],
        },
        credits: {
          if (memberId == 'Anna')
            'EUR': [const StatementCredit(ledgerId: 'p1', leftCents: 12000)],
        },
      ),
    );
  }
}

void main() {
  late Completer<UnassignedMoney> money;
  late _Statements statements;

  Future<void> pump(WidgetTester tester, Widget page) async {
    await pumpApp(
      tester,
      Consumer(
        builder: (context, ref, _) {
          ref.watch(authStateProvider);
          return page;
        },
      ),
      size: const Size(390, 1600),
      overrides: [
        ...standardTestOverrides(
          money: FakeMoneyRepository(),
          auth: FakeAuthRepository.signedIn(),
          workspace: FakeWorkspaceRepository.withWorkspace(),
        ),
        invoicingReceivablesProvider.overrideWith(
          (ref) => [_late('a', 'Anna'), _late('b', 'Ben')],
        ),
        unassignedMoneyProvider.overrideWith((ref) => money.future),
        customerStatementReaderProvider.overrideWithValue(statements),
      ],
    );
    await tester.pumpAndSettle();
  }

  setUp(() => statements = _Statements());

  bool enabled(WidgetTester tester, String key) =>
      tester.widget<ButtonStyleButton>(_key(key)).onPressed != null;

  testWidgets('while the read is pending no reminder can be shared for '
      'anyone; when it lands the customer who paid is checked first', (
    tester,
  ) async {
    money = Completer<UnassignedMoney>();
    await pump(tester, LiveReminderQueue(onMatch: (_) {}));
    expect(_key('reminder-queue-checking'), findsOneWidget);
    expect(find.text('Checking received payments…'), findsOneWidget);
    expect(enabled(tester, 'reminder-queue-next'), isFalse);
    for (final id in ['a', 'b']) {
      if (tester.any(_key('reminder-queue-share-$id'))) {
        expect(enabled(tester, 'reminder-queue-share-$id'), isFalse);
      }
    }

    money.complete(_annaPaid);
    await tester.pumpAndSettle();
    expect(_key('reminder-queue-checking'), findsNothing);
    expect(_key('reminder-queue-check-Anna'), findsOneWidget);
    expect(_key('reminder-queue-share-a'), findsNothing);
    expect(enabled(tester, 'reminder-queue-share-b'), isTrue);
    expect(find.text('Share the next one · Ben'), findsOneWidget);
  });

  testWidgets('while the read is pending the customer page offers no Remind; '
      'when it lands, the customer who paid is offered Match', (tester) async {
    money = Completer<UnassignedMoney>();
    await pump(
      tester,
      LiveCustomerPage(
        customerId: 'Anna',
        onOpenInvoice: (_) {},
        onAction: (_) {},
      ),
    );
    expect(_key('customer-page-action'), findsNothing);
    expect(find.text('Remind'), findsNothing);

    money.complete(_annaPaid);
    await tester.pumpAndSettle();
    expect(find.text('Match the payment'), findsWidgets);
    expect(_key('customer-page-action'), findsOneWidget);
    expect(find.text('Remind'), findsNothing);
  });

  testWidgets('read, and the customer holds nothing: Remind is offered', (
    tester,
  ) async {
    money = Completer<UnassignedMoney>()
      ..complete(const UnassignedMoney(currency: 'EUR', paymentsOf: {}));
    await pump(
      tester,
      LiveCustomerPage(
        customerId: 'Ben',
        onOpenInvoice: (_) {},
        onAction: (_) {},
      ),
    );
    expect(find.text('Remind'), findsOneWidget);
  });

  testWidgets('the page shows the snapshot\'s figures for today\'s cutoff '
      '(#3840)', (tester) async {
    money = Completer<UnassignedMoney>()..complete(_annaPaid);
    await pump(
      tester,
      LiveCustomerPage(
        customerId: 'Anna',
        onOpenInvoice: (_) {},
        onAction: (_) {},
      ),
    );
    final statement = await statements.read('w', 'Anna', kTestNow);
    final eur = statement.currencies.single;
    expect(eur.balanceCents, 0);
    expect(find.text('€120.00'), findsWidgets);
    expect(find.text('Credit: €120.00'), findsOneWidget);
    expect(find.text('Balance: €0.00'), findsOneWidget);
    // The cutoff is the business's calendar day, never an instant.
    expect(statements.asked.first.hour, 0);
    expect(statements.asked.first.day, kTestNow.day);
  });
}
