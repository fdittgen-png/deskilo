// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../application/einvoice_receipt.dart';
import '../../domain/einvoice_gateway.dart';

/// #2358 — what a national channel said about a document after taking it
/// (the KSeF number, the ANAF download id, the PA's status, the SdI
/// notification), and, for whoever issues invoices, the way to ask it
/// again. The generic upload has no read-back, so it offers nothing.
class EInvoiceReceiptLine extends ConsumerWidget {
  const EInvoiceReceiptLine({
    super.key,
    required this.transmission,
    required this.workspaceId,
    required this.canAsk,
  });

  final InvoiceTransmission transmission;
  final String workspaceId;
  final bool canAsk;

  Future<void> _ask(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    EInvoiceSubmission? answer;
    await runGuarded(
      context,
      domain: 'money',
      message: 'e-invoice receipt request failed',
      errorText: l10n.eInvoiceReceiptFailed,
      action: () async {
        answer = await requestEInvoiceReceipt(
          ref,
          workspaceId: workspaceId,
          transmissionId: transmission.id,
        );
      },
    );
    final got = answer;
    if (got == null || !context.mounted) return;
    AppSnack.info(
      context,
      got.detail.isNotEmpty
          ? l10n.eInvoiceReceiptLine(got.detail)
          : l10n.eInvoiceReceiptNothingYet,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final summary = transmission.receiptSummary;
    final askable =
        canAsk &&
        transmission.id.isNotEmpty &&
        transmission.externalId.isNotEmpty &&
        transmission.provider != 'generic';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              l10n.eInvoiceReceiptLine(summary),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (askable)
          TextButton.icon(
            key: const ValueKey('einvoice-receipt-ask'),
            onPressed: () => _ask(context, ref),
            icon: const Icon(Icons.mark_email_read_outlined),
            label: Text(l10n.eInvoiceReceiptAsk),
          ),
      ],
    );
  }
}
