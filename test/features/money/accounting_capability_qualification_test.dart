// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1868 — an export's QUALIFICATION is a separate fact from its well-formed
// bytes: balanced rows never promote invoice-only data to a complete FEC, an
// uncertified PT file is never "certified", and nothing is labelled
// accepted by an authority.
import 'package:deskilo/core/country/country_catalog.dart';
import 'package:deskilo/features/money/domain/accounting_capability.dart';
import 'package:deskilo/features/money/domain/accounting_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every offered format has one reviewed decision, and no stray ones', () {
    expect(
      accountingCapabilities.keys.toSet(),
      accountingFormats.map((f) => f.id).toSet(),
    );
    for (final f in accountingFormats) {
      expect(capabilityOf(f).producible, isTrue, reason: f.id);
    }
  });

  test('FEC from invoice-only data cannot be presented as complete books', () {
    final c = capabilityOf(fecFormat);
    expect(c.obligations, contains(Obligation.completePostedBooks));
    expect(c.mayPresentAsComplete, isFalse);
  });

  test('PT keeps the certification obligation apart from the spec', () {
    final c = capabilityOf(safTPtFormat);
    expect(c.obligations, contains(Obligation.softwareCertification));
    expect(safTPtFormat.uncertifiedSoftware, isTrue);
    expect(c.mayPresentAsComplete, isFalse);
  });

  test('no format is recorded as accepted by a target', () {
    for (final f in accountingFormats) {
      expect(
        capabilityOf(f).state,
        isNot(QualificationState.targetAccepted),
        reason: f.id,
      );
    }
  });

  test('every regulatory format carries an open obligation', () {
    for (final f in accountingFormats.where(
      (f) => f.claim == FormatClaim.regulatory,
    )) {
      expect(capabilityOf(f).obligations, isNotEmpty, reason: f.id);
    }
  });

  test('a format nobody reviewed is unsupported, never allowed', () {
    const stray = AccountingFormat(
      id: 'stray',
      claim: FormatClaim.exchange,
      countries: {},
      extension: 'csv',
    );
    expect(capabilityOf(stray).state, QualificationState.unsupported);
    expect(capabilityOf(stray).producible, isFalse);
  });

  test('every catalogued country gets the generic document handoff', () {
    for (final c in CountryCatalog.countries) {
      final offered = formatsFor(c.code).map((f) => f.id);
      expect(offered, contains('accountant_csv'), reason: c.code);
      expect(offered, contains('audit_trail'), reason: c.code);
    }
    // An unknown country is unqualified for any national file but keeps the
    // generic route.
    final unknown = formatsFor('ZZ').map((f) => f.id).toSet();
    expect(unknown, {'saft', 'accountant_csv', 'audit_trail', 'bundle'});
  });
}
