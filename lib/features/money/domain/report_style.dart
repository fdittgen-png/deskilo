// SPDX-License-Identifier: 0BSD
//
// #875 — the ink every report is drawn with.
//
// These lived as privates inside invoice_pdf.dart. Now that two engines
// draw documents — the banded one and the positioned one — and the
// on-screen mirror copies them, the colours and sizes are named once
// here. A report that mixes `<markup>` and `<text>` must read as ONE
// document, and that is only true if both draw from this file.
import 'package:pdf/pdf.dart';

const PdfColor reportAccent = PdfColor.fromInt(0xFFD32F2F);
const PdfColor reportInk = PdfColors.blueGrey900;
const PdfColor reportMuted = PdfColors.blueGrey600;
const PdfColor reportHairline = PdfColors.blueGrey200;
const PdfColor reportZebra = PdfColor.fromInt(0xFFF6F7F9);

/// Point sizes of the four typographic roles.
const double reportHeadingSize = 20;
const double reportSubheadingSize = 8;
const double reportBodySize = 10;
const double reportSmallSize = 8;

/// Letter-spacing of the small-caps section heading.
const double reportSubheadingTracking = 1.2;

/// The rule's thickness and the default breathing room.
const double reportRuleThickness = 2;
const double reportSpacerSize = 8;
