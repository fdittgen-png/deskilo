// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3674 — the owner's invoicing journey in the Demo's reference business
// (ws-1), through the real routed app on a phone (390 x 844), each step from
// the invoicing home with its tap budget (#3587):
//   * invoice April: Review, Issue, Done — Studio Nord needs a fix first (its
//     postal address, added on its member page: Fix, Edit identity, Save),
//     and Farid Haddad's month, whose pack was released and credited back,
//     is a credit note;
//   * share the due reminders by hand: Review, then Share on each line;
//   * match the transfer received: Review, the customer's Match, Assign,
//     Confirm;
//   * pay out the credit note: Review, the customer, the credit note, Record
//     the refund, Confirm — and the home reads "You are all caught up."
// After each step the figures agree: the owed card moves by exactly the
// amount the step acted on and nothing else moves, and what the step did is
// in the Demo's books once. A tap is a press that does the step's work;
// scrolling, typing and the way back (Done, Close, Back, the result page's
// close) are not counted.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/seed/demo_newcomers_seed.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/screens/demo_journeys.dart' show pumpDemo;
import '../helpers/screens/invoices.dart'
    show invoicingOwedFigures, openInvoicingTodo;

final _en = AppLocalizationsEn();

/// The phone the journey runs on.
const Size _phone = Size(390, 844);

/// Counts the touches a step costs.
class _Touches {
  int count = 0;

  Future<void> on(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      // A lazily built row: scrolled to, which is not a tap.
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('invoicing-home')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tester.ensureVisible(finder);
    await _settle(tester);
    count++;
    await tester.tap(finder);
    await _settle(tester);
  }
}

/// Bounded pumps: a page that never settles fails on what it shows.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// A money text as cents (`€1,234.56` → 123456).
int _cents(String text) => int.parse(text.replaceAll(RegExp(r'[^0-9]'), ''));

/// What the owed card says, in cents: owed in total, invoiced and received
/// this month.
typedef _Card = ({int owed, int invoiced, int received});

_Card _card(WidgetTester tester) {
  final texts = [
    for (final e
        in find
            .descendant(
              of: invoicingOwedFigures, // #4059 — the card, or the strip on a phone
              matching: find.byType(Text),
            )
            .evaluate())
      (e.widget as Text).data ?? '',
  ];
  expect(texts, isNotEmpty, reason: 'the owed card is on screen');
  int after(String label) =>
      _cents(texts[texts.indexWhere((t) => t.startsWith(label)) + 1]);
  return (
    owed: _cents(texts.firstWhere((t) => t.contains('€'))),
    invoiced: after('Invoiced in'),
    received: after('Received in'),
  );
}

/// Back (not a tap: the way home) until the invoicing home shows.
Future<void> _backHome(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    // #4059 — the home, at its top: what it sums up is above its list, and
    // a list scrolled down leaves it unbuilt.
    final home = find.byKey(const ValueKey('invoicing-home'));
    if (home.evaluate().isNotEmpty &&
        find.byKey(const ValueKey('invoice-page-more')).evaluate().isEmpty) {
      tester
          .state<ScrollableState>(
            find.descendant(of: home, matching: find.byType(Scrollable)).first,
          )
          .position
          .jumpTo(0);
      await tester.pump();
      break;
    }
    final close = [
      for (final k in ['invoice-page-close', 'customer-page-close'])
        if (find.byKey(ValueKey(k)).evaluate().isNotEmpty) k,
    ];
    if (close.isNotEmpty) {
      await tester.tap(find.byKey(ValueKey(close.first)));
    } else {
      await tester.pageBack();
    }
    await _settle(tester);
  }
  await _home(tester);
}

/// The invoicing home, scrolled to its top where the owed card is.
Future<void> _home(WidgetTester tester) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/invoices');
  await _settle(tester);
  final home = find.descendant(
    of: find.byKey(const ValueKey('invoicing-home')),
    matching: find.byType(Scrollable),
  );
  if (home.evaluate().isNotEmpty) {
    await tester.fling(home.first, const Offset(0, 3000), 3000);
    await _settle(tester);
  }
}

