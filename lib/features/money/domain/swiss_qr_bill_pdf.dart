// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2360 — the payment part and the receipt of the Swiss QR-bill, drawn on
// the foot of an A4 page (105 mm high; the receipt 62 mm wide, the payment
// part 148 mm) with the QR code at 46 x 46 mm, error correction level M,
// and the Swiss cross of 7 x 7 mm in its middle. Sizes and type sizes are
// those of the SIX guidelines: titles 11 pt, headings 6 pt (receipt) and
// 8 pt (payment part), values 8 pt and 10 pt, further information 7 pt.
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'swiss_qr_bill.dart';

/// The words of the bill, in the language of the document (the guidelines
/// define German, French, Italian and English).
class SwissQrBillStrings {
  const SwissQrBillStrings({
    required this.receipt,
    required this.paymentPart,
    required this.account,
    required this.reference,
    required this.additionalInfo,
    required this.payableBy,
    required this.payableByAddress,
    required this.currency,
    required this.amount,
    required this.acceptancePoint,
    required this.separate,
  });

  final String receipt;
  final String paymentPart;
  final String account;
  final String reference;
  final String additionalInfo;
  final String payableBy;
  final String payableByAddress;
  final String currency;
  final String amount;
  final String acceptancePoint;
  final String separate;
}

const double _mm = PdfPageFormat.mm;

pw.Widget _heading(String text, double size) => pw.Text(
  text,
  style: pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold),
);

pw.Widget _value(String text, double size) =>
    pw.Text(text, style: pw.TextStyle(fontSize: size, lineSpacing: 1));

List<String> _addressLines(SwissQrAddress a) => [
  a.name,
  [a.street, a.houseNumber].where((p) => p.isNotEmpty).join(' '),
  '${a.country == 'CH' ? '' : '${a.country}-'}${a.postalCode} ${a.city}',
].where((l) => l.trim().isNotEmpty).toList();

