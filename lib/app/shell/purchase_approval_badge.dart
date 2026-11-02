// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/context_l10n.dart';
import '../../core/ui/loading_view.dart';
import '../../features/money/domain/purchase_approval_reads.dart';

/// An unavailable count must not look like a confirmed empty queue.
class PurchaseApprovalBadge extends StatelessWidget {
  const PurchaseApprovalBadge({required this.value, super.key});
  final AsyncValue<PurchaseApprovalPage> value;

  @override
  Widget build(BuildContext context) {
    if (value.isLoading) {
      return Semantics(
        label: context.l10n.myReservationsLoadingMore,
        child: const SizedBox(width: 18, height: 18, child: LoadingView()),
      );
    }
    if (value.hasError) {
      return Tooltip(
        message: context.l10n.purchaseApprovalsRefused,
        child: const Icon(Icons.error_outline),
      );
    }
    final count = value.requireValue.count;
    return count > 0
        ? Badge.count(count: count, maxCount: 99)
        : const SizedBox.shrink();
  }
}
