// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4436 (G21) -- a sale of a traced good names the track ID it was received with. The finalize answers, per goods line,
// the lots it took with their quantities and the pieces by their tags; the till reads that answer and says it under the
// line once sold. On the Demo's counter the oat milk is traced by lot (MILK-12, the lot on hand that is not expired); the
// coffee beans are not, and name nothing.
import 'package:deskilo/app/routes/till_route.dart';
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_ledger.dart';
import 'package:deskilo/core/demo/data/demo_stock_queries.dart';
import 'package:deskilo/core/demo/data/demo_till.dart';
import 'package:deskilo/features/money/domain/counter_till.dart';
import 'package:deskilo/features/money/presentation/till_text.dart';
import 'package:deskilo/features/money/providers/till_providers.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo/l10n/app_localizations_fr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await _settle(tester);
}

void main() {
  group('the finalize answer', () {
    test('reads the lots with their quantities and the pieces by their tags, line by line', () {
      final sold = TillSold.fromJson({
        'receipt_id': 'r-1',
        'number': 'R-00007',
        'currency': 'EUR',
        'totals': {
          'net_minor': '2417',
          'tax_minor': '483',
          'gross_minor': '2900',
          'currency': 'EUR',
        },
        'tenders': 1,
        'lines': [
          {
            'line_no': 1,
            'line_id': 'l-1',
            'tracks': [
              {'kind': 'lot', 'lot_id': 'a', 'code': 'SUP-A', 'quantity': '2'},
              {'kind': 'lot', 'lot_id': 'b', 'code': 'SUP-B', 'quantity': '1'},
            ],
          },
          {
            'line_no': 3,
            'line_id': 'l-3',
            'tracks': [
              {'kind': 'lot', 'lot_id': 'p', 'code': 'SUP-P', 'quantity': '1'},
              {
                'kind': 'piece',
                'piece_id': 'x',
                'code': 'E28068940000401561D6CC01',
                'lot_id': 'p',
              },
            ],
          },
        ],
        'replayed': false,
      });
      expect(
        tillTracksText(_en, sold.tracksOf(1)),
        'Lot SUP-A × 2 · Lot SUP-B × 1',
      );
      expect(
        tillTracksText(_en, sold.tracksOf(3)),
        'Lot SUP-P × 1 · Piece E28068940000401561D6CC01',
      );
      expect(
        sold.tracksOf(2),
        isEmpty,
        reason: 'a line that is not goods, or not traced, names nothing',
      );
      expect(
        tillTracksText(AppLocalizationsFr(), sold.tracksOf(3)),
        'Lot SUP-P × 1 · Pièce E28068940000401561D6CC01',
      );
    });

    test('an answer of a server before the track IDs reads as a sale that names none', () {
      final sold = TillSold.fromJson({
        'receipt_id': 'r-1',
        'number': 'R-00001',
        'totals': {
          'net_minor': '175',
          'tax_minor': '35',
          'gross_minor': '210',
          'currency': 'EUR',
        },
      });
      expect(sold.lines, isEmpty);
      expect(sold.tracksOf(1), isEmpty);
    });
  });

  for (final size in const [Size(390, 844), Size(1440, 900)]) {
    testWidgets(
      'at ${size.width.toInt()} a sold line names the lot it was taken from, an untraced one nothing',
      (tester) async {
        final config = DemoStockConfigCommands('ws-1');
        final ledger = DemoStockLedger('ws-1', config);
        await pumpApp(
          tester,
          const TillRoute(),
          size: size,
          overrides: [
            ...standardTestOverrides(),
            stockQueriesProvider.overrideWithValue(DemoStockQueries(ledger)),
            tillPortProvider.overrideWithValue(
              DemoTill(country: 'FR', currency: 'EUR', vatPercent: 20),
            ),
          ],
        );
        await _settle(tester);
        await _tap(tester, 'till-key-demo-item-milk');
        await _tap(tester, 'till-key-demo-item-beans');
        expect(
          find.byKey(const ValueKey('till-tracks-demo-item-milk')),
          findsNothing,
          reason: 'nothing is taken before the sale',
        );
        await _tap(tester, 'till-pay');
        await tester.enterText(
          find.byKey(const ValueKey('till-cash-given')),
          '50',
        );
        await _tap(tester, 'till-cash-confirm');
        expect(find.text(_en.tillReceiptNumber('R-00001')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('till-tracks-demo-item-milk')),
          findsOneWidget,
        );
        expect(find.text(_en.tillTrackLot('MILK-12', '1')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('till-tracks-demo-item-beans')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await _tap(tester, 'till-next');
        expect(
          find.byKey(const ValueKey('till-tracks-demo-item-milk')),
          findsNothing,
        );
      },
    );
  }
}
