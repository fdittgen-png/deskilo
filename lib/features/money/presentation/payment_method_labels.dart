// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../l10n/app_localizations.dart';
import '../domain/payment_method.dart';

/// Localized label for a [PaymentMethod] (#154). PayPal, TWINT, Wero,
/// Lydia and Wise are brand names — identical in every locale, with the
/// ARB carrying them anyway so the key-parity gate covers the whole set.
String paymentMethodLabel(AppLocalizations l10n, PaymentMethod method) {
  return switch (method) {
    PaymentMethod.bankTransfer =>
      l10n.paymentMethodBankTransfer,
    PaymentMethod.cash => l10n.paymentMethodCash,
    PaymentMethod.paypal => l10n.paymentMethodPaypal,
    PaymentMethod.twint => l10n.paymentMethodTwint,
    PaymentMethod.card => l10n.paymentMethodCard,
    PaymentMethod.other => l10n.paymentMethodOther,
    PaymentMethod.wero => l10n.paymentMethodWero,
    PaymentMethod.lydia => l10n.paymentMethodLydia,
    PaymentMethod.wise => l10n.paymentMethodWise,
  };
}