void main() {
  testWidgets('the owner invoices the month, shares the reminders, matches '
      'a payment and pays out a credit note: each within its taps, the '
      'figures agreeing after each', (tester) async {
    final journey = await pumpDemo(tester, openHub: false, size: _phone);
    final f = journey.fixture;
    await _home(tester);
    final start = _card(tester);

    // Invoice April: Review; Studio Nord needs a fix (its address, added on
    // its member page); Issue; Done.
    final month = _Touches();
    final fix = _Touches();
    final issuedBefore = {for (final i in f.money.invoices) i.id};
    await openInvoicingTodo(tester); // #4059
    await month.on(
      tester,
      find.byKey(const ValueKey('invoicing-todo-invoiceTheMonth')),
    );
    expect(
      find.byKey(const ValueKey('invoice-month-fix-$demoStudioNord')),
      findsOneWidget,
      reason: 'Studio Nord has no postal address: its invoice needs a fix',
    );
    await fix.on(
      tester,
      find.byKey(const ValueKey('invoice-month-fix-$demoStudioNord')),
    );
    await fix.on(
      tester,
      find.byKey(const ValueKey('member-page-managed-edit')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('personal-info-street')),
      '14 quai du Nord',
    );
    await tester.enterText(
      find.byKey(const ValueKey('personal-info-postal-code')),
      '34120',
    );
    await tester.enterText(
      find.byKey(const ValueKey('personal-info-city')),
      'Pézenas',
    );
    await fix.on(tester, find.byKey(const ValueKey('personal-info-save')));
    // Back to the month: the page reads Studio Nord again.
    await tester.pageBack();
    await _settle(tester);
    expect(
      find.byKey(const ValueKey('invoice-month-fix-$demoStudioNord')),
      findsNothing,
      reason: 'the address was the only gap',
    );
    await month.on(tester, find.byKey(const ValueKey('invoice-month-issue')));
    expect(find.byKey(const ValueKey('invoice-month-result')), findsOneWidget);
    await month.on(tester, find.byKey(const ValueKey('result-done')));
    expect(month.count, 3, reason: 'issue the month: Review, Issue, Done');
    expect(fix.count, 3, reason: 'the fix: Fix, Edit identity, Save');
    final issued = {
      for (final i in f.money.invoices)
        if (!issuedBefore.contains(i.id)) i.memberId: i,
    };
    expect(issued.keys, unorderedEquals([demoStudioNord, demoFaridHaddad]));
    expect(issued[demoStudioNord]!.totalCents, 9000, reason: 'two half days');
    expect(
      issued[demoFaridHaddad]!.totalCents,
      -demoReleasedPackCents,
      reason: 'the released pack, credited back: a credit note',
    );
    final nord = issued[demoStudioNord]!;
    expect(nord.memberName, 'Studio Nord');
    expect(nord.memberAddress, contains('14 quai du Nord'));
    expect(issued[demoFaridHaddad]!.memberName, 'Farid Haddad');
    await _home(tester);
    final afterMonth = _card(tester);
    expect(afterMonth, (
      owed: start.owed + nord.totalCents,
      invoiced: start.invoiced + nord.totalCents,
      received: start.received,
    ), reason: 'the invoice is owed and invoiced; the credit note is neither');
    expect(
      find.text('${_en.invoicingInvoiceCount(1)} · €120.00'),
      findsOneWidget,
      reason: 'one credit note to pay out',
    );

    // Share the due reminders by hand: Review, then one Share per line.
    final share = _Touches();
    await openInvoicingTodo(tester); // #4059
    await share.on(
      tester,
      find.byKey(const ValueKey('invoicing-todo-shareReminders')),
    );
    final due = [
      for (final e
          in find
              .byWidgetPredicate(
                (w) =>
                    w.key is ValueKey<String> &&
                    (w.key! as ValueKey<String>).value.startsWith(
                      'reminder-queue-share-',
                    ),
              )
              .evaluate())
        (e.widget.key! as ValueKey<String>).value,
    ];
    expect(due.map(_invoiceOf), unorderedEquals([
      'demo-usage-chiara-extra', 'demo-usage-chiara-c', 'demo-usage-ada-b',
    ]), reason: 'the due reminders include the second same-month invoice');
    final remindedBefore = {
      for (final k in due)
        k: f.money.invoiceReminders[_invoiceOf(k)]?.length ?? 0,
    };
    for (final key in due) {
      await share.on(tester, find.byKey(ValueKey(key)));
    }
    expect(share.count, 4, reason: 'Review, then one Share per due invoice');
    // The queue says what was shared; its Done is the way back, not a send.
    expect(find.byKey(const ValueKey('reminder-queue-result')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('result-done')));
    await _settle(tester);
    for (final key in due) {
      expect(
        f.money.invoiceReminders[_invoiceOf(key)]?.length,
        remindedBefore[key]! + 1,
        reason: '$key: the reminder is recorded once',
      );
    }
    await _home(tester);
    expect(
      find.byKey(const ValueKey('invoicing-todo-shareReminders')),
      findsNothing,
      reason: 'nothing left to share',
    );
    expect(_card(tester), afterMonth, reason: 'a reminder moves no money');

    // Match the payment received by transfer: Review, the customer's Match,
    // the invoice it pays.
    final match = _Touches();
    final beforeMatch = _card(tester);
    await openInvoicingTodo(tester); // #4059
    await match.on(
      tester,
      find.byKey(const ValueKey('invoicing-todo-matchPayments')),
    );
    await match.on(
      tester,
      find.byKey(const ValueKey('invoicing-customer-action-member-2')),
    );
    final candidate = _keysStarting(
      'payment-match-demo-payment-bruno-unmatched-',
    );
    expect(candidate, isNotEmpty, reason: 'the transfer offers its invoice');
    final invoiceId = candidate.first.substring(
      'payment-match-demo-payment-bruno-unmatched-'.length,
    );
    final paidBefore = f.money.invoiceMatchesStore[invoiceId]?.paidCents ?? 0;
    final transfer = f.money.ledger
        .firstWhere((e) => e.id == 'demo-payment-bruno-unmatched')
        .amountCents;
    await match.on(
      tester,
      find.byKey(
        const ValueKey('payment-match-assign-demo-payment-bruno-unmatched'),
      ),
    );
    await match.on(
      tester,
      find.byKey(const ValueKey('assign-payment-confirm')),
    );
    expect(match.count, 4, reason: 'match a payment received: 4 taps');
    expect(
      f.money.invoiceMatchesStore[invoiceId]?.paidCents,
      paidBefore + transfer,
      reason: 'the transfer is matched to the invoice, oldest first',
    );
    // The result's Close and the page's Back are the way home, not the match.
    await tester.tap(find.byKey(const ValueKey('assign-payment-close')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('payment-match-empty')), findsOneWidget);
    await tester.pageBack();
    await _home(tester);
    expect(_card(tester), (
      owed: beforeMatch.owed - transfer,
      invoiced: beforeMatch.invoiced,
      received: beforeMatch.received,
    ), reason: 'owed falls by what was matched; it was already received');

    // Pay out the credit note: Review, the customer, the credit note, Record
    // the refund, Confirm.
    final payout = _Touches();
    final beforePayout = _card(tester);
    await openInvoicingTodo(tester); // #4059
    await payout.on(
      tester,
      find.byKey(const ValueKey('invoicing-todo-payOutRefunds')),
    );
    await payout.on(
      tester,
      find.byKey(const ValueKey('invoicing-customer-$demoFaridHaddad')),
    );
    final note = issuedNote(f);
    await payout.on(
      tester,
      find.byKey(ValueKey('customer-page-invoice-${note.id}')),
    );
    await payout.on(tester, find.byKey(const ValueKey('invoice-page-refund')));
    await payout.on(
      tester,
      find.byKey(const ValueKey('invoice-refund-submit')),
    );
    expect(payout.count, 5, reason: 'pay out a credit note: 5 taps');
    expect(
      f.money.invoiceMatchesStore[note.id]?.resolution,
      'refunded',
      reason: 'the credit note is closed by the refund paid out',
    );
    final refunds = f.money.ledger.where(
      (e) =>
          e.memberId == demoFaridHaddad &&
          e.kind == LedgerKind.charge &&
          e.category == LedgerCategory.refund,
    );
    expect(refunds, hasLength(1), reason: 'the refund is recorded once');
    expect(refunds.single.amountCents, demoReleasedPackCents);
    await _backHome(tester);
    expect(
      _card(tester),
      beforePayout,
      reason: 'the credit note was never counted as owed',
    );
    expect(
      find.text(_en.invoicingCaughtUp),
      findsOneWidget,
      reason: 'nothing left to do',
    );
  });
}

List<String> _keysStarting(String prefix) => [
  for (final e
      in find
          .byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith(prefix),
          )
          .evaluate())
    (e.widget.key! as ValueKey<String>).value,
];

/// Farid's credit note, as issued by the month.
Invoice issuedNote(DemoFixture f) => f.money.invoices.singleWhere(
  (i) => i.memberId == demoFaridHaddad && i.totalCents < 0,
);

String _invoiceOf(String shareKey) =>
    shareKey.substring('reminder-queue-share-'.length);
