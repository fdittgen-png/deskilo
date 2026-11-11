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
  });

  final Invoice invoice;
  final Receivable receivable;
  final DateTime today;

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
                paid ? total : money.formatMinor(r.openMinor),
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

/// Every other action of the invoice, in worded sections: the document,
/// the reminders, the corrections (section 4 of the final design).
class InvoiceMoreMenu extends ConsumerWidget {
  const InvoiceMoreMenu({
    super.key,
    required this.invoice,
    required this.receivable,
  });

  final Invoice invoice;
  final Receivable? receivable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final r = receivable;
    final outstanding = r?.isOutstanding ?? false;
    // Corrections a document still accepts: replace or cancel an open one
    // nothing has been matched to; write off what a part payment left.
    final open =
        r != null && r.stage == ReceivableStage.open && !r.paymentPending;
    final partly = r?.stage == ReceivableStage.partlyPaid;
    // 2014/55/EU: the e-invoice is for EU businesses, answered from the
    // live context alone (no answer while it is not ready).
    final eu = watchWorkspaceIsEu(
      ref,
      ref.watch(invoicingBusinessProvider).country,
    );
    final entries = <(String, String?, VoidCallback?)>[
      ('invoice-more-document', l.invoicePageMoreDocument, null),
      (
        'invoice-more-view',
        l.invoicePageMoreQuickView,
        () => InvoicePageActions.run(
          context,
          ref,
          sheet.InvoiceAction.quickView,
          invoice,
        ),
      ),
      (
        'invoice-more-download',
        l.invoicePageMoreDownload,
        () => InvoicePageActions.run(
          context,
          ref,
          sheet.InvoiceAction.downloadPdf,
          invoice,
        ),
      ),
      (
        'invoice-more-share',
        l.invoicePageMoreShare,
        () => InvoicePageActions.run(
          context,
          ref,
          sheet.InvoiceAction.sharePdf,
          invoice,
        ),
      ),
      if (eu)
        (
          'invoice-more-einvoice',
          l.invoicePageMoreEInvoice,
          () => InvoicePageActions.run(
            context,
            ref,
            sheet.InvoiceAction.eInvoice,
            invoice,
          ),
        ),
      if (outstanding) ...[
        ('invoice-more-reminders', l.invoicePageMoreReminders, null),
        (
          'invoice-more-hold',
          r!.onHold ? l.invoicePageMoreRelease : l.invoicePageMoreHold,
          () => InvoicePageActions.run(
            context,
            ref,
            sheet.InvoiceAction.dunningHold,
            invoice,
          ),
        ),
      ],
      if (open || partly) ...[
        ('invoice-more-corrections', l.invoicePageMoreCorrections, null),
        if (open) ...[
          (
            'invoice-more-replace',
            l.invoicePageMoreReplace,
            () => InvoicePageActions.run(
              context,
              ref,
              sheet.InvoiceAction.replace,
              invoice,
            ),
          ),
          (
            'invoice-more-cancel',
            l.invoicePageMoreCancel,
            () => InvoicePageActions.run(
              context,
              ref,
              sheet.InvoiceAction.markErroneous,
              invoice,
            ),
          ),
        ],
        if (partly)
          (
            'invoice-more-writeoff',
            l.invoicePageMoreWriteOff,
            () => requestInvoiceWriteoffDialog(context, ref, invoice),
          ),
      ],
    ];
    return PopupMenuButton<int>(
      key: const ValueKey('invoice-page-more'),
      tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
      onSelected: (i) => entries[i].$3?.call(),
      itemBuilder: (_) => [
        for (final (i, e) in entries.indexed)
          if (e.$3 == null)
            PopupMenuItem<int>(
              key: ValueKey(e.$1),
              enabled: false,
              height: 32,
              child: Text(
                e.$2!.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            )
          else
            PopupMenuItem<int>(
              key: ValueKey(e.$1),
              value: i,
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
