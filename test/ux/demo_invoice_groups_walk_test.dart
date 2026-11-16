// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3556 (part 2) — the Demo walked: Ada files an invoice of a euro business
// and one of the Zurich business, in francs, in a group of her own; the
// group narrows My finances to those two and its header shows one total
// per currency, never one figure across them. The group lives on her
// personal home: no business's invoice changes.
import 'package:deskilo/features/money/domain/finance_filter.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:deskilo/features/money/providers/finance_overview_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/screens/demo_journeys.dart';
import '../helpers/screens/desk_calendar.dart' show goTo;

Future<void> _pumps(WidgetTester tester, [int times = 10]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void _closeSheet(WidgetTester tester) => Navigator.of(
  tester.element(find.byKey(const ValueKey('invoice-group-sheet'))),
).pop();

/// My finances' tabs: Outstanding, Paid, Payments, Reminders.
TabController _tabs(WidgetTester tester) => DefaultTabController.of(
  tester.element(
    find.byWidgetPredicate((w) => w is TabBarView, skipOffstage: false).first,
  ),
);

Future<void> _file(WidgetTester tester, FinanceInvoice invoice) async {
  final button = find.byKey(ValueKey('finances-group-${invoice.id}'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await _pumps(tester, 5);
}

void main() {
  testWidgets('Ada files a euro invoice and a franc invoice in one group: '
      'two totals, the lists narrowed to them', (tester) async {
    final journey = await pumpDemo(tester, openHub: false);
    await goTo(tester, '/me/data?view=finances');
    await _pumps(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    final overview = container.read(financeOverviewProvider).requireValue;
    final owed = overview.outstanding;
    final eur = owed.firstWhere((i) => i.currency == 'EUR');
    // the Zurich business's invoice in francs, owed or paid
    final chf = newestFirst(overview.invoices.where((i) => i.currency == 'CHF'))
        .first;

    await _file(tester, eur);
    await tester.enterText(
      find.byKey(const ValueKey('invoice-group-new-name')),
      'To reimburse',
    );
    await tester.tap(find.byKey(const ValueKey('invoice-group-create')));
    await _pumps(tester, 5);
    _closeSheet(tester);
    await _pumps(tester, 5);

    // only the Zurich business's documents, as a person narrows the list
    final zurich = find.byKey(ValueKey('finances-filter-${chf.workspaceId}'));
    await tester.ensureVisible(zurich);
    await tester.tap(zurich);
    await _pumps(tester, 5);
    // the francs invoice is paid: on the Paid tab (the second)
    if (!chf.state.owed) {
      _tabs(tester).animateTo(1);
      await _pumps(tester, 5);
    }
    await _file(tester, chf);
    await tester.tap(
      find.byKey(const ValueKey('invoice-group-toggle-group-1')),
    );
    await _pumps(tester, 5);
    _closeSheet(tester);
    await _pumps(tester, 5);
    final all = find.byKey(const ValueKey('finances-filter-all'));
    await tester.ensureVisible(all);
    await tester.tap(all);
    await _pumps(tester, 5);

    final stored = (await journey.fixture.invoiceGroups.groups()).single;
    expect(stored.name, 'To reimburse');
    expect(stored.items.map((i) => i.ref.invoiceId), [eur.id, chf.id]);

    await tester.tap(
      find.byKey(const ValueKey('finances-group-filter-group-1')),
    );
    await _pumps(tester, 5);
    _tabs(tester).animateTo(0);
    await _pumps(tester, 5);
    final header = find.byKey(const ValueKey('finances-group-header'));
    expect(
      find.descendant(of: header, matching: find.text('2 invoices')),
      findsOneWidget,
    );
    final totals = tester
        .widget<Text>(find.byKey(const ValueKey('finances-group-totals')))
        .data!;
    expect(totals.split(' · '), hasLength(2), reason: 'one total per currency');
    expect(totals, contains('CHF'));
    expect(find.byKey(ValueKey('finances-invoice-${eur.id}')), findsOneWidget);
    final others = owed.where((i) => i.id != eur.id && i.id != chf.id);
    for (final other in others) {
      expect(
        find.byKey(ValueKey('finances-invoice-${other.id}')),
        findsNothing,
      );
    }
  });
}
