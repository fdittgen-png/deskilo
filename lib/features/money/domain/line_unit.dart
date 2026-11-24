// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4442 -- a unit a free line of a quote or an invoice may be sold in besides the four it always offers: the business's
// own (kilometres, a drum of cable). The units themselves belong to the business's configuration (the stock reads and
// maintains them); the money feature only knows what a line carries of one -- its code, its label and its UN/ECE code --
// and is given them through `lineUnitsProvider`, so it never imports the stock.
class LineUnit {
  const LineUnit({required this.code, this.label, this.unEceCode});

  /// The code the line stores (`km`, `drum`).
  final String code;

  /// The word the business gave the unit; null for a built-in it did not rename.
  final String? label;

  /// The code the structured invoice needs; null when the unit has none.
  final String? unEceCode;
}
