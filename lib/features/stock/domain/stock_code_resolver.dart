// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4359 (G10) -- what a scanned code names. The server resolves ONE code per scan (`stock_resolve_code_v1`):
// a place, an item (by its own or a package-unit code), a variant, a lot, a bound tag or nothing. A scan only
// fills a sheet with ids; every command the sheet then calls is the one it already calls, with its own rights,
// so resolving a code never authorises anything. This file is the answer and the port; the Supabase and Demo
// resolvers implement it.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader, JsonShapeException;

/// What a code names.
enum ScannedKind {
  place,
  item,
  variant,
  lot,
  tag,
  unknown;

  static ScannedKind fromWire(String? wire) => values.firstWhere((k) => k.name == wire, orElse: () => unknown);
}

/// A place the code names.
class ScannedPlace {
  const ScannedPlace({required this.id, required this.code, required this.name, required this.kind});

  final String id;
  final String code;
  final String name;
  final String kind;
}

/// An item the code names; an assistant session gets names only, so the id may be empty.
class ScannedItem {
  const ScannedItem({required this.id, required this.name, required this.unit});

  final String id;
  final String name;
  final String unit;
}

/// A package unit a code names: one carton is `factorNum / factorDen` of the inventory unit.
class ScannedUnit {
  const ScannedUnit({required this.unit, required this.factorNum, required this.factorDen});

  final String unit;
  final int factorNum;
  final int factorDen;

  /// The quantity of the inventory unit that one scan of this code stands for, as an exact fraction.
  ({int num, int den}) get factor => (num: factorNum, den: factorDen);
}

/// The answer to one scan.
class StockCodeResolution {
  const StockCodeResolution({
    required this.kind,
    required this.code,
    this.matchedBy,
    this.place,
    this.item,
    this.variantId,
    this.variantLabel,
    this.unit,
    this.lotId,
    this.lotCode,
    this.tagBound = false,
    this.tagOwnerKind,
    this.knownProduct = false,
  });

  /// A code that names nothing.
  const StockCodeResolution.unknown(this.code)
    : kind = ScannedKind.unknown,
      matchedBy = null,
      place = null,
      item = null,
      variantId = null,
      variantLabel = null,
      unit = null,
      lotId = null,
      lotCode = null,
      tagBound = false,
      tagOwnerKind = null,
      knownProduct = false;

  final ScannedKind kind;

  /// The normalised code (trimmed; a tag in upper-case hex).
  final String code;

  /// How the server matched it (`place_barcode`, `gtin`, `unit_code`, `lot_label`, `tag`, ...), when it says.
  final String? matchedBy;
  final ScannedPlace? place;
  final ScannedItem? item;
  final String? variantId;
  final String? variantLabel;

  /// Set when the code is a package-unit code: one scan is a carton.
  final ScannedUnit? unit;
  final String? lotId;
  final String? lotCode;
  final bool tagBound;

  /// #4436 -- what a bound tag is on (`item`, `variant`, `lot`, `unit`, `place` or `piece`), when the server says.
  final String? tagOwnerKind;

  /// A bound tag on one piece: a sale of it names that piece.
  bool get isPieceTag => kind == ScannedKind.tag && tagBound && tagOwnerKind == 'piece';

  /// An SGTIN whose GTIN is one of the business's item codes but whose tag is not bound yet.
  final bool knownProduct;

  /// The answer of `stock_resolve_code_v1`; an answer of the wrong shape throws, it is never "unknown".
  factory StockCodeResolution.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_resolve_code');
    final kind = ScannedKind.fromWire(r.string('kind'));
    final code = r.stringOr('code');
    ScannedPlace? place;
    final p = r.objectOrNull('place');
    if (p != null) {
      place = ScannedPlace(id: p.stringOr('id'), code: p.stringOr('code'), name: p.stringOr('name'), kind: p.stringOr('kind'));
    }
    ScannedItem? item;
    final i = r.objectOrNull('item');
    if (i != null) item = ScannedItem(id: i.stringOr('id'), name: i.stringOr('name'), unit: i.stringOr('unit'));
    final v = r.objectOrNull('variant');
    ScannedUnit? unit;
    final u = r.objectOrNull('unit');
    if (u != null) {
      // #4499 -- a package unit without its factor (a tag still on a unit name no unit of the item has) is unreadable:
      // the scan says so, it never counts one piece for a carton.
      final num = u.integer('factor_num'), den = u.integer('factor_den');
      if (num <= 0 || den <= 0) throw JsonShapeException('stock_resolve_code', 'unit.factor', 'a positive factor', '$num/$den');
      unit = ScannedUnit(unit: u.stringOr('unit'), factorNum: num, factorDen: den);
    }
    final l = r.objectOrNull('lot');
    final t = r.objectOrNull('tag');
    return StockCodeResolution(
      kind: kind,
      code: code,
      matchedBy: r.stringOrNull('matched_by'),
      place: place,
      item: item,
      variantId: v?.stringOrNull('id'),
      variantLabel: v?.stringOrNull('label'),
      unit: unit,
      lotId: l?.stringOrNull('id'),
      lotCode: l?.stringOrNull('code'),
      tagBound: t?.boolOr('bound', fallback: false) ?? false,
      tagOwnerKind: t?.stringOrNull('owner_kind'),
      knownProduct: r.boolOr('known_product', fallback: false),
    );
  }
}

/// Resolves a scanned code in a business: one call per scan.
abstract interface class StockCodeResolver {
  Future<StockCodeResolution> resolve(String workspaceId, String code);
}
