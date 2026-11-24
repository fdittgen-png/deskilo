// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4293 (G7, cut B) -- the Demo's product and place registry for the reference business: its
// shop items with a barcode, unit, price, last known cost, a home address and what the ONE Demo
// ledger holds. A home place is advice kept here: naming one moves nothing in the ledger. The
// rules are the server's: only a real, active place of the business is a home, the filters keep
// what is homed in a place or below it, and a page is bounded and continues from its cursor.
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_config_commands.dart';
import 'package:deskilo/features/stock/domain/stock_page.dart';
import 'package:deskilo/features/stock/domain/stock_registry.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import 'demo_stock_ledger.dart';

class DemoStockRegistry implements StockRegistry {
  DemoStockRegistry(this._workspaceId, this._ledger, this._config);

  final String _workspaceId;
  final DemoStockLedger _ledger;
  final StockConfigCommands _config;

  /// Item id -> (barcode, price in cents, cost in minor units of one inventory unit).
  static const catalogue = <String, (String, int, String?)>{
    'demo-item-beans': ('3017620422003', 2400, '1650'),
    'demo-item-milk': ('3256540000032', 210, '120'),
    'demo-item-mugs': ('4006381333931', 890, null),
    'demo-item-syrup': ('5000112548167', 780, '410'),
  };

  /// Item id -> the place it belongs at: the eye-level shelf of the sales floor, the back room,
  /// the depot's reserve; the syrup has none yet.
  final Map<String, String?> _homes = {
    'demo-item-beans': 'demo-place-eye-shelf',
    'demo-item-milk': 'demo-place-back',
    'demo-item-mugs': 'demo-place-depot-back',
  };

  Future<List<StockPlaceConfig>> _places() => _config.places(_workspaceId);

  /// [place] and every place inside it.
  Set<String> _within(List<StockPlaceConfig> all, String place) {
    final out = {place};
    var grew = true;
    while (grew) {
      grew = false;
      for (final p in all) {
        if (p.parentId != null && out.contains(p.parentId) && out.add(p.id)) grew = true;
      }
    }
    return out;
  }

  @override
  Future<StockPage<StockRegistryRow>> page(
    String workspaceId, {
    String? placeId,
    bool noHome = false,
    int limit = 50,
    StockCursor? after,
  }) async {
    if (workspaceId != _workspaceId) return const StockPage(rows: [], complete: true);
    final places = await _places();
    final byId = {for (final p in places) p.id: p};
    final scope = placeId == null ? null : _within(places, placeId);
    final onHand = await _ledger.onHand();
    final rows = <StockRegistryRow>[];
    for (final item in _ledger.itemList) {
      final entry = catalogue[item.id];
      final home = byId[_homes[item.id]];
      if (noHome && home != null) continue;
      if (scope != null && (home == null || !scope.contains(home.id))) continue;
      var held = ExactQuantity.zero;
      for (final r in onHand) {
        if (r.itemId == item.id && r.variantId == null) held = held + r.quantity;
      }
      rows.add(
        StockRegistryRow(
          itemId: item.id,
          itemName: item.name,
          unit: item.unit,
          barcode: entry?.$1,
          priceCents: entry?.$2,
          cost: entry?.$3,
          costVisible: true,
          homeLocationId: home?.id,
          homeCode: home?.code,
          homeAddressPath: home?.addressPath,
          onHand: held,
        ),
      );
    }
    rows.sort((a, b) => a.itemName.compareTo(b.itemName));
    final from = (after?['offset'] as int?) ?? 0;
    final shown = rows.skip(from).take(limit).toList();
    final more = from + limit < rows.length;
    return StockPage(rows: shown, complete: !more, next: more ? {'version': 1, 'offset': from + limit} : null);
  }

  @override
  Future<void> setHome(
    String workspaceId, {
    required String itemId,
    required String? variantId,
    required String? placeId,
    required String requestId,
  }) async {
    // an item of the catalogue, or a service made an item in this session (#4402)
    if (workspaceId != _workspaceId || (!catalogue.containsKey(itemId) && (await _config.item(workspaceId, itemId))?.stockable != true)) {
      throw const StockConfigRefused('item', StockRefusal.itemUnknown);
    }
    if (placeId != null) {
      final place = (await _places()).where((p) => p.id == placeId).firstOrNull;
      if (place == null || place.virtual || !place.active) {
        throw const StockConfigRefused('home_location_id', StockRefusal.homeInvalid);
      }
    }
    _homes[itemId] = placeId;
  }
}
