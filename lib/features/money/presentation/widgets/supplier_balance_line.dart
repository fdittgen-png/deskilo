// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/loading_view.dart';
import '../../providers/supplier_balance_provider.dart';

/// The complete server balance, distinct from annual purchase-document spend.
class SupplierBalanceLine extends ConsumerWidget {
  const SupplierBalanceLine({
    required this.workspaceId,
    required this.supplierId,
    required this.onOpenPayables,
    super.key,
  });

  final String workspaceId;
  final String supplierId;
  final VoidCallback onOpenPayables;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final result = ref.watch(supplierBalancesProvider(workspaceId));
    // Do not show an older successful amount during a refresh or error.
    if (result.isLoading) {
      return const SizedBox(height: AppSpacing.xl, child: LoadingView());
    }
    if (result.hasError) {
      return Row(
        children: [
          Expanded(child: Text(l10n.suppliersBalanceUnavailable)),
          TextButton(
            onPressed: () =>
                ref.invalidate(supplierBalancesProvider(workspaceId)),
            child: Text(l10n.commonRetry),
          ),
        ],
      );
    }
    final balances = result.requireValue
        .where((balance) => balance.supplierId == supplierId)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (balances.isEmpty)
          Text(l10n.suppliersNoOutstanding)
        else
          for (final balance in balances) ...[
            Text(
              l10n.suppliersOutstanding(
                moneyFormat(balance.currency)
                    .formatMinor(balance.remainingCents),
              ),
            ),
            if (balance.heldCents != 0)
              Text(
                l10n.suppliersHeld(
                  moneyFormat(balance.currency).formatMinor(balance.heldCents),
                ),
              ),
          ],
        TextButton(
          key: ValueKey('supplier-payables-$supplierId'),
          onPressed: onOpenPayables,
          child: Text(l10n.suppliersViewPayables),
        ),
      ],
    );
  }
}
