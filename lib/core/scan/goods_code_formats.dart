// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4360 (G11) -- the codes the camera reads in the goods sheets: product barcodes (EAN-13, EAN-8, UPC-A, UPC-E,
// Code 128) and the 2D labels of places and GS1 products (DataMatrix, QR). Decoding is `flutter_zxing`, the
// free-software reader the app already uses for QR codes (no Google service, no new dependency); the QR-only
// scanners (check-in, invitations, badges) keep asking for QR alone.
import 'package:flutter_zxing/flutter_zxing.dart' show Format;

const int goodsCodeFormats =
    Format.ean13 | Format.ean8 | Format.upca | Format.upce | Format.code128 | Format.dataMatrix | Format.qrCode;
