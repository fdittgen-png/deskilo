// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-f -- "Payments to match" as a person meets it: each payment no
// invoice has taken, the invoices it could settle (the same amount first), one
// tap to match an exact one, "None of these" to leave a payment as it is, and
// the honest empty and failed states; no rule of the experience breaks at 320
// and 390 px.
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/money/application/payment_candidates.dart';
import 'package:deskilo/features/money/application/receivables.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/presentation/invoicing/payments_to_match_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';
import '../../ux/experience_guards.dart';

Finder _key(String k) => find.byKey(ValueKey(k));

/// The money fake that remembers the matches it was asked for.
class _Repo extends FakeMoneyRepository {
  final List<String> matched = [];
  Exception? failWith;

  @override
  Future<void> matchInvoice({
    required String invoiceId,
    required String paymentLedgerId,
    required String resolution,
    String note = '',
  }) async {
    final failure = failWith;
    if (failure != null) throw failure;
    matched.add('$invoiceId<-$paymentLedgerId:$resolution');
  }
}

Receivable _inv(String id, int open, DateTime issued) => Receivable(
  invoiceId: id,
  customerId: 'anna',
  customerName: 'Anna Alder',
  number: 'INV-$id',
  currency: 'EUR',
  totalMinor: open,
  openMinor: open,
  issuedOn: issued,
  stage: ReceivableStage.open,
  paymentToMatch: true,
);

LedgerEntry _payment(String id, int cents) => LedgerEntry(
  id: id,
  memberId: 'anna',
  kind: LedgerKind.credit,
  category: LedgerCategory.payment,
  amountCents: cents,
  description: 'Transfer',
  period: '2026-09',
  createdAt: DateTime(2026, 9, 20),
  occurredOn: DateTime(2026, 9, 18),
);

void main() {
  late _Repo repo;

  PaymentToMatch row(String paymentId, int cents, List<Receivable> invoices) {
    return (
      customer: invoices.first,
      payment: _payment(paymentId, cents),
      candidates: candidatesFor(
        paymentMinor: cents,
        currency: 'EUR',
        customerInvoices: invoices,
      ),
    );
  }

  setUp(() => repo = _Repo());

  Future<void> pump(
    WidgetTester tester,
    Future<List<PaymentToMatch>> Function() loader, {
    Size size = const Size(390, 844),
  }) async {
    await pumpApp(
      tester,
      Consumer(
        key: UniqueKey(),
        builder: (context, ref, _) {
          ref.watch(authStateProvider);
          return PaymentsToMatchScreen(
            receivables: const [],
            currency: 'EUR',
            workspaceId: 'ws-1',
            loader: loader,
          );
        },
      ),
      size: size,
      overrides: standardTestOverrides(
        money: repo,
        auth: FakeAuthRepository.signedIn(),
        workspace: FakeWorkspaceRepository.withWorkspace(),
      ),
    );
    await tester.pumpAndSettle();
  }

  final invoices = [
    _inv('older', 5000, DateTime(2026, 8)),
    _inv('exact', 12000, DateTime(2026, 9, 5)),
  ];

  testWidgets('a payment lists the invoices it could settle, the same amount '
      'first', (tester) async {
    await pump(tester, () async => [row('p1', 12000, invoices)]);
    expect(find.text('Anna Alder'), findsOneWidget);
    expect(find.textContaining('120.00 received'), findsOneWidget);
    expect(find.text('Same amount'), findsOneWidget);
    expect(
      tester.getTopLeft(_key('payment-match-p1-exact')).dy,
      lessThan(tester.getTopLeft(_key('payment-match-p1-older')).dy),
    );
    expect(repo.matched, isEmpty, reason: 'nothing happens until a tap');
  });

  testWidgets('one tap on the exact invoice matches it, exactly', (
    tester,
  ) async {
    await pump(tester, () async => [row('p1', 12000, invoices)]);
    await tester.tap(_key('payment-match-p1-exact'));
    await tester.pumpAndSettle();
    expect(repo.matched, ['exact<-p1:exact']);
  });

  testWidgets('a refusal is said and nothing is matched', (tester) async {
    repo.failWith = Exception('refused');
    await pump(tester, () async => [row('p1', 12000, invoices)]);
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
    await pump(
      tester,
      () async => [
        (
          customer: invoices.first,
          payment: _payment('p9', 9900),
          candidates: const <MatchCandidate>[],
        ),
      ],
    );
    expect(find.text('No payment is waiting for an invoice.'), findsOneWidget);
    expect(find.text('Anna Alder'), findsNothing);
  });

  testWidgets('nothing waiting is said, and a failed read has a retry', (
    tester,
  ) async {
    await pump(tester, () async => const []);
    expect(find.text('No payment is waiting for an invoice.'), findsOneWidget);
    var calls = 0;
    await pump(tester, () async {
      calls++;
      if (calls == 1) throw StateError('offline');
      return [row('p1', 12000, invoices)];
    });
    expect(_key('payment-match-failed'), findsOneWidget);
    await tester.tap(_key('payment-match-retry'));
    await tester.pumpAndSettle();
    expect(_key('payment-match-failed'), findsNothing);
    expect(find.text('Anna Alder'), findsOneWidget);
  });

  // The picture a pull request attaches (SHEET=1), at a phone's own height.
  testWidgets('sheet: two payments', (tester) async {
    await loadSheetFonts();
    await pump(
      tester,
      () async => [row('p1', 12000, invoices), row('p2', 7777, invoices)],
    );
    await writeSheet(tester, sheet: 'payments-to-match', name: 'list');
  });

  for (final (width, scale) in [(320.0, 1.3), (390.0, 1.0), (1280.0, 1.0)]) {
    testWidgets('the list keeps the rules at $width px, ×$scale', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(
        tester,
        () async => [row('p1', 12000, invoices), row('p2', 7777, invoices)],
        size: Size(width, 3000),
      );
      expect(guardProblems(tester, width: width), isEmpty);
      semantics.dispose();
    });
  }
}
