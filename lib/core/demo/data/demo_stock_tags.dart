// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4363 (G14) -- the Demo's tags, kept in memory behind the same port as the server's: a tag is bound to one
// owner (an item, a place or a package unit), the same read again is `replayed`, a tag bound elsewhere is refused
// with the owner, a retired tag is out of use. Two tags are bound from the start (Shelf A and the Mugs), so a scan
// or a read finds something. The scanner resolver reads the same store.
import '../../../features/stock/domain/stock_bulk_read.dart';
import '../../../features/stock/domain/stock_config.dart';
import '../../../features/stock/domain/stock_tags.dart';
import '../../codes/dk_code.dart';
import '../../settings/setting_defaults.g.dart';
import '../demo_replay.dart';

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
  DemoStockTags({this.tagModeOf, this.nameOf}) {
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

  /// An item's name, for the answers of a bulk read.
  final Future<String?> Function(String itemId)? nameOf;

  /// The item a piece tag names (already normalised), or null: the Demo's pieces are all in the main store.
  String? pieceItemOf(String code) => _active.where((t) => t.code == code && t.pieceId != null).firstOrNull?.owner.itemId;

  static const _mainPlace = BulkPlace(id: 'demo-place-main', code: 'MAIN', name: 'Main store');

  final List<_Bound> _active = [];

  /// The tagged pieces of an item: the piece and its tag (#4434).
  List<({String pieceId, String code})> pieceTags(String itemId) => [
    for (final t in _active)
      if (t.pieceId != null && t.owner.itemId == itemId) (pieceId: t.pieceId!, code: t.code),
  ];
  final _answers = Replay<TagBound>();
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

  /// #4379 -- the pieces a put-away makes ([allocation] of it): one per tag, each tag bound to its own piece, as
  /// 0889 does. A tag read twice in the allocation, or in force anywhere, is refused DKG22 with the allocation and
  /// the tag's place among them (from 1); nothing is bound then. [check] only says whether they would bind.
  void addPieces(String itemId, List<String> codes, {required int allocation, bool check = false}) {
    final seen = <String>{};
    for (var n = 0; n < codes.length; n++) {
      final code = normalise(codes[n]);
      final held = _active.where((t) => t.code == code).firstOrNull;
      if (!seen.add(code) || held != null) {
        throw StockTagRefused(DkCode.dkg22, {
          'allocation': allocation,
          'unit': n + 1,
          'code': code,
          'owner': held?.owner.locationId ?? held?.owner.itemId ?? itemId,
        });
      }
    }
    if (check) return;
    for (final code in seen) {
      final n = _next++;
      _active.add(_Bound('demo-tag-$n', code, TagOwner.item(itemId), kind: code.length >= 24 ? 'epc' : 'uid', pieceId: 'demo-piece-$n'));
    }
  }

  @override
  Future<TagBound> bind(String workspaceId, {required String requestId, required String code, required TagOwner owner}) async {
    if (_answers.seen(requestId) case final first?) return first;
    final normalised = normalise(code);
    if (!_hex.hasMatch(normalised)) throw const StockConfigRefused('tag.code', StockRefusal.tagMalformed);
    final held = _active.where((t) => t.code == normalised).firstOrNull;
    // a piece's tag names a piece, never the item it belongs to: the server compares the kind of owner too
    if (held != null && (held.pieceId != null || !_same(held.owner, owner))) {
      throw StockTagRefused(DkCode.dkg22, {'code': normalised, 'owner': held.owner.locationId ?? held.owner.itemId});
    }
    // what a tag on an item names is the item's tag mode: batches here, pieces by the movement path
    final itemId = owner.itemId;
    if (held == null && tagModeOf != null && owner.kind != 'place' && itemId != null) {
      final mode = await tagModeOf!(itemId);
      if (mode == 'per_unit') throw const StockConfigRefused('owner', StockRefusal.tagPerUnitItem);
      if (mode != 'per_batch') throw const StockConfigRefused('owner', StockRefusal.tagModeNone);
    }
    final bound = held ?? _Bound('demo-tag-${_next++}', normalised, owner);
    if (held == null) _active.add(bound);
    final answer = TagBound(
      tag: StockTag(id: bound.id, code: normalised, kind: 'uid', ownerKind: owner.kind, unit: owner.unit),
      replayed: held != null,
    );
    return _answers.keep(requestId, answer);
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

  @override
  Future<BulkResolution> resolveCodes(String workspaceId, List<String> codes) async {
    final distinct = <String, String>{};
    final invalid = <String>[];
    for (final raw in codes) {
      final typed = raw.trim();
      if (typed.isEmpty || raw.length > 200) {
        invalid.add(typed.length > 60 ? typed.substring(0, 60) : typed);
        continue;
      }
      distinct.putIfAbsent(normalise(typed), () => typed);
    }
    final results = <BulkCode>[];
    for (final MapEntry(key: code, value: typed) in distinct.entries) {
      final held = _active.where((t) => t.code == code).firstOrNull;
      if (held == null) {
        results.add(BulkCode(input: typed, kind: 'unknown'));
      } else if (held.pieceId != null) {
        final item = held.owner.itemId!;
        results.add(BulkCode(
          input: typed,
          kind: 'tag',
          itemName: await nameOf?.call(item),
          piece: BulkPiece(id: held.pieceId!, state: 'in_stock', itemId: item, place: _mainPlace),
        ));
      } else {
        results.add(BulkCode(input: typed, kind: 'tag', itemName: held.owner.itemId == null ? null : await nameOf?.call(held.owner.itemId!)));
      }
    }
    return BulkResolution(received: codes.length, distinct: distinct.length, limit: SettingDefaults.stockTagReadMaxTags, truncated: false, codes: results, invalid: invalid);
  }
}
