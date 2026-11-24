// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4435 (G20) -- the Demo's handling units, answering as the server does from the goods ledger the Demo keeps: a pallet of 30 mugs
// and a carton of 10 kg of coffee beans stand at the main store. A unit claims only what is loose there (the balance minus what
// open units hold), a move goes through the ledger and moves the whole content, a second move with the revision someone else
// already moved is refused with the unit's new place, an unpack leaves the content loose, a repack makes the store's own units
// of what it took (the totals never change, and it happens at one place).
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../features/stock/domain/handling_units.dart';
import '../../../features/stock/domain/stock_config.dart';
import '../../../features/stock/domain/stock_page.dart';
import 'demo_stock_ledger.dart';

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

class DemoStockHandlingUnits implements StockHandlingUnits {
  DemoStockHandlingUnits(this._ledger) {
    final pallet = _Unit('demo-unit-1', 'PAL-001', HandlingUnitKind.pallet, _main, labelCode: '003760001234567895');
    pallet.lines.add(_Line('demo-item-mugs', ExactQuantity.parse('30')));
    final carton = _Unit('demo-unit-2', 'CT-001', HandlingUnitKind.carton, _main);
    carton.lines.add(_Line('demo-item-beans', ExactQuantity.parse('10')));
    _units.addAll([pallet, carton]);
  }

  static const _main = 'demo-place-main';

  final DemoStockLedger _ledger;
  final List<_Unit> _units = [];
  final Map<String, Object> _answers = {};
  int _next = 3;

  String _codeOf(String place) => switch (place) {
        _main => 'MAIN',
        'demo-place-shelf' => 'SHELF-A',
        'demo-place-branch' => 'BRANCH',
        _ => place,
      };

  HandlingUnit _json(_Unit u) => HandlingUnit(
        id: u.id,
        code: u.code,
        labelCode: u.labelCode,
        kind: u.kind,
        state: u.state,
        locationId: u.locationId,
        locationCode: _codeOf(u.locationId),
        parentUnitId: u.parent,
        revision: u.revision,
        lineCount: u.lines.length,
      );

  StockItem _item(String id) => DemoStockLedger.items.firstWhere((i) => i.id == id);

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

  Never _refuse(String code, Map<String, Object?> detail) =>
      throw StockUnitRefused(code, detail);

  _Unit _byId(String id) {
    final u = _units.where((x) => x.id == id).firstOrNull;
    if (u == null) _refuse('DKG28', {'reason': 'unit_unknown', 'unit_id': id});
    return u;
  }

  /// A request made twice answers what it answered the first time.
  T _once<T extends Object>(String requestId, T Function() run) => (_answers[requestId] ??= run()) as T;

  @override
  Future<HandlingUnitPage> page(String workspaceId, {String? locationId, HandlingUnitState state = HandlingUnitState.open, Map<String, Object?>? after}) async {
    final rows = [for (final u in _units) if (u.state == state && (locationId == null || u.locationId == locationId)) u]
      ..sort((a, b) => a.code.compareTo(b.code));
    return HandlingUnitPage(rows: [for (final u in rows) _json(u)]);
  }

  @override
  Future<HandlingUnitDetail?> unit(String workspaceId, String unitId) async {
    final u = _units.where((x) => x.id == unitId).firstOrNull;
    if (u == null) return null;
    return HandlingUnitDetail(
      unit: _json(u),
      lines: [
        for (final l in u.lines)
          HandlingUnitLine(itemId: l.itemId, itemName: _item(l.itemId).name, quantity: l.quantity, unit: _item(l.itemId).unit),
      ],
      children: [for (final c in _units) if (c.parent == u.id && c.state == HandlingUnitState.open) _json(c)],
    );
  }

  _Unit _make(UnitDraft d) {
    if (_units.any((u) => u.code.toLowerCase() == d.code.trim().toLowerCase())) _refuse('DKG29', {'code': d.code});
    if (d.code.trim().isEmpty) _refuse('DKG28', {'reason': 'unit'});
    final u = _Unit('demo-unit-${_next++}', d.code.trim(), d.kind, d.locationId, labelCode: d.labelCode, parent: d.parentUnitId);
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

  @override
  Future<HandlingUnit> make(String workspaceId, String requestId, UnitDraft draft) async => _once(requestId, () => _json(_make(draft)));

  _Unit _open(String unitId, int revision) {
    final u = _byId(unitId);
    if (u.state != HandlingUnitState.open || u.revision != revision) {
      _refuse('DKG27', {'unit_id': u.id, 'state': u.state.name, 'location_id': u.locationId, 'revision': u.revision});
    }
    return u;
  }

  @override
  Future<HandlingUnit> move(String workspaceId, String requestId, {required String unitId, required String toLocationId, required int revision}) async {
    final known = _answers[requestId];
    if (known != null) return known as HandlingUnit;
    final u = _open(unitId, revision);
    if (toLocationId == u.locationId) _refuse('DKG28', {'reason': 'same_place', 'location_id': toLocationId});
    final moving = [u, for (final c in _units) if (c.parent == u.id && c.state == HandlingUnitState.open) c];
    for (final m in moving) {
      for (final l in m.lines) {
        await _ledger.post(DemoStockPost(item: _item(l.itemId), quantity: l.quantity, from: m.locationId, to: toLocationId, reason: 'transfer'));
      }
    }
    for (final m in moving) {
      m.locationId = toLocationId;
      m.revision++;
    }
    return _answers[requestId] = _json(u);
  }

  @override
  Future<HandlingUnit> unpack(String workspaceId, String requestId, {required String unitId, required int revision}) async {
    final known = _answers[requestId];
    if (known != null) return known as HandlingUnit;
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
    return _answers[requestId] = _json(u);
  }

  @override
  Future<List<HandlingUnit>> repack(String workspaceId, String requestId, {required List<RepackSource> sources, required List<UnitDraft> targets}) async {
    final known = _answers[requestId];
    if (known != null) return (known as List).cast<HandlingUnit>();
    final out = <String, ExactQuantity>{};
    final place = targets.first.locationId;
    final taken = <(_Line, ExactQuantity)>[];
    for (final s in sources) {
      final q = ExactQuantity.parse(s.line.quantity);
      out[s.line.itemId] = (out[s.line.itemId] ?? ExactQuantity.zero) + q;
      if (s.unitId != null) {
        final u = _byId(s.unitId!);
        final l = u.lines.where((x) => x.itemId == s.line.itemId).firstOrNull;
        if (l == null || l.quantity < q) _refuse('DKG28', {'reason': 'not_in_unit', 'unit_id': u.id});
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
      if ((into[e.key] ?? ExactQuantity.zero) != e.value) _refuse('DKG28', {'reason': 'conservation', 'item_id': e.key});
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
    final answer = <HandlingUnit>[for (final u in made) _json(u)];
    _answers[requestId] = answer;
    return answer;
  }

  @override
  Future<LotUnitTrace> lotTrace(String workspaceId, {required String itemId, required String lotId}) async =>
      const LotUnitTrace(held: [], repacks: []);
}
