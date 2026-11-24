// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4359 (G10) -- the Demo resolves a scanned code through the same port as the server: a place by its barcode or
// code, an item by its barcode (what the registry shows) or one of its own codes, a package-unit code as the item
// with the unit's exact factor. It reads the Demo's own registry and configuration, so what a person adds there
// is what a scan finds; a code that names nothing is `unknown`, never an error.
import '../../../features/stock/domain/stock_code_resolver.dart';
import '../../../features/stock/domain/stock_config.dart';
import '../../../features/stock/domain/stock_config_commands.dart';
import '../../../features/stock/domain/stock_page.dart';
import '../../../features/stock/domain/stock_registry.dart';
import '../../../features/stock/domain/stock_tags.dart';
import 'demo_stock_tags.dart';

class DemoStockCodeResolver implements StockCodeResolver {
  DemoStockCodeResolver(this._workspaceId, this._config, this._registry, [this._tags]);

  final String _workspaceId;
  final StockConfigCommands _config;
  final StockRegistry _registry;
  final DemoStockTags? _tags;

  @override
  Future<StockCodeResolution> resolve(String workspaceId, String code) async {
    final typed = code.trim();
    if (workspaceId != _workspaceId || typed.isEmpty) return StockCodeResolution.unknown(typed);
    final held = _tags?.ownerOf(DemoStockTags.normalise(typed));
    final places = await _config.places(_workspaceId);
    return await _place(places, typed, held) ?? await _item(typed, held) ?? StockCodeResolution.unknown(typed);
  }

  /// A place by its tag, barcode or code.
  Future<StockCodeResolution?> _place(List<StockPlaceConfig> places, String typed, TagOwner? held) async {
    for (final p in places) {
      if (!p.active) continue;
      final byTag = held?.locationId == p.id;
      final byBarcode = p.barcode != null && p.barcode == typed;
      if (!byTag && !byBarcode && p.code != typed) continue;
      return StockCodeResolution(
        kind: byTag ? ScannedKind.tag : ScannedKind.place,
        code: byTag ? DemoStockTags.normalise(typed) : typed,
        matchedBy: byTag ? 'tag' : (byBarcode ? 'place_barcode' : 'place_code'),
        place: ScannedPlace(id: p.id, code: p.code, name: p.name, kind: p.kind),
        tagBound: byTag,
      );
    }
    return null;
  }

  /// An item by its tag, barcode or one of its own codes (a package-unit code carries its factor).
  Future<StockCodeResolution?> _item(String typed, TagOwner? held) async {
    StockCursor? after;
    var complete = false;
    while (!complete) {
      final page = await _registry.page(_workspaceId, limit: 200, after: after);
      final found = await _inPage(page.rows, typed, held);
      if (found != null) return found;
      complete = page.complete || page.next == null;
      after = page.next;
    }
    return null;
  }

  /// The row of [rows] that [typed] names, if any.
  Future<StockCodeResolution?> _inPage(List<StockRegistryRow> rows, String typed, TagOwner? held) async {
    for (final row in rows) {
      final item = ScannedItem(id: row.itemId, name: row.itemName, unit: row.unit);
      if (held?.itemId == row.itemId) {
        final norm = DemoStockTags.normalise(typed);
        return StockCodeResolution(
          kind: ScannedKind.tag,
          code: norm,
          matchedBy: 'tag',
          item: item,
          tagBound: true,
          tagOwnerKind: _tags?.pieceItemOf(norm) != null ? 'piece' : held?.kind,
        );
      }
      if (row.barcode == typed) return StockCodeResolution(kind: ScannedKind.item, code: typed, matchedBy: 'gtin', item: item);
      final config = await _config.item(_workspaceId, row.itemId);
      final named = config?.codes.where((c) => c.code == typed).firstOrNull;
      if (config == null || named == null) continue;
      final unit = named.unit == null ? null : config.units.where((u) => u.unit == named.unit).firstOrNull;
      return StockCodeResolution(
        kind: ScannedKind.item,
        code: typed,
        matchedBy: unit == null ? 'own_code' : 'unit_code',
        item: item,
        unit: unit == null ? null : _scanned(unit),
      );
    }
    return null;
  }

  static ScannedUnit _scanned(StockUnitDraft u) => ScannedUnit(unit: u.unit, factorNum: u.factorNum, factorDen: u.factorDen);
}
