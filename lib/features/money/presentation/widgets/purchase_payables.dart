// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/purchase.dart';
import '../../providers/money_providers.dart';
import '../../providers/purchase_providers.dart';
import 'purchase_labels.dart';

/// "Open · 50.00 remaining", "Applied to invoice N", "On hold": where a claim
/// stands, in words the person can act on.
String claimStatusLabel(AppLocalizations l10n, PurchaseObligation o) {
  if (o.state == ObligationState.cancelled) return l10n.purchasesClaimCancelled;
  if (o.state == ObligationState.held) return l10n.purchasesClaimHeld;
  final invoice = o.appliedInvoice;
  if (invoice != null && o.remainingCents == 0) {
    return l10n.purchasesClaimApplied(invoice.number);
  }
  return l10n.purchasesClaimOpen(
    moneyFormat(o.currency).formatMinor(o.remainingCents),
  );
}

/// The To-pay list: what the space still owes for approved purchases, one
/// group per kind of creditor. A row opens the document behind it.
class PurchasePayablesView extends ConsumerWidget {
  const PurchasePayablesView({
    required this.workspaceId,
    required this.onOpen,
    super.key,
  });

  final String workspaceId;
  final void Function(String purchaseId) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final payables = ref.watch(payablesProvider(workspaceId));
    final names = ref.watch(memberLabelsProvider);
    final rows = payables.value;
    if (rows == null) {
      return payables.hasError
          ? Text(l10n.purchasesOwedEmpty)
          : const LoadingView();
    }
    Widget group(String title, CreditorKind kind) {
      final mine = [
        for (final r in rows)
          if (r.obligation.creditorKind == kind) r,
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          if (mine.isEmpty)
            Text(
              l10n.purchasesOwedEmpty,
              key: ValueKey('payables-empty-${kind.wire}'),
            ),
          for (final r in mine)
            ListTile(
              key: ValueKey('payable-${r.obligation.id}'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.purchasesClaimOwedTo(
                  names[r.obligation.creditorId] ?? l10n.purchasesClaimYou,
                ),
              ),
              subtitle: Text(
                [
                  purchaseKindLabel(l10n, r.purchase.kind),
                  if (r.purchase.category.isNotEmpty) r.purchase.category,
                  claimStatusLabel(l10n, r.obligation),
                ].join(' · '),
              ),
              trailing: Text(
                moneyFormat(r.obligation.currency)
                    .formatMinor(r.obligation.amountCents),
              ),
              onTap: () => onOpen(r.purchase.id),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.purchasesToPayIntro,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        group(l10n.purchasesOwedMembers, CreditorKind.member),
        const SizedBox(height: AppSpacing.md),
        group(l10n.purchasesOwedSuppliers, CreditorKind.supplier),
      ],
    );
  }
}
