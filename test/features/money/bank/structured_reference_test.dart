// SPDX-License-Identifier: AGPL-3.0-or-later
// test-inventory: pure rules — the invariant is the QRR and ISO 11649 check digits
//
// #2380 — a structured reference is one only when its check digits hold: a
// QR reference (27 digits, recursive modulus 10, possibly printed in
// groups) or an ISO 11649 creditor reference (RF, modulus 97, possibly
// printed in groups of four) is found in free text; the same characters
// with a wrong check digit are free text.
import 'package:deskilo/features/money/domain/bank/structured_reference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalised for storage and comparison', () {
    expect(normalizeReference(' rf18 5390 0754 7034 '), 'RF18539007547034');
  });

  test('a QR and a creditor reference are told by their check digits', () {
    expect(isQrReference('21 00000 00003 13947 14300 09017'), isTrue);
    expect(isQrReference('210000000003139471430009018'), isFalse);
    expect(isCreditorReference('RF18 5390 0754 7034'), isTrue);
    expect(isCreditorReference('RF19 5390 0754 7034'), isFalse);
  });

  test('found in free text', () {
    expect(
      structuredReferenceIn(
        'Invoice 2026-0042 ref 21 00000 00003 13947 14300 09017 thanks',
      ),
      '210000000003139471430009017',
    );
    expect(
      structuredReferenceIn('Payment RF18 5390 0754 7034 Demo Member Two'),
      'RF18539007547034',
    );
    expect(structuredReferenceIn('rf18539007547034.'), 'RF18539007547034');
  });

  test('wrong check digits are free text', () {
    expect(structuredReferenceIn('ref 210000000003139471430009018'), isNull);
    expect(structuredReferenceIn('Payment RF19 5390 0754 7034'), isNull);
    expect(structuredReferenceIn('Invoice 2026-0042'), isNull);
    expect(structuredReferenceIn(''), isNull);
  });
}
