// SPDX-License-Identifier: AGPL-3.0-or-later

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
