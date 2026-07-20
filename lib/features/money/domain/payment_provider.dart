// SPDX-License-Identifier: MIT

/// Online-payment providers the create-payment-order Edge Function can
/// charge with (docs/design/payments-integration.md). Wire names match
/// the function's `provider` parameter — never rename.
enum PaymentProvider {
  paypal('paypal'),
  stripe('stripe'),
  mollie('mollie');

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
