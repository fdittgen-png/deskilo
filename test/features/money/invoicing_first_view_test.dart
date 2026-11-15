// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4059 — below desk width the invoicing home sums up in one compact block,
// so its first customer starts inside the first view; each to-do's button
// names its task; a negative amount is named, never a bare minus.
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/i18n/format_controller.dart';
import 'package:deskilo/features/money/application/receivables.dart';
import 'package:deskilo/features/money/application/receivables_answers.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoicing_words.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/demo_journeys.dart' show pumpDemo;

final _firstCustomer = find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      RegExp(r'^invoicing-customer-[^-]')
          .hasMatch((w.key! as ValueKey<String>).value) &&
      !(w.key! as ValueKey<String>).value.contains('-action-') &&
      !(w.key! as ValueKey<String>).value.contains('-panel-'),
  skipOffstage: false,
);

void main() {
  // #4059 — 768×844 is walked in its own file (a second Demo in one file
  // keeps the first one's read of the invoices pending).
  for (final size in const [Size(390, 844)]) {
    testWidgets('at ${size.width.toInt()}×844 the first customer starts in '
        'the first view', (tester) async {
      await pumpDemo(tester, openHub: false, size: size);
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
          .read(routerProvider)
          .go('/invoices');
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      // Read whatever the finder's offstage rule says of the route at 768:
      // the page is the one on screen (its bar reads Invoices).
      final home = find.byKey(
        const ValueKey('invoicing-home'),
        skipOffstage: false,
      );
      expect(home, findsOneWidget);
      expect(find.text('Invoices'), findsWidgets);
      expect(
        find.byKey(const ValueKey('invoicing-summary'), skipOffstage: false),
        findsOneWidget,
      );
      expect(_firstCustomer, findsWidgets);
      final top = tester.getTopLeft(_firstCustomer.first).dy;
      expect(
        top,
        lessThan(tester.getRect(home).bottom),
        reason: 'the first customer is in the first view',
      );
    });
  }

  testWidgets('each to-do names its task', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    String button(TodoKind kind) => todoWordsOf(l, (
      kind: kind,
      tally: const Tally(2, {'EUR': 100}),
    ), 'April').button;
    expect(button(TodoKind.invoiceTheMonth), 'Review April');
    expect(button(TodoKind.shareReminders), 'Share reminders');
    expect(button(TodoKind.confirmPayments), 'Confirm payments');
    expect(button(TodoKind.matchPayments), 'Match payments');
    expect(button(TodoKind.payOutRefunds), 'Pay out refunds');
    expect(button(TodoKind.issueDrafts), 'Issue drafts');
    expect(button(TodoKind.rejectedEInvoices), 'Fix the e-invoices');
    expect(button(TodoKind.keepOriginals), 'Keep them');
  });

  testWidgets('a negative amount is named, and currencies stay side by side', (
    tester,
  ) async {
    late String said;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            said = amountsOf(
              appFormatOf(context),
              const Tally(2, {'EUR': -3000, 'CHF': 12000}),
              credit: (a) => 'credit $a',
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(said, contains('credit'));
    expect(said, isNot(contains('-')));
    expect(said, contains(' · '), reason: 'two currencies, never added');
  });
}
