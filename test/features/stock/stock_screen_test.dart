// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4161 (B) -- the Stock screen as a person uses it, on a phone (390) and on
// a desk (1440): exact quantities by item, lot and place; the next page only
// from the cursor the last one gave; filters that narrow the read; the
// loading, empty and failed states, a failed read never shown as empty; and
// one movement at its address, whose cost a reader without the right is told
// is not shown (not zero).
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:deskilo/core/i18n/format_controller.dart';
import 'package:deskilo/features/stock/application/stock_view.dart';
import 'package:deskilo/features/stock/domain/stock_page.dart';
import 'package:deskilo/features/stock/domain/stock_queries.dart';
import 'package:deskilo/features/stock/domain/stock_trace.dart';
import 'package:deskilo/features/stock/presentation/stock_movement_screen.dart';
import 'package:deskilo/features/stock/presentation/stock_screen.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

StockOnHandRow _row(String item, String place, String quantity, String unit, {String? lot}) =>
    StockOnHandRow(
      workspaceId: 'w',
      itemId: 'i-$item',
      itemName: item,
      lotId: lot == null ? null : 'l-$lot',
      lotCode: lot,
      locationId: 'p-$place',
      locationCode: place,
      locationName: '',
      quantity: ExactQuantity.parse(quantity),
      unit: unit,
    );

StockMovementRow _move(String id, {String? cost}) => StockMovementRow(
  workspaceId: 'w',
  id: id,
  itemId: 'i-Wine',
  itemName: 'Wine',
  lotId: null,
  lotCode: null,
  fromLocationId: 'p-SUPPLIER',
  fromLocationCode: 'SUPPLIER',
  toLocationId: 'p-MAIN',
  toLocationCode: 'MAIN',
  quantity: ExactQuantity.parse('0.333333'),
  unit: 'l',
  enteredQuantity: ExactQuantity.parse('1'),
  enteredUnit: 'third',
  occurredAt: DateTime.utc(2026, 3, 3, 9),
  reason: 'receipt',
  unitCost: cost,
  causes: const {},
);

/// A stock read with pages of two, that can be made to fail.
class _Stock implements StockQueries {
  _Stock({this.rows = const [], this.failPages = 0, this.movements = const []});

  final List<StockOnHandRow> rows;
  final List<StockMovementRow> movements;
  int failPages;
  final asked = <({String? itemId, String? locationId, Object? after})>[];

  StockPage<T> _page<T>(List<T> all, StockCursor? after) {
    final from = (after?['offset'] as int?) ?? 0;
    final more = from + 2 < all.length;
    return StockPage(
      rows: all.skip(from).take(2).toList(),
      complete: !more,
      next: more ? {'version': 1, 'offset': from + 2} : null,
    );
  }

  @override
  Future<StockPage<StockOnHandRow>> onHandPage(String workspaceId, {String? itemId, String? locationId, int limit = 50, StockCursor? after}) async {
    asked.add((itemId: itemId, locationId: locationId, after: after));
    if (failPages > 0) {
      failPages--;
      throw const StockReadException('boom');
    }
    return _page([
      for (final r in rows)
        if ((itemId == null || r.itemId == itemId) && (locationId == null || r.locationId == locationId)) r,
    ], after);
  }

  @override
  Future<StockPage<StockMovementRow>> movementsPage(String workspaceId, {String? itemId, String? locationId, int limit = 50, StockCursor? after}) async =>
      _page(movements, after);

  @override
  Future<StockMovementRow?> movement(String workspaceId, String movementId) async =>
      movements.where((m) => m.id == movementId).firstOrNull;

  @override
  Future<List<StockPlace>> places(String workspaceId) async => const [
    StockPlace(id: 'p-MAIN', code: 'MAIN', name: 'Main'),
    StockPlace(id: 'p-SHELF', code: 'SHELF', name: ''),
  ];

  @override
  Future<List<StockItem>> items(String workspaceId) async => const [
    StockItem(id: 'i-Wine', name: 'Wine', unit: 'l'),
  ];

  @override
  Future<List<StockItem>> unstocked(String workspaceId) async => const [];
}

