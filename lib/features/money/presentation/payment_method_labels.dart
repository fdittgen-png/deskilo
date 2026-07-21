// SPDX-License-Identifier: 0BSD
import '../../../l10n/app_localizations.dart';
import '../domain/payment_method.dart';

/// Localized label for a [PaymentMethod] (#154). PayPal, TWINT, Wero,
/// Lydia and Wise are brand names — identical in every locale, with the
/// ARB carrying them anyway so the key-parity gate covers the whole set.
String paymentMethodLabel(AppLocalizations? l10n, PaymentMethod method) {
  return switch (method) {
    PaymentMethod.bankTransfer =>
      l10n?.paymentMethodBankTransfer ?? 'Bank transfer',
    PaymentMethod.cash => l10n?.paymentMethodCash ?? 'Cash',
    PaymentMethod.paypal => l10n?.paymentMethodPaypal ?? 'PayPal',
    PaymentMethod.twint => l10n?.paymentMethodTwint ?? 'TWINT',
    PaymentMethod.card => l10n?.paymentMethodCard ?? 'Card',
    PaymentMethod.other => l10n?.paymentMethodOther ?? 'Other',
    PaymentMethod.wero => l10n?.paymentMethodWero ?? 'Wero',
    PaymentMethod.lydia => l10n?.paymentMethodLydia ?? 'Lydia',
    PaymentMethod.wise => l10n?.paymentMethodWise ?? 'Wise',
  };
}
