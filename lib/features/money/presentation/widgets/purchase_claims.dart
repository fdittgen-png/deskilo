// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_snack.dart';
import '../../domain/purchase.dart';
import '../../providers/purchase_providers.dart';
import 'purchase_payables.dart';
import 'purchase_payment_dialogs.dart';
import 'purchase_reverse_dialog.dart';

/// What the space owes for one document: each claim with the payments
/// recorded against it, and for who may, the reversal of a payment.
class PurchaseClaimsSection extends ConsumerWidget {
  const PurchaseClaimsSection({
    required this.workspaceId,
    required this.claims,
    required this.canPay,
    super.key,
  });

  final String workspaceId;
  final List<PurchaseObligation> claims;
  final bool canPay;

  Future<void> _reverse(
    BuildContext context,
    WidgetRef ref,
    PurchaseObligation claim,
    SettlementAllocation payment,
  ) async {
    final done = await showReverseDialog(context, workspaceId, claim, payment);
    // Saved or not, the claim is read again: a lost answer may have landed.
    ref
      ..invalidate(purchaseDetailProvider)
      ..invalidate(payablesProvider(workspaceId));
    if (done != true || !context.mounted) return;
    AppSnack.success(context, context.l10n.purchasesReverseSaved);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.purchasesClaimsTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        for (final o in claims) ...[
          ListTile(
            key: ValueKey('purchase-claim-${o.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(claimStatusLabel(l10n, o)),
            trailing: Text(moneyFormat(o.currency).formatMinor(o.amountCents)),
          ),
          for (final a in o.allocations)
            ListTile(
              key: ValueKey('allocation-${a.id}'),
              contentPadding: const EdgeInsets.only(left: AppSpacing.md),
              dense: true,
              title: Text(
                a.isReversal
                    ? l10n.purchasesReversalLine(
                        moneyFormat(o.currency)
                            .formatMinor(a.amountCents.abs()),
                      )
                    : l10n.purchasesPaymentLine(
                        moneyFormat(o.currency).formatMinor(a.amountCents),
                        a.paidOn == null
                            ? ''
                            : material.formatMediumDate(a.paidOn!),
                        paymentMethodLabel(l10n, a.method),
                      ),
              ),
              subtitle: a.reversed ? Text(l10n.purchasesPaymentReversed) : null,
              trailing:
                  canPay && a.reversible && !o.mine && o.appliedInvoice == null
                  ? TextButton(
                      key: ValueKey('allocation-reverse-${a.id}'),
                      onPressed: () => _reverse(context, ref, o, a),
                      child: Text(l10n.purchasesReverseAction),
                    )
                  : null,
            ),
        ],
      ],
    );
  }
}
