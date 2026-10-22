// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2492 — the invoice sheet's palette, shared by its libraries.
import 'package:pdf/pdf.dart';

/// DesKilo brand accent — matches the launcher icon red.
const PdfColor pdfAccent = PdfColor.fromInt(0xFFD32F2F);
const PdfColor pdfInk = PdfColors.blueGrey900;
const PdfColor pdfMuted = PdfColors.blueGrey600;
const PdfColor pdfHairline = PdfColors.blueGrey200;

/// Light grey of the erroneous watermark. Painted at half opacity OVER
/// the content: as a background it disappeared behind the billed-to card
/// and the period box, which swallowed half the word. Over white it lands
/// at the same light grey; over a figure it only greys the stroke, so
/// every amount stays readable.
const PdfColor pdfWatermark = PdfColors.grey400;

const double pdfWatermarkOpacity = 0.5;
const PdfColor pdfZebra = PdfColor.fromInt(0xFFF6F7F9);
