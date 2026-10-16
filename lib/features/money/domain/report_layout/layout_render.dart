// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #875 — the positioned engine: a [LayoutDocument] to a PDF.
//
// The banded engine let position fall out of flow. Here every zone and
// every element resolves its own lengths against the box it sits in,
// so a design that says `x="110mm" y="45mm"` lands there, and the
// conformance harness can measure that it did. The four zones keep the
// #872 contract — header on page one, continuation after, footer on
// every page, body the only thing that flows — because the design says
// so, not because the engine assumed it.
//
// #2592 — the drawing lives in packages/deskilo_document_pdf. What stays
// here is Deskilo's: the Liquid pass with the invoice placeholders, the
// recipient read from the invoice data map, and the band-markup bridge.
import 'dart:typed_data';

import 'package:deskilo_document_pdf/deskilo_document_pdf.dart' as doc;
import 'package:liquify/liquify.dart';
import 'package:pdf/widgets.dart' as pw;

import '../invoice_pdf_template.dart';
import '../invoice_report.dart';
import '../report_block_widgets.dart';
import 'layout_model.dart';
import 'layout_units.dart';
import 'layout_xml.dart';

export 'package:deskilo_document_pdf/deskilo_document_pdf.dart'
    show layoutImageNames;

/// The Liquid pass, then the XML parse — the same order the bands use.
///
/// String VALUES are XML-escaped before Liquid sees them, so a member
/// called "Smith & Sons" cannot turn the document into something that
/// is no longer XML. The template itself is never escaped: it IS the
/// XML. Placeholders are seeded first (#875), so an absent one is empty
/// rather than nil and a guarded element vanishes cleanly.
LayoutDocument renderLayoutDocument(
  String xml,
  Map<String, Object?> data,
) {
  final seeded = <String, Object?>{
    ...InvoicePdfTemplate.placeholderDefaults,
    ...data,
  };
  final String rendered;
  try {
    rendered =
        Template.parse(xml, data: Map.of(_xmlEscaped(seeded))).render();
  } catch (e, st) {
    throw LayoutException(LayoutError.liquid, '$e', cause: e, stackTrace: st);
  }
  return parseLayoutXml(rendered);
}

Map<String, Object?> _xmlEscaped(Map<String, Object?> data) =>
    {for (final e in data.entries) e.key: _escapeValue(e.value)};

Object? _escapeValue(Object? v) => switch (v) {
      // #880 — the owner's texts are values too.
      final OwnerTexts t => t.mapValues((s) => _escapeValue(s)! as String),
      final String s => s
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;')
          .replaceAll('"', '&quot;'),
      final List<dynamic> l => [for (final x in l) _escapeValue(x)],
      final Map<dynamic, dynamic> m => {
          for (final e in m.entries) '${e.key}': _escapeValue(e.value),
        },
      _ => v,
    };


/// Renders [document] to A4 pages.
///
/// [data] is the unescaped map the recipient block reads its name and
/// address from. The legal chrome the bands never templated — the
/// watermark and the digital signature — stays non-templated here too:
/// it is passed in, never designed.
Future<Uint8List> buildLayoutPdf({
  required LayoutDocument document,
  required Map<String, Object?> data,
  required String documentTitle,
  required String pageLabel,
  required pw.Font baseFont,
  required pw.Font boldFont,
  Map<String, Uint8List> images = const {},
  String watermark = '',
  String signatureLabel = '',
  String signature = '',
  List<pw.Widget> additionalBody = const [],
  // #2360 — a page after the document's own (the Swiss QR-bill).
  pw.Page? lastPage,
}) => doc.buildLayoutPdf(
  document: document,
  // #886 — the full name, else the display name.
  recipientName: '${_nonEmpty(data['client_name']) ?? data['member'] ?? ''}',
  recipientAddress: '${data['client_address'] ?? ''}',
  documentTitle: documentTitle,
  pageLabel: pageLabel,
  baseFont: baseFont,
  boldFont: boldFont,
  images: images,
  watermark: watermark,
  signatureLabel: signatureLabel,
  signature: signature,
  additionalBody: additionalBody,
  lastPage: lastPage,
  markup: (source, images) =>
      reportBlockWidgets(parseReportMarkup(source), images: images),
);

Object? _nonEmpty(Object? v) => v == null || '$v'.isEmpty ? null : v;
