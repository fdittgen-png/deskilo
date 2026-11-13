// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-f -- "Payments to match" as a person meets it: each payment no
// invoice has taken, the invoices it could settle (the same amount first), one
// tap to match an exact one, "None of these" to leave a payment as it is, and
// the honest empty and failed states; no rule of the experience breaks at 320
// and 390 px. The list is read from the CURRENT invoices and the one answer
// of money not assigned: after a match, the next payment is offered only what
// is still open; it is in the business's currency; a match runs once.
import 'dart:async';

import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/ui/kit/kit_card.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/money/application/receivables.dart';
import 'package:deskilo/features/money/domain/invoice_commands.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoicing_reads.dart';
import 'package:deskilo/features/money/presentation/invoicing/payments_to_match_screen.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart' show Invoice;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';
import '../../ux/experience_guards.dart';

Finder _key(String k) => find.byKey(ValueKey(k));

/// The money fake that settles what it is asked to match, and whose ledger
/// read can fail or wait.
class _Repo extends FakeMoneyRepository {
  final List<String> matched = [];
  Exception? failWith;
  Exception? ledgerFails;
  Exception? invoicesFail;
  Completer<void>? matching;

  /// The open invoices the reader turns the archive into.
  List<Receivable> open = [];

  @override
  Future<void> matchInvoice({
    required String invoiceId,
    required String paymentLedgerId,
    required String resolution,
    String note = '',
    int? amountCents,
  }) async {
    final failure = failWith;
    if (failure != null) throw failure;
    await matching?.future;
    matched.add('$invoiceId<-$paymentLedgerId:$resolution');
    usePayment(
      paymentLedgerId,
      amountCents ??
          ledger.firstWhere((e) => e.id == paymentLedgerId).amountCents,
    );
    open = [
      for (final r in open)
        if (r.invoiceId != invoiceId) r,
    ];
  }

  /// What the server lists for a payment: each open invoice, all of it due.
  @override
  Future<List<InvoiceCapacity>> paymentInvoiceCapacity({
    required String workspaceId,
    required String paymentLedgerId,
  }) async => [
    for (final r in open)
      InvoiceCapacity(
        invoiceId: r.invoiceId,
        stillDueCents: r.openMinor,
        canTake: true,
      ),
  ];

  @override
  Future<List<Invoice>> fetchInvoices(String workspaceId) async {
    final failure = invoicesFail;
    if (failure != null) throw failure;
    return super.fetchInvoices(workspaceId);
  }

  @override
  Future<List<LedgerEntry>> fetchWorkspaceLedger(String workspaceId) async {
    final failure = ledgerFails;
    if (failure != null) throw failure;
    return super.fetchWorkspaceLedger(workspaceId);
  }
}

Receivable _inv(
  String id,
  int open,
  DateTime issued, {
  String currency = 'EUR',
}) => Receivable(
  invoiceId: id,
  customerId: 'anna',
  customerName: 'Anna Alder',
  number: 'INV-$id',
  currency: currency,
  totalMinor: open,
  openMinor: open,
  issuedOn: issued,
  stage: ReceivableStage.open,
);

/// A payment of an earlier month: not spent inside a later invoice.
LedgerEntry _payment(String id, int cents) => LedgerEntry(
  id: id,
  memberId: 'anna',
  kind: LedgerKind.credit,
  category: LedgerCategory.payment,
  amountCents: cents,
  description: 'Transfer',
  period: '2026-03',
  createdAt: DateTime(2026, 3, 20),
  occurredOn: DateTime(2026, 3, 18),
);

