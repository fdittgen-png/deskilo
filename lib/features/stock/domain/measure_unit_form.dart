// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4442 -- what a person may type into the unit form, as a pure function: the rules are the server's own (0951) so a refusal
// there is the rare case, not the usual one. The form maps each problem to the sentence under its field.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import 'workspace_units.dart';

/// The fields of the unit form that can be wrong.
enum MeasureUnitField { code, name, dimension, factor, unEceCode }

final _code = RegExp(r'^[a-z][a-z0-9_]{0,19}$');
final _ece = RegExp(r'^[A-Z0-9]{2,3}$');

/// What the person typed into the form. [isNew]: a unit being created (its code, dimension and factor are chosen); [fixed]: a
/// built-in unit, whose dimension and factor are not the person's to change; [factor] is the typed factor read as an exact
/// quantity, or null when it is not one.
class MeasureUnitInput {
  const MeasureUnitInput({
    required this.isNew,
    required this.fixed,
    required this.code,
    required this.name,
    required this.dimension,
    required this.factor,
    required this.unEceCode,
  });

  final bool isNew;
  final bool fixed;
  final String code;
  final String name;
  final UnitDimension? dimension;
  final ExactQuantity? factor;
  final String unEceCode;
}

/// The fields that are wrong in what the person typed.
Set<MeasureUnitField> measureUnitProblems(MeasureUnitInput input) => {
  if (input.isNew && !_code.hasMatch(input.code.trim())) MeasureUnitField.code,
  if (input.name.trim().length > 40 || (input.isNew && input.name.trim().isEmpty)) MeasureUnitField.name,
  if (input.isNew && input.dimension == null) MeasureUnitField.dimension,
  if (!input.fixed && (input.factor == null || factorOfQuantity(input.factor!) == null)) MeasureUnitField.factor,
  if (input.unEceCode.trim().isNotEmpty && !_ece.hasMatch(input.unEceCode.trim())) MeasureUnitField.unEceCode,
};

/// The unit a quantity of [dimension] is counted in: the built-in whose factor is 1.
WorkspaceUnit? baseUnitOf(Iterable<WorkspaceUnit> units, UnitDimension dimension) {
  for (final u in units) {
    if (u.builtIn && u.dimension == dimension && u.factorNum == u.factorDen) return u;
  }
  return null;
}
