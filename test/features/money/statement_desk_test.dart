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

Future<void> _pump(WidgetTester tester) => pumpStateScreen(
  tester,
  const Scaffold(
    body: StatementDesk(statement: _statement, currencyCode: 'EUR'),
  ),
  overrides: standardTestOverrides(),
  size: const Size(1440, 1200),
);

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
}
