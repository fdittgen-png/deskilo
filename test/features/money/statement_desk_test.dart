// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3627 — the month at the desk: the statement's figures as tiles over its
// lines, every line a figure the server computed, signed as the balance —
// so the lines add up to the balance shown above them. A tile shows its own
// lines.
import 'package:deskilo/features/money/domain/statement.dart';
import 'package:deskilo/features/money/presentation/widgets/statement_desk.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/read_probe.dart';

const _statement = Statement(
  period: '2026-05',
  subscriptionPct: 100,
  feeCents: 20000,
  includedHalfDays: 20,
  openDays: 21,
  usedHalfDays: 24,
  extraHalfDays: 4,
  overageCents: 6000,
  creditsCents: 15000,
  // 15000 − 20000 − 6000 − 1200 − 800
  balanceCents: -13000,
  accessorySupplementCents: 1200,
  deskSupplementCents: 800,
);

Future<void> _pump(
  WidgetTester tester, {
  Statement statement = _statement,
  Size size = const Size(1440, 1200),
}) => pumpStateScreen(
  tester,
  Scaffold(
    body: StatementDesk(statement: statement, currencyCode: 'EUR'),
  ),
  overrides: standardTestOverrides(),
  size: size,
);

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void main() {
  test('the lines are the statement\'s own figures and add up to its '
      'balance', () {
    final lines = statementLines(AppLocalizationsEn(), _statement);
    expect(lines.map((l) => l.id), [
      'fee',
      'overage',
      'accessories',
      'desks',
      'credits',
    ], reason: 'a supplement of zero is not a line');
    expect(
      lines.fold<int>(0, (sum, l) => sum + l.cents),
      _statement.balanceCents,
    );
  });

  testWidgets('the balance above equals the total of the lines under it; a '
      'tile shows its own lines, chosen again all of them', (tester) async {
    await _pump(tester);
    await tester.pumpAndSettle();
    final balance = tester
        .widget<Text>(find.byKey(const ValueKey('statement-desk-balance')))
        .data;
    final total = tester
        .widget<Text>(find.byKey(const ValueKey('records-total-EUR')))
        .data;
    expect(total, balance);
    expect(find.byKey(const ValueKey('statement-desk-used')), findsOneWidget);

    final en = AppLocalizationsEn();
    await tester.tap(find.byKey(const ValueKey('statement-desk-tile-credits')));
    await tester.pumpAndSettle();
    expect(
      find.text(en.ledgerCategorySubscription),
      findsOneWidget,
      reason: 'the tile keeps its label; the table shows only credits',
    );
    expect(find.text(en.billAccessorySupplements), findsNothing);

    await tester.tap(find.byKey(const ValueKey('statement-desk-tile-credits')));
    await tester.pumpAndSettle();
    expect(find.text(en.billAccessorySupplements), findsOneWidget);
  });

  testWidgets('the usage tile names its unit and the balance says owed; the '
      'tiles carry the rows\' sign', (tester) async {
    await _pump(tester);
    await tester.pump(const Duration(milliseconds: 300));
    final en = AppLocalizationsEn();
    expect(_text(tester, 'statement-desk-used'), '24 of 20 half-days');
    expect(en.statementDeskUsed(14, 36), '14 of 36 half-days');
    expect(en.statementDeskUsed(1, 1), '1 of 1 half-day');
    expect(find.text(en.statementDeskBalanceOwed), findsOneWidget);
    expect(find.text(en.statementDeskBalanceCredit), findsNothing);
    final subscription = find.descendant(
      of: find.byKey(const ValueKey('statement-desk-tile-subscription')),
      matching: find.textContaining('200'),
    );
    final row = find.descendant(
      of: find.byKey(const ValueKey('statement-desk-lines')),
      matching: find.textContaining('200'),
    );
    expect(tester.widget<Text>(subscription).data, startsWith('-'));
    expect(
      tester.widget<Text>(row.first).data,
      tester.widget<Text>(subscription).data,
      reason: 'the tile and its row use the same sign',
    );
  });

  testWidgets('a positive balance reads as a credit, a zero one as settled',
      (tester) async {
    final en = AppLocalizationsEn();
    await _pump(tester, statement: _statement.copyWith(balanceCents: 500));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(en.statementDeskBalanceCredit), findsOneWidget);
    await _pump(tester, statement: _statement.copyWith(balanceCents: 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(en.statementDeskBalanceSettled), findsOneWidget);
  });

  testWidgets('a month with only the subscription and credits shows no table '
      'repeating the tiles', (tester) async {
    await _pump(
      tester,
      statement: _statement.copyWith(
        overageCents: 0,
        accessorySupplementCents: 0,
        deskSupplementCents: 0,
        balanceCents: -5000,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('statement-desk-lines')), findsNothing);
    expect(
      find.byKey(const ValueKey('statement-desk-no-movements')),
      findsOneWidget,
    );
  });

  testWidgets('at phone width the tiles read whole and nothing overflows', (
    tester,
  ) async {
    await _pump(tester, size: const Size(390, 844));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(_text(tester, 'statement-desk-used'), '24 of 20 half-days');
  });
}
