// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4442 -- a business's own units of measure and their conversions (1 km = 1000 m). Each unit has a code, a label in the
// business's own words (null on a built-in: the app names it in the member's language), a dimension, an exact factor to the
// dimension's base unit as a fraction (a km is 1000/1 m, a mm is 1/1000 m) and, for an e-invoice, a UN/ECE code. The owner and
// the admins maintain them; a built-in unit and a unit that is used keep their dimension and factor (the server refuses, with
// the stock configuration's own refusal: `StockConfigRefused(field, reason)`).
//
// The conversion is exact, as the server's `workspace_unit_convert` is: through the base unit, never through a double; two
// dimensions never convert; an answer six decimals cannot hold is refused, not rounded.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// What a unit measures. Units of one dimension convert to each other; units of two never do.
enum UnitDimension {
  count,
  mass,
  volume,
  length,
  area,
  time;

  static UnitDimension? fromWire(Object? wire) {
    for (final d in values) {
      if (d.name == wire) return d;
    }
    return null;
  }
}

/// One unit of a business.
class WorkspaceUnit {
  const WorkspaceUnit({
    required this.code,
    required this.dimension,
    required this.factorNum,
    required this.factorDen,
    this.label,
    this.unEceCode,
    this.builtIn = false,
    this.archived = false,
    this.sortOrder = 1000,
  });

  /// Reads a row of `workspace_units`, or the answer of `workspace_unit_save_v1`. A dimension this version does not know
  /// is an error, never a guess.
  factory WorkspaceUnit.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'workspace_units');
    final dimension = UnitDimension.fromWire(r.string('dimension'));
    if (dimension == null) throw FormatException('workspace_units: unknown dimension ${r.string('dimension')}');
    return WorkspaceUnit(
      code: r.string('code'),
      label: r.stringOrNull('label'),
      dimension: dimension,
      factorNum: r.integer('factor_num'),
      factorDen: r.integer('factor_den'),
      unEceCode: r.stringOrNull('un_ece_code'),
      builtIn: r.boolOr('built_in', fallback: false),
      archived: r.boolOr('archived', fallback: false),
      sortOrder: r.intOrNull('sort_order') ?? 1000,
    );
  }

  final String code;

  /// The business's own word, or null where the app names the unit (a built-in).
  final String? label;
  final UnitDimension dimension;

  /// The exact factor to the dimension's base unit: [factorNum] / [factorDen], both above zero, reduced.
  final int factorNum;
  final int factorDen;

  /// The UN/ECE recommendation 20 code an e-invoice needs (KMT, MTR, KGM, ...), when the unit has one.
  final String? unEceCode;

  /// One of the 13 units every business starts with: its code, dimension and factor are fixed.
  final bool builtIn;

  /// Hidden from pickers; what already uses it keeps working.
  final bool archived;
  final int sortOrder;

  WorkspaceUnit copyWith({String? Function()? label, String? Function()? unEceCode, bool? archived}) => WorkspaceUnit(
    code: code,
    dimension: dimension,
    factorNum: factorNum,
    factorDen: factorDen,
    label: label == null ? this.label : label(),
    unEceCode: unEceCode == null ? this.unEceCode : unEceCode(),
    builtIn: builtIn,
    archived: archived ?? this.archived,
    sortOrder: sortOrder,
  );
}

/// What a person types to create or edit a unit. A null field is left as it was (on an edit); [label] null on a new unit is
/// refused by the server.
class MeasureUnitDraft {
  const MeasureUnitDraft({
    required this.code,
    this.label,
    this.dimension,
    this.factorNum,
    this.factorDen,
    this.unEceCode,
    this.sortOrder,
    this.clearLabel = false,
  });

  final String code;
  final String? label;
  final UnitDimension? dimension;
  final int? factorNum;
  final int? factorDen;
  final String? unEceCode;
  final int? sortOrder;

  /// Gives a built-in unit back the app's own word (the label is cleared).
  final bool clearLabel;

  Map<String, Object?> toJson() => {
    'code': code,
    if (label != null) 'label': label,
    if (clearLabel) 'label': null,
    if (dimension != null) 'dimension': dimension!.name,
    if (factorNum != null) 'factor_num': factorNum,
    if (factorDen != null) 'factor_den': factorDen,
    if (unEceCode != null) 'un_ece_code': unEceCode,
    if (sortOrder != null) 'sort_order': sortOrder,
  };
}

/// The units of a business and the commands that maintain them.
abstract interface class WorkspaceUnits {
  /// The units of [workspaceId], archived ones included, in their order.
  Future<List<WorkspaceUnit>> units(String workspaceId);

  /// Creates a unit or edits one (`workspace_unit_save_v1`): a retried [requestId] answers once.
  Future<WorkspaceUnit> save(String workspaceId, {required String requestId, required MeasureUnitDraft draft});

  /// Hides or shows a unit that is no longer used (`workspace_unit_archive_v1`).
  Future<void> archive(String workspaceId, {required String requestId, required String code, required bool archived});
}

