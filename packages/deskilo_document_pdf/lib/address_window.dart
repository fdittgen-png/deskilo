// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:deskilo_document_model/address_window_kind.dart';
import 'package:pdf/widgets.dart' as pw;

export 'package:deskilo_document_model/address_window_kind.dart';


/// One PostScript point per millimetre.
const double _mm = 72 / 25.4;

/// The address field, in page coordinates.
///
/// 45 mm from the top (50 mm is the outer limit an aperture tolerates)
/// and a 85 × 40 mm rectangle. The width and height are the APERTURE:
/// everything drawn must fit inside them or it is behind cardboard.
const double addressWindowTop = 45 * _mm;
const double addressWindowWidth = 85 * _mm;
const double addressWindowHeight = 40 * _mm;

/// The lowest top-edge an aperture still shows. Drawing the field below
/// this hides it, so it is a bound the conformance check asserts.
const double addressWindowTopLimit = 50 * _mm;

/// Where the document's own content resumes — 90 mm, below BOTH the
/// field and the tolerance band under it. The invoice identification
/// (the word "Facture", the number, the dates) starts here, so this is
/// the first line of the body and not a matter of taste.
const double addressWindowFlowResume = 90 * _mm;

/// The page margin: 20 mm from the top and left edges, which is where
/// the sender block sits. The letterhead therefore has the 25 mm
/// between it and [addressWindowTop] to work in.
const double pageMargin = 20 * _mm;

/// #923 — the tallest a letterhead PICTURE may be inside the sender
/// band. The band itself is 25 mm (20 → 45); a logo of 12 mm leaves
/// room for the three or four lines of identity that sit under it, and
/// a design that states its own size still wins.
const double senderLogoMaxHeight = 12 * _mm;

extension AddressWindowGeometry on AddressWindow {
  /// Distance from the LEFT PAGE EDGE to the address field.
  ///
  /// 110 mm is the right-hand DL aperture the French spec names; 20 mm
  /// is the DIN 5008 left-hand one.
  double get leftEdge => switch (this) {
        AddressWindow.left => 20 * _mm,
        AddressWindow.right => 110 * _mm,
        // Never read: [off] places nothing.
        AddressWindow.off => 0,
      };

  bool get isOn => this != AddressWindow.off;
}

/// The recipient exactly as the window shows it.
///
/// Deliberately plain: no tint, no frame, nothing a postal reader has
/// to see past, and set large enough to stay legible through the film.
/// It lives here rather than in `invoice_pdf.dart` so the geometry and
/// the block that has to sit inside it stay in one file.
pw.Widget addressWindowRecipient({
  required String name,
  required String address,
}) =>
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(name, style: const pw.TextStyle(fontSize: 11)),
        if (address.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(address, style: const pw.TextStyle(fontSize: 11)),
          ),
      ],
    );

/// The address block painted at PAGE coordinates on the first sheet.
///
/// It ignores the document's margins deliberately: the envelope does
/// too, and the French field ends 195 mm across a 210 mm page, past
/// where a 16 mm right margin would stop it.
pw.Widget addressWindowBackground(
  AddressWindow window, {
  required int pageNumber,
  required pw.Widget child,
}) =>
    pageNumber != 1
        ? pw.SizedBox()
        : pw.FullPage(
            ignoreMargins: true,
            child: pw.Stack(children: [
              pw.Positioned(
                left: window.leftEdge,
                top: addressWindowTop,
                child: pw.SizedBox(
                  width: addressWindowWidth,
                  height: addressWindowHeight,
                  child: child,
                ),
              ),
            ]),
          );
