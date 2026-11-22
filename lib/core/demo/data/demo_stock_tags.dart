// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4363 (G14) -- the Demo's tags, kept in memory behind the same port as the server's: a tag is bound to one
// owner (an item, a place or a package unit), the same read again is `replayed`, a tag bound elsewhere is refused
// with the owner, a retired tag is out of use. Two tags are bound from the start (Shelf A and the Mugs), so a scan
// or a read finds something. The scanner resolver reads the same store.
import '../../../features/stock/domain/stock_config.dart';
import '../../../features/stock/domain/stock_tags.dart';

class _Bound {
  _Bound(this.id, this.code, this.owner);

  final String id;
  final String code;
  final TagOwner owner;
}

class DemoStockTags implements StockTags {
  DemoStockTags() {
    _active
      ..add(_Bound('demo-tag-1', 'A1B2C3D4', const TagOwner.place('demo-place-shelf')))
      ..add(_Bound('demo-tag-2', '04E5F6A7B8C9D0', const TagOwner.item('demo-item-mugs')));
  }

  final List<_Bound> _active = [];
  final Map<String, TagBound> _answers = {};
  int _next = 3;

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
        StockTag(id: t.id, code: t.code, kind: 'uid', ownerKind: t.owner.kind, unit: t.owner.unit),
  ];

  @override
  Future<TagBound> bind(String workspaceId, {required String requestId, required String code, required TagOwner owner}) async {
    final first = _answers[requestId];
    if (first != null) return first;
    final normalised = normalise(code);
    if (!_hex.hasMatch(normalised)) throw const StockConfigRefused('tag.code', 'tag_malformed');
    final held = _active.where((t) => t.code == normalised).firstOrNull;
    if (held != null && !_same(held.owner, owner)) {
      throw StockTagRefused('DKG22', {'code': normalised, 'owner': held.owner.locationId ?? held.owner.itemId});
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
    if (held == null) throw const StockTagRefused('DKG04');
    _active.remove(held);
  }
}
