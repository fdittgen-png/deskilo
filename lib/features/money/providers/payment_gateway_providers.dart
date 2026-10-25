// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/payment_provider.dart';
import '../domain/payment_test_check.dart';
import 'money_providers.dart';

part 'payment_gateway_providers.g.dart';

/// Which online-payment providers [workspaceId] has connected, as the
/// online-payments screen reads it: configured or not, the public fields,
/// and only the NAMES of the secrets that hold a value.
@riverpod
Future<Map<PaymentProvider, PaymentProviderStatus>> paymentGatewayStatus(
  Ref ref,
  String workspaceId,
) => ref.watch(paymentGatewayRepositoryProvider).fetchPaymentGatewayStatus(workspaceId);

/// The online-payments test of [workspaceId]: what a member's checkout
/// would do with the keys it holds. Read only when the owner asks, and
/// again on each retry; nothing is paid or written by reading it. A
/// refusal is the answer, shown at once, never retried behind a spinner.
@Riverpod(retry: _noRetry)
Future<PaymentTestCheck> paymentTestCheck(Ref ref, String workspaceId) =>
    ref.watch(paymentGatewayRepositoryProvider).testPaymentKeys(workspaceId);

Duration? _noRetry(int retryCount, Object error) => null;
