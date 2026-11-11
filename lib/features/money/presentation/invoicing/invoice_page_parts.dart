// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-d -- the parts of the invoice page: who and how much (the
// summary), what was invoiced (the lines), the PDF, and "More" with every
// other action of the invoice in worded sections; and the runner of the
// invoice's existing actions with the page's context.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/kit/kit_card.dart';
import '../../../../core/ui/kit/status_chip.dart';
import '../../application/receivables.dart';
import '../../domain/invoice_line_text.dart';
import '../../providers/money_providers.dart';
import '../invoice_actions.dart';
import '../invoice_proforma.dart';
import '../invoice_status.dart';
import '../report_strings_l10n.dart';
import '../widgets/invoice_detail_sheet.dart' as sheet show InvoiceAction;
import 'invoicing_words.dart';

/// The invoice's existing actions, run with the page's context.
abstract final class InvoicePageActions {
  /// Runs [action] on [invoice] (the flows the detail sheet always had).
  static Future<void> run(
    BuildContext context,
    WidgetRef ref,
    sheet.InvoiceAction action,
    Invoice invoice,
  ) => runInvoiceAction(
    context,
    ref,
    action,
    invoice,
    countryCode: ref.read(invoicingBusinessProvider).country,
  );
}

/// Who, how much is open of the total, and the status in words.
class InvoiceSummaryCard extends StatelessWidget {
  const InvoiceSummaryCard({
    super.key,
    required this.invoice,
    required this.receivable,
    required this.today,
    this.termNote,
    this.closure,
  });

  final Invoice invoice;
  final Receivable receivable;
  final DateTime today;

  /// A quiet line under the due date: no payment term was agreed.
  final String? termNote;