/// Millionths in one: a quantity holds six decimals.
final BigInt _micro = BigInt.from(10).pow(6);

/// The exact fraction a typed factor is, as the server stores it: `0.001` is 1/1000 and `1000` is 1000/1, reduced. Null when it
/// is not above zero.
({int num, int den})? factorOfQuantity(ExactQuantity factor) {
  if (factor.isNegative || factor.isZero) return null;
  final million = _micro;
  final g = factor.micro.gcd(million);
  return (num: (factor.micro ~/ g).toInt(), den: (million ~/ g).toInt());
}

/// A unit's factor as the person reads it: a decimal (`1000`, `0.001`) when six decimals hold it, else the fraction (`1/3`).
String factorText(WorkspaceUnit unit) {
  final micro = BigInt.from(unit.factorNum) * _micro;
  final den = BigInt.from(unit.factorDen);
  if (micro.remainder(den) != BigInt.zero) return '${unit.factorNum}/${unit.factorDen}';
  final read = ExactQuantity.tryParse(_decimal(micro ~/ den));
  return read.value?.text ?? '${unit.factorNum}/${unit.factorDen}';
}

/// Millionths as decimal text (`1500000` is `1.500000`).
String _decimal(BigInt micro) {
  final digits = micro.abs().toString().padLeft(7, '0');
  return '${micro.isNegative ? '-' : ''}${digits.substring(0, digits.length - 6)}.${digits.substring(digits.length - 6)}';
}

/// The 13 units every business starts with, in the order of the server's seed (0951): the six of the original stock registry, then
/// length, area and time. A built-in's code, dimension and factor are fixed; the business may give it a word of its own.
const List<WorkspaceUnit> builtInUnits = [
  WorkspaceUnit(code: 'piece', dimension: UnitDimension.count, factorNum: 1, factorDen: 1, unEceCode: 'C62', builtIn: true, sortOrder: 10),
  WorkspaceUnit(code: 'g', dimension: UnitDimension.mass, factorNum: 1, factorDen: 1, unEceCode: 'GRM', builtIn: true, sortOrder: 20),
  WorkspaceUnit(code: 'kg', dimension: UnitDimension.mass, factorNum: 1000, factorDen: 1, unEceCode: 'KGM', builtIn: true, sortOrder: 30),
  WorkspaceUnit(code: 'ml', dimension: UnitDimension.volume, factorNum: 1, factorDen: 1, unEceCode: 'MLT', builtIn: true, sortOrder: 40),
  WorkspaceUnit(code: 'cl', dimension: UnitDimension.volume, factorNum: 10, factorDen: 1, unEceCode: 'CLT', builtIn: true, sortOrder: 50),
  WorkspaceUnit(code: 'l', dimension: UnitDimension.volume, factorNum: 1000, factorDen: 1, unEceCode: 'LTR', builtIn: true, sortOrder: 60),
  WorkspaceUnit(code: 'mm', dimension: UnitDimension.length, factorNum: 1, factorDen: 1000, unEceCode: 'MMT', builtIn: true, sortOrder: 70),
  WorkspaceUnit(code: 'cm', dimension: UnitDimension.length, factorNum: 1, factorDen: 100, unEceCode: 'CMT', builtIn: true, sortOrder: 80),
  WorkspaceUnit(code: 'm', dimension: UnitDimension.length, factorNum: 1, factorDen: 1, unEceCode: 'MTR', builtIn: true, sortOrder: 90),
  WorkspaceUnit(code: 'km', dimension: UnitDimension.length, factorNum: 1000, factorDen: 1, unEceCode: 'KMT', builtIn: true, sortOrder: 100),
  WorkspaceUnit(code: 'm2', dimension: UnitDimension.area, factorNum: 1, factorDen: 1, unEceCode: 'MTK', builtIn: true, sortOrder: 110),
  WorkspaceUnit(code: 'min', dimension: UnitDimension.time, factorNum: 1, factorDen: 1, unEceCode: 'MIN', builtIn: true, sortOrder: 120),
  WorkspaceUnit(code: 'h', dimension: UnitDimension.time, factorNum: 60, factorDen: 1, unEceCode: 'HUR', builtIn: true, sortOrder: 130),
];

/// The units an item was counted in before a business had units of its own (0747): what the pickers offer while the feature is off.
const Set<String> _originalStockUnitCodes = {'piece', 'g', 'kg', 'ml', 'cl', 'l'};

/// The units a picker for what an item is counted in offers: the six of before while the feature is off, every unit that is not
/// archived when it is on, and always [keep] (the unit the item already has, archived or not, so editing it never loses it).
List<WorkspaceUnit> pickableUnits(List<WorkspaceUnit> all, {required bool unitsOn, String? keep}) => [
  for (final u in all)
    if (u.code == keep || (unitsOn ? !u.archived : _originalStockUnitCodes.contains(u.code))) u,
];
