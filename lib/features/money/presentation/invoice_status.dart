// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/invoice.dart';

/// Where an invoice stands in the 0067 lifecycle. Derived from the
/// document plus its match — ONE definition, used by the archive rows,
/// the open cards and the detail sheet, so a badge can never say one
/// thing on one screen and another elsewhere.
enum InvoiceLifecycle {
  /// Issued, waiting for its payment. The only state that still accepts
  /// reminders, correction and matching.
  open,

  /// Matched, but a validation quorum has not decided yet (0067).
  awaitingValidation,

  /// Matched and standing — DEFINITIVE (0068): no void, no replacement.
  paid,

  /// Matched to a payment that did NOT cover the whole invoice
  /// (resolution `under_accepted`) and the remainder NOT yet written
  /// off (#504): the invoice is STILL OPEN — the rest is owed until an
  /// explicit, validated cancellation.
  partiallyPaid,

  /// Partially paid AND the outstanding remainder was cancelled through
  /// the validation framework (#504) — only now is it archived.
  remainderCancelled,

  /// A NEGATIVE document (credit note, #508) the workspace refunded:
  /// the payout is booked and the avoir is closed.
  refunded,

  /// Tagged erroneous (0061); a replacement may carry the corrected data.
  erroneous,
}

InvoiceLifecycle invoiceLifecycleOf(Invoice invoice, InvoiceMatch? match) {
  if (invoice.isVoided) return InvoiceLifecycle.erroneous;
  if (match == null) return InvoiceLifecycle.open;
  if (match.pending) return InvoiceLifecycle.awaitingValidation;
  if (match.resolution == 'refunded') return InvoiceLifecycle.refunded;
  if (match.resolution == 'under_accepted') {
    return match.writeoffAt == null
        ? InvoiceLifecycle.partiallyPaid
        : InvoiceLifecycle.remainderCancelled;
  }
  return InvoiceLifecycle.paid;
}

/// The lifecycle as a compact chip. Replaces the dot-joined status words
/// that used to hide inside a row's grey subtitle line.
class InvoiceStatusChip extends StatelessWidget {
  const InvoiceStatusChip({super.key, required this.status});

  final InvoiceLifecycle status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final (Color background, Color foreground, String label) = switch (status) {
      InvoiceLifecycle.open => (
          colors.surfaceContainerHighest,
          colors.onSurfaceVariant,
          l10n?.invoiceStatusOpen ?? 'Open',
        ),
      InvoiceLifecycle.awaitingValidation => (
          colors.primaryContainer,
          colors.onPrimaryContainer,
          l10n?.invoiceMatchPendingBadge ?? 'Awaiting validation',
        ),
      InvoiceLifecycle.paid => (
          colors.secondaryContainer,
          colors.onSecondaryContainer,
          l10n?.invoiceMatchedBadge ?? 'Paid',
        ),
      InvoiceLifecycle.partiallyPaid => (
          colors.tertiaryContainer,
          colors.onTertiaryContainer,
          l10n?.invoiceStatusPartiallyPaid ?? 'Partially paid',
        ),
      InvoiceLifecycle.remainderCancelled => (
          colors.tertiaryContainer,
          colors.onTertiaryContainer,
          l10n?.invoiceStatusRemainderCancelled ??
              'Partially paid · remainder cancelled',
        ),
      InvoiceLifecycle.refunded => (
          colors.secondaryContainer,
          colors.onSecondaryContainer,
          l10n?.invoiceStatusRefunded ?? 'Refunded',
        ),
      InvoiceLifecycle.erroneous => (
          colors.errorContainer,
          colors.onErrorContainer,
          l10n?.invoiceVoidedChip ?? 'Erroneous',
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: foreground),
      ),
    );
  }
}
