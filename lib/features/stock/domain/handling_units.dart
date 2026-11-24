// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4435 (G20) -- handling units as the stock reads and acts on them: a pallet, a carton, a crate or a store box has a code, a
// place and a content (items with their lot, quantity and pieces). It is moved with its whole content in one request, unpacked
// where it stands, and repackaged into the store's own units without a balance ever changing. The ledger stays the authority
// of quantity: a unit is a claim on loose stock, and the server refuses what the ledger cannot honour.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// What a unit is.
enum HandlingUnitKind {
  pallet,
  carton,
  crate,
  box,
  other;

  static HandlingUnitKind of(String? wire) =>
      HandlingUnitKind.values.firstWhere((k) => k.name == wire, orElse: () => HandlingUnitKind.other);
}

/// Where a unit is in its life: open (it holds goods), unpacked (its content is loose at its place), retired.
enum HandlingUnitState {
  open,
  unpacked,
  retired;

  static HandlingUnitState of(String? wire) =>
      HandlingUnitState.values.firstWhere((s) => s.name == wire, orElse: () => HandlingUnitState.open);
}

/// One unit as the lists and the commands answer it. [revision] is what a move or an unpack names: a unit that changed since
/// it was read is refused (`StockUnitChanged`), not overwritten.
class HandlingUnit {
  const HandlingUnit({
    required this.id,
    required this.code,
    required this.kind,
    required this.state,
    required this.locationId,
    required this.revision,
    this.labelCode,
    this.parentUnitId,
    this.locationCode = '',
    this.lineCount = 0,
  });

  final String id;
  final String code;
  final String? labelCode;
  final HandlingUnitKind kind;
  final HandlingUnitState state;
  final String locationId;
  final String locationCode;
  final String? parentUnitId;
  final int revision;
  final int lineCount;

  bool get isOpen => state == HandlingUnitState.open;

  factory HandlingUnit.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_handling_unit');
    return HandlingUnit(
      id: r.string('id'),
      code: r.string('code'),
      labelCode: r.stringOrNull('label_code'),
      kind: HandlingUnitKind.of(r.stringOrNull('kind')),
      state: HandlingUnitState.of(r.stringOrNull('state')),
      locationId: r.string('location_id'),
      locationCode: r.stringOr('location_code'),
      parentUnitId: r.stringOrNull('parent_unit_id'),
      revision: r.integer('revision'),
      lineCount: r.intOrAbsent('lines') ?? 0,
    );
  }
}

/// One piece (an item tracked piece by piece) in a unit line, with its tag when it has one.
class HandlingUnitPiece {
  const HandlingUnitPiece({required this.pieceId, this.tag = ''});

  final String pieceId;
  final String tag;
}

/// What a unit holds of one item, variant and lot.
class HandlingUnitLine {
  const HandlingUnitLine({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unit,
    this.variantId,
    this.lotId,
    this.lotCode = '',
    this.expiresOn,
    this.pieces = const [],
  });

  final String itemId;
  final String itemName;
  final String? variantId;
  final String? lotId;
  final String lotCode;
  final DateTime? expiresOn;
  final ExactQuantity quantity;
  final String unit;
  final List<HandlingUnitPiece> pieces;

  factory HandlingUnitLine.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_handling_unit.lines');
    final expires = r.stringOrNull('expires_on');
    return HandlingUnitLine(
      itemId: r.string('item_id'),
      itemName: r.stringOr('item_name'),
      variantId: r.stringOrNull('variant_id'),
      lotId: r.stringOrNull('lot_id'),
      lotCode: r.stringOr('lot_code'),
      expiresOn: expires == null ? null : DateTime.parse(expires),
      quantity: ExactQuantity.parse(r.string('quantity')),
      unit: r.stringOr('unit'),
      pieces: [
        for (final p in r.requiredList('pieces'))
          HandlingUnitPiece(
            pieceId: JsonReader.of(p, context: 'stock_handling_unit.pieces').string('piece_id'),
            tag: JsonReader.of(p, context: 'stock_handling_unit.pieces').stringOr('tag'),
          ),
      ],
    );
  }
}