void main() {
  late _Repo repo;

  setUp(() => repo = _Repo());

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    await pumpApp(
      tester,
      Consumer(
        key: UniqueKey(),
        builder: (context, ref, _) {
          ref.watch(authStateProvider);
          return const PaymentsToMatchScreen(currency: 'EUR');
        },
      ),
      size: size,
      overrides: [
        ...standardTestOverrides(
          money: repo,
          auth: FakeAuthRepository.signedIn(),
          workspace: FakeWorkspaceRepository.withWorkspace(),
        ),
        // The reader of the invoices, as the archive answers now.
        invoicingReceivablesProvider.overrideWith((ref) {
          ref.watch(invoicesProvider);
          return List.of(repo.open);
        }),
      ],
    );
    await tester.pumpAndSettle();
  }

  final older = _inv('older', 5000, DateTime(2026, 4));
  final exact = _inv('exact', 12000, DateTime(2026, 5, 5));

  testWidgets('a payment lists the invoices it could settle, the same amount '
      'first', (tester) async {
    repo
      ..open = [older, exact]
      ..ledger.add(_payment('p1', 12000));
    await pump(tester);
    expect(find.text('Anna Alder'), findsOneWidget);
    expect(find.textContaining('120.00 received'), findsOneWidget);
    expect(find.text('Same amount'), findsOneWidget);
    expect(
      tester.getTopLeft(_key('payment-match-p1-exact')).dy,
      lessThan(tester.getTopLeft(_key('payment-match-p1-older')).dy),
    );
    expect(repo.matched, isEmpty, reason: 'nothing happens until a tap');
  });

  testWidgets('#3614 — at the desk, two panes: the payments on the left, '
      'the open invoices of the chosen one on the right', (tester) async {
    repo
      ..open = [older, exact]
      ..ledger.add(_payment('p1', 12000))
      ..ledger.add(_payment('p2', 5000));
    await pump(tester, size: const Size(1440, 900));
    expect(_key('payment-match-payments'), findsOneWidget);
    expect(_key('payment-match-pick-p1'), findsOneWidget);
    expect(_key('payment-match-pick-p2'), findsOneWidget);
    // One payment open on the right, with its invoices.
    expect(
      find.descendant(
        of: _key('payment-match-invoices'),
        matching: find.byType(KitCard),
      ),
      findsOneWidget,
    );
    final first = _key('payment-match-p1').evaluate().isNotEmpty ? 'p1' : 'p2';
    final second = first == 'p1' ? 'p2' : 'p1';
    await tester.tap(_key('payment-match-pick-$second'));
    await tester.pumpAndSettle();
    expect(_key('payment-match-$second'), findsOneWidget);
    expect(_key('payment-match-$first'), findsNothing);
    expect(repo.matched, isEmpty, reason: 'choosing a payment matches nothing');
  });

  testWidgets('a payment partly used shows what is left of it, and that '
      'is what its invoices are compared with', (tester) async {
    repo
      ..open = [older, exact]
      ..ledger.add(_payment('p1', 12000))
      ..usePayment('p1', 7000);
    await pump(tester);
    expect(find.textContaining('50.00 received'), findsOneWidget);
    expect(find.textContaining('120.00 received'), findsNothing);
    expect(find.text('Same amount'), findsOneWidget);
    expect(
      tester.getTopLeft(_key('payment-match-p1-older')).dy,
      lessThan(tester.getTopLeft(_key('payment-match-p1-exact')).dy),
      reason: 'the 50.00 invoice is the exact one now',
    );
  });

  testWidgets('one tap on the exact invoice matches it, exactly; the next '
      'payment no longer offers the invoice it settled', (tester) async {
    repo
      ..open = [older, exact]
      ..ledger.addAll([_payment('p1', 12000), _payment('p2', 12000)]);
    await pump(tester);
    expect(_key('payment-match-p2-exact'), findsOneWidget);
    await tester.tap(_key('payment-match-p1-exact'));
    await tester.pumpAndSettle();
    expect(repo.matched, ['exact<-p1:exact']);
    expect(_key('payment-match-p1'), findsNothing, reason: 'p1 is taken');
    expect(_key('payment-match-p2'), findsOneWidget);
    expect(
      _key('payment-match-p2-exact'),
      findsNothing,
      reason: 'the invoice p1 settled is not offered again',
    );
    expect(_key('payment-match-p2-older'), findsOneWidget);
  });

  testWidgets('each payment has "Assign to invoices", which opens the sheet '
      'on that payment; a partly used one says what is already assigned', (
    tester,
  ) async {
    repo
      ..open = [older, exact]
      ..ledger.addAll([_payment('p1', 12000), _payment('p2', 9000)])
      ..usePayment('p2', 4000);
    await pump(tester);
    expect(_key('payment-match-assign-p1'), findsOneWidget);
    expect(_key('payment-match-assign-p2'), findsOneWidget);
    expect(_key('payment-match-used-p2'), findsOneWidget);
    expect(_key('payment-match-used-p1'), findsNothing);
    await tester.tap(_key('payment-match-assign-p1'));
    await tester.pumpAndSettle();
    expect(find.text('Record a payment'), findsOneWidget);
    expect(_key('assign-payment-confirm'), findsOneWidget);
  });

  testWidgets('a double tap matches once, and no other card can match while '
      'it runs', (tester) async {
    repo
      ..open = [older, exact]
      ..ledger.addAll([_payment('p1', 12000), _payment('p2', 5000)])
      ..matching = Completer<void>();
    await pump(tester);
    await tester.tap(_key('payment-match-p1-exact'));
    await tester.tap(_key('payment-match-p1-exact'), warnIfMissed: false);
    await tester.pump();
    await tester.tap(_key('payment-match-p2-older'), warnIfMissed: false);
    await tester.pump();
    repo.matching!.complete();
    await tester.pumpAndSettle();
    expect(repo.matched, ['exact<-p1:exact']);
  });

  testWidgets('another amount opens the match dialog on the tapped payment', (
    tester,
  ) async {
    final id = await repo.createInvoice(
      workspaceId: 'ws-1',
      memberId: 'anna',
      period: kTestPeriod,
    );
    repo
      ..open = [_inv(id, 9000, DateTime(2026, 5))]
      ..ledger.addAll([_payment('p1', 12000), _payment('p2', 7777)]);
    await pump(tester);
    await tester.tap(_key('payment-match-p1-$id'));
    await tester.pumpAndSettle();
    final group = tester.widget<RadioGroup<String>>(
      _key('invoicing-dashboard-radio-group'),
    );
    expect(group.groupValue, 'p1', reason: 'not the newest, the tapped one');
  });

  testWidgets('#3285: the invoices fail to read before the difference '
      'dialog: said with Try again, nothing matched, the lock released; Try '
      'again opens the dialog on the same payment', (tester) async {
    final id = await repo.createInvoice(
      workspaceId: 'ws-1',
      memberId: 'anna',
      period: kTestPeriod,
    );
    repo
      ..open = [_inv(id, 9000, DateTime(2026, 5))]
      ..ledger.addAll([_payment('p1', 12000), _payment('p2', 7777)]);
    await pump(tester);
    // Reading the invoices fails when the card is tapped: said at once, no
    // half minute of retries first.
    repo.invoicesFail = Exception('offline');
    await tester.tap(_key('payment-match-p1-$id'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
    expect(find.text('The invoices could not be read.'), findsOneWidget);
    expect(_key('invoicing-dashboard-radio-group'), findsNothing);
    expect(repo.matched, isEmpty);
    expect(tester.takeException(), isNull, reason: 'no uncaught error');
    repo.invoicesFail = null;
    await tester.tap(_key('payment-match-read-retry'));
    await tester.pumpAndSettle();
    final group = tester.widget<RadioGroup<String>>(
      _key('invoicing-dashboard-radio-group'),
    );
    expect(group.groupValue, 'p1', reason: 'the retry keeps the payment');
  });

  testWidgets('#3285: an invoice gone meanwhile is said, not passed over in '
      'silence', (tester) async {
    repo
      ..open = [_inv('gone', 9000, DateTime(2026, 5))]
      ..ledger.add(_payment('p1', 12000));
    await pump(tester);
    await tester.tap(_key('payment-match-p1-gone'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.text('This invoice is no longer open: the list is read again.'),
      findsOneWidget,
    );
    expect(_key('invoicing-dashboard-radio-group'), findsNothing);
    expect(repo.matched, isEmpty);
  });

  testWidgets('the payment is in the business\'s currency; an invoice in '
      'another currency is not offered', (tester) async {
    repo
      ..open = [exact, _inv('usd', 12000, DateTime(2026, 5, 9), currency: 'USD')]
      ..ledger.add(_payment('p1', 12000));
    await pump(tester);
    expect(_key('payment-match-p1-exact'), findsOneWidget);
    expect(_key('payment-match-p1-usd'), findsNothing);
    expect(find.textContaining('\$'), findsNothing);
  });

  testWidgets('a refusal is said and nothing is matched', (tester) async {
    repo
      ..failWith = Exception('refused')
      ..open = [older, exact]
      ..ledger.add(_payment('p1', 12000));
    await pump(tester);
    await tester.tap(_key('payment-match-p1-exact'));
    await tester.pumpAndSettle();
    expect(repo.matched, isEmpty);
    expect(
      find.text('Anna Alder'),
      findsOneWidget,
      reason: 'the payment stays',
    );
  });

  testWidgets('a payment with no open invoice to pay is the customer\'s '
      'credit, not a to-do: it is not listed', (tester) async {
    repo.ledger.add(_payment('p9', 9900));
    await pump(tester);
    expect(find.text('No payment is waiting for an invoice.'), findsOneWidget);
    expect(find.text('Anna Alder'), findsNothing);
  });

  testWidgets('a failed read has a retry', (tester) async {
    repo
      ..open = [older, exact]
      ..ledger.add(_payment('p1', 12000))
      ..ledgerFails = Exception('offline');
    await pump(tester);
    expect(_key('payment-match-failed'), findsOneWidget);
    repo.ledgerFails = null;
    await tester.tap(_key('payment-match-retry'));
    await tester.pumpAndSettle();
    expect(_key('payment-match-failed'), findsNothing);
    expect(find.text('Anna Alder'), findsOneWidget);
  });

  void twoPayments() => repo
    ..open = [older, exact]
    ..ledger.addAll([_payment('p1', 12000), _payment('p2', 7777)]);

  // The picture a pull request attaches (SHEET=1), at a phone's own height.
  testWidgets('sheet: two payments', (tester) async {
    await loadSheetFonts();
    twoPayments();
    await pump(tester);
    await writeSheet(tester, sheet: 'payments-to-match', name: 'list');
  });

  for (final (width, scale) in [(320.0, 1.3), (390.0, 1.0), (1280.0, 1.0)]) {
    testWidgets('the list keeps the rules at $width px, ×$scale', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      twoPayments();
      await pump(tester, size: Size(width, 3000));
      expect(guardProblems(tester, width: width), isEmpty);
      semantics.dispose();
    });
  }
}