/// The Swiss cross: a black square with a white cross, framed in white.
pw.Widget _swissCross() => pw.Container(
  width: 7 * _mm,
  height: 7 * _mm,
  color: PdfColors.white,
  child: pw.Center(
    child: pw.Container(
      width: 6.2 * _mm,
      height: 6.2 * _mm,
      color: PdfColors.black,
      child: pw.Stack(
        children: [
          pw.Positioned(
            left: (6.2 - 4.05) / 2 * _mm,
            top: (6.2 - 1.2) / 2 * _mm,
            child: pw.Container(
              width: 4.05 * _mm,
              height: 1.2 * _mm,
              color: PdfColors.white,
            ),
          ),
          pw.Positioned(
            left: (6.2 - 1.2) / 2 * _mm,
            top: (6.2 - 4.05) / 2 * _mm,
            child: pw.Container(
              width: 1.2 * _mm,
              height: 4.05 * _mm,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    ),
  ),
);

/// The page of the bill: A4, the slip in its lower 105 mm.
pw.Page swissQrBillPage({
  required SwissQrBill bill,
  required SwissQrBillStrings strings,
  required pw.Font baseFont,
  required pw.Font boldFont,
}) {
  final debtor = bill.debtor;
  final reference = bill.referenceGrouped;
  final creditorLines = _addressLines(bill.creditor);

  pw.Widget payableBy({
    required double head,
    required double body,
    required double boxW,
    required double boxH,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _heading(
        debtor == null ? strings.payableByAddress : strings.payableBy,
        head,
      ),
      if (debtor != null)
        for (final line in _addressLines(debtor)) _value(line, body)
      else
        pw.Container(
          width: boxW * _mm,
          height: boxH * _mm,
          decoration: pw.BoxDecoration(border: pw.Border.all(width: .75)),
        ),
    ],
  );

  pw.Widget block(
    String head,
    List<String> lines,
    double headSize,
    double bodySize,
  ) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3 * _mm),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _heading(head, headSize),
        for (final l in lines) _value(l, bodySize),
      ],
    ),
  );

  final receipt = pw.Positioned(
    left: 0,
    top: 0,
    child: pw.SizedBox(
      width: 62 * _mm,
      height: 105 * _mm,
      child: pw.Padding(
        padding: const pw.EdgeInsets.all(5 * _mm),
        child: pw.Stack(
          children: [
            pw.Positioned(
              left: 0,
              top: 0,
              child: pw.Text(
                strings.receipt,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Positioned(
              left: 0,
              top: 12 * _mm,
              child: pw.SizedBox(
                width: 52 * _mm,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    block(
                      strings.account,
                      [bill.accountGrouped, ...creditorLines],
                      6,
                      8,
                    ),
                    if (reference.isNotEmpty)
                      block(strings.reference, [reference], 6, 8),
                    payableBy(head: 6, body: 8, boxW: 52, boxH: 20),
                  ],
                ),
              ),
            ),
            pw.Positioned(
              left: 0,
              top: 68 * _mm,
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _heading(strings.currency, 6),
                      _value(bill.currency, 8),
                    ],
                  ),
                  pw.SizedBox(width: 12 * _mm),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _heading(strings.amount, 6),
                      _value(bill.amountGrouped, 8),
                    ],
                  ),
                ],
              ),
            ),
            pw.Positioned(
              right: 0,
              top: 82 * _mm,
              child: _heading(strings.acceptancePoint, 6),
            ),
          ],
        ),
      ),
    ),
  );

  final part = pw.Positioned(
    left: 62 * _mm,
    top: 0,
    child: pw.SizedBox(
      width: 148 * _mm,
      height: 105 * _mm,
      child: pw.Stack(
        children: [
          pw.Positioned(
            left: 5 * _mm,
            top: 5 * _mm,
            child: pw.Text(
              strings.paymentPart,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Positioned(
            left: 5 * _mm,
            top: 17 * _mm,
            child: pw.Stack(
              alignment: pw.Alignment.center,
              children: [
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(
                    errorCorrectLevel: pw.BarcodeQRCorrectionLevel.medium,
                  ),
                  data: bill.payload,
                  width: 46 * _mm,
                  height: 46 * _mm,
                  drawText: false,
                  margin: pw.EdgeInsets.zero,
                ),
                _swissCross(),
              ],
            ),
          ),
          pw.Positioned(
            left: 5 * _mm,
            top: 68 * _mm,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _heading(strings.currency, 8),
                    _value(bill.currency, 10),
                  ],
                ),
                pw.SizedBox(width: 12 * _mm),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _heading(strings.amount, 8),
                    _value(bill.amountGrouped, 10),
                  ],
                ),
              ],
            ),
          ),
          pw.Positioned(
            left: 56 * _mm,
            top: 5 * _mm,
            child: pw.SizedBox(
              width: 87 * _mm,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  block(
                    strings.account,
                    [bill.accountGrouped, ...creditorLines],
                    8,
                    10,
                  ),
                  if (reference.isNotEmpty)
                    block(strings.reference, [reference], 8, 10),
                  if (bill.additionalInfo.trim().isNotEmpty)
                    block(
                      strings.additionalInfo,
                      [clean(bill.additionalInfo)],
                      8,
                      10,
                    ),
                  payableBy(head: 8, body: 10, boxW: 65, boxH: 25),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  return pw.Page(
    pageTheme: pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
    ),
    build: (context) => pw.Stack(
      children: [
        pw.Positioned(
          left: 0,
          bottom: 105 * _mm,
          child: pw.SizedBox(
            width: 210 * _mm,
            child: pw.Center(
              child: pw.Text(
                strings.separate,
                style: const pw.TextStyle(fontSize: 6),
              ),
            ),
          ),
        ),
        pw.Positioned(
          left: 0,
          right: 0,
          bottom: 105 * _mm - .5,
          child: pw.Container(height: .5, color: PdfColors.black),
        ),
        pw.Positioned(
          left: 0,
          bottom: 0,
          child: pw.SizedBox(
            width: 210 * _mm,
            height: 105 * _mm,
            child: pw.Stack(
              children: [
                receipt,
                part,
                pw.Positioned(
                  left: 62 * _mm,
                  top: 0,
                  child: pw.Container(
                    width: .5,
                    height: 105 * _mm,
                    color: PdfColors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
