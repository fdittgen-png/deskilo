// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/purchase.dart';
import '../../providers/money_providers.dart';
import '../../providers/purchase_providers.dart';
import 'purchase_labels.dart';
import 'purchase_offset_dialog.dart';
import 'purchase_payment_dialogs.dart';

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
    this.canPay = false,
    this.canOffset = false,
    super.key,
  });

  final String workspaceId;
  final void Function(String purchaseId) onOpen;

  /// The signed-in person holds recordOutgoingPayments; the server decides
  /// again on every write.
  final bool canPay;

  /// The signed-in person may also settle an invoice (issueInvoices).
  final bool canOffset;

  Future<void> _offset(
    BuildContext context,
    WidgetRef ref,
    PurchaseObligation claim,
  ) async {
    final saved = await showOffsetDialog(context, workspaceId, claim);
    ref.invalidate(payablesProvider(workspaceId));
    if (saved != true || !context.mounted) return;
    ref.invalidate(invoiceMatchesProvider);
    AppSnack.success(context, context.l10n.purchasesOffsetSaved);
  }

  Future<void> _pay(
    BuildContext context,
    WidgetRef ref,
    PurchaseObligation claim,
  ) async {
    final saved = await showReimbursementDialog(context, workspaceId, claim);
    // Saved or not, the claim is read again: a lost answer may have landed.
    ref.invalidate(payablesProvider(workspaceId));
    if (saved != true || !context.mounted) return;
    AppSnack.success(context, context.l10n.purchasesPaySaved);
  }

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
                  r.obligation.creditorName ??
                      names[r.obligation.creditorId] ??
                      l10n.purchasesClaimYou,
                ),
              ),
              subtitle: Text(
                [
                  purchaseKindLabel(l10n, r.purchase.kind),
                  if (r.purchase.category.isNotEmpty) r.purchase.category,
                  claimStatusLabel(l10n, r.obligation),
                ].join(' · '),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    moneyFormat(
                      r.obligation.currency,
                    ).formatMinor(r.obligation.amountCents),
                  ),
                  if (canPay && r.obligation.payable && !r.obligation.mine)
                    IconButton(
                      key: ValueKey('payable-pay-${r.obligation.id}'),
                      tooltip: l10n.purchasesPayAction,
                      icon: const Icon(Icons.payments_outlined),
                      onPressed: () => _pay(context, ref, r.obligation),
                    ),
                  if (canPay &&
                      canOffset &&
                      r.obligation.payable &&
                      !r.obligation.mine &&
                      r.obligation.creditorKind == CreditorKind.member)
                    IconButton(
                      key: ValueKey('payable-offset-${r.obligation.id}'),
                      tooltip: l10n.purchasesOffsetAction,
                      icon: const Icon(Icons.swap_horiz),
                      onPressed: () => _offset(context, ref, r.obligation),
                    ),
                ],
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