/// A unit with its content and the units nested in it.
class HandlingUnitDetail {
  const HandlingUnitDetail({required this.unit, required this.lines, this.children = const []});

  final HandlingUnit unit;
  final List<HandlingUnitLine> lines;
  final List<HandlingUnit> children;
}

/// A page of the list, with the cursor of the next (null at the end).
class HandlingUnitPage {
  const HandlingUnitPage({required this.rows, this.next});

  final List<HandlingUnit> rows;
  final Map<String, Object?>? next;
}

/// A line of content to claim (making a unit) or to put in a new unit (a repack): [pieceIds] only for a piece-tracked item.
class UnitLineDraft {
  const UnitLineDraft({required this.itemId, required this.quantity, this.variantId, this.lotId, this.pieceIds = const []});

  final String itemId;
  final String? variantId;
  final String? lotId;
  final String quantity;
  final List<String> pieceIds;

  Map<String, Object?> toJson() => {
        'item_id': itemId,
        if (variantId != null) 'variant_id': variantId,
        if (lotId != null) 'lot_id': lotId,
        'quantity': quantity,
        if (pieceIds.isNotEmpty) 'units': [for (final p in pieceIds) {'piece_id': p}],
      };
}

/// A unit to make: its own code (and the supplier's label when it came on a labelled pallet), its kind, its place, its content.
class UnitDraft {
  const UnitDraft({required this.code, required this.kind, required this.locationId, required this.lines, this.labelCode, this.parentUnitId});

  final String code;
  final String? labelCode;
  final HandlingUnitKind kind;
  final String locationId;
  final String? parentUnitId;
  final List<UnitLineDraft> lines;

  Map<String, Object?> toJson() => {
        'code': code,
        if (labelCode != null && labelCode!.isNotEmpty) 'label_code': labelCode,
        'kind': kind.name,
        'location_id': locationId,
        if (parentUnitId != null) 'parent_unit_id': parentUnitId,
        'lines': [for (final l in lines) l.toJson()],
      };
}

/// Content taken out of a unit (or, with no [unitId], out of loose stock at [locationId]) in a repack.
class RepackSource {
  const RepackSource({required this.line, this.unitId, this.locationId, this.revision});

  final String? unitId;
  final String? locationId;
  final int? revision;
  final UnitLineDraft line;

  Map<String, Object?> toJson() => {
        if (unitId != null) 'unit_id': unitId,
        if (locationId != null) 'location_id': locationId,
        if (revision != null) 'revision': revision,
        ...line.toJson(),
      };
}

/// Where a lot is held in units, and every repack that touched it (out of which unit, into which).
class LotUnitTrace {
  const LotUnitTrace({required this.held, required this.repacks});

  final List<({String unitId, String code, String locationId, ExactQuantity quantity})> held;
  final List<({String repackId, DateTime madeAt, String direction, String? code, ExactQuantity quantity, String? pieceId})> repacks;
}

/// The stock's handling units. Every command takes the request id that makes a retry answer the same result.
abstract interface class StockHandlingUnits {
  Future<HandlingUnitPage> page(String workspaceId, {String? locationId, HandlingUnitState state = HandlingUnitState.open, Map<String, Object?>? after});

  Future<HandlingUnitDetail?> unit(String workspaceId, String unitId);

  Future<HandlingUnit> make(String workspaceId, String requestId, UnitDraft draft);

  Future<HandlingUnit> move(String workspaceId, String requestId, {required String unitId, required String toLocationId, required int revision});

  Future<HandlingUnit> unpack(String workspaceId, String requestId, {required String unitId, required int revision});

  Future<List<HandlingUnit>> repack(String workspaceId, String requestId, {required List<RepackSource> sources, required List<UnitDraft> targets});

  Future<LotUnitTrace> lotTrace(String workspaceId, {required String itemId, required String lotId});
}
