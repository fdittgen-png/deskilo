// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2380 (0650, 0657) -- the Demo journey of undoing a bank match of money in.
//
// The Pézenas owner opens Money > Cash > Bank statements, confirms the two payments
// that carry their invoice's reference, undoes one of them with a reason
// through the real dialog, and then matches the same movement again through
// the real Match action. Read back from the Demo's own repositories: the
// invoice reads open again, the payment credit stays and is the SAME one when
// the movement is matched again, the payment that completed a part-paid
// invoice is undone alone and leaves it part-paid, the ledger never gains or loses a row, the
// timeline gets one applied invoice_payment_reversed event and no payment
// event, and an undoing refused by the books (a closed period) says so in
// words and changes nothing. Everything runs inside the Demo's own container
// over its in-memory repositories: the owner's real repositories are not
// reached.
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/demo/data/bank_statement_repository.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/bank/bank_records.dart';
import 'package:deskilo/features/money/providers/bank_statement_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/demo_journeys.dart' show pumpDemo;

/// A bounded settle: a sheet, a dialog and a snackbar arrive within it.
Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 15; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A snackbar waits behind the one before it: clear the queue between steps.
void _clearSnackBars(WidgetTester tester) => tester
    .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
    .clearSnackBars();

void main() {
  testWidgets('journey: undo a bank match of money in, match it again with '
      'the same payment, and a closed period refuses in words', (tester) async {
    final journey = await pumpDemo(tester, openHub: false);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    final bank = container.read(bankStatementRepositoryProvider)
        as FakeBankStatementRepository;
    final money = journey.fixture.money;
    final events = journey.fixture.events;

    container.read(routerProvider).go('/money/cash');
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('bank-statements-button')));
    await _settle(tester);
    final statement = (await bank.fetchStatements('ws-1'))
        .singleWhere((s) => s.statementRef == 'DEMO-NTFCTN-1');
    await tester.tap(find.byKey(ValueKey('bank-statement-${statement.id}')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('bank-confirm-references')));
    await _settle(tester);

    final matched = (await bank.fetchLines(statement.id))
        .where((l) => l.status == BankLineStatus.matched)
        .toList();
    expect(matched, hasLength(2), reason: 'the two reference payments are matched');
    // One of the two settles its invoice alone; the other completes a
    // part-paid invoice, so another payment is matched to that invoice.
    bool alone(StoredBankLine l) =>
        money.invoiceMatchesStore[l.invoiceId]!.paidCents == l.amountCents;
    final line = matched.singleWhere(alone);
    final partial = matched.singleWhere((l) => !alone(l));
    final invoiceId = line.invoiceId!;
    final creditBefore = money.invoiceMatchesStore[invoiceId]!.paymentLedgerId;
    final ledgerBefore = money.ledger.length;
    final paymentEventsBefore =
        events.events.where((e) => e.type == EventType.invoicePayment).length;

    // Undone through the real dialog: a blank reason sends nothing.
    await tester.tap(find.byKey(ValueKey('bank-line-tile-${line.id}')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('bank-undo-confirm')));
    await _settle(tester);
    expect(bank.unmatches, isEmpty);
    await tester.enterText(
      find.byKey(const ValueKey('bank-undo-reason')),
      'Paid for the wrong invoice',
    );
    await tester.tap(find.byKey(const ValueKey('bank-undo-confirm')));
    await _settle(tester);

    expect((await bank.fetchLines(statement.id)).firstWhere((l) => l.id == line.id).status,
        BankLineStatus.recorded);
    expect(money.invoiceMatchesStore.containsKey(invoiceId), isFalse,
        reason: 'the invoice reads open again');
    expect(money.ledger.length, ledgerBefore, reason: 'no ledger row added or removed');
    expect(bank.unmatches.values.single.reason, 'Paid for the wrong invoice');
    expect(
      events.events.where((e) => e.type == EventType.invoicePaymentReversed),
      hasLength(1),
    );
    expect(
      events.events.where((e) => e.type == EventType.invoicePayment).length,
      paymentEventsBefore,
      reason: 'the undoing is not read as a payment',
    );

    // Matched again through the real Match action: the same payment.
    await tester.tap(find.byKey(ValueKey('bank-line-tile-${line.id}')));
    await _settle(tester);
    await tester.tap(find.byKey(ValueKey('bank-match-invoice-$invoiceId')));
    await tester.tap(find.byKey(const ValueKey('bank-match-confirm')));
    await _settle(tester);
    expect(money.invoiceMatchesStore[invoiceId]!.paymentLedgerId, creditBefore,
        reason: 'the SAME payment credit');
    expect(money.ledger.length, ledgerBefore, reason: 'and no second credit');

    // The payment that completed a part-paid invoice is undone alone: the
    // invoice is part-paid again by what it had before (0657).
    final partialBefore = money.invoiceMatchesStore[partial.invoiceId]!.paidCents;
    _clearSnackBars(tester);
    await tester.tap(find.byKey(ValueKey('bank-line-tile-${partial.id}')));
    await _settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('bank-undo-reason')),
      'Wrong invoice',
    );
    await tester.tap(find.byKey(const ValueKey('bank-undo-confirm')));
    await _settle(tester);
    final left = money.invoiceMatchesStore[partial.invoiceId]!;
    expect(left.paidCents, partialBefore - partial.amountCents,
        reason: 'the earlier part payment stays');
    expect(left.resolution, 'under_accepted', reason: 'part-paid again');
    expect(
      (await bank.fetchLines(statement.id)).singleWhere((l) => l.id == partial.id).status,
      BankLineStatus.recorded,
    );

    // The books are closed over the payment matched again: refused, in words.
    bank.booksClosedThrough = DateTime(2999);
    _clearSnackBars(tester);
    await tester.tap(find.byKey(ValueKey('bank-line-tile-${line.id}')));
    await _settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('bank-undo-reason')),
      'Too late',
    );
    await tester.tap(find.byKey(const ValueKey('bank-undo-confirm')));
    await _settle(tester);
    expect(find.textContaining('closed period'), findsOneWidget);
    expect(money.invoiceMatchesStore.containsKey(invoiceId), isTrue,
        reason: 'refused: nothing changed');
    expect(bank.unmatches, hasLength(2),
        reason: 'the two undoings, and not the refused one, are on record');
  });
}
