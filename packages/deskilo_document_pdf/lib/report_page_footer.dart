// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:pdf/widgets.dart' as pw;

import 'report_style.dart';

/// Space for the continuation page number is identical on every sheet.
/// MultiPage measures this entire band before flowing the body, then
/// anchors its bottom to the page margin. Extra footer lines grow upward.
const double _reportPageNumberBandHeight = 18;

pw.Widget reportPageFooter(
  pw.Context context, {
  required List<pw.Widget> content,
  required String pageLabel,
  // #2862 — a report numbers page 1 too ("Page 1/3"); a letter starts at
  // page 2, so a one-page letter carries no number at all.
  bool numberFirstPage = false,
}) => pw.Column(
  mainAxisSize: pw.MainAxisSize.min,
  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
  children: [
    ...content,
    pw.SizedBox(
      height: _reportPageNumberBandHeight,
      child: numberFirstPage || context.pageNumber > 1
          ? pw.Align(
              alignment: pw.Alignment.bottomRight,
              child: pw.Text(
                '$pageLabel ${context.pageNumber}/${context.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: reportSmallSize,
                  color: reportMuted,
                ),
              ),
            )
          : null,
    ),
  ],
);
