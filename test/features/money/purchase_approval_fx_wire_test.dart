// SPDX-License-Identifier: AGPL-3.0-or-later
// The scoped rate stays exact and rejects invalid wire states and types.
import 'package:deskilo/features/money/domain/purchase_approval_reads.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  JsonReader fx(Map<String, Object?> values) => JsonReader(values, context: 'fx');

  test('recorded rate remains exact decimal text', () {
    final rate = PurchaseApprovalFx.fromJson(fx({
      'status': 'recorded',
      'currency': 'CHF',
      'functional_currency': 'EUR',
      'rate': '12345678.1234567890',
      'rate_date': '2026-11-02',
      'source': 'bank',
    }));
    expect(rate.status, PurchaseApprovalFxStatus.recorded);
    expect(rate.rate, '12345678.1234567890');
    expect(rate.functionalCurrency, 'EUR');
    expect(rate.source, 'bank');
  });

  test('same, missing and malformed rates do not masquerade as recorded', () {
    for (final status in ['same_currency', 'missing']) {
      final value = PurchaseApprovalFx.fromJson(fx({
        'status': status, 'currency': 'EUR', 'functional_currency': 'EUR',
      }));
      expect(value.rate, isNull);
    }
    expect(() => PurchaseApprovalFx.fromJson(fx({'status': 'unknown'})), throwsFormatException);
    expect(() => PurchaseApprovalFx.fromJson(fx({
      'status': 'recorded', 'currency': 'CHF', 'functional_currency': 'EUR',
      'rate': 1.2, 'rate_date': '2026-11-02', 'source': 'bank',
    })), throwsA(isA<JsonShapeException>()));
  });
}
