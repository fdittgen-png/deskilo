// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3913 — a ledger row of a kind or a category this version cannot read
// leaves the money received and not assigned UNKNOWN, never smaller: the
// read refuses with LedgerRowsUnreadable, every page that shows it says so in
// one sentence (never 0, never a raw error), and nobody can be reminded on
// it. A member's bill says the rows that were left out.

import 'package:deskilo/core/data/unreadable_rows.dart';
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/ui/inline_banner.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/money/application/receivables.dart';
import 'package:deskilo/features/money/application/unassigned_money.dart';
import 'package:deskilo/features/money/domain/statement.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoicing_home.dart'
    show InvoicingSource;
import 'package:deskilo/features/money/presentation/invoicing/invoicing_home_parts.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoicing_live_pages.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoicing_reads.dart';
import 'package:deskilo/features/money/presentation/invoicing/payments_to_match_screen.dart';
import 'package:deskilo/features/money/presentation/widgets/bill_view.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _sentence = AppLocalizationsEn().invoicingUnassignedUnreadable;

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

Future<void> _pump(WidgetTester tester, Widget page) => pumpApp(
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
    unassignedMoneyProvider.overrideWith(
      (ref) => Future<UnassignedMoney>.error(const LedgerRowsUnreadable()),
    ),
  ],
);

void main() {
  setUp(UnreadableRows.instance.clear);

  test('the money not assigned refuses when the workspace ledger left a row '
      'out, never a smaller figure', () async {
    // The ledger read counts through this registry (ledgerArea).
    await _OneUnreadable().fetchWorkspaceLedger('ws-1');
    expect(
      () => refuseUnreadableLedger('ws-1'),
      throwsA(isA<LedgerRowsUnreadable>()),
    );
    UnreadableRows.instance.clear();
    expect(() => refuseUnreadableLedger('ws-1'), returnsNormally);
  });

  testWidgets('the reminder queue says the money is not known and shares '
      'nothing', (tester) async {
    await _pump(tester, LiveReminderQueue(onMatch: (_) {}));
    await tester.pumpAndSettle();
    expect(find.text(_sentence), findsOneWidget);
    expect(find.text('0'), findsNothing);
    for (final id in ['a', 'b']) {
      final share = find.byKey(ValueKey('reminder-queue-share-$id'));
      if (tester.any(share)) {
        expect(tester.widget<ButtonStyleButton>(share).onPressed, isNull);
      }
    }
  });

  testWidgets('a customer page says the money is not known and offers no '
      'Remind', (tester) async {
    await _pump(
      tester,
      LiveCustomerPage(
        customerId: 'Ben',
        onOpenInvoice: (_) {},
        onAction: (_) {},
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('customer-page-unreadable')),
      findsOneWidget,
    );
    expect(find.text(_sentence), findsOneWidget);
    expect(find.text('Remind'), findsNothing);
  });

  testWidgets('the payments to match say the money is not known, not that '
      'the read failed', (tester) async {
    await _pump(
      tester,
      const PaymentsToMatchScreen(currency: 'EUR', customerId: 'Anna'),
    );
    await tester.pumpAndSettle();
    expect(find.text(_sentence), findsOneWidget);
    expect(find.text(AppLocalizationsEn().readStateFailed), findsNothing);
  });

  testWidgets('the home names the credits as not known, not as a failed '
      'read', (tester) async {
    await _pump(
      tester,
      InvoicingFailedSource(source: InvoicingSource.credits, onRetry: () {}),
    );
    await tester.pumpAndSettle();
    expect(find.text(_sentence), findsOneWidget);
  });

  testWidgets('a member\'s bill says the ledger rows left out', (tester) async {
    UnreadableRows.instance.record(ledgerArea('member-1'), 'member-1', {
      'le-9': 'ledger refund/coupon',
    }, scope: 'member-1');
    await pumpApp(
      tester,
      const SingleChildScrollView(
        child: BillView(
          statement: Statement(
            period: '2026-05',
            subscriptionPct: 50,
            feeCents: 18000,
            includedHalfDays: 10,
            openDays: 21,
            usedHalfDays: 4,
            extraHalfDays: 0,
            overageCents: 0,
            creditsCents: 0,
            balanceCents: 18000,
          ),
          ledger: [],
          pendingMoneyEvents: [],
          currencyCode: 'EUR',
          memberId: 'member-1',
          nowPeriod: '2026-05',
        ),
      ),
      size: const Size(390, 2000),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(UnreadableRowsNotice),
        matching: find.byType(Text),
      ),
      findsWidgets,
    );
  });
}

/// The workspace ledger read with one row this version cannot read: counted
/// through the same registry the real read records into.
class _OneUnreadable extends FakeMoneyRepository {
  @override
  Future<List<LedgerEntry>> fetchWorkspaceLedger(String workspaceId) async {
    final rows = await super.fetchWorkspaceLedger(workspaceId);
    UnreadableRows.instance.record(ledgerArea('ws:$workspaceId'), workspaceId, {
      'le-9': 'ledger refund/coupon',
    }, scope: workspaceId);
    return rows;
  }
}
