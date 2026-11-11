// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3671 -- two lines of the sheet "Assign to invoices" that come from the
// server's capacity read (`payment_invoice_capacity_v1`): an invoice whose
// payment awaits approval, shown and not offered; and a failed read of that
// list, said at once with Try again.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/kit/kit_metrics.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/assign_payment_plan.dart';
import '../../application/receivables.dart';

/// An invoice that takes no part now: a payment of it awaits approval.
class AssignPaymentWaitingLine extends StatelessWidget {
  AssignPaymentWaitingLine(this.invoice)
    : super(key: ValueKey('assign-payment-waiting-${invoice.invoiceId}'));

  final Receivable invoice;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      context.l10n.assignPaymentRowWaiting(invoice.number),
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

/// The list of what each invoice can take could not be read.
class AssignPaymentCapacityFailed extends StatelessWidget {
  const AssignPaymentCapacityFailed({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.assignPaymentReadFailedInvoices,
          key: const ValueKey('assign-payment-failed-capacity'),
        ),
        TextButton(
          key: const ValueKey('assign-payment-retry-capacity'),
          style: TextButton.styleFrom(
            minimumSize: const Size.square(KitMetrics.minTarget),
          ),
          onPressed: onRetry,
          child: Text(l10n.commonRetry),
        ),
      ],
    );
  }
}

/// Why the server refused, in the app's own words.
String assignRefusalText(AppLocalizations l10n, PaymentRefusal why) =>
    switch (why) {
      PaymentRefusal.payer => l10n.assignRefusePayer,
      PaymentRefusal.business => l10n.assignRefuseBusiness,
      PaymentRefusal.currency => l10n.assignRefuseCurrency,
      PaymentRefusal.duplicate => l10n.assignRefuseDuplicate,
      PaymentRefusal.partBeyondInvoice => l10n.assignRefusePartOver,
      PaymentRefusal.sumBeyondLeft => l10n.assignRefuseSumOver,
      PaymentRefusal.usedMeanwhile => l10n.assignRefuseUsed,
      PaymentRefusal.noteRequired => l10n.assignRefuseNote,
      PaymentRefusal.notAllowed => l10n.assignRefuseNotAllowed,
      PaymentRefusal.generic => l10n.assignRefuseGeneric,
    };