/// The trace of a movement with no purchase behind it (the movement page also reads its trace).
class _NoPurchase implements StockTraceReader {
  @override
  Future<StockTraceAnswer> trace(String workspaceId, String movementId) async => StockTraceAnswer(
    truncated: false,
    traces: [
      StockTrace(
        movementId: movementId,
        quantity: ExactQuantity.zero,
        reason: 'receipt',
        cost: null,
        purchase: const TracePurchase(state: TraceState.notLinked, billsState: TraceState.notLinked, bills: [], billsTruncated: false),
      ),
    ],
  );

  @override
  Future<DocumentGoods> documentGoods(String workspaceId, String kind, String id, {int limit = 50, Map<String, Object?>? after}) async =>
      const DocumentGoods(state: TraceState.notLinked, rows: [], more: false);

  @override
  Future<StockValuation> valuation(String workspaceId, {DateTime? at}) => throw UnimplementedError();
}

Future<void> _open(WidgetTester tester, _Stock stock, Size size, {Widget? home, Set<WorkspacePermission>? held, AppFormat? format}) async {
  await pumpApp(
    tester,
    home ?? const StockScreen(),
    size: size,
    overrides: [
      // a test that pins its own format replaces the standard one
      ...standardTestOverrides(pinFormats: format == null),
      stockQueriesProvider.overrideWithValue(stock),
      stockTraceReaderProvider.overrideWithValue(_NoPurchase()),
      if (held != null) myPermissionsProvider.overrideWithValue(held),
      if (format != null) ...[appFormatProvider.overrideWithValue(format), personalFormatProvider.overrideWithValue(format)],
    ],
  );
  await tester.pumpAndSettle();
}

const _phone = Size(390, 844);
const _desk = Size(1440, 900);

