// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4442 -- the units of a business as the app reads them: a row decodes with its exact factor and a dimension it knows (one
// it does not know is an error, never a guess), a draft says only what the person changed, and a conversion is exact through
// the base unit: 2.5 km is 2500 m, two dimensions never convert, and an answer six decimals cannot hold is refused.
import 'package:deskilo/features/stock/domain/workspace_units.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

const _km = WorkspaceUnit(code: 'km', dimension: UnitDimension.length, factorNum: 1000, factorDen: 1, builtIn: true);
const _m = WorkspaceUnit(code: 'm', dimension: UnitDimension.length, factorNum: 1, factorDen: 1, builtIn: true);
const _mm = WorkspaceUnit(code: 'mm', dimension: UnitDimension.length, factorNum: 1, factorDen: 1000, builtIn: true);
const _kg = WorkspaceUnit(code: 'kg', dimension: UnitDimension.mass, factorNum: 1000, factorDen: 1, builtIn: true);
const _third = WorkspaceUnit(code: 'third', label: 'A third of a metre', dimension: UnitDimension.length, factorNum: 1, factorDen: 3);
const _huge = WorkspaceUnit(code: 'huge', label: 'Huge', dimension: UnitDimension.length, factorNum: 9000000000000000, factorDen: 1);

String? _text(ExactQuantity q, WorkspaceUnit from, WorkspaceUnit to) => convertUnit(q, from, to).value?.text;

void main() {
  group('a row', () {
    test('decodes with its exact factor, its UN/ECE code and its flags', () {
      final unit = WorkspaceUnit.fromJson({
        'code': 'drum',
        'label': 'Cable drum',
        'dimension': 'length',
        'factor_num': 50,
        'factor_den': 1,
        'un_ece_code': 'C62',
        'built_in': false,
        'archived': true,
        'sort_order': 1000,
      });
      expect([unit.code, unit.label, unit.dimension, unit.factorNum, unit.factorDen, unit.unEceCode, unit.builtIn, unit.archived],
          ['drum', 'Cable drum', UnitDimension.length, 50, 1, 'C62', false, true]);
    });

    test('a built-in has no label, and a dimension this version does not know is an error', () {
      final km = WorkspaceUnit.fromJson({'code': 'km', 'label': null, 'dimension': 'length', 'factor_num': 1000, 'factor_den': 1, 'built_in': true});
      expect([km.label, km.builtIn, km.archived, km.sortOrder], [null, true, false, 1000]);
      expect(() => WorkspaceUnit.fromJson({'code': 'x', 'dimension': 'luminosity', 'factor_num': 1, 'factor_den': 1}), throwsFormatException);
      expect(() => WorkspaceUnit.fromJson({'code': 'x', 'dimension': 'length', 'factor_num': 1}), throwsA(anything));
    });
  });

  group('a draft', () {
    test('carries only what the person set', () {
      expect(const MeasureUnitDraft(code: 'drum').toJson(), {'code': 'drum'});
      expect(
        const MeasureUnitDraft(code: 'drum', label: 'Cable drum', dimension: UnitDimension.length, factorNum: 50, factorDen: 1, unEceCode: 'C62', sortOrder: 5).toJson(),
        {'code': 'drum', 'label': 'Cable drum', 'dimension': 'length', 'factor_num': 50, 'factor_den': 1, 'un_ece_code': 'C62', 'sort_order': 5},
      );
    });

    test('can give a built-in unit the app\'s own word back', () {
      expect(const MeasureUnitDraft(code: 'km', clearLabel: true).toJson(), {'code': 'km', 'label': null});
    });
  });

  group('a conversion', () {
    ExactQuantity q(String text) => ExactQuantity.parse(text);

    test('goes through the base unit, exactly', () {
      expect(_text(q('2.5'), _km, _m), '2500');
      expect(_text(q('250'), _mm, _m), '0.25');
      expect(_text(q('1'), _m, _km), '0.001');
      expect(_text(q('1.5'), _km, _km), '1.5');
      expect(_text(q('-3'), _km, _m), '-3000');
      expect(_text(q('0'), _km, _mm), '0');
    });

    test('never crosses dimensions', () {
      expect(convertUnit(q('1'), _kg, _m).problem, UnitConversionProblem.differentDimensions);
      expect(convertUnit(q('1'), _kg, _m).value, isNull);
    });

    test('refuses an answer six decimals cannot hold, and never rounds it', () {
      expect(convertUnit(q('1'), _m, _third).problem, isNull, reason: 'a metre is exactly three thirds');
      expect(_text(q('1'), _m, _third), '3');
      expect(convertUnit(q('1'), _third, _m).problem, UnitConversionProblem.notExact, reason: 'a third of a metre has no six-decimal value');
      expect(_text(q('3'), _third, _m), '1');
      expect(_text(q('0.000001'), _mm, _km), isNull, reason: 'a millionth of a mm in km is 1e-12');
    });

    test('refuses an answer beyond what a quantity holds', () {
      expect(convertUnit(q('999999999999'), _huge, _mm).problem, UnitConversionProblem.outOfRange);
    });
  });

  group('a factor', () {
    test('typed as a decimal is the exact reduced fraction', () {
      expect(factorOfQuantity(ExactQuantity.parse('1000')), (num: 1000, den: 1));
      expect(factorOfQuantity(ExactQuantity.parse('0.001')), (num: 1, den: 1000));
      expect(factorOfQuantity(ExactQuantity.parse('2.5')), (num: 5, den: 2));
      expect(factorOfQuantity(ExactQuantity.parse('0.000001')), (num: 1, den: 1000000));
      expect(factorOfQuantity(ExactQuantity.parse('0')), isNull);
      expect(factorOfQuantity(ExactQuantity.parse('-1')), isNull);
    });

    test('reads as a decimal when six decimals hold it, else as the fraction', () {
      expect(factorText(_km), '1000');
      expect(factorText(_mm), '0.001');
      expect(factorText(_third), '1/3');
      expect(factorText(const WorkspaceUnit(code: 'h', dimension: UnitDimension.time, factorNum: 60, factorDen: 1)), '60');
    });
  });
}
