// SPDX-License-Identifier: AGPL-3.0-or-later
import 'payment_intent.dart';
import 'payment_provider.dart';
import 'payment_test_check.dart';

/// #2591 — online payments: the attempts, which providers the workspace
/// can charge with, the owner's credentials, and starting a checkout.
abstract interface class PaymentGatewayRepository {
  /// All online-payment attempts of the workspace (0045) — the export's
  /// online-payments rows. Admin-readable by the 0045 policy.
  Future<List<PaymentIntent>> fetchPaymentIntents(String workspaceId);

  /// Which online-payment providers this WORKSPACE can charge with
  /// (create-payment-order's config probe) — plus per-provider missing
  /// config fields for the owner diagnostics. An undeployed function maps
  /// to [PaymentGatewayConfig.notDeployed], never a throw.
  Future<PaymentGatewayConfig> fetchPaymentConfig(String workspaceId);

  /// Owner-only: the per-provider server-config status (configured flag,
  /// non-secret fields, which secret fields are set — never their values).
  Future<Map<PaymentProvider, PaymentProviderStatus>> fetchPaymentGatewayStatus(
    String workspaceId,
  );

  /// Owner-only: what a member's checkout would do with the keys
  /// [workspaceId] holds (RPC `payment_test_check`), read without a
  /// payment; refused while online payments are off.
  Future<PaymentTestCheck> testPaymentKeys(String workspaceId);

  /// Owner-only: merge [config] into a provider's server credentials
  /// (blank fields keep existing values). Secrets go to the deny-all
  /// payment_credentials table via an owner-gated RPC.
  Future<void> setPaymentCredentials(
    String workspaceId,
    PaymentProvider provider,
    Map<String, String> config,
  );

  /// Owner-only: remove a provider's server credentials entirely.
  Future<void> clearPaymentProvider(
    String workspaceId,
    PaymentProvider provider,
  );

  /// Starts an online payment with [provider] for [amountCents] of the
  /// member's bill (docs/design/payments-integration.md). Returns the
  /// provider's approval URL + order id, or a not-configured result naming
  /// the missing server env vars. Throws [PaymentGatewayException] on
  /// provider/auth errors so traces carry the server detail.
  ///
  /// [requestId] (#2014 B) names the attempt: a retry with the same id is
  /// answered from the intent it already opened, never a second order.
  /// A request that was already paid answers [PaymentOrderStart.alreadyPaid].
  Future<PaymentOrderStart> createPaymentOrder({
    required PaymentProvider provider,
    required String workspaceId,
    required String memberId,
    required int amountCents,
    required String currencyCode,
    required String period,
    String? requestId,
  });
}