void main() {
  for (final (name, size) in [('phone', _phone), ('desk', _desk)]) {
    group('on a $name', () {
      testWidgets('exact quantities by item, place and lot, and the next page from its cursor', (tester) async {
        final stock = _Stock(rows: [
          _row('Beans', 'MAIN', '12.5', 'kg'),
          _row('Wine', 'MAIN', '0.999999', 'l'),
          _row('Juice', 'MAIN', '4', 'piece', lot: 'A'),
        ]);
        await _open(tester, stock, size);
        expect(find.text('12.5 kg'), findsOneWidget);
        expect(find.text('0.999999 l'), findsOneWidget, reason: 'three thirds, exactly');
        expect(find.text('MAIN · ${_en.stockNoLot}'), findsNWidgets(2));
        expect(find.byKey(const ValueKey('stock-more')), findsOneWidget, reason: 'the page is not complete: it says so');
        expect(find.text('4 piece'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('stock-more')));
        await tester.pumpAndSettle();
        expect(find.text('4 piece'), findsOneWidget);
        expect(find.text('MAIN · ${_en.stockLotLabel('A')}'), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-more')), findsNothing);
        expect(stock.asked.map((a) => (a.after as Map?)?['offset']), [null, 2],
            reason: 'the second page asks from the cursor the first gave');
        expect(find.text('12.5 kg'), findsOneWidget, reason: 'no row repeated');
      });

      testWidgets('a filter narrows the read and an empty result says so', (tester) async {
        final stock = _Stock(rows: [_row('Beans', 'MAIN', '1', 'kg')]);
        await _open(tester, stock, size);
        await tester.tap(find.byKey(const ValueKey('stock-filter-place')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('SHELF').last);
        await tester.pumpAndSettle();
        expect(stock.asked.last.locationId, 'p-SHELF');
        expect(find.byKey(const ValueKey('stock-empty')), findsOneWidget);
        expect(find.text(_en.stockEmptyFiltered), findsOneWidget);
      });

      testWidgets('a failed first read is not an empty list, and the same page can be asked again', (tester) async {
        final stock = _Stock(rows: [_row('Beans', 'MAIN', '1', 'kg')], failPages: 1);
        await _open(tester, stock, size);
        expect(find.byKey(const ValueKey('stock-failed')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-empty')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('stock-retry')));
        await tester.pumpAndSettle();
        expect(find.text('1 kg'), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-failed')), findsNothing);
      });

      testWidgets('a failed next page keeps the rows shown and offers the same page again', (tester) async {
        final stock = _Stock(rows: [
          _row('Beans', 'MAIN', '1', 'kg'),
          _row('Wine', 'MAIN', '2', 'l'),
          _row('Mugs', 'MAIN', '3', 'piece'),
        ]);
        await _open(tester, stock, size);
        stock.failPages = 1;
        await tester.tap(find.byKey(const ValueKey('stock-more')));
        await tester.pumpAndSettle();
        expect(find.text('1 kg'), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-more-failed')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('stock-more-retry')));
        await tester.pumpAndSettle();
        expect(find.text('3 piece'), findsOneWidget);
        expect(stock.asked.where((a) => (a.after as Map?)?['offset'] == 2).length, 2,
            reason: 'the retry asks the same cursor');
      });

      testWidgets('nothing in stock reads as nothing, not as an error', (tester) async {
        await _open(tester, _Stock(), size);
        expect(find.text(_en.stockEmpty), findsOneWidget);
      });

      testWidgets('the movement log lists the movements with their exact quantity', (tester) async {
        final stock = _Stock(movements: [_move('m-1'), _move('m-2')]);
        await _open(tester, stock, size, home: const StockScreen(tab: StockTab.movements));
        await tester.pumpAndSettle();
        expect(find.text('0.333333 l'), findsNWidgets(2));
        expect(find.byKey(const ValueKey('stock-movement-m-1')), findsOneWidget);
      });

      // #4427 -- the date follows the member's format locale, not the interface language
      testWidgets('an English screen with a German format shows the movement on 3.3.2026', (tester) async {
        final stock = _Stock(movements: [_move('m-1')]);
        await _open(tester, stock, size,
            home: const StockScreen(tab: StockTab.movements), format: const AppFormat(locale: 'de_DE', currencyCode: 'EUR'));
        await tester.pumpAndSettle();
        expect(find.text(_en.stockTabMovements), findsWidgets, reason: 'the interface is English');
        expect(find.textContaining('3.3.2026'), findsOneWidget);
        expect(find.textContaining('3/3/2026'), findsNothing);
      });
    });
  }

  group('one movement at its address', () {
    testWidgets('shows what moved, stored and entered, and the cost to a reader who may see it', (tester) async {
      final stock = _Stock(movements: [_move('m-1', cost: '250.5')]);
      await _open(tester, stock, _phone,
          home: const StockMovementScreen(movementId: 'm-1'),
          held: {WorkspacePermission.viewStock, WorkspacePermission.viewFinances});
      expect(find.text('0.333333 l'), findsOneWidget);
      expect(find.text('1 third'), findsOneWidget, reason: 'what was entered, beside what is stored');
      expect(find.textContaining('2.505'), findsOneWidget, reason: '250.5 minor units, as a major amount');
    });

    testWidgets('a reader without finance rights is told the cost is not shown, never a zero', (tester) async {
      final stock = _Stock(movements: [_move('m-1')]);
      await _open(tester, stock, _phone,
          home: const StockMovementScreen(movementId: 'm-1'),
          held: {WorkspacePermission.viewStock});
      expect(find.text(_en.stockCostNotShown), findsOneWidget);
      expect(find.textContaining('0.00'), findsNothing);
    });

    testWidgets('an address that is no movement says so', (tester) async {
      await _open(tester, _Stock(), _desk,
          home: const StockMovementScreen(movementId: 'nothing'),
          held: {WorkspacePermission.viewStock});
      expect(find.byKey(const ValueKey('stock-movement-none')), findsOneWidget);
    });

    test('a cost in minor units is shown as the major amount it is, with no float', () {
      expect(stockCostText('250.5', 'EUR'), '2.505 EUR');
      expect(stockCostText('100', 'EUR'), '1.00 EUR');
      expect(stockCostText('5', 'EUR'), '0.05 EUR');
      expect(stockCostText('1.5', 'JPY'), '1.5 JPY');
    });
  });
}
