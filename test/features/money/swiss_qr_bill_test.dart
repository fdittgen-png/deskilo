// SPDX-License-Identifier: AGPL-3.0-or-later
// test-inventory: pure rules — the invariant is the SIX QR-bill data structure
//
// #2360 — the payload of a Swiss QR-bill follows the SIX guidelines
// (version 0200): header, account, creditor, amount, debtor, reference,
// information, EPD. Vectors: the SIX documentation's QR-IBAN and QRR, the
// ISO 11649 specimen.
import 'package:deskilo/features/money/domain/swiss_qr_bill.dart';
import 'package:flutter_test/flutter_test.dart';

const _creditor = SwissQrAddress(
  name: 'Robert Schneider AG',
  street: 'Rue du Lac',
  houseNumber: '1268',
  postalCode: '2501',
  city: 'Biel',
);
const _debtor = SwissQrAddress(
  name: 'Pia-Maria Rutschmann-Schnyder',
  street: 'Grosse Marktgasse',
  houseNumber: '28',
  postalCode: '9400',
  city: 'Rorschach',
);

void main() {
  test('IBAN checks: Swiss, QR-IBAN, checksum', () {
    expect(isSwissIban('CH44 3199 9123 0008 8901 2'), isTrue);
    expect(isQrIban('CH44 3199 9123 0008 8901 2'), isTrue);
    expect(isSwissIban('CH93 0076 2011 6238 5295 7'), isTrue);
    expect(isQrIban('CH93 0076 2011 6238 5295 7'), isFalse);
    expect(isSwissIban('CH93 0076 2011 6238 5295 8'), isFalse);
    expect(isSwissIban('DE89 3704 0044 0532 0130 00'), isFalse);
  });

  test('QRR: 26 digits and the recursive modulus-10 check digit', () {
    expect(qrrReferenceOf('2026-0042'), isNotNull);
    expect(isValidQrr('210000000003139471430009017'), isTrue);
    expect(isValidQrr('210000000003139471430009018'), isFalse);
    expect(qrrCheckDigit('21000000000313947143000901'), 7);
    expect(qrrReferenceOf('no digits'), isNull);
    expect(qrrReferenceOf('1' * 27), isNull);
    expect(isValidQrr(qrrReferenceOf('INV-2026-0042')!), isTrue);
  });

  test('SCOR: ISO 11649', () {
    expect(isValidScor('RF18 5390 0754 7034'), isTrue);
    expect(scorReferenceOf('539007547034'), 'RF18539007547034');
    expect(isValidScor(scorReferenceOf('INV-2026-0042')!), isTrue);
    expect(scorReferenceOf('x' * 22), isNull);
  });

  test('the payload: header, account, creditor, amount, reference, EPD', () {
    const bill = SwissQrBill(
      iban: 'CH44 3199 9123 0008 8901 2',
      creditor: _creditor,
      amountCents: 194975,
      currency: 'CHF',
      debtor: _debtor,
      referenceType: 'QRR',
      reference: '210000000003139471430009017',
      additionalInfo: 'Order of 15 June 2020',
    );
    expect(bill.problems, isEmpty);
    expect(bill.payload.split('\r\n'), [
      'SPC',
      '0200',
      '1',
      'CH4431999123000889012',
      'S',
      'Robert Schneider AG',
      'Rue du Lac',
      '1268',
      '2501',
      'Biel',
      'CH',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '1949.75',
      'CHF',
      'S',
      'Pia-Maria Rutschmann-Schnyder',
      'Grosse Marktgasse',
      '28',
      '9400',
      'Rorschach',
      'CH',
      'QRR',
      '210000000003139471430009017',
      'Order of 15 June 2020',
      'EPD',
    ]);
    expect(bill.accountGrouped, 'CH44 3199 9123 0008 8901 2');
    expect(bill.referenceGrouped, '21 00000 00003 13947 14300 09017');
    expect(bill.amountGrouped, '1 949.75');
  });

  test('the reference type and the account must agree', () {
    SwissQrBill with_(String iban, String type, String ref) => SwissQrBill(
      iban: iban,
      creditor: _creditor,
      amountCents: 1000,
      currency: 'CHF',
      referenceType: type,
      reference: ref,
    );
    expect(
      with_('CH44 3199 9123 0008 8901 2', 'SCOR', 'RF18539007547034').problems,
      contains('qrIbanNeedsQrr'),
    );
    expect(
      with_(
        'CH93 0076 2011 6238 5295 7',
        'QRR',
        '210000000003139471430009017',
      ).problems,
      contains('qrrNeedsQrIban'),
    );
    expect(with_('CH93 0076 2011 6238 5295 7', 'NON', '').problems, isEmpty);
    expect(
      with_('CH93 0076 2011 6238 5295 7', 'SCOR', 'RF18539007547035').problems,
      contains('reference'),
    );
  });

  test('currency, amount, lengths and the Latin character set', () {
    const long = SwissQrAddress(
      name: 'x',
      postalCode: '1',
      city: 'a very long town name that exceeds thirty-five characters',
    );
    const bill = SwissQrBill(
      iban: 'CH93 0076 2011 6238 5295 7',
      creditor: long,
      amountCents: 0,
      currency: 'USD',
    );
    expect(bill.problems, containsAll(['currency', 'amount', 'creditor.city']));
    expect(clean('Zoë Ørsted – Łódź\n'), 'Zoë Ørsted . Łódź');
  });

  test('forInvoice: QR-IBAN takes QRR, a plain IBAN SCOR, else none', () {
    final qr = SwissQrBill.forInvoice(
      iban: 'CH93 0076 2011 6238 5295 7',
      qrIban: 'CH44 3199 9123 0008 8901 2',
      creditor: _creditor,
      debtor: _debtor,
      totalCents: 10810,
      currency: 'CHF',
      invoiceNumber: 'INV-2026-0042',
    )!;
    expect(qr.referenceType, 'QRR');
    expect(qr.account, 'CH4431999123000889012');
    final plain = SwissQrBill.forInvoice(
      iban: 'CH93 0076 2011 6238 5295 7',
      qrIban: '',
      creditor: _creditor,
      debtor: null,
      totalCents: 10810,
      currency: 'EUR',
      invoiceNumber: 'INV-2026-0042',
    )!;
    expect(plain.referenceType, 'SCOR');
    expect(plain.problems, isEmpty);
    SwissQrBill? make({
      String iban = '',
      String qrIban = '',
      int total = 100,
    }) => SwissQrBill.forInvoice(
      iban: iban,
      qrIban: qrIban,
      creditor: _creditor,
      debtor: null,
      totalCents: total,
      currency: 'CHF',
      invoiceNumber: '42',
    );
    expect(make(), isNull, reason: 'no Swiss account');
    expect(make(iban: 'DE89 3704 0044 0532 0130 00'), isNull);
    expect(
      make(iban: 'CH93 0076 2011 6238 5295 7', total: -5),
      isNull,
      reason: 'a credit note is not paid in',
    );
    // A debtor the guidelines refuse is left out; the bill stands.
    final noDebtor = SwissQrBill.forInvoice(
      iban: 'CH93 0076 2011 6238 5295 7',
      qrIban: '',
      creditor: _creditor,
      debtor: const SwissQrAddress(name: '', postalCode: '', city: ''),
      totalCents: 100,
      currency: 'CHF',
      invoiceNumber: '42',
    )!;
    expect(noDebtor.debtor, isNull);
  });

  test('a street line is split into street and house number', () {
    final a = SwissQrAddress.fromLines(
      name: 'n',
      streetLine: 'Bahnhofstrasse 12a',
      postalCode: '8001',
      city: 'Zürich',
    );
    expect((a.street, a.houseNumber), ('Bahnhofstrasse', '12a'));
    final b = SwissQrAddress.fromLines(
      name: 'n',
      streetLine: 'Rue du Lac',
      postalCode: '2501',
      city: 'Biel',
    );
    expect((b.street, b.houseNumber), ('Rue du Lac', ''));
  });
}
