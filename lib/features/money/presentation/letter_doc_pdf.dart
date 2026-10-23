// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #494 / #875 — a letter document's PDF: its positioned layout when it
// has one that renders, else its bands.
//
// #2898 — a document may bring pictures drawn for it alone (the
// configuration PDF's level plans). They go by the names its markup
// gives them, win over the workspace's image library and are never
// fetched from it. invoice_documents.dart re-exports this file.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/files/file_names.dart';
import '../../../core/l10n/context_l10n.dart';
import '../domain/invoice_pdf.dart';
import '../domain/invoice_report.dart';
import 'invoice_documents.dart' show developmentMark;
import 'report_image_resolve.dart';
import 'report_layout_actions.dart';

/// The PDF of a rendered letter document (#494).
///
/// #875 — with [layoutXml] and [data] the positioned engine renders the
/// letter and [report] is only the fallback for a layout that fails.
Future<({Uint8List bytes, String fileName})> letterDocPdf(
  BuildContext context,
  WidgetRef ref, {
  required InvoiceReport report,
  required String title,
  String? layoutXml,
  Map<String, Object?> data = const {},
}) => letterPdfOf(
  ref,
  (
    report: report,
    title: title,
    layoutXml: layoutXml,
    data: data,
    images: const {},
  ),
  // #917 — read before the first await: the context must not be used
  // across an async gap, and the answer cannot change mid-render.
  pageLabel: context.l10n.invoicePdfPage,
  watermark: developmentMark(context, ref),
);

/// [letterDocPdf] with its words resolved: the [pageLabel], and the
/// [watermark] a development workspace prints (#917). #2898 — the
/// source's `images` are the document's own pictures, by the name its
/// markup gives them, in the positioned layout and the bands alike.
Future<({Uint8List bytes, String fileName})> letterPdfOf(
  WidgetRef ref,
  ({
    InvoiceReport report,
    String title,
    String? layoutXml,
    Map<String, Object?> data,
    Map<String, Uint8List> images,
  })
  source, {
  required String pageLabel,
  String watermark = '',
}) async {
  final (:report, :title, :layoutXml, :data, :images) = source;
  Future<pw.Font> font(String asset) async =>
      pw.Font.ttf(await rootBundle.load(asset));
  if (layoutXml != null) {
    final bytes = await tryLayoutPdf(
      layoutXml: layoutXml,
      data: data,
      what: title,
      documentTitle: title,
      pageLabel: pageLabel,
      font: font,
      image: (name) async => images[name] ?? await layoutImage(ref, name),
      // #917 — a report from a rehearsal space says so, like its
      // invoices do.
      watermark: watermark,
    );
    if (bytes != null) {
      return (bytes: bytes, fileName: '${safeFileSlug(title)}.pdf');
    }
  }
  final bytes = await buildBandedLetterPdf(
    report: report,
    reportImages: await resolveReportImages(
      ref,
      report,
      strict: true,
      prepared: images,
    ),
    pageLabel: pageLabel,
    documentTitle: title,
    baseFont: await font('assets/fonts/Roboto-Regular.ttf'),
    boldFont: await font('assets/fonts/Roboto-Bold.ttf'),
    watermark: watermark,
  );
  return (
    bytes: Uint8List.fromList(bytes),
    fileName: '${safeFileSlug(title)}.pdf',
  );
}
