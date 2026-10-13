// SPDX-License-Identifier: AGPL-3.0-or-later
// test-inventory: pure rules — the invariant is the UK catalogue and the VRN shape
//
// #2359 — a UK workspace starts from HMRC's rates, and the registration
// number is checked against HMRC's shape (the server twin is
// `invoice_essentials_missing`, pgTAP 174).
import 'package:deskilo/features/money/domain/vat_catalogue.dart';
import 'package:deskilo/features/money/domain/vat_compliance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the UK catalogue: 20, 5, a zero rate and an exempt line, dated', () {
    final rates = vatCatalogueFor('GB');
    expect(rates.map((r) => (r.percent, r.category)), [
      (20.0, 'S'),
      (5.0, 'S'),
      (0.0, 'Z'),
      (0.0, 'E'),
    ]);
    expect(rates.first.isDefault, isTrue);
    expect(rates.where((r) => r.isDefault), hasLength(1));
    expect(rates[0].validFrom, '2011-01-04');
    expect(rates[1].validFrom, '1997-09-01');
    // The exempt line carries its statutory reason; no other line does.
    expect(rates[3].exemptionReason, contains('Schedule 9'));
    expect(rates.take(3).every((r) => r.exemptionReason.isEmpty), isTrue);
    expect(vatCatalogueNote('GB'), contains('opted to tax'));
  });

  test('HMRC registration numbers', () {
    for (final ok in [
      'GB123456789',
      'GB 123 4567 89',
      'GB123456789012',
      'GBGD001',
      'GBHA599',
      'XI123456789',
    ]) {
      expect(looksLikeEuVatId(ok), isTrue, reason: ok);
    }
    for (final bad in ['GB12345', 'GB1234567890', 'GBGD0011', 'GB12345678A']) {
      expect(looksLikeEuVatId(bad), isFalse, reason: bad);
    }
  });
}
