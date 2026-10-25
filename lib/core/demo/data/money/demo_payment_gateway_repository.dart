// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/features/money/domain/payment_gateway_repository.dart';
import 'package:deskilo/features/money/domain/payment_intent.dart';
import 'package:deskilo/features/money/domain/payment_provider.dart';
import 'package:deskilo/features/money/domain/payment_test_check.dart';

import '../money_repository.dart';

/// #2591 — the demo's online payments and their provider credentials, answered
/// from one space's in-memory money store ([FakeMoneyRepository]); every other
/// port of that space reads and writes the same store.
class DemoPaymentGateway implements PaymentGatewayRepository {
  DemoPaymentGateway(this._m);

  final FakeMoneyRepository _m;

  @override
  Future<List<PaymentIntent>> fetchPaymentIntents(String workspaceId) async =>
      List.of(_m.paymentIntents);

  @override
  Future<PaymentGatewayConfig> fetchPaymentConfig(String workspaceId) async =>
      PaymentGatewayConfig(
        providers: List.of(_m.paymentProviders),
        missing: _m.paymentMissing,
      );

  @override
  Future<Map<PaymentProvider, PaymentProviderStatus>> fetchPaymentGatewayStatus(
    String workspaceId,
  ) async => Map.of(_m.paymentStatus);

  /// The demo is a rehearsal: it opens no payment, and its keys are the
  /// installation's, which the test cannot read.
  @override
  Future<PaymentTestCheck> testPaymentKeys(String workspaceId) async =>
      PaymentTestCheck(
        verdict: _m.paymentStatus.isEmpty
            ? PaymentTestVerdict.noProvider
            : PaymentTestVerdict.unverified,
        takesPayments: false,
        modes: {
          for (final provider in _m.paymentStatus.keys)
            provider: PaymentKeyMode.installation,
        },
      );

  @override
  Future<void> setPaymentCredentials(
    String workspaceId,
    PaymentProvider provider,
    Map<String, String> config,
  ) async {
    _m.savedPaymentConfigs.add((provider, config));
  }

  @override
  Future<void> clearPaymentProvider(
    String workspaceId,
    PaymentProvider provider,
  ) async {
    _m.clearedProviders.add(provider);
  }

  @override
  Future<PaymentOrderStart> createPaymentOrder({
    required PaymentProvider provider,
    required String workspaceId,
    required String memberId,
    required int amountCents,
    required String currencyCode,
    required String period,
    String? requestId,
  }) async {
    _m.paymentOrders.add((provider, amountCents));
    final url = _m.paymentApprovalUrl;
    if (url == null) {
      return const PaymentOrderStart(missing: ['PAYPAL_CLIENT_ID']);
    }
    return PaymentOrderStart(approveUrl: url, orderId: 'order-1');
  }
}