  /// How a cancelled invoice ended, in place of the open amount's line.
  final Widget? closure;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final format = appFormatOf(context);
    final r = receivable;
    final money = format.moneyIn(r.currency);
    final status = invoiceStatusOf(r, today);
    final paid = r.stage == ReceivableStage.paid;
    final total = money.formatMinor(r.totalMinor.abs());
    final due = r.dueOn;
    return KitCard(
      key: const ValueKey('invoice-page-summary'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.sm,
        children: [
          Text(r.customerName, style: theme.textTheme.titleSmall),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                // What is still open while it is owed (or a refund owed); the
                // document's total once its story has ended.
                r.isOutstanding || r.stage == ReceivableStage.refundOwed
                    ? money.formatMinor(r.openMinor)
                    : total,
                style: theme.textTheme.headlineMedium?.emphasised.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              StatusChip(
                label: statusWordsOf(l, format, r, status),
                tone: statusToneOf(status.kind),
              ),
            ],
          ),
          ?closure,
          if (closure == null)
            Text(
              paid
                  ? l.invoicePagePaidInFull
                  : due == null
                  ? l.invoicePageOpenOfUndated(total)
                  : l.invoicePageOpenOf(
                      total,
                      format.dates(DateShape.monthDay).format(due),
                    ),
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          if (termNote case final note?)
            Text(
              note,
              key: const ValueKey('invoice-page-term-note'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// What was invoiced, line by line, in the words the PDF uses.
class InvoiceLinesCard extends StatelessWidget {
  const InvoiceLinesCard({super.key, required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final format = appFormatOf(context);
    final words = reportStringsFor(context);
    final money = format.moneyIn(invoice.currency);
    return KitCard(
      key: const ValueKey('invoice-page-lines'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.sm,
        children: [
          KitLabel(l.invoicePageInvoiced),
          for (final line in invoice.lines)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.md,
              children: [
                Expanded(
                  child: Text(
                    invoiceLineText(words, line, period: invoice.period),
                  ),
                ),
                Text(
                  money.formatMinor(line.amountCents),
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The document as the customer received it.
class InvoicePdfCard extends ConsumerWidget {
  const InvoicePdfCard({super.key, required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return KitCard(
      key: const ValueKey('invoice-page-pdf'),
      child: Row(
        spacing: AppSpacing.md,
        children: [
          Icon(Icons.description_outlined, color: theme.colorScheme.primary),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.invoicePagePdf, style: theme.textTheme.titleSmall),
                Text(
                  l.invoicePagePdfHint,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          TextButton(
            key: const ValueKey('invoice-page-view'),
            onPressed: () => InvoicePageActions.run(
              context,
              ref,
              sheet.InvoiceAction.quickView,
              invoice,
            ),
            child: Text(l.invoicePageView),
          ),
        ],
      ),
    );
  }
}

/// A write-off is offered on a part-paid invoice while none already waits for
/// its approval (one at a time).
bool invoiceWriteOffOffered(Receivable? r) =>
    r != null &&
    r.stage == ReceivableStage.partlyPaid &&
    !r.awaitingSecondApproval;

/// The proforma asks for the whole total: only while nothing is paid and no
/// payment is on its way.
bool _proformaOffered(Receivable? r) =>
    r != null && r.stage == ReceivableStage.open && !r.paymentPending;

/// One line of the More menu: its key, its words, and what it does (a header
/// has no action).
typedef _Entry = (String, String?, VoidCallback?);

/// Every other action of the invoice, in worded sections: the document,
/// the reminders, the corrections (section 4 of the final design).
class InvoiceMoreMenu extends ConsumerWidget {
  const InvoiceMoreMenu({
    super.key,
    required this.invoice,
    required this.receivable,
    this.awaitsReplacement = false,
  });

  final Invoice invoice;
  final Receivable? receivable;

  /// Cancelled as issued by mistake and not replaced yet: the replacement
  /// can still be issued.
  final bool awaitsReplacement;

  VoidCallback _run(
    BuildContext context,
    WidgetRef ref,
    sheet.InvoiceAction action,
  ) =>
      () => InvoicePageActions.run(context, ref, action, invoice);

  /// The document: see it, download it, share it, its e-invoice, a proforma.
  List<_Entry> _document(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final r = receivable;
    // 2014/55/EU: the e-invoice is for EU businesses, answered from the
    // live context alone (no answer while it is not ready).
    final eu = watchWorkspaceIsEu(
      ref,
      ref.watch(invoicingBusinessProvider).country,
    );
    return [
      ('invoice-more-document', l.invoicePageMoreDocument, null),
      (
        'invoice-more-view',
        l.invoicePageMoreQuickView,
        _run(context, ref, sheet.InvoiceAction.quickView),
      ),
      (
        'invoice-more-download',
        l.invoicePageMoreDownload,
        _run(context, ref, sheet.InvoiceAction.downloadPdf),
      ),
      (
        'invoice-more-share',
        l.invoicePageMoreShare,
        _run(context, ref, sheet.InvoiceAction.sharePdf),
      ),
      if (eu)
        (
          'invoice-more-einvoice',
          l.invoicePageMoreEInvoice,
          _run(context, ref, sheet.InvoiceAction.eInvoice),
        ),
      // An issued invoice re-sent as a payment request; the document does
      // not change.
      if (_proformaOffered(r))
        (
          'invoice-more-proforma',
          l.invoiceProformaAction,
          () => shareProforma(context, ref, invoice),
        ),
    ];
  }

  /// The reminders: share one (whatever the reminder mode) and hold them.
  List<_Entry> _reminders(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final r = receivable;
    if (!(r?.isOutstanding ?? false)) return const [];
    return [
      ('invoice-more-reminders', l.invoicePageMoreReminders, null),
      if (invoice.totalCents > 0)
        (
          'invoice-more-remind',
          l.invoicePageMoreRemind,
          _run(context, ref, sheet.InvoiceAction.remind),
        ),
      (
        'invoice-more-hold',
        r!.onHold ? l.invoicePageMoreRelease : l.invoicePageMoreHold,
        _run(context, ref, sheet.InvoiceAction.dunningHold),
      ),
    ];
  }

  /// The payment: match one to this invoice (a credit note is never matched).
  List<_Entry> _payment(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    if (!(receivable?.isOutstanding ?? false) || invoice.totalCents <= 0) {
      return const [];
    }
    return [
      ('invoice-more-payment', l.invoicePageMorePayment, null),
      (
        'invoice-more-match',
        l.invoicePageMoreMatch,
        _run(context, ref, sheet.InvoiceAction.markPaid),
      ),
    ];
  }

  /// The corrections THIS invoice still accepts: its own match decides, not
  /// the customer's other payments. Replace or cancel an open one nothing is
  /// matched to; write off what a part payment left, once.
  List<_Entry> _corrections(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final r = receivable;
    final match = ref.watch(invoiceMatchesProvider).value?[invoice.id];
    final open =
        r != null &&
        r.stage == ReceivableStage.open &&
        match == null &&
        invoiceLifecycleOf(invoice, match) == InvoiceLifecycle.open;
    final partly = r?.stage == ReceivableStage.partlyPaid;
    if (!(open || partly || awaitsReplacement)) return const [];
    return [
      ('invoice-more-corrections', l.invoicePageMoreCorrections, null),
      if (awaitsReplacement)
        (
          'invoice-more-issue-replacement',
          l.invoicePageMoreIssueReplacement,
          _run(context, ref, sheet.InvoiceAction.replace),
        ),
      if (open) ...[
        (
          'invoice-more-replace',
          l.invoicePageMoreReplace,
          _run(context, ref, sheet.InvoiceAction.replace),
        ),
        (
          'invoice-more-cancel',
          l.invoicePageMoreCancel,
          _run(context, ref, sheet.InvoiceAction.markErroneous),
        ),
      ],
      if (invoiceWriteOffOffered(r))
        (
          'invoice-more-writeoff',
          l.invoicePageMoreWriteOff,
          () => requestInvoiceWriteoffDialog(context, ref, invoice),
        ),
    ];
  }

  /// The entries in their worded sections; a header has no action.
  List<_Entry> _entries(BuildContext context, WidgetRef ref) => [
    ..._document(context, ref),
    ..._reminders(context, ref),
    ..._payment(context, ref),
    ..._corrections(context, ref),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = _entries(context, ref);
    return PopupMenuButton<String>(
      key: const ValueKey('invoice-page-more'),
      tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
      // By the entry's key, read from the entries as they are NOW: the list
      // depends on live reads, so a refresh while the menu is open must never
      // run the neighbour's action. An entry that is gone does nothing.
      onSelected: (key) {
        for (final e in _entries(context, ref)) {
          if (e.$1 == key) {
            e.$3?.call();
            return;
          }
        }
      },
      itemBuilder: (_) => [
        for (final e in entries)
          if (e.$3 == null)
            PopupMenuItem<String>(
              key: ValueKey(e.$1),
              enabled: false,
              height: 32,
              child: Text(
                e.$2!.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            )
          else
            PopupMenuItem<String>(
              key: ValueKey(e.$1),
              value: e.$1,
              child: Text(e.$2!),
            ),
      ],
      child: ConstrainedBox(
        // The worded button is a whole target, not just its words.
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(MaterialLocalizations.of(context).moreButtonTooltip),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }
}
