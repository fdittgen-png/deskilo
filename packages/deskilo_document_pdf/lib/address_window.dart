// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:deskilo_document_model/address_window_kind.dart';
import 'package:deskilo_document_model/paper.dart';
import 'package:pdf/widgets.dart' as pw;

export 'package:deskilo_document_model/address_window_kind.dart';


/// One PostScript point per millimetre.
const double _mm = 72 / 25.4;

/// The address field, in page coordinates.
///
/// 45 mm from the top (50 mm is the outer limit an aperture tolerates)
/// and a 85 × 40 mm rectangle ([AddressWindowMillimetres.fieldOn]). The width
/// and height are the APERTURE: everything drawn must fit inside them or it
/// is behind cardboard.
const double addressWindowTop = addressWindowTopMm * _mm;

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
  /// Distance from the LEFT PAGE EDGE to the address field, in points
  /// ([AddressWindowMillimetres.leftEdgeMm]).
  double get leftEdge => leftEdgeMm * _mm;

  bool get isOn => this != AddressWindow.off;
}

/// #3981 — the address field of a window on a paper, in points.
extension AddressFieldPoints on AddressField {
  double get leftPt => leftMm * _mm;
  double get topPt => topMm * _mm;
  double get widthPt => widthMm * _mm;
  double get heightPt => heightMm * _mm;
  double get senderLimitPt => senderLimitMm * _mm;
  double get flowResumePt => flowResumeMm * _mm;
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
  double fontSize = 11,
}) =>
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(name, style: pw.TextStyle(fontSize: fontSize)),
        if (address.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(address, style: pw.TextStyle(fontSize: fontSize)),
          ),
      ],
    );

/// #3981 — whether the recipient, laid out at [fontSize] and wrapped at
/// [widthPt], is no taller than [heightPt]. The same widget and the same
/// layout the field draws, so the answer is the one the page gives: a
/// recipient that does not fit is not placed in the field (the engine
/// would drop it), it is printed whole in the flow instead.
bool addressFitsField({
  required String name,
  required String address,
  required double widthPt,
  required double heightPt,
  required double fontSize,
  required pw.ThemeData theme,
}) {
  final widget = addressWindowRecipient(
    name: name,
    address: address,
    fontSize: fontSize,
  );
  final context = pw.Context(document: pw.Document().document)
      .inheritFrom(theme);
  widget.layout(context, pw.BoxConstraints(maxWidth: widthPt));
  return widget.box!.height <= heightPt + 0.01;
}

/// The address block painted at PAGE coordinates on the first sheet.
///
/// It ignores the document's margins deliberately: the envelope does
/// too, and the French field ends 195 mm across a 210 mm page, past
/// where a 16 mm right margin would stop it.
pw.Widget addressWindowBackground(
  AddressWindow window, {
  required int pageNumber,
  required pw.Widget child,
  Paper paper = Paper.a4,
}) =>
    pageNumber != 1
        ? pw.SizedBox()
        : pw.FullPage(
            ignoreMargins: true,
            child: pw.Stack(children: [
              pw.Positioned(
                left: window.fieldOn(paper).leftPt,
                top: window.fieldOn(paper).topPt,
                child: pw.SizedBox(
                  width: window.fieldOn(paper).widthPt,
                  height: window.fieldOn(paper).heightPt,
                  child: child,
                ),
              ),
            ]),
          );
