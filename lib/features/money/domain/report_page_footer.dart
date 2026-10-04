// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:pdf/widgets.dart' as pw;

import 'report_style.dart';

/// Space for the continuation page number is identical on every sheet.
/// MultiPage measures this entire band before flowing the body, then
/// anchors its bottom to the page margin. Extra footer lines grow upward.
const double reportPageNumberBandHeight = 18;

pw.Widget reportPageFooter(
  pw.Context context, {
  required List<pw.Widget> content,
  required String pageLabel,
}) => pw.Column(
  mainAxisSize: pw.MainAxisSize.min,
  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
  children: [
    ...content,
    pw.SizedBox(
      height: reportPageNumberBandHeight,
      child: context.pageNumber > 1
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
