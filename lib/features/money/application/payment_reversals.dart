// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3925 — the payments a provider reversed that wait for someone who sees the
// finances to look at them, and marking one looked at: the one door the
// payments screen uses.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/payment_intent.dart';
import '../providers/money_providers.dart';

/// The reversed payments of [workspaceId] nobody has looked at yet.
Future<List<PaymentIntent>> reversalsAwaitingReview(
  WidgetRef ref,
  String workspaceId,
) async => [
  for (final p
      in await ref
          .read(paymentGatewayRepositoryProvider)
          .fetchPaymentIntents(workspaceId))
    if (p.awaitsReview) p,
];

/// Marks the reversal of [intentId] as looked at.
Future<void> markReversalReviewed(WidgetRef ref, String intentId) =>
    ref.read(paymentGatewayRepositoryProvider).reviewPaymentReversal(intentId);
