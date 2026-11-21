// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #917 -- the diagonal mark, painted the same way on EVERY document this
// app produces (#4160: it lives with the other report primitives, not in the
// invoice renderer). Which word a document wears is the HOST's policy (an
// invoice's proforma/void/copy priority is money's); this draws the word it is
// given. Its size follows the word's LENGTH so a long one ('DÉVELOPPEMENT',
// 'FEHLERHAFT') still lands inside the sheet.
import 'dart:math' as math;

import 'package:pdf/widgets.dart' as pw;

import 'report_style.dart';

/// The point size a [watermark] of that length is drawn at.
double reportWatermarkSize(String watermark) =>
    math.min(120.0, 820 / math.max(watermark.length, 1));

/// The foreground builder of a page theme: null for an empty word.
pw.Widget Function(pw.Context)? reportWatermarkForeground(String watermark) {
  if (watermark.isEmpty) return null;
  final markSize = reportWatermarkSize(watermark);
  return (context) => pw.FullPage(
    ignoreMargins: true,
    child: pw.Opacity(
      opacity: reportWatermarkOpacity,
      child: pw.Center(
        child: pw.Transform.rotate(
          angle: math.pi / 4,
          child: pw.Text(
            watermark,
            style: pw.TextStyle(
              fontSize: markSize,
              color: reportWatermark,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ),
    ),
  );
}
