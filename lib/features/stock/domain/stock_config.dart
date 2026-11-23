// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4169 (A1) -- what an operator edits of the stock configuration: an item's
// stock metadata with its package units and codes, and the business's places.
// Each save names the revision it read; the server refuses a stale one, and
// refuses a content that is not valid with the field and the reason, so the
// screen can show it under that field.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// A package unit of one item: `factorNum / factorDen` of its inventory unit.
class StockUnitDraft {
  const StockUnitDraft({
    required this.unit,
    required this.factorNum,
    required this.factorDen,
    this.defaultPurchase = false,
    this.defaultSale = false,
  });

  final String unit;
  final int factorNum;
  final int factorDen;
  final bool defaultPurchase;
  final bool defaultSale;

  Map<String, Object?> toJson() => {
    'unit': unit,
    'factor_num': factorNum,
    'factor_den': factorDen,
    'default_purchase': defaultPurchase,
    'default_sale': defaultSale,
  };

  factory StockUnitDraft.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'item_units');
    return StockUnitDraft(
      unit: r.string('unit'),
      factorNum: r.integer('factor_num'),
      factorDen: r.integer('factor_den'),
      defaultPurchase: r.boolOr('default_purchase', fallback: false),
      defaultSale: r.boolOr('default_sale', fallback: false),
    );
  }
}

/// A code of one item: a GTIN (with its check digit) or the business's own.
class StockCodeDraft {
  const StockCodeDraft({required this.code, required this.kind, this.unit});

  final String code;

  /// `gtin` or `own`.
  final String kind;

  /// The package unit the code names; null is the inventory unit.
  final String? unit;

  Map<String, Object?> toJson() => {'code': code, 'kind': kind, 'unit': unit};

  factory StockCodeDraft.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'item_codes');
    return StockCodeDraft(
      code: r.string('code'),
      kind: r.string('kind'),
      unit: r.stringOrNull('unit'),
    );
  }
}

/// The stock side of one item, as read and as saved.
class StockItemConfig {
  const StockItemConfig({
    required this.itemId,
    required this.revision,
    required this.stockable,
    required this.purchasable,
    required this.sellable,
    required this.inventoryUnit,
    required this.tracking,
    required this.shelfLifeDays,
    required this.units,
    required this.codes,
  });

  final String itemId;
  final int revision;
  final bool stockable;
  final bool purchasable;
  final bool sellable;
  final String inventoryUnit;

  /// `none`, `lot` or `expiry`.
  final String tracking;
  final int? shelfLifeDays;
  final List<StockUnitDraft> units;
  final List<StockCodeDraft> codes;

  /// The body of a save: the lists sent are the complete lists.
  Map<String, Object?> toSave() => {
    'stockable': stockable,
    'purchasable': purchasable,
    'sellable': sellable,
    'inventory_unit': inventoryUnit,
    'tracking': tracking,
    'shelf_life_days': shelfLifeDays,
    'units': [for (final u in units) u.toJson()],
    'codes': [for (final c in codes) c.toJson()],
  };
}

/// A place of the business, as read and as saved.
class StockPlaceConfig {
  const StockPlaceConfig({
    required this.id,
    required this.revision,
    required this.kind,
    required this.code,
    required this.name,
    required this.barcode,
    required this.parentId,
    required this.active,
    required this.virtual,
    this.receivesFromSuppliers = true,
    this.pickRole,
    String? addressPath,
  }) : addressPath = addressPath ?? code;

  final String id;
  final int revision;
  final String kind;
  final String code;
  final String name;
  final String? barcode;
  final String? parentId;
  final bool active;

  /// A virtual place (supplier, customer, loss, opening) is the server's.
  final bool virtual;

  /// A site only: whether goods are put away here from a supplier (false: by transfer only).
  final bool receivesFromSuppliers;

  /// A place below a site: `picking` (front of house) or `reserve` (overstock); null: not said.
  final String? pickRole;

  /// The codes of the place and of everything above it, joined by [stockAddressJoint]: the
  /// server's composed address. The person reads it through [stockAddress].
  final String addressPath;

  factory StockPlaceConfig.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_locations');
    return StockPlaceConfig(
      id: r.string('id'),
      revision: r.integer('revision'),
      kind: r.string('kind'),
      code: r.string('code'),
      name: r.stringOr('name'),
      barcode: r.stringOrNull('barcode'),
      parentId: r.stringOrNull('parent_id'),
      active: r.boolOr('active', fallback: true),
      virtual: r.boolOr('virtual', fallback: false),
      receivesFromSuppliers: r.boolOr('receives_from_suppliers', fallback: true),
      pickRole: r.stringOrNull('pick_role'),
      addressPath: r.stringOrNull('address_path'),
    );
  }
}

/// What the server joins the codes of an address with (the unit separator); never shown.
const String stockAddressJoint = '\u001f';

/// The address of [place] as the person reads it: its codes from the site down, joined with
/// [separator] (the workspace setting `stock.address_separator`).
String stockAddress(StockPlaceConfig place, String separator) =>
    place.addressPath.split(stockAddressJoint).join(separator);

/// What a save of a place says: the place and its new revision.
typedef StockSaved = ({String id, int revision, bool replayed});

/// Why a save changed nothing.
sealed class StockConfigFailure implements Exception {
  const StockConfigFailure();
}

/// The revision read is not the one the server holds: read again.
final class StockConfigStale extends StockConfigFailure {
  const StockConfigStale();
}

/// The content is not valid: [field] (`units[0].factor_den`, `code`) and the
/// [reason] (`factor_invalid`, `code_duplicate`, `location_cycle`, ...).
final class StockConfigRefused extends StockConfigFailure {
  const StockConfigRefused(this.field, this.reason);

  final String field;
  final String reason;

  @override
  String toString() => 'StockConfigRefused($field: $reason)';
}

/// The first movement fixed the unit and the tracking of this item.
final class StockConfigInUse extends StockConfigFailure {
  const StockConfigInUse();
}

/// Less is held than was asked: nothing moved (DKG03). [detail] is what the
/// server said it held, when it said.
/// #4363 -- a tag command refused for a reason of its own: `DKG22` the tag is bound elsewhere (detail: code,
/// owner), `DKG23` it was retired lately (detail: code, days), `DKG24` it is on a piece still in stock, `DKG04`
/// it is not a tag in force here.
final class StockTagRefused extends StockConfigFailure {
  const StockTagRefused(this.code, [this.detail = const {}]);

  final String code;
  final Map<String, Object?> detail;

  @override
  String toString() => 'StockTagRefused($code)';
}

final class StockNotEnough extends StockConfigFailure {
  const StockNotEnough([this.detail = '']);

  final String detail;

  @override
  String toString() => 'StockNotEnough($detail)';
}
