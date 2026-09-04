// SPDX-License-Identifier: 0BSD
//
// #874 — THE LOCAL REPORT PROBE.
//
//   flutter test test/features/money/report_probe_test.dart --plain-name probe
//
// Renders an invoice through the real engine, measures the produced
// PDF, prints every zone in millimetres with a verdict, and writes the
// file to build/pdf-conformance/ so it can be opened and — the point of
// the exercise — folded into an envelope.
//
// It is a test rather than a bin/ script because the PDF engine needs
// the Flutter test binding to load fonts, and because a probe that is
// also a gate cannot rot: it runs in CI with everything else.
//
// Point it at REAL BANDS by pasting a design into `_bands` below; leave
// it null to probe the built-in layout.
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/features/money/domain/address_window.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_pdf.dart';
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/domain/report_conformance.dart';
import 'package:deskilo/features/money/presentation/invoice_line_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../helpers/pdf_geometry.dart';

/// The design under probe. Paste a workspace's real bands in here;
/// `return null` instead to probe the built-in layout.
ReportBands? bandsUnderProbe() => const ReportBands(
  header: '''# {{ workspace }}
{% if seller_legal_form != "" %}> {{ seller_legal_form }}{% endif %}
{% if workspace_address != "" %}> {{ workspace_address }}{% endif %}
{% if seller_registration != "" %}> {{ seller_registration }}{% endif %}''',
  body: '''## FACTURE {{ number }}
> Date d'émission : {{ issued }}
> Prestation : {{ period }}

= Désignation | Quantité | Prix unit HT | Total HT
{% for line in lines %}{{ line.label }} | {{ line.qty }} | {{ line.unit_price }} | {{ line.amount }}
{% endfor %}---''',
  continuation: '''> {{ workspace }} · {{ number }}
---''',
  footer: '''---
:::
> {{ workspace }}
|||
{% if iban != "" %}> IBAN : {{ iban }}{% endif %}
|||
{% if payment_terms != "" %}> {{ payment_terms }}{% endif %}
:::''',
    );

pw.Font _ttf(String path) =>
    pw.Font.ttf(ByteData.sublistView(File(path).readAsBytesSync()));

const _strings = InvoicePdfStrings(
  invoiceTitle: 'Facture', issuedOn: 'Émise le', issuedBy: 'Émise par',
  billedTo: 'Facturé à', total: 'Total TTC', signature: 'Signature',
  voided: '', voidedWatermark: 'Erronée', proforma: 'Proforma',
  replaces: 'Remplace', description: 'Désignation', charges: 'Charges',
  payments: 'Règlements', annex: 'Annexe', attendance: 'Présences',
  activity: 'Réservations', reserved: 'réservé', page: 'Page',
);

void main() {
  test('probe', () async {
    const window = AddressWindow.right;
    final invoice = Invoice(
      id: 'i', workspaceId: 'w', memberId: 'm',
      number: 'INV-2026-0045',
      issuedAt: DateTime.utc(2026, 9, 4),
      title: '2026-08', currency: 'EUR',
      memberName: 'SASU KaloA',
      memberAddress: '209 rue Jean Bart, Immeuble AGORA 1B\n31670 LABÈGE',
      workspaceName: 'COWORKONTI',
      workspaceAddress: '4 avenue de Castelnau, 34120 Pézenas',
      issuerName: 'Flo', signature: 'a' * 64, totalCents: 10000,
      lines: const [
        InvoiceLine(
            kind: 'adjustment',
            label: 'Participation 100 %',
            amountCents: 10000),
      ],
    );

    final bands = bandsUnderProbe();
    final report = bands == null
        ? null
        : renderReportBands(bands: bands, data: {
            'workspace': invoice.workspaceName,
            'workspace_address': invoice.workspaceAddress,
            'seller_legal_form': 'Association loi 1901',
            'seller_registration': 'SIRET 10825191900016',
            'number': invoice.number,
            'issued': '4 sept. 2026',
            'period': 'août 2026',
            'iban': 'FR76 1027 8090 5300 0206 7120 122',
            'payment_terms': 'Paiement à réception, à 30 jours.',
            'lines': [
              {'label': 'Participation 100 %', 'qty': '1',
               'unit_price': '100,00 €', 'amount': '100,00 €'},
            ],
          });

    final bytes = await buildInvoicePdf(
      invoice: invoice,
      strings: _strings,
      report: report,
      addressWindow: window,
      money: (c) => '${(c / 100).toStringAsFixed(2)} €',
      lineText: (l) => invoiceLineText(null, l),
      activityText: (e) => annexEntryText(null, e),
      dateLabel: '4 sept. 2026',
      periodLabel: 'août 2026',
      baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
      boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
    );

    final path = saveForInspection(bytes, 'probe-invoice.pdf');
    final ink = textPositions(bytes).where((i) => i.page == 1).toList();
    final issues = <ConformanceIssue>[];

    // ignore: avoid_print
    print('\n  PDF: $path   (${bands == null ? "built-in" : "bands"})\n');
    for (final zone in reportZones(window)) {
      final inZone = ink.where((i) => zone.containsY(i.yMm)).toList();
      final left = zone.leftMm;
      final width = zone.widthMm;
      var verdict = inZone.isEmpty ? 'empty' : '${inZone.length} runs';
      if (left != null) {
        for (final i in inZone) {
          if (i.xMm < left - 0.5) {
            issues.add(ConformanceIssue(zone.name,
                '${i.xMm.toStringAsFixed(1)} mm is left of $left mm'));
          }
          if (width != null && i.xMm > left + width) {
            issues.add(ConformanceIssue(zone.name,
                '${i.xMm.toStringAsFixed(1)} mm overruns the '
                '${width.toStringAsFixed(0)} mm zone'));
          }
        }
      }
      if (zone.name == 'address field' && inZone.isEmpty) {
        issues.add(ConformanceIssue(zone.name,
            'NO RECIPIENT — the envelope shows blank, and a French '
            'invoice without the buyer named is non-compliant'));
        verdict = 'EMPTY';
      }
      // ignore: avoid_print
      print('  ${zone.name.padRight(15)} '
          '${zone.topMm.toStringAsFixed(0).padLeft(3)}–'
          '${zone.bottomMm.toStringAsFixed(0).padLeft(3)} mm   $verdict');
    }

    // Nothing may sit between the aperture and where the body resumes.
    for (final i in ink) {
      if (i.yMm > (addressWindowTop + addressWindowHeight) * 25.4 / 72 &&
          i.yMm < addressWindowFlowResume * 25.4 / 72) {
        issues.add(ConformanceIssue(
            'tolerance band', '$i sits under the aperture'));
      }
    }

    // ignore: avoid_print
    print(issues.isEmpty
        ? '\n  CONFORMS\n'
        : '\n  ${issues.length} ISSUE(S):\n${issues.map((i) => "    $i").join("\n")}\n');
    expect(issues, isEmpty, reason: issues.join('; '));
  });
}
