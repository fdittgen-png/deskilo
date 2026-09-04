// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/report_block_widgets.dart';
import 'invoice_actions.dart';

/// #671 — the cover page for a batch print, rendered from the report
/// editor's bands for [docId] through the same pipeline every other
/// document uses.
///
/// Returning three lists rather than a widget keeps the PDF builders
/// free of the money feature: they take pw widgets and never learn what
/// a ReportBand is.
({
  List<pw.Widget> header,
  List<pw.Widget> body,
  List<pw.Widget> footer,
}) batchCover(
  BuildContext context,
  WidgetRef ref, {
  required String docId,
  required Map<String, Object?> data,
}) {
  final report = renderLetterDoc(context, ref, docId: docId, data: data);
  return (
    header: reportBlockWidgets(report.header),
    body: reportBlockWidgets(report.body),
    footer: reportBlockWidgets(report.footer),
  );
}
