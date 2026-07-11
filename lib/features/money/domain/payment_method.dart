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
  other('other'),
  // #192 — append only (AGENT_RULES: enum values are persisted by name,
  // never reorder). Pickers use [displayOrder] so `other` still renders
  // last.
  wero('wero'),
  lydia('lydia'),
  wise('wise');

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

  /// Declaration order with the catch-all [other] moved to the end —
  /// what method pickers iterate. Declaration order itself is
  /// append-only (#192 landed after [other]), so it is not a
  /// presentable order on its own.
  static List<PaymentMethod> get displayOrder => [
        for (final method in values)
          if (method != other) method,
        other,
      ];
}
