// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1913 — an issuer can hold the reminders of an invoice (a dispute, a
// wrong person, insolvency) and release the hold; while it holds, the
// sheet says so and no reminder goes out by hand. An invoice whose due
// date was never agreed says that reminders wait for a review.
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/invoices.dart';

/// An OPEN invoice lives on the Open tab, not in the archive.
Future<void> _openOpenInvoice(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(const ValueKey('invoice-tab-open')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('invoice-open-$id')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('hold with a reason, see it, release it', (tester) async {
    final money = await seededMoney(matched: false);
    final invoice = money.invoices.single;
    await pumpInvoices(tester, money: money);
    await _openOpenInvoice(tester, invoice.id);

    final hold = find.byKey(const ValueKey('invoice-hold-action'));
    await tester.ensureVisible(hold);
    expect(find.text('Hold reminders'), findsOneWidget);
    await tester.tap(hold);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('dunning-hold-dispute')));
    await tester.enterText(
      find.byKey(const ValueKey('dunning-hold-note')),
      'contests the hours',
    );
    await tester.tap(find.byKey(const ValueKey('dunning-hold-confirm')));
    await tester.pumpAndSettle();
    expect(money.dunningHolds[invoice.id], 'dispute');

    // A held invoice is not reminded by hand either.
    await expectLater(money.remindInvoice(invoice.id), throwsStateError);

    await _openOpenInvoice(tester, invoice.id);
    expect(
      find.text('Reminders on hold: The member disputes it'),
      findsOneWidget,
    );
    final release = find.byKey(const ValueKey('invoice-hold-action'));
    await tester.ensureVisible(release);
    expect(find.text('Release the reminder hold'), findsOneWidget);
    await tester.tap(release);
    await tester.pumpAndSettle();
    expect(money.dunningHolds.containsKey(invoice.id), isFalse);
  });

  testWidgets('a due date nobody agreed to says reminders wait for review', (
    tester,
  ) async {
    final money = await seededMoney(matched: false);
    money.invoices[0] = money.invoices[0].copyWith(
      dueOn: DateTime(2026, 3, 2),
      maturityBasis: 'default_term',
    );
    final Invoice invoice = money.invoices.single;
    await pumpInvoices(tester, money: money);
    await _openOpenInvoice(tester, invoice.id);
    expect(
      find.textContaining('No agreed payment term was recorded'),
      findsOneWidget,
    );
  });
}
