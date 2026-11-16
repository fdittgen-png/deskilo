// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4118 -- the page goldens of an invoice in French and German, on A4 and on
// Letter, in both engines (the English four are report_paper_letter_test).
// The invoice is the English one, frozen in the language (#3850) and printed
// through the app's own document path, so its words are the document's own,
// not words written here. Its lines carry what each language makes long: a
// German compound and a French label with its space before the colon.
//
// Besides the ink positions (goldens, compared byte for byte), every word the
// document prints for that language must reach the page whole: a head or a
// label that its column cut, or that wrapped in the middle, fails the test.
// Regenerate the goldens with --dart-define=WRITE_GOLDEN=true only when a
// document is meant to change.
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/presentation/invoice_documents.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_document_model/deskilo_document_model.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pdf_geometry.dart';
import '../../helpers/pdf_text.dart';
import '../../helpers/real_async.dart';

const _write = bool.fromEnvironment('WRITE_GOLDEN');

const _recipient = 'Zephyrine Quarterbridge-Okonkwo';

/// What a language makes long, as lines of the same invoice.
const _long = {
  'fr': [
    'Location : salle de réunion « Le Grand Atelier »',
    'Abonnement : accès illimité',
  ],
  'de': [
    'Bürogemeinschaftsmitgliedschaftsbeitrag',
    'Besprechungsraumnutzungsgebühr',
  ],
};

/// The country whose business prints in the language.
const _country = {'fr': 'FR', 'de': 'DE'};

Invoice _invoice(String language, Paper paper) {
  final long = _long[language]!;
  return Invoice(
    id: 'i1',
    workspaceId: 'w1',
    memberId: 'm1',
    number: 'INV-2026-0050',
    issuedAt: DateTime.utc(2026, 9, 4),
    title: '2026-08',
    currency: 'USD',
    memberName: _recipient,
    memberAddress: '1 Main Street\nSpringfield, IL 62701',
    workspaceName: 'COWORKONTI',
    workspaceAddress: '4 avenue de Castelnau, 34120 Pézenas',
    issuerName: 'Flo',
    signature: 'a' * 64,
    totalCents: 10000 * 60,
    paper: paper.wire,
    documentLanguage: language,
    formatLocale: '${language}_${_country[language]}',
    lines: [
      for (var i = 0; i < 60; i++)
        InvoiceLine(
          kind: 'adjustment',
          label: i < long.length ? long[i] : 'Desk, half day $i',
          amountCents: 10000,
        ),
    ],
  );
}

Workspace _business(String language, {required bool positioned}) => Workspace(
  id: 'ws-$language',
  name: 'COWORKONTI',
  countryCode: _country[language]!,
  currencyCode: 'USD',
  timezone: 'UTC',
  inviteCode: '',
  defaultLocale: language,
  environment: 'prod',
  featureFlags: {
    'invoicePdfTemplate': true,
    'reportDesigner': true,
    'invoicing': true,
    'reportLayouts': positioned,
    'letterStandard': positioned,
    'invoiceAddressWindow': true,
  },
);

/// The invoice as the app prints it, through its own document path.
Future<Uint8List> _print(
  WidgetTester tester,
  String language,
  Paper paper, {
  required bool positioned,
}) async {
  Uint8List? bytes;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('it'), // never the document's language
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          key: const ValueKey('go'),
          onPressed: () async {
            final pdf = await buildInvoicePdfFile(
              context,
              _invoice(language, paper),
              InvoicePdfFileOptions(
                reference: ActiveTaxReference.current,
                workspace: _business(language, positioned: positioned),
              ),
            );
            bytes = Uint8List.fromList(pdf.bytes);
          },
          child: const Text('go'),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    await tester.tap(find.byKey(const ValueKey('go')));
    await untilReal(() => bytes != null, what: 'the invoice PDF build');
  });
  return bytes!;
}

