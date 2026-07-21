// SPDX-License-Identifier: 0BSD
import 'package:deskilo/features/money/domain/payment_method.dart';
import 'package:deskilo/features/money/presentation/payment_method_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'wire names are pinned — the record_payment payload tag is a stable '
      'contract (#154, #192)', () {
    expect(PaymentMethod.bankTransfer.wireName, 'bank_transfer');
    expect(PaymentMethod.cash.wireName, 'cash');
    expect(PaymentMethod.paypal.wireName, 'paypal');
    expect(PaymentMethod.twint.wireName, 'twint');
    expect(PaymentMethod.card.wireName, 'card');
    expect(PaymentMethod.other.wireName, 'other');
    expect(PaymentMethod.wero.wireName, 'wero');
    expect(PaymentMethod.lydia.wireName, 'lydia');
    expect(PaymentMethod.wise.wireName, 'wise');
    // Server-side constraint on record_payment (migration 0019).
    for (final method in PaymentMethod.values) {
      expect(method.wireName.length, lessThanOrEqualTo(32));
    }
  });

  test('fromWire round-trips every value and tolerates unknown tags', () {
    for (final method in PaymentMethod.values) {
      expect(PaymentMethod.fromWire(method.wireName), method);
    }
    expect(PaymentMethod.fromWire(null), isNull);
    expect(PaymentMethod.fromWire(''), isNull);
    expect(PaymentMethod.fromWire('written_by_a_newer_app'), isNull);
  });

  test(
      'displayOrder covers every method exactly once with the catch-all '
      'last — declaration order is append-only, so #192 methods sit after '
      '`other`', () {
    expect(
      PaymentMethod.displayOrder.toSet(),
      PaymentMethod.values.toSet(),
    );
    expect(PaymentMethod.displayOrder.length, PaymentMethod.values.length);
    expect(PaymentMethod.displayOrder.last, PaymentMethod.other);
  });

  test('English fallback labels exist for the #192 methods (brand names)',
      () {
    expect(paymentMethodLabel(null, PaymentMethod.wero), 'Wero');
    expect(paymentMethodLabel(null, PaymentMethod.lydia), 'Lydia');
    expect(paymentMethodLabel(null, PaymentMethod.wise), 'Wise');
  });
}
