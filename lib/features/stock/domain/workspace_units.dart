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
import 'package:meta/meta.dart';

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
class UnitDraft {
  const UnitDraft({
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
  Future<WorkspaceUnit> save(String workspaceId, {required String requestId, required UnitDraft draft});

  /// Hides or shows a unit that is no longer used (`workspace_unit_archive_v1`).
  Future<void> archive(String workspaceId, {required String requestId, required String code, required bool archived});
}

/// Why a quantity has no value in another unit.
@visibleForTesting
enum UnitConversionProblem {
  /// Two dimensions: a length is not a mass.
  differentDimensions,

  /// The answer has more than six decimals: it is refused, never rounded.
  notExact,

  /// The answer is beyond what a quantity can hold.
  outOfRange,
}

/// [quantity] of [from] as a quantity of [to], exactly (no screen reads it yet: the Settings > Units screen does): `quantity x from / to` through the dimension's base unit.
@visibleForTesting
({ExactQuantity? value, UnitConversionProblem? problem}) convertUnit(ExactQuantity quantity, WorkspaceUnit from, WorkspaceUnit to) {
  if (from.dimension != to.dimension) return (value: null, problem: UnitConversionProblem.differentDimensions);
  final numerator = quantity.micro * BigInt.from(from.factorNum) * BigInt.from(to.factorDen);
  final denominator = BigInt.from(from.factorDen) * BigInt.from(to.factorNum);
  if (numerator.remainder(denominator) != BigInt.zero) return (value: null, problem: UnitConversionProblem.notExact);
  final micro = numerator ~/ denominator;
  final digits = micro.abs().toString().padLeft(7, '0');
  final read = ExactQuantity.tryParse('${micro.isNegative ? '-' : ''}${digits.substring(0, digits.length - 6)}.${digits.substring(digits.length - 6)}');
  return read.value == null ? (value: null, problem: UnitConversionProblem.outOfRange) : (value: read.value, problem: null);
}
