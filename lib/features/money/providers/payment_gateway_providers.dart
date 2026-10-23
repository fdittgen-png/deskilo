// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/payment_provider.dart';
import 'money_providers.dart';

part 'payment_gateway_providers.g.dart';

/// Which online-payment providers [workspaceId] has connected, as the
/// online-payments screen reads it: configured or not, the public fields,
/// and only the NAMES of the secrets that hold a value.
@riverpod
Future<Map<PaymentProvider, PaymentProviderStatus>> paymentGatewayStatus(
  Ref ref,
  String workspaceId,
) => ref.watch(moneyRepositoryProvider).fetchPaymentGatewayStatus(workspaceId);
