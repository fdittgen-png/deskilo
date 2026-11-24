// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4442 -- a quantity in another unit of the same dimension, exactly, for the tests that check what the server's
// `workspace_unit_convert` answers: `quantity x from / to` through the dimension's base unit. The app converts nothing
// itself (the server does), so no lib file carries this.
import 'package:deskilo/features/stock/domain/workspace_units.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// Why a quantity has no value in another unit.
enum UnitConversionProblem {
  /// Two dimensions: a length is not a mass.
  differentDimensions,

  /// The answer has more than six decimals: it is refused, never rounded.
  notExact,

  /// The answer is beyond what a quantity can hold.
  outOfRange,
}

/// [quantity] of [from] as a quantity of [to].
({ExactQuantity? value, UnitConversionProblem? problem}) convertUnit(ExactQuantity quantity, WorkspaceUnit from, WorkspaceUnit to) {
  if (from.dimension != to.dimension) return (value: null, problem: UnitConversionProblem.differentDimensions);
  final numerator = quantity.micro * BigInt.from(from.factorNum) * BigInt.from(to.factorDen);
  final denominator = BigInt.from(from.factorDen) * BigInt.from(to.factorNum);
  if (numerator.remainder(denominator) != BigInt.zero) return (value: null, problem: UnitConversionProblem.notExact);
  final micro = numerator ~/ denominator;
  final digits = micro.abs().toString().padLeft(7, '0');
  final text = '${micro.isNegative ? '-' : ''}${digits.substring(0, digits.length - 6)}.${digits.substring(digits.length - 6)}';
  final read = ExactQuantity.tryParse(text);
  return read.value == null ? (value: null, problem: UnitConversionProblem.outOfRange) : (value: read.value, problem: null);
}
