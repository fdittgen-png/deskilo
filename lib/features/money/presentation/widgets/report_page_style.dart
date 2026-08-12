// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

/// The PRINT-FIDELITY contract (#548) — one shared source for every
/// on-screen rendering of a report band, mirroring `invoice_pdf.dart`
/// POINT FOR POINT: same page metrics (A4, the same margins), same
/// colors (ink/muted/accent are constants of the printed document, not
/// of the app theme — paper is white in dark mode too), same font
/// (the exact Roboto TTFs the PDF embeds, registered as the
/// `ReportRoboto` family), same sizes and paddings. The visual editor,
/// the in-designer preview and the quick preview all draw through
/// this file, so the design surface IS the generated document — the
/// professional-designer promise (Crystal/DevExpress/Docentric).
abstract final class ReportPage {
  /// A4 in PDF points — 1pt is rendered as 1 logical pixel at 100 %.
  static const double width = 595.27559;
  static const double height = 841.88976;

  /// `invoice_pdf.dart`: `margin: EdgeInsets.fromLTRB(48, 44, 48, 44)`.
  static const EdgeInsets margins = EdgeInsets.fromLTRB(48, 44, 48, 44);

  /// The printable height of one page — the page-break guide interval.
  static double get contentHeight => height - margins.top - margins.bottom;

  /// Print colors — constants of the document (PdfColors.blueGrey900 /
  /// blueGrey600 / the DesKilo accent), independent of the app theme.
  static const Color ink = Color(0xFF263238);
  static const Color muted = Color(0xFF546E7A);
  static const Color accent = Color(0xFFD32F2F);
  static const Color paper = Colors.white;

  /// The designer's backdrop and chrome — NOT part of the document.
  static const Color backdrop = Color(0xFFECEFF1);
  static const Color chrome = Color(0xFF78909C);

  /// The family registered in pubspec over the SAME Roboto TTFs the
  /// PDF embeds — glyph-identical text on screen and on paper.
  static const String fontFamily = 'ReportRoboto';

  // The exact text styles of `_reportWidget` in invoice_pdf.dart.
  static const TextStyle heading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: ink,
  );
  static const TextStyle subheading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 8,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.2,
    color: muted,
  );
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    color: ink,
  );
  static const TextStyle small = TextStyle(
    fontFamily: fontFamily,
    fontSize: 8,
    color: muted,
  );
  static TextStyle row({required bool bold}) => TextStyle(
        fontFamily: fontFamily,
        fontSize: 10,
        color: ink,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      );
}

/// Dashed page-break guides (#548): a designer-chrome line every
/// printable-page-height, so the owner SEES where the generated PDF
/// will break onto the next page. Pure chrome — never printed.
class PageBreakGuidePainter extends CustomPainter {
  const PageBreakGuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ReportPage.chrome.withValues(alpha: .6)
      ..strokeWidth = 1;
    for (var y = ReportPage.contentHeight;
        y < size.height;
        y += ReportPage.contentHeight) {
      for (var x = 0.0; x < size.width; x += 10) {
        canvas.drawLine(Offset(x, y), Offset(x + 5, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PageBreakGuidePainter oldDelegate) => false;
}
