// SPDX-License-Identifier: MIT

/// How a recorded payment was made (spec §7, #154). Recording only — the
/// app never processes payments (no PSP; F-Droid-clean). The wire name is
/// what `record_payment` stores in the event payload; '' (an absent or
/// pre-#154 event) renders as no method at all.
enum PaymentMethod {
  bankTransfer('bank_transfer'),
  cash('cash'),
  paypal('paypal'),
  twint('twint'),
  card('card'),
  other('other');

  const PaymentMethod(this.wireName);

  /// Stable payload tag (snake_case, ≤32 chars — enforced server-side).
  final String wireName;

  /// The method for [wireName], or null for '' / unknown tags (forward
  /// compatibility: an event written by a newer app version must not
  /// crash the feed).
  static PaymentMethod? fromWire(String? wireName) {
    for (final method in values) {
      if (method.wireName == wireName) return method;
    }
    return null;
  }
}
