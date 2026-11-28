// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4479 (0990) -- the UN/ECE codes a unit may carry are one list on two sides: the app's picker
// (`uneceUnitCodes`) and the server's check (`unece_unit_known`, 0990). A code is added to both or to neither; the built-in units'
// own codes are on it; and what the form refuses is what the list does not hold.
import 'dart:io';

import 'package:deskilo/features/stock/domain/measure_unit_form.dart';
import 'package:deskilo/features/stock/domain/unece_unit_codes.dart';
import 'package:deskilo/features/stock/domain/workspace_units.dart';
import 'package:flutter_test/flutter_test.dart';

/// The origin of the list: the validator configuration the CI e-invoice validators run (tool/einvoice/validate.sh), its release and digest, and
/// the rule that holds the unit codes. Updating the list is a new release of this source in the migration, in the app's list and here.
const _release = 'release-3.0.21';
const _digest = '399395de5f6240a76ccc5751e4ee9dd329e37f5f7cfe4ee5c93188294ce8cd68';
const _rule = 'BR-CL-23';
const _count = 2162;

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
  test('the app lists exactly the codes the server accepts, and both name their source', () {
    expect(uneceUnitCodes.keys.toSet(), _serverCodes());
    expect(uneceUnitCodes, hasLength(_count));
    for (final path in ['supabase/migrations/0990_conversion_provenance_and_unece_list.sql', 'lib/features/stock/domain/unece_unit_codes.dart']) {
      final text = File(path).readAsStringSync();
      expect(text, allOf(contains(_release), contains(_digest), contains(_rule)), reason: '$path names its source');
    }
    expect(File('tool/einvoice/validate.sh').readAsStringSync(), allOf(contains(_release), contains(_digest)), reason: 'the CI validators run the same release');
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
