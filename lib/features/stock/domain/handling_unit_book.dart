// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4403 -- the handling units of one business (pallets, cartons) and the rules a unit meets, in the domain beside
// the stock ledger whose goods they hold. It does no I/O. A unit claims only what is loose at its place (the
// balance minus what the open units there hold); a move goes through the ledger and moves the whole content, its
// child units with it; a stale revision is refused with where the unit now is; an unpack leaves the content loose;
// a repack takes from units or loose stock at one place and makes new units of exactly what it took. The server
// stays the authority: 0929 (stock_hu_loose, stock_hu_make_v1, stock_hu_lock, stock_hu_move_v1,
// stock_hu_unpack_v1) and 0930 (stock_hu_repack_v1), at the lines cited.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../core/codes/dk_code.dart';
import 'handling_units.dart';
import 'stock_config.dart';
import 'stock_ledger.dart';

class _Line {
  _Line(this.itemId, this.quantity);

  final String itemId;
  ExactQuantity quantity;
}

class _Unit {
  _Unit(this.id, this.code, this.kind, this.locationId, {this.labelCode, this.parent});

  final String id;
  final String code;
  final String? labelCode;
  final HandlingUnitKind kind;
  String locationId;
  String? parent;
  HandlingUnitState state = HandlingUnitState.open;
  int revision = 1;
  final List<_Line> lines = [];
}

/// The handling units kept on one [StockLedger].
class HandlingUnitBook {
  HandlingUnitBook(this._ledger, {this.prefix = 'stock'});

  final StockLedger _ledger;

  /// What the units' addresses begin with.
  final String prefix;

  final List<_Unit> _units = [];
  int _next = 1;

  /// A unit of the opening story: [lines] (item, quantity) are taken as loose there, unchecked.
  void seed(String id, String code, HandlingUnitKind kind, String locationId, Map<String, String> lines, {String? labelCode}) {
    final u = _Unit(id, code, kind, locationId, labelCode: labelCode);
    for (final MapEntry(:key, :value) in lines.entries) {
      u.lines.add(_Line(key, ExactQuantity.parse(value)));
    }
    _units.add(u);
    _next++;
  }

  HandlingUnit _json(_Unit u) => HandlingUnit(
    id: u.id,
    code: u.code,
    labelCode: u.labelCode,
    kind: u.kind,
    state: u.state,
    locationId: u.locationId,
    locationCode: _ledger.codeOf(u.locationId),
    parentUnitId: u.parent,
    revision: u.revision,
    lineCount: u.lines.length,
  );

  /// The units of [state] (at [locationId] when one is named), by code.
  List<HandlingUnit> page({String? locationId, HandlingUnitState state = HandlingUnitState.open}) => [
    for (final u in [for (final u in _units) if (u.state == state && (locationId == null || u.locationId == locationId)) u]
      ..sort((a, b) => a.code.compareTo(b.code)))
      _json(u),
  ];

  /// A unit with its content and its open child units; null for one the business does not have.
  HandlingUnitDetail? unit(String unitId) {
    final u = _units.where((x) => x.id == unitId).firstOrNull;
    if (u == null) return null;
    return HandlingUnitDetail(
      unit: _json(u),
      lines: [
        for (final l in u.lines)
          if (_ledger.itemOf(l.itemId) case final item?)
            HandlingUnitLine(itemId: l.itemId, itemName: item.name, quantity: l.quantity, unit: item.unit),
      ],
      children: [for (final c in _units) if (c.parent == u.id && c.state == HandlingUnitState.open) _json(c)],
    );
  }

  /// What is loose of [itemId] at [place]: the balance minus what the open units there hold (0929 stock_hu_loose:31).
  ExactQuantity _loose(String itemId, String place, {_Unit? except}) {
    var held = _ledger.balance(itemId, place);
    for (final u in _units) {
      if (u.state != HandlingUnitState.open || u.locationId != place || identical(u, except)) continue;
      for (final l in u.lines) {
        if (l.itemId == itemId) held = held - l.quantity;
      }
    }
    return held;
  }

  Never _refuse(String code, Map<String, Object?> detail) => throw StockUnitRefused(code, detail);

  _Unit _byId(String id) {
    final u = _units.where((x) => x.id == id).firstOrNull;
    if (u == null) _refuse(DkCode.dkg28, {'reason': 'unit_unknown', 'unit_id': id});
    return u;
  }

