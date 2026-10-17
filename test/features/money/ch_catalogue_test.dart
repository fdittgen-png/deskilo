// SPDX-License-Identifier: AGPL-3.0-or-later
// test-inventory: pure rules — the invariant is the Swiss UID and the dated rate plan
//
// #2360 — a Swiss seller's UID has the MWST suffix and a valid check digit
// (server twin `swiss_uid_valid`, pgTAP 177), prints as CHE-123.456.789
// MWST, and the 2028 rates wait for the vote of 2026-11-29.
import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
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
    // The plan is data (#2539): proposed rows, nothing applies while unconfirmed.
    const today = '2026-10-16';
    expect(vatPlannedChangeFor('CH', 8.1, asOf: today), isNull);
    expect(vatPlannedChangeFor('CH', 3.8, asOf: today), isNull);
    expect(vatCatalogueNote('CH', asOf: today), isNot(contains('The vote passed')));
    expect(vatCatalogueFor('CH', asOf: '2027-12-31').first.percent, 8.1);
  });

  test('the platform owner confirms the plan: the change is proposed, the rates do not move', () {
    const today = '2026-10-16';
    final confirmed = _confirmedPlan();
    final standard = vatPlannedChangeFor('CH', 8.1, asOf: today, reference: confirmed)!;
    expect((standard.toPercent, standard.from), (8.5, '2028-01-01'));
    expect(vatPlannedChangeFor('CH', 3.8, asOf: today, reference: confirmed)!.toPercent, 4.0);
    // The reduced rate is not touched by the reform.
    expect(vatPlannedChangeFor('CH', 2.6, asOf: today, reference: confirmed), isNull);
    expect(vatCatalogueNote('CH', asOf: today, reference: confirmed), contains('The vote passed'));
    // Until the day, today's rate stays 8.1; from it, the catalogue reads 8.5.
    expect(vatCatalogueFor('CH', asOf: today, reference: confirmed).first.percent, 8.1);
    expect(vatCatalogueFor('CH', asOf: '2028-02-01', reference: confirmed).first.percent, 8.5);
    // Once the new rate is in force there is nothing left to plan.
    expect(vatPlannedChangeFor('CH', 8.5, asOf: '2028-02-01', reference: confirmed), isNull);
  });

  test('a proposal classifies no line until it is confirmed', () {
    final now = ActiveTaxReference.current;
    expect(now.groupOfRate('CH', 4.0, 'S', asOf: '2028-02-01'), '');
    expect(_confirmedPlan().groupOfRate('CH', 4.0, 'S', asOf: '2028-02-01'), 'intermediate');
  });

  test('a withdrawn plan leaves the old rate in force on the day', () {
    final withdrawn = TaxReferenceSet([
      for (final r in ActiveTaxReference.current.rows)
        if (r.validFrom != '2028-01-01')
          if (r.country == 'CH' && r.validTo == '2028-01-01') r.reopenedUntil(null) else r,
    ]);
    expect(vatCatalogueFor('CH', asOf: '2028-02-01', reference: withdrawn).first.percent, 8.1);
    expect(vatPlannedChangeFor('CH', 8.1, asOf: '2026-10-16', reference: withdrawn), isNull);
  });
}

/// The bundled data with the two 2028 versions confirmed, as after the vote.
TaxReferenceSet _confirmedPlan() => TaxReferenceSet([
      for (final r in ActiveTaxReference.current.rows)
        if (r.domain == TaxDomain.rate && r.country == 'CH' && r.validFrom == '2028-01-01')
          r.confirmedWith('Federal Gazette')
        else
          r,
    ]);
