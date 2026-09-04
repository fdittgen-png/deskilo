// SPDX-License-Identifier: 0BSD

import 'package:pdf/widgets.dart' as pw;

/// #869 — where a window envelope shows the recipient on an A4 sheet.
///
/// A printed invoice is folded into a window envelope, so the recipient
/// block cannot sit wherever the document flow happens to leave it: it
/// has to land inside the window, measured from the PAGE edge and never
/// from the document's own margins. That is the whole reason this is
/// page geometry and not a layout preference.
///
/// Two conventions cover the countries this app ships to, and they
/// disagree about the side:
///
///  * [left] — DIN 5008 form B: the address field starts 20 mm from the
///    left edge and 45 mm from the top, and measures 85 × 45 mm.
///    Germany, Austria and Switzerland specify it, and the window
///    envelopes sold across northern Europe and North America follow the
///    same side.
///  * [right] — French usage, and the enveloppe à fenêtre La Poste
///    sells: the same 85 × 45 mm field at the same 45 mm from the top,
///    but 110 mm from the left, putting the window on the right.
///
/// Envelope stock varies more than any standard admits, so the country
/// picks only the DEFAULT and the owner overrides it. [off] keeps the
/// pre-#869 flow layout, for a workspace that never posts a sheet.
enum AddressWindow { off, left, right }

/// One PostScript point per millimetre.
const double _mm = 72 / 25.4;

/// The top of the address field, and its size. Identical in both
/// conventions — only the side differs — so they are constants rather
/// than members of the enum.
const double addressWindowTop = 45 * _mm;
const double addressWindowWidth = 85 * _mm;
const double addressWindowHeight = 45 * _mm;

/// Where the sender's own letterhead has to stop: the address field
/// begins at [addressWindowTop], so anything above it must fit in the
/// 45 mm band, and the document's own content resumes below the field.
const double addressWindowBottom = addressWindowTop + addressWindowHeight;

extension AddressWindowGeometry on AddressWindow {
  /// Distance from the LEFT PAGE EDGE to the address field.
  double get leftEdge => switch (this) {
        AddressWindow.left => 20 * _mm,
        AddressWindow.right => 110 * _mm,
        // Never read: [off] places nothing.
        AddressWindow.off => 0,
      };

  bool get isOn => this != AddressWindow.off;
}

/// The convention a country's envelope stock implies.
///
/// Only France (and Monaco, which uses La Poste's stock) is mapped to
/// [AddressWindow.right] with any confidence; everything else takes the
/// DIN geometry, which is the ISO-derived default and the one most
/// window envelopes outside France are cut for. This is a starting
/// point the owner corrects per workspace — never a claim about every
/// envelope sold in a country.
AddressWindow addressWindowForCountry(String countryCode) =>
    switch (countryCode.toUpperCase()) {
      'FR' || 'MC' => AddressWindow.right,
      _ => AddressWindow.left,
    };

const Map<AddressWindow, String> _wire = {
  AddressWindow.off: 'off',
  AddressWindow.left: 'left',
  AddressWindow.right: 'right',
};

String addressWindowWire(AddressWindow window) => _wire[window]!;

/// `null` — the stored value is absent or unreadable — means FOLLOW THE
/// COUNTRY, which is why this cannot fold into a non-null default.
AddressWindow? addressWindowFromWire(String? wire) => switch (wire) {
      'off' => AddressWindow.off,
      'left' => AddressWindow.left,
      'right' => AddressWindow.right,
      _ => null,
    };

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
