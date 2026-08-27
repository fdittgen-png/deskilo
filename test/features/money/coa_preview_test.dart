// SPDX-License-Identifier: 0BSD
//
// #671 — the chart-of-accounts PREVIEW.
//
// It exists so an owner can see what a real chart looks like against
// their own country, and so the FEC/DATEV export sheets can PROPOSE
// account numbers instead of showing four blank fields whose meaning
// only an accountant knows.
//
// The whole risk of this feature is that it stops reading as a preview.
// The tests below are mostly about that: an exempt workspace must never
// be shown a VAT account it does not owe, an unknown country must not be
// handed France's chart wearing a national label, and the printable must
// carry its disclaimer.
import 'package:deskilo/features/money/domain/coa_preview.dart';
import 'package:deskilo/features/money/domain/vat_regime.dart';
import 'package:flutter_test/flutter_test.dart';

CoaChart chart(String country, VatRegime regime) => coaChartFor(
      countryCode: country,
      regime: regime,
      noteFor: (role) => 'note:${role.name}',
    );

void main() {
  group('the suggestion fits the country', () {
    test('France proposes the PCG, and it matches what the FEC defaults to',
        () {
      final c = chart('FR', VatRegime.vatRegistered);
      expect(c.code, 'PCG');
      // fec.dart's FecAccounts defaults. If either side moves, the
      // preview would promise numbers the export does not use.
      expect(c.numberFor(CoaAccountRole.customers), '411000');
      expect(c.numberFor(CoaAccountRole.revenue), '706000');
      expect(c.numberFor(CoaAccountRole.bank), '512000');
      expect(c.numberFor(CoaAccountRole.vat), '445710');
    });

    test('Germany and Austria propose SKR03, matching the DATEV defaults',
        () {
      for (final country in ['DE', 'AT']) {
        final c = chart(country, VatRegime.vatRegistered);
        expect(c.code, 'SKR03', reason: '$country uses DATEV/SKR');
        expect(c.numberFor(CoaAccountRole.customers), '10000');
        expect(c.numberFor(CoaAccountRole.revenue), '8400');
        expect(c.numberFor(CoaAccountRole.bank), '1200');
      }
    });

    test('the case of the country code does not matter', () {
      expect(chart('fr', VatRegime.exempt).code, 'PCG');
      expect(chart('De', VatRegime.exempt).code, 'SKR03');
    });

    test('an unknown country gets a GENERIC chart, never France\'s', () {
      final c = chart('JP', VatRegime.vatRegistered);
      expect(c.code, 'GEN',
          reason: 'a wrong-country chart that LOOKS national misleads '
              'more than one that is obviously generic');
      expect(c.numberFor(CoaAccountRole.customers), isNot('411000'));
    });

    test('every supported country resolves to a chart with all roles', () {
      // The 14 countries the setup questionnaire offers.
      for (final country in [
        'FR', 'DE', 'BE', 'ES', 'IT', 'LU', 'CH', 'AT',
        'NL', 'PT', 'GB', 'NO', 'US', 'CA',
      ]) {
        final c = chart(country, VatRegime.vatRegistered);
        expect(c.code, isNotEmpty, reason: '$country has no chart');
        for (final role in CoaAccountRole.values) {
          expect(() => c.numberFor(role), returnsNormally,
              reason: '$country is missing ${role.name}');
        }
      }
    });
  });

  group('it never suggests tax a workspace does not charge', () {
    test('an exempt or out-of-scope workspace gets NO VAT account', () {
      for (final regime in [VatRegime.exempt, VatRegime.notSubject]) {
        final c = chart('FR', regime);
        expect(
          c.accounts.any((a) => a.role == CoaAccountRole.vat),
          isFalse,
          reason: 'showing "TVA collectée" to an association that owes no '
              'VAT tells it to book something that does not exist',
        );
        // The other three still stand.
        expect(c.accounts.length, 3);
      }
    });

    test('a VAT-registered workspace gets it', () {
      final c = chart('FR', VatRegime.vatRegistered);
      expect(c.accounts.any((a) => a.role == CoaAccountRole.vat), isTrue);
      expect(c.accounts.length, 4);
    });
  });

  group('it stays a preview', () {
    test('every account carries a note explaining itself', () {
      // The reader is someone who does NOT already know what a
      // receivable is — a bare number would teach them nothing.
      final c = chart('DE', VatRegime.vatRegistered);
      for (final a in c.accounts) {
        expect(a.note, isNotEmpty, reason: '${a.number} has no explanation');
      }
    });

    test('labels stay in the CHART\'s language, not the reader\'s', () {
      // An accountant recognises "Prestations de services"; a translated
      // label is not findable in their software.
      expect(chart('FR', VatRegime.vatRegistered)
          .accounts
          .firstWhere((a) => a.role == CoaAccountRole.revenue)
          .label,
          'Prestations de services');
      expect(chart('DE', VatRegime.vatRegistered)
          .accounts
          .firstWhere((a) => a.role == CoaAccountRole.bank)
          .label,
          'Bank');
    });
  });
}