/// The sheets and every ink position, as the English goldens write them.
String _inkGolden(Uint8List bytes, Paper paper) => [
  for (final m in RegExp(
    r'/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+([\d.]+)\s*\]',
  ).allMatches(String.fromCharCodes(bytes)))
    'sheet ${double.parse(m.group(1)!).toStringAsFixed(2)} x '
        '${double.parse(m.group(2)!).toStringAsFixed(2)}',
  for (final i in textPositions(bytes, paper: paper))
    'p${i.page} ${i.xMm.toStringAsFixed(1)} ${i.yMm.toStringAsFixed(1)}',
].join('\n');

void _golden(String name, String actual) {
  final file = File('test/features/money/goldens/$name.txt');
  if (_write) file.writeAsStringSync('$actual\n');
  expect(
    '$actual\n',
    file.readAsStringSync(),
    reason: '$name: regenerate with --dart-define=WRITE_GOLDEN=true',
  );
}

/// The words of the document in [language], by the app's own bundle.
List<String> _words(AppLocalizations l10n, {required bool positioned}) => [
  l10n.invoicePdfIssuedOn,
  l10n.invoicePdfDescription,
  l10n.invoiceBalance,
  if (positioned) ...[
    l10n.invoicePdfPayments,
    l10n.vatPdfNet,
    l10n.reportColQty,
    l10n.reportColUnitPrice,
    l10n.reportColTotal,
    l10n.invoicePdfTitle,
  ] else ...[
    l10n.invoicePdfIssuedBy,
    l10n.invoicePdfCharges,
  ],
];

/// A space of any width is a space.
String _plain(String text) => text.replaceAll(RegExp('[\u00a0\u202f]'), ' ');

/// The lines of the document: consecutive words on one baseline of a page.
List<({int page, double y, String text})> _lines(Uint8List bytes, Paper paper) {
  final runs = [
    for (final (page, texts) in pdfPageTexts(bytes).indexed)
      for (final text in texts) (page: page + 1, text: text),
  ];
  final at = textPositions(bytes, paper: paper);
  expect(runs.length, at.length, reason: 'one position per text run');
  final lines = <({int page, double y, String text})>[];
  for (var i = 0; i < runs.length; i++) {
    final last = lines.isEmpty ? null : lines.last;
    if (last != null &&
        last.page == at[i].page &&
        (last.y - at[i].yMm).abs() < 0.5) {
      lines[lines.length - 1] = (
        page: last.page,
        y: last.y,
        text: '${last.text} ${_plain(runs[i].text)}',
      );
    } else {
      lines.add((page: at[i].page, y: at[i].yMm, text: _plain(runs[i].text)));
    }
  }
  return lines;
}

void main() {
  for (final language in _long.keys) {
    final l10n = lookupAppLocalizations(Locale(language));
    for (final positioned in const [false, true]) {
      for (final paper in Paper.values) {
        final engine = positioned ? 'positioned' : 'banded';
        final name =
            'invoice_ink_${engine}_${paper.wire.toLowerCase()}_$language';
        testWidgets(
          'golden: the $language invoice, $engine, on ${paper.wire}',
          (tester) async {
            final bytes = await _print(
              tester,
              language,
              paper,
              positioned: positioned,
            );
            _golden(name, _inkGolden(bytes, paper));
            // no ink off the sheet
            for (final i in textPositions(bytes, paper: paper)) {
              expect(i.xMm, inInclusiveRange(0, paper.widthMm), reason: '$i');
              expect(i.yMm, inInclusiveRange(0, paper.heightMm), reason: '$i');
            }
            // every word of the document reaches the page whole, on one line,
            // and so do the long labels of its lines
            final lines = _lines(bytes, paper).map((l) => l.text);
            for (final word in [
              ..._words(l10n, positioned: positioned),
              ..._long[language]!,
            ]) {
              expect(
                lines.any((line) => line.contains(_plain(word))),
                isTrue,
                reason: '"$word" is cut or broken on $name: ${lines.toList()}',
              );
            }
          },
        );
      }
    }
  }
}
