// SPDX-License-Identifier: MIT

/// Per-workspace payment instructions (spec §7, #155): how members are
/// asked to settle an unpaid statement. Purely informational — the app
/// records payments, it never processes them (no PSP; F-Droid-clean).
class PaymentInstructions {
  const PaymentInstructions({
    this.iban = '',
    this.paypalMe = '',
    this.reference = '',
  });

  /// The workspace's bank account, e.g. `DE89 3704 0044 0532 0130 00`.
  final String iban;

  /// A PayPal.me handle or full link; normalized to a URL by
  /// [paypalMeUri].
  final String paypalMe;

  /// Reference-line hint, e.g. `DesKilo <member> <period>`.
  final String reference;

  /// True when there is nothing to show — the statement renders no
  /// how-to-pay card at all.
  bool get isEmpty =>
      iban.trim().isEmpty &&
      paypalMe.trim().isEmpty &&
      reference.trim().isEmpty;

  /// The PayPal.me link as a launchable https URI, or null when unset.
  /// Accepts a bare handle (`somebody`), `paypal.me/somebody`, or a full
  /// `https://…` link — owners paste whatever PayPal showed them.
  Uri? get paypalMeUri {
    final raw = paypalMe.trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return Uri.tryParse(raw);
    }
    final handle =
        raw.startsWith('paypal.me/') ? raw : 'paypal.me/$raw';
    return Uri.tryParse('https://$handle');
  }

  factory PaymentInstructions.fromDb(Map<String, dynamic> db) =>
      PaymentInstructions(
        iban: db['iban'] as String? ?? '',
        paypalMe: db['paypal_me'] as String? ?? '',
        reference: db['reference'] as String? ?? '',
      );

  Map<String, dynamic> toDb() => {
        'iban': iban.trim(),
        'paypal_me': paypalMe.trim(),
        'reference': reference.trim(),
      };
}
