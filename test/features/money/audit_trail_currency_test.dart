// SPDX-License-Identifier: AGPL-3.0-or-later
// #2488 -- the audit trail states its amounts in the workspace's currency
// (its digits follow the currency: a yen has none, a dinar three), and only
// reads as the registry's default currency when no workspace names one.
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

  test('without a currency the registry default (the euro) stands, as it always did', () {
    expect(amount(csv()), '1234.56');
  });

  test('an empty currency code formats as the registry default currency', () {
    expect(moneyFormat('').code, 'EUR');
    expect(moneyFormat(null).code, 'EUR');
    expect(moneyFormat('CHF').code, 'CHF');
  });
}