  /// A unit made of loose stock (0929 stock_hu_make_v1:141): a code not taken (DKG29) and not empty (DKG28), each
  /// line no more than is loose there.
  _Unit _make(UnitDraft d) {
    if (_units.any((u) => u.code.toLowerCase() == d.code.trim().toLowerCase())) _refuse(DkCode.dkg29, {'code': d.code});
    if (d.code.trim().isEmpty) _refuse(DkCode.dkg28, {'reason': 'unit'});
    final u = _Unit('$prefix-unit-${_next++}', d.code.trim(), d.kind, d.locationId, labelCode: d.labelCode, parent: d.parentUnitId);
    _units.add(u);
    for (final l in d.lines) {
      final q = ExactQuantity.parse(l.quantity);
      final asked = _loose(l.itemId, d.locationId, except: u);
      if (q > asked) {
        _units.remove(u);
        throw StockNotEnough('${asked.text} loose of ${q.text}');
      }
      final held = u.lines.where((x) => x.itemId == l.itemId).firstOrNull;
      if (held == null) {
        u.lines.add(_Line(l.itemId, q));
      } else {
        held.quantity = held.quantity + q;
      }
    }
    return u;
  }

  HandlingUnit make(UnitDraft draft) => _json(_make(draft));

  /// An open unit at the revision read, else refused with where it now is (0929 stock_hu_lock:198, DKG27).
  _Unit _open(String unitId, int revision) {
    final u = _byId(unitId);
    if (u.state != HandlingUnitState.open || u.revision != revision) {
      _refuse(DkCode.dkg27, {'unit_id': u.id, 'state': u.state.name, 'location_id': u.locationId, 'revision': u.revision});
    }
    return u;
  }

  /// The unit and its open child units moved, whole, through the ledger (0929 stock_hu_move_v1:217).
  HandlingUnit move({required String unitId, required String toLocationId, required int revision}) {
    final u = _open(unitId, revision);
    if (toLocationId == u.locationId) _refuse(DkCode.dkg28, {'reason': 'same_place', 'location_id': toLocationId});
    final moving = [u, for (final c in _units) if (c.parent == u.id && c.state == HandlingUnitState.open) c];
    for (final m in moving) {
      for (final l in m.lines) {
        _ledger.post(StockPost(item: _ledger.itemOf(l.itemId)!, quantity: l.quantity, from: m.locationId, to: toLocationId, reason: 'transfer'));
      }
    }
    for (final m in moving) {
      m.locationId = toLocationId;
      m.revision++;
    }
    return _json(u);
  }

  /// The content left loose and the child units let go (0929 stock_hu_unpack_v1:287).
  HandlingUnit unpack({required String unitId, required int revision}) {
    final u = _open(unitId, revision);
    for (final c in _units) {
      if (c.parent == u.id) {
        c.parent = null;
        c.revision++;
      }
    }
    u.lines.clear();
    u.state = HandlingUnitState.unpacked;
    u.revision++;
    return _json(u);
  }

  /// Units made at one place of exactly what [sources] take from units or loose stock (0930 stock_hu_repack_v1:20):
  /// a source unit holds what it gives (DKG28 not_in_unit), loose stock is there, and each item's totals are the
  /// same on both sides (DKG28 conservation). A unit left empty is unpacked.
  List<HandlingUnit> repack({required List<RepackSource> sources, required List<UnitDraft> targets}) {
    final out = <String, ExactQuantity>{};
    final place = targets.first.locationId;
    final taken = <(_Line, ExactQuantity)>[];
    for (final s in sources) {
      final q = ExactQuantity.parse(s.line.quantity);
      out[s.line.itemId] = (out[s.line.itemId] ?? ExactQuantity.zero) + q;
      if (s.unitId != null) {
        final u = _byId(s.unitId!);
        final l = u.lines.where((x) => x.itemId == s.line.itemId).firstOrNull;
        if (l == null || l.quantity < q) _refuse(DkCode.dkg28, {'reason': 'not_in_unit', 'unit_id': u.id});
        taken.add((l, q));
      } else if (q > _loose(s.line.itemId, place)) {
        throw const StockNotEnough('not that much loose');
      }
    }
    final into = <String, ExactQuantity>{};
    for (final t in targets) {
      for (final l in t.lines) {
        into[l.itemId] = (into[l.itemId] ?? ExactQuantity.zero) + ExactQuantity.parse(l.quantity);
      }
    }
    for (final e in out.entries) {
      if ((into[e.key] ?? ExactQuantity.zero) != e.value) _refuse(DkCode.dkg28, {'reason': 'conservation', 'item_id': e.key});
    }
    for (final (l, q) in taken) {
      l.quantity = l.quantity - q;
    }
    final made = [for (final t in targets) _make(t)];
    for (final u in _units) {
      if (u.state == HandlingUnitState.open && u.lines.every((l) => l.quantity == ExactQuantity.zero) && u.lines.isNotEmpty) {
        u.lines.removeWhere((l) => l.quantity == ExactQuantity.zero);
        u.state = HandlingUnitState.unpacked;
        u.revision++;
      } else {
        u.lines.removeWhere((l) => l.quantity == ExactQuantity.zero);
      }
    }
    return [for (final u in made) _json(u)];
  }
}
