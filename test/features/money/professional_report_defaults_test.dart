// SPDX-License-Identifier: AGPL-3.0-or-later
// Country-aware default output and preservation of each report's actual
// information are the contract; owner designs must continue to win.
import 'dart:io';

import 'package:deskilo/features/money/domain/address_window.dart';
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/domain/report_kind.dart';
import 'package:deskilo/features/money/domain/report_layout/layout_render.dart';
import 'package:deskilo/features/money/presentation/report_defaults.dart';
import 'package:deskilo/features/money/presentation/report_layout_defaults.dart';
import 'package:deskilo/l10n/app_localizations_de.dart';
import 'package:deskilo/l10n/app_localizations_fr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../helpers/pdf_geometry.dart';

void main() {
  test('every registered document has a professional preset that renders', () {
    for (final kind in reportKinds(reminderLevels: 3)) {
      for (final locale in [AppLocalizationsFr(), AppLocalizationsDe()]) {
        final preset = presetsForDoc(
          kind.id,
          locale,
        ).singleWhere((p) => p.id == 'professional');
        expect(
          renderReportBands(
            bands: preset.bands,
            data: sampleReportData(locale),
          ),
          isNotNull,
          reason: kind.id,
        );
        final xml = resolveLayoutXmlFor(
          template: InvoicePdfTemplate.empty,
          kindId: kind.id,
          letterStandard: true,
          l10n: locale,
        );
        if (xml != null) {
          expect(
            () => renderLayoutDocument(xml, sampleReportData(locale)),
            returnsNormally,
            reason: kind.id,
          );
        }
      }
    }
  });

  test('all variants retain payment and consumption-specific sections', () {
    for (final preset in presetsForDoc('payments', null)) {
      expect(preset.bands.body, contains('validated_total'));
      expect(preset.bands.body, contains('pending_payments_total'));
    }
    for (final preset in presetsForDoc('usage', null)) {
      expect(preset.bands.body, contains('usage_records'));
    }
    for (final kind in ['workspace', 'usage', 'vat', 'payments', 'status']) {
      expect(
        defaultBandsForDoc(kind, null).footer,
        isNot(contains('late_penalty')),
        reason: kind,
      );
    }
  });

  test(
    'country selects the postal default; explicit owner preference wins',
    () {
      for (final (country, side) in [('FR', 'fr'), ('DE', 'din')]) {
        final xml = resolveLayoutXmlFor(
          template: InvoicePdfTemplate.empty,
          kindId: 'invoice',
          letterStandard: true,
          countryCode: country,
        );
        expect(xml, contains('<recipient window="$side"/>'));
      }
      expect(
        resolveLayoutXmlFor(
          template: const InvoicePdfTemplate(addressWindow: AddressWindow.left),
          kindId: 'invoice',
          letterStandard: true,
          countryCode: 'FR',
        ),
        contains('<recipient window="din"/>'),
      );
      const custom = InvoicePdfTemplate(layouts: {'invoice': 'owner layout'});
      expect(
        resolveLayoutXmlFor(
          template: custom,
          kindId: 'invoice',
          letterStandard: true,
          countryCode: 'DE',
        ),
        'owner layout',
      );
    },
  );

  test(
    'professional FR and DE invoice PDFs place recipient on the correct side',
    () async {
      final data = {
        ...sampleReportData(null),
        'client_name': 'EXAMPLE RECIPIENT',
        'client_address': '18 Example Street\n12345 Example City',
      };
      for (final (country, x) in [('FR', 110.0), ('DE', 20.0)]) {
        final xml = resolveLayoutXmlFor(
          template: InvoicePdfTemplate.empty,
          kindId: 'invoice',
          letterStandard: true,
          countryCode: country,
        )!;
        final bytes = await buildLayoutPdf(
          document: renderLayoutDocument(xml, data),
          data: data,
          documentTitle: 'Synthetic invoice',
          pageLabel: 'Page',
          baseFont: pw.Font.ttf(
            File('assets/fonts/Roboto-Regular.ttf')
                .readAsBytesSync()
                .buffer
                .asByteData(),
          ),
          boldFont: pw.Font.ttf(
            File('assets/fonts/Roboto-Bold.ttf')
                .readAsBytesSync()
                .buffer
                .asByteData(),
          ),
        );
        final output = Directory('build/professional-reports')
          ..createSync(recursive: true);
        File('${output.path}/invoice-$country.pdf').writeAsBytesSync(bytes);
        final address = textPositions(bytes)
            .where((p) => p.page == 1 && p.yMm >= 45 && p.yMm < 85)
            .toList();
        expect(address, isNotEmpty);
        expect(address.every((p) => p.xMm >= x - .5 && p.xMm < x + 85), isTrue);
      }
    },
  );
}
