// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4499 -- a scanned package unit counts by its factor: a carton of 12 is 12 pieces. A unit the server names without a
// factor, or with a factor that is not positive (a tag still on a unit name no unit of the item has), is an answer of
// the wrong shape: the scan reads it as unreadable, never as one piece.
import 'package:deskilo/features/stock/domain/stock_code_resolver.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonShapeException;
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _answer(Map<String, Object?> unit) => {
  'kind': 'tag',
  'code': 'E28011606000020000004499',
  'item': {'id': 'i1', 'name': 'Water', 'unit': 'piece'},
  'unit': unit,
  'tag': {'bound': true, 'owner_kind': 'unit'},
};

void main() {
  test('a package unit with its factor counts by it', () {
    final r = StockCodeResolution.fromJson(_answer({'unit': 'box_of_6', 'factor_num': 6, 'factor_den': 1}));
    expect(r.unit!.factor, (num: 6, den: 1));
  });

  test('a package unit without a factor is unreadable, not one piece', () {
    expect(() => StockCodeResolution.fromJson(_answer({'unit': 'Box of 6'})), throwsA(isA<JsonShapeException>()));
    expect(
      () => StockCodeResolution.fromJson(_answer({'unit': 'Box of 6', 'factor_num': 6, 'factor_den': null})),
      throwsA(isA<JsonShapeException>()),
    );
  });

  test('a factor that is not positive is unreadable too', () {
    expect(
      () => StockCodeResolution.fromJson(_answer({'unit': 'box_of_6', 'factor_num': 0, 'factor_den': 1})),
      throwsA(isA<JsonShapeException>()),
    );
  });

  test('a code with no package unit is the item itself', () {
    final r = StockCodeResolution.fromJson({'kind': 'item', 'code': '4006381333931', 'item': {'id': 'i1', 'name': 'Water', 'unit': 'piece'}});
    expect(r.unit, isNull);
  });
}
