// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../invoice_journey.dart';
import 'invoice_journey_view.dart';

/// #812 — "How invoicing works": the four steps of the journey, each with
/// what the WORKSPACE does and what the MEMBER does. One sheet for both
/// sides, reachable from the issuers' hub and from a member's Invoices
/// face, so the two never learn two different processes.
Future<void> showInvoiceProcessSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => const _ProcessBody(),
    );

class _ProcessBody extends StatelessWidget {
  const _ProcessBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final steps = <(InvoiceStep, IconData, String, String)>[
      (
        InvoiceStep.issued,
        Icons.receipt_long_outlined,
        l10n?.journeyHowIssuedWorkspace ??
            "Issues the invoice from the month's tracked data — numbered, "
                'signed, immutable — and shares the PDF or sends the '
                'e-invoice.',
        l10n?.journeyHowIssuedMember ??
            'Finds it on the Invoices face: positions, balance, due date.',
      ),
      (
        InvoiceStep.payment,
        Icons.payments_outlined,
        l10n?.journeyHowPaymentWorkspace ??
            'Waits for the money. Past the term it sends the reminder '
                'levels it configured — by hand or automatically.',
        l10n?.journeyHowPaymentMember ??
            'Pays online (settled at once) or by transfer, then records '
                'the payment so the workspace knows.',
      ),
      (
        InvoiceStep.confirmation,
        Icons.fact_check_outlined,
        l10n?.journeyHowConfirmationWorkspace ??
            'Another admin confirms the declared payment; the issuer then '
                'matches the registered payment to the invoice (Mark as '
                'paid) — a validation rule may hand the match to the '
                'validators. Paid more? A credit note. Paid less? '
                'Partially paid, the rest owed until paid or written off.',
        l10n?.journeyHowConfirmationMember ??
            'Nothing to do — unless the workspace recorded the payment '
                'for them: then they confirm it in Events.',
      ),
      (
        InvoiceStep.closed,
        Icons.inventory_2_outlined,
        l10n?.journeyHowClosedWorkspace ??
            'Paid, remainder cancelled or refunded: the invoice moves to '
                'the archive. A wrong invoice is marked erroneous and '
                'replaced — before payment, never after.',
        l10n?.journeyHowClosedMember ??
            'The month reads settled and the invoice stays readable '
                'forever: quick view, PDF, share.',
      ),
    ];
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          key: const ValueKey('invoice-process-sheet'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n?.journeyHowTitle ?? 'How invoicing works',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n?.journeyHowIntro ??
                    'Four steps, the same for every invoice. Each one says '
                        'whose move it is.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final (i, (step, icon, workspace, member)) in steps.indexed)
                Padding(
                  key: ValueKey('invoice-process-step-${step.name}'),
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        foregroundColor: theme.colorScheme.onPrimaryContainer,
                        child: Icon(icon, size: 20),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${i + 1} · ${invoiceStepLabel(l10n, step)}',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            _Side(
                              label: l10n?.journeyHowWorkspaceLabel ??
                                  'Workspace',
                              text: workspace,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            _Side(
                              label: l10n?.journeyHowMemberLabel ?? 'Member',
                              text: member,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One side of a step: who, then what they do.
class _Side extends StatelessWidget {
  const _Side({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 1,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: AppRadius.smAll,
          ),
          child: Text(label, style: theme.textTheme.labelSmall),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
      ],
    );
  }
}
