// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Report-language resolution (#496, #3850): the reader's preferred language
// → the business's document language → its country's first shipped
// language (the `document_language` rows of the tax reference store) →
// English. It never throws: a country with several shipped languages is one
// whose business chooses, and the server gave every such business one (0753).

import 'package:deskilo/core/country/country_catalog.dart';
import 'package:deskilo/core/locale/report_language.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:flutter_test/flutter_test.dart';

/// A country's official languages, from the bundled reference rows.
List<String> countryDocumentLanguages(String country) =>
    ActiveTaxReference.current.documentLanguagesOf(country)?.languages ?? const [];

void main() {
  group('resolveReportLanguage (#496, #3850)', () {
    test('the reader\'s language wins when the app ships it', () {
      expect(
        resolveReportLanguage(
            memberLocale: 'de', workspaceLocale: 'fr', countryLanguages: const ['fr']),
        'de',
      );
    });

    test('then the business\'s document language', () {
      expect(
        resolveReportLanguage(workspaceLocale: 'fr', countryLanguages: const ['de']),
        'fr',
      );
    });

    test('then the country\'s first shipped language, from the reference rows', () {
      expect(resolveReportLanguage(countryLanguages: countryDocumentLanguages('FR')), 'fr');
      expect(resolveReportLanguage(countryLanguages: countryDocumentLanguages('AT')), 'de');
      expect(resolveReportLanguage(countryLanguages: countryDocumentLanguages('US')), 'en');
      // Belgium's first official language (Dutch) is not shipped: French.
      expect(resolveReportLanguage(countryLanguages: countryDocumentLanguages('BE')), 'fr');
    });

    test('a country whose languages the app does not ship reads English, '
        'where it used to have no entry or throw', () {
      for (final country in ['PL', 'NL', 'PT']) {
        expect(resolveReportLanguage(countryLanguages: countryDocumentLanguages(country)), 'en',
            reason: country);
      }
    });

    test('an unsupported member language is skipped, not honored', () {
      expect(
        resolveReportLanguage(
            memberLocale: 'pt', workspaceLocale: 'it', countryLanguages: const ['fr']),
        'it',
      );
    });
  });

  test('the countries whose business chooses its document language are the '
      'catalogue\'s with more than one shipped language: BE, CA, CH, LU', () {
    expect(
      {
        for (final c in CountryCatalog.countries)
          if (choosesDocumentLanguage(countryDocumentLanguages(c.code))) c.code,
      },
      {'BE', 'CA', 'CH', 'LU'},
    );
    // Every country of the catalogue has its row.
    for (final c in CountryCatalog.countries) {
      expect(countryDocumentLanguages(c.code), isNotEmpty, reason: c.code);
    }
  });

  group('per-language template overlays (#496)', () {
    const base = InvoicePdfTemplate(
      header: '# base',
      extraDocs: {'agreement': ReportBands(header: '# base agreement')},
    );

    test('forLocale merges: overlay documents win, the rest inherits',
        () {
      final template = base.withTranslation(
        'de',
        const InvoicePdfTemplate(
          extraDocs: {'agreement': ReportBands(header: '# DE Vertrag')},
        ),
      );
      final de = template.forLocale('de');
      // The agreement is the German one…
      expect(de.docBands('agreement')!.header, '# DE Vertrag');
      // …the invoice bands inherit the base.
      expect(de.invoiceBands.header, '# base');
      // An unknown language returns the base untouched.
      expect(template.forLocale('it').docBands('agreement')!.header,
          '# base agreement');
      expect(template.forLocale('').invoiceBands.header, '# base');
    });

    test('translations round-trip through the jsonb', () {
      final template = base.withTranslation(
        'fr',
        const InvoicePdfTemplate(header: '# FR facture'),
      );
      final restored = InvoicePdfTemplate.fromJson(
          template.toJson().cast<String, dynamic>());
      expect(restored.forLocale('fr').invoiceBands.header, '# FR facture');
      expect(restored.forLocale('fr').docBands('agreement')!.header,
          '# base agreement');
    });
  });

}
