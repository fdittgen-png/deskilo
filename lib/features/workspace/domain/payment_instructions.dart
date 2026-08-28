// SPDX-License-Identifier: 0BSD
import '../../../core/country/country_catalog.dart';

/// Per-workspace payment instructions (spec §7, #155): how members are
/// asked to settle an unpaid statement. Purely informational — the app
/// records payments, it never processes them (no PSP; F-Droid-clean).
class PaymentInstructions {
  const PaymentInstructions({
    this.iban = '',
    this.paypalMe = '',
    this.reference = '',
    this.wero = '',
    this.lydia = '',
    this.wise = '',
    this.accountNumber = '',
    this.bankCode = '',
    this.bankName = '',
    this.bic = '',
  });

  /// #711 — for countries that do not bank by IBAN: the account number
  /// and the code that routes to the bank (a UK sort code, a US ABA
  /// routing number, a Canadian transit + institution number). [bic]
  /// is the SWIFT code a cross-border transfer asks for.
  final String accountNumber;
  final String bankCode;
  final String bankName;
  final String bic;

  bool get hasLocalBankDetails =>
      accountNumber.trim().isNotEmpty || bankCode.trim().isNotEmpty;

  /// The workspace's bank account, e.g. `DE89 3704 0044 0532 0130 00`.
  final String iban;

  /// A PayPal.me handle or full link; normalized to a URL by
  /// [paypalMeUri].
  final String paypalMe;

  /// Reference-line hint, e.g. `DesKilo <member> <period>`.
  final String reference;

  /// The phone number the workspace receives Wero payments on (#192).
  final String wero;

  /// The phone number or username for Lydia payments (#192).
  final String lydia;

  /// A Wisetag (`@handle`) or Wise payment link (#192).
  final String wise;

  /// True when there is nothing to show — the statement renders no
  /// how-to-pay card at all.
  bool get isEmpty =>
      iban.trim().isEmpty &&
      paypalMe.trim().isEmpty &&
      reference.trim().isEmpty &&
      wero.trim().isEmpty &&
      lydia.trim().isEmpty &&
      wise.trim().isEmpty;

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
        wero: db['wero'] as String? ?? '',
        lydia: db['lydia'] as String? ?? '',
        wise: db['wise'] as String? ?? '',
        accountNumber: db['account_number'] as String? ?? '',
        bankCode: db['bank_code'] as String? ?? '',
        bankName: db['bank_name'] as String? ?? '',
        bic: db['bic'] as String? ?? '',
      );

  Map<String, dynamic> toDb() => {
        'iban': iban.trim(),
        'paypal_me': paypalMe.trim(),
        'reference': reference.trim(),
        'wero': wero.trim(),
        'lydia': lydia.trim(),
        'wise': wise.trim(),
        'account_number': accountNumber.trim(),
        'bank_code': bankCode.trim(),
        'bank_name': bankName.trim(),
        'bic': bic.trim(),
      };
}

/// What the bank-routing field is CALLED where the workspace banks
/// (#711): the same number wears a different name in every scheme, and
/// an owner in Leeds typing into "Routing number" is not sure they are
/// in the right box.
String bankCodeLabelFor(BankingScheme scheme, {
  required String sortCode,
  required String routingNumber,
  required String transitNumber,
  required String bankCode,
}) =>
    switch (scheme) {
      BankingScheme.uk => sortCode,
      BankingScheme.us => routingNumber,
      BankingScheme.ca => transitNumber,
      BankingScheme.sepa => bankCode,
    };
