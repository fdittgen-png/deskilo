// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:deskilo/core/data/json_reader.dart';
import 'package:deskilo/features/money/domain/supplier_payables_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('continuation is explicit and retains both cursor fields', () {
    final page = SupplierPayablesPage.fromJson({
      'rows': <Object>[],
      'next': {'created': '2026-01-01T00:00:00Z', 'id': 'last'},
    });
    expect(page.rows, isEmpty);
    expect(page.next, (created: '2026-01-01T00:00:00Z', id: 'last'));
    expect(SupplierPayablesPage.fromJson({'rows': <Object>[], 'next': null}).next,
        isNull);
  });

  test('an incomplete cursor is an error, not the end of the list', () {
    expect(
      () => SupplierPayablesPage.fromJson({
        'rows': <Object>[],
        'next': {'created': '2026-01-01T00:00:00Z'},
      }),
      throwsA(isA<JsonShapeException>()),
    );
  });
}
