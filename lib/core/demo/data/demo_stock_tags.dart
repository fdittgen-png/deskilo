// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4363 (G14) -- the Demo's tags, kept in memory behind the same port as the server's: a tag is bound to one
// owner (an item, a place or a package unit), the same read again is `replayed`, a tag bound elsewhere is refused
// with the owner, a retired tag is out of use. Two tags are bound from the start (Shelf A and the Mugs), so a scan
// or a read finds something. The scanner resolver reads the same store.
import '../../../features/stock/domain/stock_config.dart';
import '../../../features/stock/domain/stock_tags.dart';
import '../../codes/dk_code.dart';

class _Bound {
  _Bound(this.id, this.code, this.owner, {this.kind = 'uid', this.pieceId});

  final String id;
  final String code;
  final TagOwner owner;

  /// `uid` (an NFC chip) or `epc` (a UHF label).
  final String kind;

  /// The piece a per-piece tag names; null for every other tag.
  final String? pieceId;
}

class DemoStockTags implements StockTags {
  /// [tagModeOf] answers an item's effective tag mode (`none`, `per_batch`, `per_unit`) as the server reads it; without it
  /// every owner binds, which is what the tests that bind chips without items rely on.
  DemoStockTags({this.tagModeOf}) {
    _active
      ..add(_Bound('demo-tag-1', 'A1B2C3D4', const TagOwner.place('demo-place-shelf')))
      ..add(_Bound('demo-tag-2', '04E5F6A7B8C9D0', const TagOwner.item('demo-item-mugs')))
      // #4362 -- a second place tag, a crate of apples tagged per batch, and a gift basket of five pieces, each with a tag
      ..add(_Bound('demo-tag-3', 'A1B2C3D5', const TagOwner.place('demo-place-back')))
      ..add(_Bound('demo-tag-4', 'E2801160600002054AF3D001', const TagOwner.item('demo-item-apples'), kind: 'epc'));
    for (var i = 1; i <= 5; i++) {
      _active.add(_Bound('demo-tag-${4 + i}', 'E2801160600002054AF3E00$i', const TagOwner.item('demo-item-basket'), kind: 'epc', pieceId: 'demo-piece-$i'));
    }
  }

  final Future<String?> Function(String itemId)? tagModeOf;

  final List<_Bound> _active = [];
  final Map<String, TagBound> _answers = {};
  int _next = 10;

  static final _hex = RegExp(r'^[0-9A-F]{4,64}$');

  /// The code as the server normalises it: upper-case, without spaces, ':' or '-'.
  static String normalise(String code) => code.replaceAll(RegExp(r'[\s:\-]'), '').toUpperCase();

  /// Who holds [code] (already normalised), or null.
  TagOwner? ownerOf(String code) => _active.where((t) => t.code == code).firstOrNull?.owner;

  bool _same(TagOwner a, TagOwner b) => a.kind == b.kind && a.itemId == b.itemId && a.unit == b.unit && a.locationId == b.locationId;

  @override
  Future<List<StockTag>> tags(String workspaceId, TagOwner owner) async => [
    for (final t in _active)
      if ((owner.locationId != null && t.owner.locationId == owner.locationId) || (owner.itemId != null && t.owner.itemId == owner.itemId))
        StockTag(id: t.id, code: t.code, kind: t.kind, ownerKind: t.pieceId == null ? t.owner.kind : 'piece', unit: t.owner.unit, pieceId: t.pieceId),
  ];

  @override
  Future<TagBound> bind(String workspaceId, {required String requestId, required String code, required TagOwner owner}) async {
    final first = _answers[requestId];
    if (first != null) return first;
    final normalised = normalise(code);
    if (!_hex.hasMatch(normalised)) throw const StockConfigRefused('tag.code', 'tag_malformed');
    final held = _active.where((t) => t.code == normalised).firstOrNull;
    // a piece's tag names a piece, never the item it belongs to: the server compares the kind of owner too
    if (held != null && (held.pieceId != null || !_same(held.owner, owner))) {
      throw StockTagRefused(DkCode.dkg22, {'code': normalised, 'owner': held.owner.locationId ?? held.owner.itemId});
    }
    // what a tag on an item names is the item's tag mode: batches here, pieces by the movement path
    final itemId = owner.itemId;
    if (held == null && tagModeOf != null && owner.kind != 'place' && itemId != null) {
      final mode = await tagModeOf!(itemId);
      if (mode == 'per_unit') throw const StockConfigRefused('owner', 'tag_per_unit_item');
      if (mode != 'per_batch') throw const StockConfigRefused('owner', 'tag_mode_none');
    }
    final bound = held ?? _Bound('demo-tag-${_next++}', normalised, owner);
    if (held == null) _active.add(bound);
    final answer = TagBound(
      tag: StockTag(id: bound.id, code: normalised, kind: 'uid', ownerKind: owner.kind, unit: owner.unit),
      replayed: held != null,
    );
    return _answers[requestId] = answer;
  }

  @override
  Future<void> retire(String workspaceId, {required String requestId, required String code, required String reason}) async {
    final normalised = normalise(code);
    final held = _active.where((t) => t.code == normalised).firstOrNull;
    if (held == null) throw const StockTagRefused(DkCode.dkg04);
    // a piece is retired with its tag only when it is not in stock: the Demo's pieces are in stock
    if (held.pieceId != null) throw const StockTagRefused(DkCode.dkg24);
    _active.remove(held);
  }
}
