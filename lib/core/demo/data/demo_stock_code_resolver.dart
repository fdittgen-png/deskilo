// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4359 (G10) -- the Demo resolves a scanned code through the same port as the server: a place by its barcode or
// code, an item by its barcode (what the registry shows) or one of its own codes, a package-unit code as the item
// with the unit's exact factor. It reads the Demo's own registry and configuration, so what a person adds there
// is what a scan finds; a code that names nothing is `unknown`, never an error.
import '../../../features/stock/domain/stock_code_resolver.dart';
import '../../../features/stock/domain/stock_config.dart';
import '../../../features/stock/domain/stock_config_commands.dart';
import '../../../features/stock/domain/stock_registry.dart';

class DemoStockCodeResolver implements StockCodeResolver {
  DemoStockCodeResolver(this._workspaceId, this._config, this._registry);

  final String _workspaceId;
  final StockConfigCommands _config;
  final StockRegistry _registry;

  @override
  Future<StockCodeResolution> resolve(String workspaceId, String code) async {
    final typed = code.trim();
    if (workspaceId != _workspaceId || typed.isEmpty) return StockCodeResolution.unknown(typed);
    for (final p in await _config.places(_workspaceId)) {
      if (!p.active) continue;
      final byBarcode = p.barcode != null && p.barcode == typed;
      if (byBarcode || p.code == typed) {
        return StockCodeResolution(
          kind: ScannedKind.place,
          code: typed,
          matchedBy: byBarcode ? 'place_barcode' : 'place_code',
          place: ScannedPlace(id: p.id, code: p.code, name: p.name, kind: p.kind),
        );
      }
    }
    final page = await _registry.page(_workspaceId, limit: 200);
    for (final row in page.rows) {
      if (row.barcode == typed) {
        return StockCodeResolution(
          kind: ScannedKind.item,
          code: typed,
          matchedBy: 'gtin',
          item: ScannedItem(id: row.itemId, name: row.itemName, unit: row.unit),
        );
      }
      final config = await _config.item(_workspaceId, row.itemId);
      final named = config?.codes.where((c) => c.code == typed).firstOrNull;
      if (config == null || named == null) continue;
      final unit = named.unit == null ? null : config.units.where((u) => u.unit == named.unit).firstOrNull;
      return StockCodeResolution(
        kind: ScannedKind.item,
        code: typed,
        matchedBy: unit == null ? 'own_code' : 'unit_code',
        item: ScannedItem(id: row.itemId, name: row.itemName, unit: row.unit),
        unit: unit == null ? null : _scanned(unit),
      );
    }
    return StockCodeResolution.unknown(typed);
  }

  static ScannedUnit _scanned(StockUnitDraft u) => ScannedUnit(unit: u.unit, factorNum: u.factorNum, factorDen: u.factorDen);
}
