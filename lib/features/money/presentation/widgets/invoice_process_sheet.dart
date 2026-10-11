// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
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
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final steps = <(InvoiceStep, IconData, String, String)>[
      (
        InvoiceStep.issued,
        Icons.receipt_long_outlined,
        l10n.journeyHowIssuedWorkspace,
        l10n.journeyHowIssuedMember,
      ),
      (
        InvoiceStep.payment,
        Icons.payments_outlined,
        l10n.journeyHowPaymentWorkspace,
        l10n.journeyHowPaymentMember,
      ),
      (
        InvoiceStep.confirmation,
        Icons.fact_check_outlined,
        l10n.journeyHowConfirmationWorkspace,
        l10n.journeyHowConfirmationMember,
      ),
      (
        InvoiceStep.closed,
        Icons.inventory_2_outlined,
        l10n.journeyHowClosedWorkspace,
        l10n.journeyHowClosedMember,
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
                l10n.journeyHowTitle,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.journeyHowIntro,
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
                              label: l10n.journeyHowWorkspaceLabel,
                              text: workspace,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            _Side(
                              label: l10n.journeyHowMemberLabel,
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
