// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3852 - the sheet a document is printed on. Its wire words are the ones
// the analysis report already offers, 'A4' and 'Letter', and they are the
// same in a layout's `page` attribute, a business's setting and the value
// an invoice keeps from its issue.

/// A paper size, in millimetres.
enum Paper {
  a4('A4', 210, 297),
  letter('Letter', 215.9, 279.4);

  const Paper(this.wire, this.widthMm, this.heightMm);

  /// The word that names it on the wire and in a layout.
  final String wire;
  final double widthMm;
  final double heightMm;

  /// The paper [wire] names, or null when it names none.
  static Paper? fromWire(String? wire) {
    for (final paper in values) {
      if (paper.wire == wire) return paper;
    }
    return null;
  }
}
