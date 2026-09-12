// SPDX-License-Identifier: 0BSD
import '../../../l10n/app_localizations.dart';
import '../domain/payment_provider.dart';

/// #1154 — the provider's display name, once (was copied into the money
/// screen and the provider configuration screen).
String paymentProviderLabel(AppLocalizations? l10n, PaymentProvider provider) =>
    switch (provider) {
      PaymentProvider.paypal => l10n?.paymentMethodPaypal ?? 'PayPal',
      PaymentProvider.stripe =>
        l10n?.paymentProviderStripe ?? 'Credit card (Stripe)',
      PaymentProvider.mollie =>
        l10n?.paymentProviderMollie ?? 'Mollie — iDEAL, Bancontact…',
      PaymentProvider.wero => l10n?.paymentProviderWero ?? 'Wero (via Mollie)',
    };
