// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4479 (0990) -- the UN/ECE Recommendation 20 / 21 codes a unit may carry are one list on two sides: the app's picker
// (`uneceUnitCodes`) and the server's check (`unece_unit_known`, 0990). A code is added to both or to neither; the built-in units'
// own codes are on it; and what the form refuses is what the list does not hold.
import 'dart:io';

import 'package:deskilo/features/stock/domain/measure_unit_form.dart';
import 'package:deskilo/features/stock/domain/unece_unit_codes.dart';
import 'package:deskilo/features/stock/domain/workspace_units.dart';
import 'package:flutter_test/flutter_test.dart';

Set<String> _serverCodes() {
  final sql = File('supabase/migrations/0990_conversion_provenance_and_unece_list.sql').readAsStringSync();
  final body = RegExp(r"unece_unit_known\(p_code text\).*?regexp_split_to_array\('([^']*)'", dotAll: true).firstMatch(sql)!.group(1)!;
  return body.split(' ').toSet();
}

MeasureUnitInput _input(String ece, {String stored = ''}) => MeasureUnitInput(
  isNew: false,
  fixed: true,
  code: 'x',
  name: '',
  dimension: UnitDimension.count,
  factor: null,
  unEceCode: ece,
  storedUnEceCode: stored,
);

void main() {
  test('the app lists exactly the codes the server accepts', () {
    expect(uneceUnitCodes.keys.toSet(), _serverCodes());
  });

  test('every built-in unit carries a code of the list', () {
    for (final u in builtInUnits) {
      if (u.unEceCode != null) expect(uneceUnitCodes, contains(u.unEceCode), reason: u.code);
    }
  });

  test('the form refuses a code of the right shape that is not on the list, and keeps one stored before', () {
    expect(measureUnitProblems(_input('QQQ')), contains(MeasureUnitField.unEceCode));
    expect(measureUnitProblems(_input('KGM')), isNot(contains(MeasureUnitField.unEceCode)));
    expect(measureUnitProblems(_input('')), isNot(contains(MeasureUnitField.unEceCode)));
    expect(measureUnitProblems(_input('QZQ', stored: 'QZQ')), isNot(contains(MeasureUnitField.unEceCode)), reason: 'unchanged');
    expect(measureUnitProblems(_input('ZQZ', stored: 'QZQ')), contains(MeasureUnitField.unEceCode), reason: 'changed to another');
  });
}
