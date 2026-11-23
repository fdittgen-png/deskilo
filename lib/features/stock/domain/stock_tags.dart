// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4363 (G14) -- the tags (NFC chips, UHF labels) bound to the things of the stock, as the server keeps them:
// `stock_tags_v1` lists the active tags of an item or a place, `stock_tag_bind_v1` binds one (one request id per
// read: the same read again answers `replayed`, never a second tag), `stock_tag_retire_v1` takes one out of use
// with a reason. A refusal arrives as a typed failure (`StockTagRefused`, `StockConfigRefused`).
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;

import 'stock_bulk_read.dart';

/// What a tag is bound to: an item, a place, or a package unit of an item.
class TagOwner {
  const TagOwner.item(String this.itemId) : kind = 'item', unit = null, locationId = null;
  const TagOwner.place(String this.locationId) : kind = 'place', itemId = null, unit = null;
  const TagOwner.unit(String this.itemId, String this.unit) : kind = 'unit', locationId = null;

  /// `item`, `place` or `unit` (a variant, lot or piece is not bound from here).
  final String kind;
  final String? itemId;
  final String? unit;
  final String? locationId;

  /// The filter `stock_tags_v1` takes: an item or a place.
  Map<String, Object?> get filter => locationId != null ? {'location_id': locationId} : {'item_id': itemId};

  /// The owner `stock_tag_bind_v1` takes.
  Map<String, Object?> toJson() => {
    'kind': kind,
    if (itemId != null) 'item_id': itemId,
    if (unit != null) 'unit': unit,
    if (locationId != null) 'location_id': locationId,
  };
}

/// An active tag.
class StockTag {
  const StockTag({required this.id, required this.code, required this.kind, required this.ownerKind, this.unit, this.pieceId});

  final String id;

  /// Upper-case hex.
  final String code;

  /// `uid` (an NFC chip) or `epc` (a UHF label, which a phone cannot read).
  final String kind;
  final String ownerKind;
  final String? unit;

  /// The piece this tag names, for an item tracked piece by piece (`owner_kind` `piece`); null otherwise.
  final String? pieceId;

  /// A tag that names one piece of the item.
  bool get isPiece => ownerKind == 'piece';

  bool get isUhf => kind == 'epc';

  factory StockTag.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_tags');
    return StockTag(
      id: r.string('tag_id'),
      code: r.string('code'),
      kind: r.string('tag_kind'),
      ownerKind: r.string('owner_kind'),
      unit: r.stringOrNull('unit'),
      pieceId: r.stringOrNull('piece_id'),
    );
  }
}

/// What binding answered.
class TagBound {
  const TagBound({required this.tag, required this.replayed});

  final StockTag tag;

  /// The same tag was already on this owner (or the request id was seen): nothing new was made.
  final bool replayed;

  factory TagBound.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_tag_bind');
    return TagBound(
      tag: StockTag(
        id: r.string('tag_id'),
        code: r.string('code'),
        kind: r.string('tag_kind'),
        ownerKind: r.string('owner_kind'),
      ),
      replayed: r.boolOr('replayed', fallback: false),
    );
  }
}

/// The reasons offered to take a tag out of use.
const stockTagRetireReasons = ['lost', 'damaged', 'replaced'];

abstract interface class StockTags {
  Future<List<StockTag>> tags(String workspaceId, TagOwner owner);

  Future<TagBound> bind(String workspaceId, {required String requestId, required String code, required TagOwner owner});

  Future<void> retire(String workspaceId, {required String requestId, required String code, required String reason});

  /// #4364 -- a bulk read resolved in one call (`stock_resolve_codes_v1`): each distinct tag as the one resolver of a
  /// scan answers it, with the piece's place and state; unknown tags answer unknown, never an error.
  Future<BulkResolution> resolveCodes(String workspaceId, List<String> codes);
}
