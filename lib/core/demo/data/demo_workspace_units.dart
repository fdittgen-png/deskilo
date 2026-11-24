// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4442 -- the Demo's units of measure, behind the same port as the server's and with the server's own rules (0951): every
// business starts with the 13 built-ins; a unit is created and edited by code (a retried request id answers the stored
// answer, another content under it is refused); a built-in keeps its dimension and factor; a used unit keeps them and cannot
// be archived; a factor is a reduced fraction. Nothing leaves the process.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/stock/domain/stock_config.dart';
import '../../../features/stock/domain/workspace_units.dart';
import '../../codes/dk_code.dart';

/// The 13 built-in units of the server's seed, in its order (code, dimension, factor, UN/ECE code).
const _builtIn = <(String, UnitDimension, int, int, String)>[
  ('piece', UnitDimension.count, 1, 1, 'C62'),
  ('g', UnitDimension.mass, 1, 1, 'GRM'),
  ('kg', UnitDimension.mass, 1000, 1, 'KGM'),
  ('ml', UnitDimension.volume, 1, 1, 'MLT'),
  ('cl', UnitDimension.volume, 10, 1, 'CLT'),
  ('l', UnitDimension.volume, 1000, 1, 'LTR'),
  ('mm', UnitDimension.length, 1, 1000, 'MMT'),
  ('cm', UnitDimension.length, 1, 100, 'CMT'),
  ('m', UnitDimension.length, 1, 1, 'MTR'),
  ('km', UnitDimension.length, 1000, 1, 'KMT'),
  ('m2', UnitDimension.area, 1, 1, 'MTK'),
  ('min', UnitDimension.time, 1, 1, 'MIN'),
  ('h', UnitDimension.time, 60, 1, 'HUR'),
];

final _code = RegExp(r'^[a-z][a-z0-9_]{0,19}$');
final _ece = RegExp(r'^[A-Z0-9]{2,3}$');

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

/// The in-memory units of every business the Demo shows.
class DemoWorkspaceUnits implements WorkspaceUnits {
  /// Whether the business holds [code] as the unit of an item, a line or a movement; the Demo asks its own ledger.
  bool Function(String workspaceId, String code) usedBy = (_, _) => false;

  /// Whether an item of the business has [code] as a packaging unit (a box of 6): one code keeps one meaning.
  bool Function(String workspaceId, String code) packages = (_, _) => false;

  final Map<String, List<WorkspaceUnit>> _units = {};
  final Map<String, ({String digest, WorkspaceUnit answer})> _requests = {};

  List<WorkspaceUnit> _of(String workspaceId) => _units.putIfAbsent(workspaceId, () => [
    for (final (i, b) in _builtIn.indexed)
      WorkspaceUnit(
        code: b.$1,
        dimension: b.$2,
        factorNum: b.$3,
        factorDen: b.$4,
        unEceCode: b.$5,
        builtIn: true,
        sortOrder: (i + 1) * 10,
      ),
  ]);

  @override
  Future<List<WorkspaceUnit>> units(String workspaceId) async {
    final all = [..._of(workspaceId)]..sort((a, b) => a.sortOrder != b.sortOrder ? a.sortOrder.compareTo(b.sortOrder) : a.code.compareTo(b.code));
    return all;
  }

  @override
  Future<WorkspaceUnit> save(String workspaceId, {required String requestId, required MeasureUnitDraft draft}) async {
    final digest = '$workspaceId|${draft.toJson()}';
    final stored = _requests[requestId];
    if (stored != null) {
      if (stored.digest != digest) throw const PostgrestException(message: 'this request id was already used for a different request', code: DkCode.dkg07);
      return stored.answer;
    }
    if (!_code.hasMatch(draft.code)) throw const StockConfigRefused('code', StockRefusal.codeMalformed);
    final list = _of(workspaceId);
    final at = list.indexWhere((u) => u.code == draft.code);
    final old = at < 0 ? null : list[at];
    if (old == null && packages(workspaceId, draft.code)) throw const StockConfigRefused('code', StockRefusal.codeDuplicate);
    final unit = _edited(draft, old);
    if (old != null) _keepsWhatIsFixed(workspaceId, old, unit);
    if (at < 0) {
      list.add(unit);
    } else {
      list[at] = unit;
    }
    _requests[requestId] = (digest: digest, answer: unit);
    return unit;
  }

  /// The unit [draft] makes of [old] (null: a new one): what it sets, else what was, the fraction reduced, every field checked.
  WorkspaceUnit _edited(MeasureUnitDraft draft, WorkspaceUnit? old) {
    final dimension = draft.dimension ?? old?.dimension;
    if (dimension == null) throw const StockConfigRefused('dimension', StockRefusal.dimensionInvalid);
    var num = draft.factorNum ?? old?.factorNum;
    var den = draft.factorDen ?? old?.factorDen ?? 1;
    if (num == null || num <= 0 || den <= 0) throw const StockConfigRefused('factor', StockRefusal.factorInvalid);
    final g = _gcd(num, den);
    num ~/= g;
    den ~/= g;
    final label = draft.clearLabel ? null : (draft.label ?? old?.label);
    if (old == null && (label == null || label.trim().isEmpty)) throw const StockConfigRefused('label', StockRefusal.labelRequired);
    if (label != null && label.trim().length > 40) throw const StockConfigRefused('label', StockRefusal.tooLong);
    final ece = draft.unEceCode ?? old?.unEceCode;
    if (ece != null && !_ece.hasMatch(ece)) throw const StockConfigRefused('un_ece_code', StockRefusal.eceInvalid);
    return WorkspaceUnit(
      code: draft.code,
      label: label?.trim(),
      dimension: dimension,
      factorNum: num,
      factorDen: den,
      unEceCode: ece,
      builtIn: old?.builtIn ?? false,
      archived: old?.archived ?? false,
      sortOrder: draft.sortOrder ?? old?.sortOrder ?? 1000,
    );
  }

  /// A built-in and a used unit keep their dimension and factor.
  void _keepsWhatIsFixed(String workspaceId, WorkspaceUnit old, WorkspaceUnit unit) {
    if (unit.dimension == old.dimension && unit.factorNum == old.factorNum && unit.factorDen == old.factorDen) return;
    if (old.builtIn) throw const StockConfigRefused('factor', StockRefusal.registryUnit);
    if (usedBy(workspaceId, old.code)) throw const StockConfigRefused('factor', StockRefusal.unitInUse);
  }

  @override
  Future<void> archive(String workspaceId, {required String requestId, required String code, required bool archived}) async {
    final list = _of(workspaceId);
    final at = list.indexWhere((u) => u.code == code);
    if (at < 0) throw const StockConfigRefused('unit', StockRefusal.unitUnknown);
    if (archived && !list[at].archived && usedBy(workspaceId, code)) throw const StockConfigRefused('archived', StockRefusal.unitInUse);
    list[at] = list[at].copyWith(archived: archived);
  }
}
