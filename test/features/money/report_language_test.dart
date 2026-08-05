// SPDX-License-Identifier: 0BSD
//
// Report-language resolution (#496): member's preferred language →
// per-language template overlay → workspace language → country
// language, RAISING for a multi-language country with nothing
// configured — the app must not guess between French and German.
import 'dart:io';

import 'package:deskilo/core/locale/report_language.dart';
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveReportLanguage (#496)', () {
    test('the member\'s own language wins', () {
      expect(
        resolveReportLanguage(
            memberLocale: 'de', workspaceLocale: 'fr', countryCode: 'FR'),
        'de',
      );
    });

    test('unset member falls back to the workspace language', () {
      expect(
        resolveReportLanguage(workspaceLocale: 'fr', countryCode: 'DE'),
        'fr',
      );
    });

    test('nothing configured: the country decides — unambiguous '
        'countries only', () {
      expect(resolveReportLanguage(countryCode: 'FR'), 'fr');
      expect(resolveReportLanguage(countryCode: 'AT'), 'de');
      expect(resolveReportLanguage(countryCode: 'US'), 'en');
      // A language the app does not ship documents in → English.
      expect(resolveReportLanguage(countryCode: 'PT'), 'en');
    });

    test('a MULTI-language country with nothing configured raises', () {
      for (final country in ['BE', 'CH', 'LU', 'CA']) {
        expect(
          () => resolveReportLanguage(countryCode: country),
          throwsA(isA<AmbiguousReportLanguage>()),
          reason: country,
        );
        // …but a configured workspace language settles it.
        expect(
          resolveReportLanguage(
              workspaceLocale: 'fr', countryCode: country),
          'fr',
        );
      }
    });

    test('an unsupported member language is skipped, not honored', () {
      expect(
        resolveReportLanguage(
            memberLocale: 'pt', workspaceLocale: 'it', countryCode: 'FR'),
        'it',
      );
    });
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

  test('migration 0098 stores the member preferred locale', () {
    final sql =
        File('supabase/migrations/0098_member_preferred_locale.sql')
            .readAsStringSync();
    expect(sql, contains('preferred_locale'));
  });
}
