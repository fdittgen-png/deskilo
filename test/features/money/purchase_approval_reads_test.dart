// SPDX-License-Identifier: AGPL-3.0-or-later
// #3070: approval read decoding preserves count, continuation and action limits.
import 'package:deskilo/core/data/json_reader.dart';
import 'package:deskilo/features/money/domain/purchase_approval_reads.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('page count and full cursor survive decoding', () {
    final page = PurchaseApprovalPage.fromJson({
      'count': 201,
      'version': 'v1',
      'rows': <Object>[],
      'next': {'created': '2026-01-01T00:00:00Z', 'id': 'last'},
    });
    expect(page.count, 201);
    expect(page.next, (created: '2026-01-01T00:00:00Z', id: 'last'));
    expect(
      () => PurchaseApprovalPage.fromJson({
        'count': 1,
        'version': 'v1',
        'rows': <Object>[],
        'next': {'created': 'x'},
      }),
      throwsA(isA<JsonShapeException>()),
    );
  });
  test('a missing action flag fails closed', () {
    final result = PurchaseApprovalDetail.fromJson({
      'detail': {
        'id': '1',
        'revision': 1,
        'lines': <Object>[],
        'sources': <Object>[],
        'obligations': <Object>[],
      },
      'can_approve': true,
    });
    expect(result.canApprove, isTrue);
    expect(result.canReject, isFalse);
  });
}
