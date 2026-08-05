// SPDX-License-Identifier: 0BSD
//
// Legal-valid invoices (#480): the InvoiceLegal mentions, the statutory
// defaults, the new report variables (seller identity, client address,
// line qty/unit price/VAT rate) and the four presets every document
// ships. The reference: the French mandatory-mention list (coordonnées
// complètes du vendeur, N° TVA, détail des lignes, totaux par taux,
// modalités de règlement, mentions particulières).
import 'dart:io';

import 'package:deskilo/features/money/domain/invoice_legal.dart';
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/presentation/report_defaults.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InvoiceLegal (#480)', () {
    test('round-trips json; absent keys read as empty', () {
      expect(InvoiceLegal.fromJson(const {}), const InvoiceLegal());
      const legal = InvoiceLegal(
        legalForm: 'SARL au capital de 7 500 €',
        registration: 'RCS Saint-Brieuc 680 357 910',
        paymentTerms: 'Règlement à réception',
        latePenalty: '3× taux légal',
        recoveryIndemnity: '40 €',
        escompte: 'Aucun escompte',
        insurance: 'Assurance Pro, France métropolitaine',
        specialMentions: 'TVA non applicable, art. 293 B du CGI',
      );
      expect(InvoiceLegal.fromJson(legal.toJson()), legal);
    });

    test('migration 0094 stores the column the repository reads', () {
      final sql = File('supabase/migrations/0094_invoice_legal.sql')
          .readAsStringSync();
      expect(sql, contains('invoice_legal'));
    });
  });

  group('every document ships the same four presets (#480)', () {
    for (final doc in ['invoice', 'proforma', 'statement', 'r1', 'r2']) {
      test(doc, () {
        final presets = presetsForDoc(doc, null);
        expect(presets.map((p) => p.id),
            ['classic', 'simple', 'verbose', 'formal']);
        // The first preset IS the default the uncustomized doc renders.
        expect(presets.first.bands.header,
            defaultBandsForDoc(doc, null).header);
      });
    }
  });

  group('the shipped invoice presets are legally complete (#480)', () {
    final data = sampleReportData(null);

    for (final id in reportPresetIds) {
      test('preset $id carries the mandatory mentions', () {
        final bands = presetsForDoc('invoice', null)
            .firstWhere((p) => p.id == id)
            .bands;
        final report = renderReportBands(bands: bands, data: data);
        expect(report, isNotNull);
        final text = [
          ...report!.header,
          ...report.body,
          ...report.footer,
        ].map(blockText).join('\n');
        // Seller identity: name, legal form & capital, register, VAT no.
        expect(text, contains('Coworking Demo'));
        expect(text, contains('SARL au capital de 7 500 €'));
        expect(text, contains('RCS Demo City 123 456 789'));
        expect(text, contains('FR 39 680 357 910'));
        // Client name + address.
        expect(text, contains('Alex Sample'));
        expect(text, contains('3 Avenue de la Liberté, 35000 Rennes'));
        // Number and date.
        expect(text, contains('INV-2026-0042'));
        expect(text, contains('2026-07-31'));
        // Per-rate VAT recap + total HT / total TVA / TTC.
        expect(text, contains('20 %'));
        expect(text, contains('120,83 €'));
        expect(text, contains('24,17 €'));
        expect(text, contains('145,00 €'));
        // The four statutory payment clauses.
        expect(text, contains('Payment on receipt.'));
        expect(text, contains('No discount for early payment.'));
        expect(text, contains('three times the statutory interest rate'));
        expect(text, contains('recovery indemnity'));
      });
    }

    test('the verbose preset details qty × unit price and per-line net',
        () {
      final bands = presetsForDoc('invoice', null)
          .firstWhere((p) => p.id == 'verbose')
          .bands;
      final report = renderReportBands(bands: bands, data: data)!;
      final text =
          [...report.header, ...report.body].map(blockText).join('\n');
      expect(text, contains('1 × 120,00 €'));
      expect(text, contains('100,00 €'));
    });

    test('optional mentions stay OFF the document until declared', () {
      final report = renderReportBands(
        bands: defaultBandsForDoc('invoice', null),
        data: {...data, 'insurance': '', 'special_mentions': ''},
      )!;
      final text = report.footer.map(blockText).join('\n');
      expect(text, isNot(contains('Assurance')));
      // …and ON it when they are.
      final withInsurance = renderReportBands(
        bands: defaultBandsForDoc('invoice', null),
        data: {
          ...data,
          'insurance':
              'Assurance décennale — Assurance Pro, France métropolitaine',
        },
      )!;
      expect(withInsurance.footer.map(blockText).join('\n'),
          contains('Assurance décennale'));
    });

    test('the exemption reason replaces the VAT recap for a franchise '
        'workspace (art. 293 B)', () {
      final report = renderReportBands(
        bands: defaultBandsForDoc('invoice', null),
        data: {
          ...data,
          'has_vat': false,
          'vat': const [],
          'exemption_reason': 'TVA non applicable, art. 293 B du CGI',
        },
      )!;
      final text = [...report.body].map(blockText).join('\n');
      expect(text, contains('TVA non applicable, art. 293 B du CGI'));
      expect(text, isNot(contains('24,17')));
    });
  });

  test('reminder letters cite the statutory late-payment clauses (#480)',
      () {
    for (final id in reportPresetIds) {
      final bands =
          presetsForDoc('r2', null).firstWhere((p) => p.id == id).bands;
      final report =
          renderReportBands(bands: bands, data: sampleReportData(null))!;
      final text = [
        ...report.header,
        ...report.body,
        ...report.footer,
      ].map(blockText).join('\n');
      expect(text, contains('three times the statutory interest rate'),
          reason: 'preset $id');
      expect(text, contains('recovery indemnity'), reason: 'preset $id');
    }
  });
}

/// Flattens any block to its visible text.
String blockText(ReportBlock block) => switch (block) {
      ReportHeading(:final text) => text,
      ReportSubheading(:final text) => text,
      ReportText(:final text) => text,
      ReportMuted(:final text) => text,
      ReportTableRow(:final cells) => cells.join(' | '),
      ReportDivider() => '',
      ReportSpacer() => '',
    };
