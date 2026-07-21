// SPDX-License-Identifier: 0BSD

/// Online-payment providers the create-payment-order Edge Function can
/// charge with (docs/design/payments-integration.md). Wire names match
/// the function's `provider` parameter — never rename.
enum PaymentProvider {
  paypal('paypal'),
  stripe('stripe'),
  mollie('mollie'),
  wero('wero');

  const PaymentProvider(this.wireName);

  final String wireName;

  static PaymentProvider? fromWire(String? name) => PaymentProvider.values
      .where((p) => p.wireName == name)
      .firstOrNull;
}

/// What the deployment can actually charge with: the providers whose
/// server secrets are configured, plus — for diagnostics — which env vars
/// each unconfigured provider still lacks.
class PaymentGatewayConfig {
  const PaymentGatewayConfig({
    required this.providers,
    this.missing = const {},
  });

  /// Fully configured, offerable providers (possibly empty).
  final List<PaymentProvider> providers;

  /// provider wire name → missing server env vars. The owner-facing
  /// diagnostics dialog renders this so "not set up" is never a mystery.
  final Map<String, List<String>> missing;

  /// The payment Edge Function is not deployed at all (invoke 404) —
  /// modelled as a config with a sentinel so callers can name the fix.
  static const PaymentGatewayConfig notDeployed = PaymentGatewayConfig(
    providers: [],
    missing: {'functions': ['create-payment-order (not deployed)']},
  );
}

/// Result of starting an online payment.
class PaymentOrderStart {
  const PaymentOrderStart({
    this.approveUrl,
    this.orderId,
    this.missing = const [],
  });

  /// The provider's hosted approval/checkout page; null when the provider
  /// is not configured on this deployment.
  final Uri? approveUrl;

  /// The provider's order/session/payment id (traceable in the webhook
  /// settlement and `payment_intents`).
  final String? orderId;

  /// Missing server env vars when [approveUrl] is null.
  final List<String> missing;

  bool get started => approveUrl != null;
}

/// A payment call the server answered with an error (provider refusal,
/// auth mismatch…). Carries the status + server detail so the trace log
/// pinpoints the failure.
class PaymentGatewayException implements Exception {
  const PaymentGatewayException(this.status, this.detail);

  final int status;
  final String detail;

  @override
  String toString() => 'PaymentGatewayException($status): $detail';
}

/// One editable field of a provider's server config (owner UI).
class PaymentField {
  const PaymentField({
    required this.key,
    required this.secret,
    this.options,
  });

  /// The config key sent to `set_payment_credentials` (matches the Edge
  /// Function's field names).
  final String key;

  /// Secret fields render obscured and are never read back — the status
  /// only reports whether they are set.
  final bool secret;

  /// When non-null, the field is a choice (e.g. PayPal sandbox/live).
  final List<String>? options;
}

/// The config fields each provider needs, in display order. Labels are
/// resolved in the UI from the [PaymentField.key].
const Map<PaymentProvider, List<PaymentField>> paymentProviderFields = {
  PaymentProvider.paypal: [
    PaymentField(key: 'client_id', secret: true),
    PaymentField(key: 'secret', secret: true),
    PaymentField(key: 'env', secret: false, options: ['sandbox', 'live']),
    PaymentField(key: 'webhook_id', secret: true),
    PaymentField(key: 'return_url', secret: false),
  ],
  PaymentProvider.stripe: [
    PaymentField(key: 'secret_key', secret: true),
    PaymentField(key: 'webhook_secret', secret: true),
    PaymentField(key: 'return_url', secret: false),
  ],
  PaymentProvider.mollie: [
    PaymentField(key: 'api_key', secret: true),
    PaymentField(key: 'return_url', secret: false),
  ],
  // Wero rides Mollie: same credentials (a Mollie API key with Wero
  // enabled) + return URL.
  PaymentProvider.wero: [
    PaymentField(key: 'api_key', secret: true),
    PaymentField(key: 'return_url', secret: false),
  ],
};

/// Owner read-back of one provider's server config (never the secret
/// values — only whether they are set, plus the non-secret fields).
class PaymentProviderStatus {
  const PaymentProviderStatus({
    this.configured = false,
    this.publicFields = const {},
    this.secretKeysSet = const {},
  });

  final bool configured;

  /// Non-secret fields (return_url, env), echoed back for editing.
  final Map<String, String> publicFields;

  /// Names of the secret fields that currently hold a value.
  final Set<String> secretKeysSet;
}
