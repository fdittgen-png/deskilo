// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4185 -- the counter's receipts screen: what the till made, and the sale whose card answer was lost waiting for someone
// who may see the finances. It reads from the counter's book, and a failed read says so in words with a retry.
import 'package:deskilo/core/demo/data/demo_till.dart';
import 'package:deskilo/features/money/domain/counter_book.dart';
import 'package:deskilo/features/money/presentation/counter_receipts_screen.dart';
import 'package:deskilo/features/money/providers/counter_book_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

class _Broken extends DemoTill implements CounterBookPort {
  _Broken() : super(country: 'FR', currency: 'EUR', vatPercent: 20);

  @override
  Future<CounterBook> book(String workspaceId) => throw StateError('no connection');
}

Future<void> _open(WidgetTester tester, CounterBookPort port, Size size) async {
  await pumpApp(
    tester,
    const CounterReceiptsScreen(workspaceId: 'ws-1'),
    size: size,
    overrides: [...standardTestOverrides(), counterBookPortProvider.overrideWithValue(port)],
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  for (final size in const [Size(390, 800), Size(1440, 900)]) {
    group('the receipts at ${size.width.toInt()}', () {
      testWidgets('the sale waiting for a card answer and the cash sale are listed, with their acts', (tester) async {
        final till = DemoTill(country: 'FR', currency: 'EUR', vatPercent: 20)..seed();
        await _open(tester, till, size);
        expect(find.text(_en.counterSaleWaitingTitle), findsOneWidget);
        final book = await till.book('ws-1');
        final cash = book.issued.single;
        expect(find.byKey(ValueKey('counter-receipt-${cash.id}')), findsOneWidget);
        expect(find.byKey(ValueKey('counter-correct-${cash.id}')), findsOneWidget);
        final card = book.waiting.single.openAuthorizations.single;
        expect(find.byKey(ValueKey('counter-answer-${card.id}')), findsOneWidget);
      });

      testWidgets('a book that cannot be read says so with a retry, and is never shown as empty', (tester) async {
        await _open(tester, _Broken(), size);
        expect(find.text(_en.counterSaleWaitingTitle), findsNothing);
        expect(find.byType(CounterReceiptsScreen), findsOneWidget);
        expect(find.byKey(const ValueKey('read-failure')), findsOneWidget);
        expect(find.byKey(const ValueKey('inline-banner-action')), findsOneWidget);
      });
    });
  }
}
