// SPDX-License-Identifier: AGPL-3.0-or-later
// #2488 -- the audit trail states its amounts in the workspace's currency
// (its digits follow the currency: a yen has none, a dinar three). #3658: a
// trail without a currency is refused, never read in a default one.
import 'package:deskilo/core/i18n/money_format.dart';
import 'package:deskilo/features/money/domain/audit_trail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final events = [
    AuditEvent(
      at: DateTime.utc(2026, 10, 5),
      kind: 'invoice',
      reference: 'INV-1',
      description: 'October',
      amountCents: 123456,
    ),
  ];
  String csv({String? currencyCode}) => buildAuditTrailCsv(
        events: events,
        generatedAt: DateTime.utc(2026, 11),
        workspaceName: 'Cowork',
        currencyCode: currencyCode,
      );
  String amount(String csvText) =>
      csvText.split('\n').firstWhere((l) => l.startsWith('2026-10-05')).split(',')[5];

  test('a euro workspace reads two decimals; a yen workspace none; a dinar three', () {
    expect(amount(csv(currencyCode: 'EUR')), '1234.56');
    expect(amount(csv(currencyCode: 'JPY')), '123456');
    expect(amount(csv(currencyCode: 'KWD')), '123.456');
  });

  test('without a currency the trail is refused, not written in a default one', () {
    expect(csv, throwsA(isA<CurrencyUnavailable>()));
    expect(() => csv(currencyCode: ''), throwsA(isA<CurrencyUnavailable>()));
  });

  test('a missing currency is no currency: no code, every amount unavailable', () {
    expect(moneyFormat('', locale: null).unavailable, isTrue);
    expect(moneyFormat(null, locale: null).unavailable, isTrue);
    expect(moneyFormat('CHF', locale: null).code, 'CHF');
  });
}
