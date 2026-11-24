// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4436 (G21) -- the track IDs a goods line of an issued document took: the lot it was taken from (the code as
// received, else the lot's label code, with the quantity taken from it) and each piece by its tag code. The server
// freezes them with the document (`invoice_line_tracks`, 0945; the counter receipt's own `tracks`, 0939), so a later
// change of a lot or a tag never alters them. ONE reader for every document: the PDF's placeholders, the invoice
// sheet and the structured e-invoice.

/// What a track names.
enum LineTrackKind {
  lot('lot'),
  piece('piece');

  const LineTrackKind(this.wire);
  final String wire;

  static LineTrackKind? fromWire(Object? wire) {
    for (final k in values) {
      if (k.wire == wire) return k;
    }
    return null;
  }
}

/// One track ID of a goods line.
class LineTrack {
  const LineTrack({required this.kind, required this.code, this.quantity = '', this.expiresOn = ''});

  final LineTrackKind kind;

  /// The lot code as received (else its label code), or the piece's tag code.
  final String code;

  /// The quantity taken from a lot, as exact decimal text ('' for a piece).
  final String quantity;

  /// The lot's expiry day (`yyyy-MM-dd`), '' where it has none.
  final String expiresOn;

  /// The words a document prints for it: `LOT-7 ×3` for a lot taken in a quantity, the bare code otherwise.
  String get text => kind == LineTrackKind.lot && quantity.isNotEmpty ? '$code ×$quantity' : code;
}

/// The tracks of a snapshot (`[{kind, code, quantity, expires_on}, …]`). What cannot be read -- an unknown kind, a
/// track without a code -- is left out, never guessed; anything that is not a list reads as none.
List<LineTrack> lineTracksFromSnapshot(Object? snapshot) {
  if (snapshot is! List) return const [];
  return [
    for (final t in snapshot)
      if (t is Map && LineTrackKind.fromWire(t['kind']) != null && '${t['code'] ?? ''}'.isNotEmpty)
        LineTrack(
          kind: LineTrackKind.fromWire(t['kind'])!,
          code: '${t['code']}',
          quantity: '${t['quantity'] ?? ''}',
          expiresOn: '${t['expires_on'] ?? ''}',
        ),
  ];
}
