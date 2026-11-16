// SPDX-License-Identifier: AGPL-3.0-or-later

import 'paper.dart';

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
///    left edge and 45 mm from the top, and measures 85 × 40 mm.
///    Germany, Austria and Switzerland specify it, and the window
///    envelopes sold across northern Europe and North America follow the
///    same side.
///  * [right] — French usage, and the enveloppe à fenêtre La Poste
///    sells: the same 85 × 40 mm field at the same 45 mm from the top,
///    but 110 mm from the left, putting the window on the right.
///
/// Envelope stock varies more than any standard admits, so the country
/// picks only the DEFAULT and the owner overrides it. [off] keeps the
/// pre-#869 flow layout, for a workspace that never posts a sheet.
enum AddressWindow { off, left, right }

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

/// #3852 — the address field's millimetres on an A4 sheet, measured from
/// the page edge: its top, its aperture and where the flow resumes. The
/// A4 values of [AddressWindowMillimetres.fieldOn]; `address_window.dart`
/// (deskilo_document_pdf) turns them into points.
const double addressWindowTopMm = 45;
const double addressWindowWidthMm = 85;
const double addressWindowHeightMm = 40;
const double addressWindowFlowResumeMm = 90;

/// #3981 — the address field of one window on one paper, measured from
/// the PAGE edge. The one place the millimetres are written per paper.
class AddressField {
  const AddressField({
    required this.leftMm,
    required this.topMm,
    required this.widthMm,
    required this.heightMm,
    required this.senderLimitMm,
    required this.flowResumeMm,
    required this.fontSizePt,
  });

  /// From the left page edge to the field.
  final double leftMm;

  /// From the top page edge to the field.
  final double topMm;
  final double widthMm;
  final double heightMm;

  /// The sender owns everything above this line and no more.
  final double senderLimitMm;

  /// Where the document's own content resumes: nothing but the recipient
  /// sits between [senderLimitMm] and here.
  final double flowResumeMm;

  /// The size the recipient is set at, so that the lines the field is
  /// made for fit in it: 11 pt in A4's 40 mm, 9.5 pt in Letter's 21 mm
  /// (five lines; a sixth does not fit).
  final double fontSizePt;

  double get bottomMm => topMm + heightMm;
  double get rightMm => leftMm + widthMm;
}

extension AddressWindowMillimetres on AddressWindow {
  /// Distance from the LEFT PAGE EDGE to the address field on an A4
  /// sheet: 110 mm is the right-hand DL aperture the French spec names;
  /// 20 mm the DIN 5008 left-hand one. [AddressWindow.off] places
  /// nothing.
  double get leftEdgeMm => switch (this) {
        AddressWindow.left => 20,
        AddressWindow.right => 110,
        AddressWindow.off => 0,
      };

  /// #3981 — the field on [paper]. A4 keeps the DIN 5008 / French
  /// millimetres. US Letter has one convention, for a #10 window envelope
  /// (window 28.6 x 114.3 mm, 22.2 mm from the left edge, 12.7 mm from the
  /// bottom, letter folded in thirds with the address panel outward): a
  /// field 25.4 mm from the left and 56 mm from the top, 83 x 21 mm, the
  /// sender above 50 mm, the flow resuming at 93 mm (the first fold is at
  /// 93.1 mm). `left` and `right` both mean it: a #10 has no right-hand
  /// window. [AddressWindow.off] keeps no left edge.
  AddressField fieldOn(Paper paper) => switch (paper) {
        Paper.a4 => AddressField(
            leftMm: leftEdgeMm,
            topMm: addressWindowTopMm,
            widthMm: addressWindowWidthMm,
            heightMm: addressWindowHeightMm,
            senderLimitMm: addressWindowTopMm,
            flowResumeMm: addressWindowFlowResumeMm,
            fontSizePt: 11,
          ),
        Paper.letter => AddressField(
            leftMm: this == AddressWindow.off ? 0 : 25.4,
            topMm: 56,
            widthMm: 83,
            heightMm: 21,
            senderLimitMm: 50,
            flowResumeMm: 93,
            fontSizePt: 9.5,
          ),
      };
}
