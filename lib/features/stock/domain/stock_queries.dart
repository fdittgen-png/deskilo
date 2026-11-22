// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4161 (A1) -- the port of the stock reads: bounded pages, never a whole
// ledger. The caller keeps its filters between pages and hands back the
// cursor it was given.
import 'stock_page.dart';

abstract interface class StockQueries {
  /// What is on hand at the real places: at most [limit] rows (1..200).
  Future<StockPage<StockOnHandRow>> onHandPage(
    String workspaceId, {
    String? itemId,
    String? locationId,
    int limit = 50,
    StockCursor? after,
  });

  /// The movements, newest first: at most [limit] rows (1..200).
  Future<StockPage<StockMovementRow>> movementsPage(
    String workspaceId, {
    String? itemId,
    String? locationId,
    int limit = 50,
    StockCursor? after,
  });

  /// The places of the business, for a filter.
  Future<List<StockPlace>> places(String workspaceId);

  /// The stock items of the business, for a filter.
  Future<List<StockItem>> items(String workspaceId);

  /// #4350 -- the services of the business that are not kept in stock yet: what an owner may start
  /// keeping as an item (a service is made an item by turning its stock setting on).
  Future<List<StockItem>> unstocked(String workspaceId);

  /// One movement by its address, or null when there is none (an id of
  /// nothing or of another business).
  Future<StockMovementRow?> movement(String workspaceId, String movementId);
}

/// A page the server answered in a shape this reader cannot trust: never an
/// empty page, never a truncated list.
class StockReadException implements Exception {
  const StockReadException(this.detail);

  final String detail;

  @override
  String toString() => 'StockReadException($detail)';
}
