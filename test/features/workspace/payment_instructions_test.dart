// SPDX-License-Identifier: 0BSD
import 'package:deskilo/features/workspace/domain/payment_instructions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toDb keys are pinned — the jsonb blob shape is a contract '
      '(#155, #192)', () {
    const instructions = PaymentInstructions(
      iban: ' DE89 3704 0044 0532 0130 00 ',
      paypalMe: 'deskilo',
      reference: 'DesKilo member period',
      wero: '+49 170 0000000',
      lydia: 'deskilo-lydia',
      wise: '@deskilo',
    );
    expect(instructions.toDb(), {
      'iban': 'DE89 3704 0044 0532 0130 00', // trimmed
      'paypal_me': 'deskilo',
      'reference': 'DesKilo member period',
      'wero': '+49 170 0000000',
      'lydia': 'deskilo-lydia',
      'wise': '@deskilo',
      // #711 — the four fields a non-IBAN country needs.
      'account_number': '',
      'bank_code': '',
      'bank_name': '',
      'bic': '',
    });
  });

  test('fromDb → toDb round-trips all ten fields', () {
    const db = {
      'iban': 'FR76 1234',
      'paypal_me': 'somebody',
      'reference': 'ref',
      'wero': '+33 6 00 00 00 00',
      'lydia': '+33 6 11 11 11 11',
      'wise': 'https://wise.com/pay/me/somebody',
      'account_number': '12345678',
      'bank_code': '40-00-01',
      'bank_name': 'Barclays',
      'bic': 'BUKBGB22',
    };
    final instructions = PaymentInstructions.fromDb(db);
    expect(instructions.wero, '+33 6 00 00 00 00');
    expect(instructions.lydia, '+33 6 11 11 11 11');
    expect(instructions.wise, 'https://wise.com/pay/me/somebody');
    expect(instructions.toDb(), db);
  });

  test('absent keys default to empty — a pre-#192 blob still parses', () {
    final instructions = PaymentInstructions.fromDb(const {
      'iban': 'DE89',
      'paypal_me': '',
      'reference': '',
    });
    expect(instructions.wero, '');
    expect(instructions.lydia, '');
    expect(instructions.wise, '');
    expect(instructions.isEmpty, isFalse);
  });

  test('isEmpty is false when only a #192 field is set — the how-to-pay '
      'card must render for a Wero-only workspace', () {
    expect(const PaymentInstructions().isEmpty, isTrue);
    expect(const PaymentInstructions(wero: '+49 170').isEmpty, isFalse);
    expect(const PaymentInstructions(lydia: 'handle').isEmpty, isFalse);
    expect(const PaymentInstructions(wise: '@tag').isEmpty, isFalse);
    // Whitespace-only counts as empty, like the #155 fields.
    expect(
      const PaymentInstructions(wero: ' ', lydia: ' ', wise: ' ').isEmpty,
      isTrue,
    );
  });
}
