// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4053 — in the Demo's reference business, the matches by reference are
// shown before they are confirmed: each movement with the invoice it
// settles, and a total per currency. Cancel writes nothing; Confirm writes
// exactly the listed matches. When one is refused, the result says it per
// movement.
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/demo/data/bank_statement_repository.dart';
import 'package:deskilo/features/money/domain/bank/bank_records.dart';
import 'package:deskilo/features/money/providers/bank_statement_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/screens/demo_journeys.dart' show pumpDemo;

Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 15; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Opens the Demo's notification statement; answers the bank fake and it.
Future<(FakeBankStatementRepository, StoredBankStatement)> _open(
  WidgetTester tester,
) async {
  await pumpDemo(tester, openHub: false);
  final container = ProviderScope.containerOf(
    tester.element(find.byType(Scaffold).first),
  );
  final bank = container.read(
    bankStatementRepositoryProvider,
  ) as FakeBankStatementRepository;
  container.read(routerProvider).go('/money/cash');
  await _settle(tester);
  await tester.tap(find.byKey(const ValueKey('bank-statements-button')));
  await _settle(tester);
  final statement = (await bank.fetchStatements('ws-1'))
      .singleWhere((s) => s.statementRef == 'DEMO-NTFCTN-1');
  await tester.tap(find.byKey(ValueKey('bank-statement-${statement.id}')));
  await _settle(tester);
  return (bank, statement);
}

Future<List<StoredBankLine>> _matched(
  FakeBankStatementRepository bank,
  StoredBankStatement statement,
) async => [
  for (final l in await bank.fetchLines(statement.id))
    if (l.status == BankLineStatus.matched) l,
];

void main() {
  testWidgets('the matches are listed with a total per currency; Cancel '
      'writes nothing and Confirm writes exactly them', (tester) async {
    final (bank, statement) = await _open(tester);
    await tester.tap(find.byKey(const ValueKey('bank-confirm-references')));
    await _settle(tester);

    final dialog = find.byKey(const ValueKey('bank-batch'));
    expect(dialog, findsOneWidget);
    final listed = find.descendant(
      of: dialog,
      matching: find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('bank-batch-line-'),
      ),
    );
    expect(listed, findsNWidgets(2));
    expect(
      find.descendant(
        of: dialog,
        matching: find.byKey(const ValueKey('bank-batch-total-EUR')),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('bank-batch-cancel')));
    await _settle(tester);
    expect(await _matched(bank, statement), isEmpty, reason: 'nothing sent');

    await tester.tap(find.byKey(const ValueKey('bank-confirm-references')));
    await _settle(tester);
    final ids = [
      for (final e in listed.evaluate())
        (e.widget.key! as ValueKey<String>).value.substring(
          'bank-batch-line-'.length,
        ),
    ];
    await tester.tap(find.byKey(const ValueKey('bank-batch-confirm')));
    await _settle(tester);
    expect(
      [for (final l in await _matched(bank, statement)) l.id],
      unorderedEquals(ids),
      reason: 'exactly the movements listed',
    );
  });

  testWidgets('a movement refused meanwhile is said per line', (tester) async {
    final (bank, statement) = await _open(tester);
    await tester.tap(find.byKey(const ValueKey('bank-confirm-references')));
    await _settle(tester);
    final refused = (await bank.fetchLines(statement.id))
        .firstWhere((l) => l.isMoneyIn && l.status.isOpen);
    bank.mayMatch = (id) => id != refused.id;
    await tester.tap(find.byKey(const ValueKey('bank-batch-confirm')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('bank-batch-result')), findsOneWidget);
    expect(find.text('1 match was confirmed'), findsOneWidget);
    final line = find.byKey(ValueKey('bank-batch-result-${refused.id}'));
    expect(
      find.descendant(of: line, matching: find.textContaining('not confirmed')),
      findsOneWidget,
    );
    expect(await _matched(bank, statement), hasLength(1));
  });
}
