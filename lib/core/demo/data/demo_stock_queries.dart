// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4161 (B) -- the Demo's goods ledger, read through the same port as the
// server's: the reference business keeps a small shop stock (beans by the
// kilogram, oat milk by the litre, mugs, a syrup received in thirds of a
// litre) at two places, with the movements behind each figure. Another Demo
// business keeps none. Pages and cursors work as the server's: a page is
// bounded, says whether it is complete, and continues from the cursor it
// gave.
import 'package:deskilo/features/stock/domain/stock_page.dart';
import 'package:deskilo/features/stock/domain/stock_queries.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

const _main = StockPlace(id: 'demo-place-main', code: 'MAIN', name: 'Main store');
const _shelf = StockPlace(id: 'demo-place-shelf', code: 'SHELF-A', name: 'Shelf A');

const _beans = StockItem(id: 'demo-item-beans', name: 'Coffee beans', unit: 'kg');
const _milk = StockItem(id: 'demo-item-milk', name: 'Oat milk', unit: 'l');
const _mugs = StockItem(id: 'demo-item-mugs', name: 'Mugs', unit: 'piece');
const _syrup = StockItem(id: 'demo-item-syrup', name: 'Syrup', unit: 'l');
// A T-shirt with no stock yet: the item the Demo's variants are edited on.
const _shirt = StockItem(id: 'demo-item-shirt', name: 'T-shirt', unit: 'piece');
const _items = [_beans, _milk, _mugs, _syrup, _shirt];

/// What the Demo business holds, per item and place.
const _balances = <(StockItem, StockPlace, String)>[
  (_beans, _main, '12.5'),
  (_milk, _main, '24'),
  (_mugs, _main, '36'),
  (_mugs, _shelf, '12'),
  (_syrup, _main, '0.999999'),
];

/// One movement of the Demo's story: the item, what was stored and entered,
/// the reason, how long ago, where to, and from where (a supplier when none).
typedef _Story = ({
  int n,
  StockItem item,
  String stored,
  String enteredUnit,
  String entered,
  String reason,
  int daysAgo,
  StockPlace to,
  StockPlace? from,
});

const _stories = <_Story>[
  (n: 7, item: _syrup, stored: '0.333333', enteredUnit: 'third', entered: '1', reason: 'receipt', daysAgo: 3, to: _main, from: null),
  (n: 6, item: _syrup, stored: '0.333333', enteredUnit: 'third', entered: '1', reason: 'receipt', daysAgo: 4, to: _main, from: null),
  (n: 5, item: _syrup, stored: '0.333333', enteredUnit: 'third', entered: '1', reason: 'receipt', daysAgo: 5, to: _main, from: null),
  (n: 4, item: _mugs, stored: '12', enteredUnit: 'piece', entered: '12', reason: 'transfer', daysAgo: 8, to: _shelf, from: _main),
  (n: 3, item: _mugs, stored: '48', enteredUnit: 'piece', entered: '48', reason: 'receipt', daysAgo: 12, to: _main, from: null),
  (n: 2, item: _milk, stored: '24', enteredUnit: 'l', entered: '24', reason: 'receipt', daysAgo: 16, to: _main, from: null),
  (n: 1, item: _beans, stored: '12.5', enteredUnit: 'kg', entered: '12.5', reason: 'receipt', daysAgo: 20, to: _main, from: null),
];

/// The movements behind them, newest first.
final _movements = [for (final s in _stories) _move(s)];

StockMovementRow _move(_Story s) => StockMovementRow(
  workspaceId: 'ws-1',
  id: 'demo-stock-movement-${s.n}',
  itemId: s.item.id,
  itemName: s.item.name,
  lotId: null,
  lotCode: null,
  fromLocationId: s.from?.id ?? 'demo-place-supplier',
  fromLocationCode: s.from?.code ?? 'SUPPLIER',
  toLocationId: s.to.id,
  toLocationCode: s.to.code,
  quantity: ExactQuantity.parse(s.stored),
  unit: s.item.unit,
  enteredQuantity: ExactQuantity.parse(s.entered),
  enteredUnit: s.enteredUnit,
  occurredAt: DateTime.utc(2026, 11).subtract(Duration(days: s.daysAgo)),
  reason: s.reason,
  unitCost: null,
  causes: const {},
);

/// The Demo's stock reads, for the reference business only.
class DemoStockQueries implements StockQueries {
  const DemoStockQueries(this.workspaceId);

  /// The business that keeps the shop stock.
  final String workspaceId;

  bool _mine(String id) => id == workspaceId;

  StockPage<T> _page<T>(List<T> all, int limit, StockCursor? after) {
    final from = (after?['offset'] as int?) ?? 0;
    final rows = all.skip(from).take(limit).toList();
    final more = from + limit < all.length;
    return StockPage(
      rows: rows,
      complete: !more,
      next: more ? {'version': 1, 'offset': from + limit} : null,
    );
  }

  @override
  Future<StockPage<StockOnHandRow>> onHandPage(
    String workspaceId, {
    String? itemId,
    String? locationId,
    int limit = 50,
    StockCursor? after,
  }) async {
    final rows = [
      if (_mine(workspaceId))
        for (final (item, place, quantity) in _balances)
          if ((itemId == null || item.id == itemId) &&
              (locationId == null || place.id == locationId))
            StockOnHandRow(
              workspaceId: workspaceId,
              itemId: item.id,
              itemName: item.name,
              lotId: null,
              lotCode: null,
              locationId: place.id,
              locationCode: place.code,
              locationName: place.name,
              quantity: ExactQuantity.parse(quantity),
              unit: item.unit,
            ),
    ];
    return _page(rows, limit, after);
  }

  @override
  Future<StockPage<StockMovementRow>> movementsPage(
    String workspaceId, {
    String? itemId,
    String? locationId,
    int limit = 50,
    StockCursor? after,
  }) async {
    final rows = [
      if (_mine(workspaceId))
        for (final m in _movements)
          if ((itemId == null || m.itemId == itemId) &&
              (locationId == null ||
                  m.fromLocationId == locationId ||
                  m.toLocationId == locationId))
            m,
    ];
    return _page(rows, limit, after);
  }

  @override
  Future<StockMovementRow?> movement(String workspaceId, String movementId) async =>
      _mine(workspaceId)
          ? _movements.where((m) => m.id == movementId).firstOrNull
          : null;

  @override
  Future<List<StockPlace>> places(String workspaceId) async =>
      _mine(workspaceId) ? const [_main, _shelf] : const [];

  @override
  Future<List<StockItem>> items(String workspaceId) async =>
      _mine(workspaceId) ? _items : const [];
}
