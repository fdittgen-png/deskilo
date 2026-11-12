// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — the customer page's statement button, end to end against a fake
// server answer: one currency opens the report actions and its quick view
// shows the document's lines; several currencies ask which one first;
// nothing open says so and prints nothing; a server that did not answer
// says so with Retry, and Retry asks the server again.
import 'package:deskilo/features/money/domain/customer_statement.dart';
import 'package:deskilo/features/money/presentation/customer_statement_print.dart';
import 'package:deskilo/features/money/providers/customer_statement_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

final _l10n = AppLocalizationsEn();

/// The server's answer, counted; [fail] makes it not answer.
class _Reader implements CustomerStatementReader {
  _Reader(this.currencies);

  final List<StatementCurrency> currencies;
  bool fail = false;
  int reads = 0;

  @override
  Future<CustomerStatement> read(
    String workspaceId,
    String memberId,
    DateTime asOf,
  ) async {
    reads++;
    if (fail) throw StateError('the statement could not be read');
    return CustomerStatement(
      memberId: memberId,
      asOf: asOf,
      currencies: currencies,
    );
  }
}

StatementCurrency _in(String currency) => StatementCurrency(
  currency: currency,
  stillDueCents: 6000,
  unappliedCents: 0,
  balanceCents: 6000,
  lines: [
    StatementLine(
      invoiceId: 'a-$currency',
      number: 'F-$currency-1',
      totalCents: 10000,
      stillDueCents: 6000,
      state: StatementLineState.partlyPaid,
      issuedAt: DateTime(2026, 9, 2),
      allocations: const [
        StatementAllocation(paymentId: 'p', amountCents: 4000),
      ],
    ),
  ],
);

Future<void> _open(WidgetTester tester, _Reader reader) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(money: FakeMoneyRepository()),
        customerStatementReaderProvider.overrideWithValue(reader),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              key: const ValueKey('statement'),
              onPressed: () => CustomerStatementPrint(
                context,
                ref,
              ).show(workspaceId: 'ws', customerId: 'm'),
              child: const Text('statement'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('statement')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('one currency: the report actions, and the quick view shows '
      'its lines', (tester) async {
    await _open(tester, _Reader([_in('EUR')]));
    expect(find.byKey(const ValueKey('customer-statement-quick')), findsOne);
    await tester.tap(find.byKey(const ValueKey('customer-statement-quick')));
    await tester.pumpAndSettle();
    expect(find.textContaining('F-EUR-1'), findsWidgets);
    expect(find.textContaining(_l10n.customerStatementStillDue), findsWidgets);
  });

  testWidgets('two currencies: asks which one, and prints only the one '
      'chosen', (tester) async {
    await _open(tester, _Reader([_in('EUR'), _in('KWD')]));
    expect(find.text(_l10n.customerStatementPickCurrency), findsOne);
    expect(find.byKey(const ValueKey('customer-statement-EUR')), findsOne);
    await tester.tap(find.byKey(const ValueKey('customer-statement-KWD')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('customer-statement-quick')));
    await tester.pumpAndSettle();
    expect(find.textContaining('F-KWD-1'), findsWidgets);
    expect(find.textContaining('F-EUR-1'), findsNothing);
  });

  testWidgets('nothing open: says so, and offers nothing to print', (
    tester,
  ) async {
    await _open(tester, _Reader(const []));
    expect(find.text(_l10n.customerStatementNothingOpen), findsOne);
    expect(
      find.byKey(const ValueKey('customer-statement-quick')),
      findsNothing,
    );
  });

  testWidgets('the server did not answer: says so with Retry, and Retry asks '
      'again', (tester) async {
    final reader = _Reader([_in('EUR')])..fail = true;
    await _open(tester, reader);
    expect(
      find.byKey(const ValueKey('customer-statement-quick')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('print-read-retry')), findsOne);
    reader.fail = false;
    await tester.tap(find.byKey(const ValueKey('print-read-retry')));
    await tester.pumpAndSettle();
    expect(reader.reads, 2);
    expect(find.byKey(const ValueKey('customer-statement-quick')), findsOne);
  });
}
