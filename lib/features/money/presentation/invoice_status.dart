// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/billing_rules.dart';
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

/// How one billing PERIOD stands once an invoice covers it (#510): the
/// covering document, its lifecycle, and what remains owed. Positive
/// [remainingCents] = the member still owes; negative = the workspace
/// owes a refund (an open credit note, #508); zero = settled.
typedef PeriodSettlement = ({
  Invoice invoice,
  InvoiceMatch? match,
  InvoiceLifecycle lifecycle,
  int remainingCents,
});

/// The settlement of [period], or null while no invoice covers it (the
/// raw ledger balance stays authoritative then). Voided and replaced
/// documents don't count; if several cover the month, the latest wins.
///
/// This is the member-side twin of the hub's open list: once the month
/// is INVOICED the debt lives on the document — the payment that
/// settles it is usually recorded in a LATER month, so the month's own
/// ledger arithmetic can never read settled (#510).
PeriodSettlement? settlementOfPeriod(
  String period,
  String memberId,
  List<Invoice> invoices,
  Map<String, InvoiceMatch> matches,
) {
  final replaced = {for (final i in invoices) ?i.replacesInvoiceId};
  Invoice? covering;
  for (final invoice in invoices) {
    // The member filter matters for ADMINS: their RLS scope holds the
    // whole workspace's archive, but their own bill must only ever
    // reflect their own documents.
    if (invoice.isVoided ||
        replaced.contains(invoice.id) ||
        invoice.memberId != memberId ||
        invoice.period != period) {
      continue;
    }
    if (covering == null || invoice.issuedAt.isAfter(covering.issuedAt)) {
      covering = invoice;
    }
  }
  if (covering == null) return null;
  final match = matches[covering.id];
  final lifecycle = invoiceLifecycleOf(covering, match);
  final remaining = switch (lifecycle) {
    // Nothing validated yet: the full face value is owed (a pending
    // match awaits its quorum — it settles nothing until confirmed).
    InvoiceLifecycle.open ||
    InvoiceLifecycle.awaitingValidation =>
      covering.totalCents,
    InvoiceLifecycle.partiallyPaid =>
      covering.totalCents - (match?.paidCents ?? 0),
    // Paid, remainder cancelled, refunded, erroneous: closed.
    _ => 0,
  };
  return (
    invoice: covering,
    match: match,
    lifecycle: lifecycle,
    remainingCents: remaining,
  );
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

/// #802/#804 — what a document CHARGES FOR, in the reader's language.
///
/// Shown wherever an invoice is named, because the kind is the thing that
/// makes an otherwise puzzling document make sense: a subscription
/// invoice is dated before the month it charges, and a settlement's
/// amount belongs to invoices that are not this one.
String invoiceKindLabel(AppLocalizations? l10n, InvoiceKind kind) =>
    switch (kind) {
      InvoiceKind.subscription =>
        l10n?.invoiceKindSubscription ?? 'Subscription, in advance',
      InvoiceKind.usage => l10n?.invoiceKindUsage ?? 'The month\'s extras',
      InvoiceKind.settlement =>
        l10n?.invoiceKindSettlement ?? 'Regrouped invoices',
      InvoiceKind.full => l10n?.invoiceKindFull ?? 'Whole month',
    };

/// #831 — the number of the settlement [invoice] was regrouped into,
/// or '' when it was not (or the settlement is not in [all]).
String settledByNumberOf(Invoice invoice, Iterable<Invoice> all) {
  final id = invoice.settledByInvoiceId;
  if (id == null) return '';
  return all.where((i) => i.id == id).firstOrNull?.number ?? '';
}
