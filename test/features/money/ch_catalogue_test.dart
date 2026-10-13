// SPDX-License-Identifier: AGPL-3.0-or-later
// test-inventory: pure rules — the invariant is the Swiss UID and the dated rate plan
//
// #2360 — a Swiss seller's UID has the MWST suffix and a valid check digit
// (server twin `swiss_uid_valid`, pgTAP 177), prints as CHE-123.456.789
// MWST, and the 2028 rates wait for the vote of 2026-11-29.
import 'package:deskilo/features/money/domain/vat_catalogue.dart';
import 'package:deskilo/features/money/domain/vat_compliance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the UID: suffix, check digit, shape', () {
    for (final ok in [
      'CHE-109.322.551 MWST',
      'CHE109322551MWST',
      'CHE-109.322.551 TVA',
      'che-109.322.551 iva',
    ]) {
      expect(isValidSwissUid(ok), isTrue, reason: ok);
    }
    for (final bad in [
      'CHE-109.322.551',
      'CHE-109.322.552 MWST',
      'CHE-109.322 MWST',
      'E109322551MWST',
      'CHE-000.000.030 MWST',
      '',
    ]) {
      expect(isValidSwissUid(bad), isFalse, reason: bad);
    }
    expect(isValidSwissUid('CHE-109.322.551', requireSuffix: false), isTrue);
  });

  test('the UID prints the way art. 26 MWSTG shows it', () {
    expect(formatSwissUid('CHE109322551MWST'), 'CHE-109.322.551 MWST');
    expect(formatSwissUid('che 109 322 551 tva'), 'CHE-109.322.551 TVA');
    expect(formatSwissUid('CHE-109.322.551'), 'CHE-109.322.551');
    expect(formatSwissUid('not a uid'), 'not a uid');
  });

  test('the Swiss rates are dated and the 2028 plan waits for the vote', () {
    final rates = vatCatalogueFor('CH');
    expect(rates.map((r) => r.percent), [8.1, 3.8, 2.6, 0]);
    expect(rates.take(3).every((r) => r.validFrom == '2024-01-01'), isTrue);
    expect(rates[3].category, 'E');
    expect(rates[3].exemptionReason, contains('Art. 21 Abs. 2 Ziff. 21'));
    // The plan is data, ready; nothing applies until the one line flips.
    expect(vatPlannedChangeFor('CH', 8.1), isNull);
    final standard = vatPlannedChangeFor('CH', 8.1, approved: true)!;
    expect((standard.toPercent, standard.from), (8.5, '2028-01-01'));
    expect(vatPlannedChangeFor('CH', 3.8, approved: true)!.toPercent, 4.0);
    // The reduced rate is not touched by the reform.
    expect(vatPlannedChangeFor('CH', 2.6, approved: true), isNull);
  });
}
