// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4161 (B) -- the Demo's goods ledger, read through the same port as the
// server's. The figures are not its own: they are the ONE Demo ledger's
// (demo_stock_ledger.dart), so what a delivery put away or a transfer moved is
// what these pages show. Another Demo business keeps none. Pages and cursors
// work as the server's: a page is bounded, says whether it is complete, and
// continues from the cursor it gave.
import 'package:deskilo/features/stock/domain/stock_page.dart';
import 'package:deskilo/features/stock/domain/stock_queries.dart';

import 'demo_stock_ledger.dart';

/// The Demo's stock reads, for the reference business only.
class DemoStockQueries implements StockQueries {
  const DemoStockQueries(this._ledger);

  final DemoStockLedger _ledger;

  /// The business that keeps the shop stock.
  String get workspaceId => _ledger.workspaceId;

  bool _mine(String id) => _ledger.mine(id);

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
    final rows = _mine(workspaceId)
        ? await _ledger.onHand(itemId: itemId, locationId: locationId)
        : <StockOnHandRow>[];
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
        for (final m in _ledger.movements)
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
          ? _ledger.movements.where((m) => m.id == movementId).firstOrNull
          : null;

  @override
  Future<List<StockPlace>> places(String workspaceId) async =>
      _mine(workspaceId) ? _ledger.filterPlaces() : const [];

  @override
  Future<List<StockItem>> items(String workspaceId) async =>
      _mine(workspaceId) ? _ledger.itemList : const [];

  @override
  Future<List<StockItem>> unstocked(String workspaceId) async =>
      _mine(workspaceId) ? await _ledger.candidates?.unstocked() ?? const [] : const [];
}
