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
import 'package:deskilo/features/money/presentation/invoice_actions.dart';
import 'package:deskilo/features/money/presentation/report_defaults.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:flutter_test/flutter_test.dart';

Workspace _workspace(Map<String, dynamic> invoiceLegal) => Workspace(
      id: 'ws-1',
      name: 'Espace Pézenas',
      countryCode: 'FR',
      currencyCode: 'EUR',
      timezone: 'Europe/Paris',
      inviteCode: 'CODE123456',
      invoiceLegal: invoiceLegal,
    );

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

    test('the verbose preset details unit price, qty and per-line net '
        'as table columns (#482)', () {
      final bands = presetsForDoc('invoice', null)
          .firstWhere((p) => p.id == 'verbose')
          .bands;
      final report = renderReportBands(bands: bands, data: data)!;
      final text =
          [...report.header, ...report.body].map(blockText).join('\n');
      expect(text, contains('Unit price | Qty'));
      expect(text, contains('120,00 € | 1 | 100,00 €'));
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

  group('the facture layout (#482)', () {
    test('the ::: / ||| markup parses into side-by-side columns', () {
      final blocks = parseReportMarkup('''
:::
Seller SA
> 1 rue du Port
|||
Client SARL
> 2 avenue de la Gare
:::''');
      final columns = (blocks.single as ReportColumns).columns;
      expect(columns, hasLength(2));
      expect((columns[0][0] as ReportText).text, 'Seller SA');
      expect((columns[1][0] as ReportText).text, 'Client SARL');
    });

    test('an empty first column pushes the totals block right', () {
      final blocks = parseReportMarkup('''
:::
|||
= Total | 100 €
:::''');
      final columns = (blocks.single as ReportColumns).columns;
      expect(columns[0], isEmpty);
      expect((columns[1].single as ReportTableRow).bold, isTrue);
    });

    test('an unclosed fence still parses — the rest becomes one column',
        () {
      final blocks = parseReportMarkup(':::\nleft\n|||\nright');
      final columns = (blocks.single as ReportColumns).columns;
      expect(columns, hasLength(2));
    });

    test('the default invoice follows the reference structure: '
        'brand|title row, seller|client row, 4-column line table, '
        'right-aligned totals', () {
      final report = renderReportBands(
        bands: defaultBandsForDoc('invoice', null),
        data: sampleReportData(null),
      )!;
      // Header: two column rows (brand/title, seller/client) around a
      // divider.
      final headerColumns =
          report.header.whereType<ReportColumns>().toList();
      expect(headerColumns, hasLength(2));
      // The client box carries the client's own identifiers (B2B).
      final clientBox =
          headerColumns[1].columns[1].map(blockText).join('\n');
      expect(clientBox, contains('Alex Sample'));
      expect(clientBox, contains('FR 79 849 149 108'));
      // Body: the line table header names the statutory columns…
      final tableHeader = report.body
          .whereType<ReportTableRow>()
          .firstWhere((r) => r.bold);
      expect(tableHeader.cells,
          ['Description', 'Unit price', 'Qty', 'Total']);
      // …and the totals sit in a right-pushed column group.
      final totals = report.body.whereType<ReportColumns>().single;
      expect(totals.columns.first, isEmpty);
      expect(totals.columns.last.map(blockText).join('\n'),
          contains('145,00 €'));
    });
  });

  group('association invoicing (#484)', () {
    test('a company workspace gets the four statutory clause defaults',
        () {
      final data = legalMentionData(null, _workspace(const {}));
      expect(data['payment_terms'], 'Payment on receipt.');
      expect(data['late_penalty'], isNot(''));
      expect(data['recovery_indemnity'], isNot(''));
      expect(data['escompte'], isNot(''));
    });

    test('an association suppresses the B2B-only clause defaults — '
        'payment terms stay, explicit text still prints', () {
      final data = legalMentionData(
          null, _workspace(const {'seller_kind': 'association'}));
      expect(data['payment_terms'], 'Payment on receipt.');
      expect(data['late_penalty'], '');
      expect(data['recovery_indemnity'], '');
      expect(data['escompte'], '');

      final explicit = legalMentionData(
          null,
          _workspace(const {
            'seller_kind': 'association',
            'late_penalty': 'Pénalités selon nos CGV',
          }));
      expect(explicit['late_penalty'], 'Pénalités selon nos CGV');
    });

    test('suppressed clauses VANISH from the rendered document — no '
        'empty bullet lines', () {
      final association = legalMentionData(
          null, _workspace(const {'seller_kind': 'association'}));
      final report = renderReportBands(
        bands: defaultBandsForDoc('invoice', null),
        data: {...sampleReportData(null), ...association},
      )!;
      final footer = report.footer.map(blockText).join('\n');
      expect(footer, contains('Payment on receipt.'));
      expect(footer, isNot(contains('recovery')));
      expect(footer, isNot(contains('statutory interest')));
      // The reminder letter drops them too.
      final letter = renderReportBands(
        bands: defaultBandsForDoc('r1', null),
        data: {...sampleReportData(null), ...association},
      )!;
      final letterText = [
        ...letter.header,
        ...letter.body,
        ...letter.footer,
      ].map(blockText).join('\n');
      expect(letterText, isNot(contains('statutory interest')));
    });

    test('the association exemption mention prints on the document '
        '(art. 261, 7-1° CGI)', () {
      final report = renderReportBands(
        bands: defaultBandsForDoc('invoice', null),
        data: {
          ...sampleReportData(null),
          'has_vat': false,
          'vat': const [],
          'exemption_reason':
              'Exonération de TVA, art. 261, 7-1° du CGI',
        },
      )!;
      expect(report.body.map(blockText).join('\n'),
          contains('art. 261, 7-1°'));
    });

    test('migration 0095 gates every VAT chokepoint on the declared '
        'regime', () {
      final sql = File('supabase/migrations/0095_vat_regime_gate.sql')
          .readAsStringSync();
      expect(sql, contains('workspace_charges_vat'));
      expect(sql, contains("vat_regime = 'vat_registered'"));
      expect(sql, contains('workspace_default_vat_percent'));
      expect(sql, contains('record_service_charge'));
      expect(sql, contains('buy_package'));
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
      ReportColumns(:final columns) => [
          for (final column in columns) column.map(blockText).join('\n'),
        ].join('\n'),
      ReportDivider() => '',
      ReportSpacer() => '',
    };
