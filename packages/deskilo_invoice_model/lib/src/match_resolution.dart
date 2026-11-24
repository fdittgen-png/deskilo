// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4418 -- how a payment match settles its invoice, decoded once from the
// `invoice_matches.resolution` text (migrations 0067, 0331).

/// How a payment match settles its invoice.
enum MatchResolution {
  /// The payment is the amount due.
  exact('exact'),

  /// Paid more; the surplus becomes a credit note.
  overCreditNote('over_credit_note'),

  /// Paid more; the surplus is kept as paid.
  overForced('over_forced'),

  /// Paid less and accepted: the invoice stays open for the rest until the
  /// remainder is written off.
  underAccepted('under_accepted'),

  /// A credit note refunded to the customer.
  refunded('refunded'),

  /// A resolution a newer server sent and this app does not know (#3730).
  /// The match is read as standing; no command ever sends this value.
  unknown('');

  const MatchResolution(this.wire);

  /// The name the server stores.
  final String wire;

  /// The resolutions a command may send: every one but [unknown].
  static List<MatchResolution> get sendable => [
    for (final r in values)
      if (r != unknown) r,
  ];

  /// [raw] as this app reads it; a value it does not know is [unknown],
  /// never a known resolution.
  static MatchResolution fromWire(String? raw) {
    for (final r in sendable) {
      if (r.wire == raw) return r;
    }
    return unknown;
  }

  /// Paid more than due: the person chose what becomes of the surplus.
  bool get isOverpaid => this == overCreditNote || this == overForced;
}
