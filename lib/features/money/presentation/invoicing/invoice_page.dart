// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-d -- one invoice: who, how much is open of the total, its status
// in words, what happened (dated, the last line "now"), what was invoiced,
// the PDF, and "More" with every action the invoice had before (section 4
// of the final design). The main action sits in a bottom bar under the
// thumb: Share reminder n (by hand), Confirm / Not received (a declared
// payment), Match the payment, Record the refund (a credit note) or the
// e-invoice to fix. A phone opens it as a page; a desk keeps it beside
// the list ([panel]).
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/server_error.dart';
import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/kit/bottom_action_bar.dart';
import '../../../../core/ui/kit/kit_card.dart';
import '../../../../core/ui/kit/status_chip.dart';
import '../../../../core/ui/kit/story.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/confirmed_payment.dart';
import '../../application/receivables.dart';
import '../../domain/dunning.dart';
import '../../domain/invoice_line_text.dart';
import '../../providers/money_providers.dart';
import '../invoice_actions.dart';
import '../report_strings_l10n.dart';
import '../widgets/invoice_detail_sheet.dart' as sheet show InvoiceAction;
import '../widgets/invoice_journey_view.dart';
import 'invoicing_reads.dart';
import 'invoicing_words.dart';

/// Opens [invoiceId]'s page over the current one (a phone, a narrow
/// window), full screen.
Future<void> openInvoicePage(BuildContext context, String invoiceId) =>
    showDialog<void>(
      context: context,
      builder: (_) =>
          Dialog.fullscreen(child: InvoicePage(invoiceId: invoiceId)),
    );

class InvoicePage extends ConsumerWidget {
  const InvoicePage({super.key, required this.invoiceId, this.onClose});

  final String invoiceId;

  /// Set when the page is a panel beside the list: its close button.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final invoices = ref.watch(invoicesProvider).value;
    final invoice = invoices?.where((i) => i.id == invoiceId).firstOrNull;
    if (invoice == null) {
      return const Scaffold(body: LoadingView());
    }
    final read = ref.watch(invoicingReaderProvider).read([invoice]);
    final r = read.isEmpty ? null : read.first;
    // The business's calendar day, from the workspace's own context.
    final now = ref.watch(clockProvider).now();
    final today =
        ref.watch(readyWorkspaceContextProvider)?.calendar.dateOf(now) ??
        DateTime(now.year, now.month, now.day);
    final rules =
        ref.watch(dunningRulesProvider).value ?? DunningRules.defaults;
    final mode = rules.automatic ? ReminderMode.automatic : ReminderMode.byHand;
    return Scaffold(
      key: ValueKey('invoice-page-$invoiceId'),
      appBar: AppBar(
        automaticallyImplyLeading: onClose == null,
        title: Text(l.invoicePageTitle(invoice.number)),
        actions: [
          _More(invoice: invoice, receivable: r),
          if (onClose != null)
            IconButton(
              key: const ValueKey('invoice-page-close'),
              tooltip: l.invoicePageClose,
              onPressed: onClose,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      bottomNavigationBar: r == null
          ? null
          : _bottomBar(context, ref, invoice, r, today, mode),
      body: ListView(
        padding: AppSpacing.mdAll,
        children: [
          if (r != null) ...[
            _Summary(invoice: invoice, receivable: r, today: today),
            const SizedBox(height: AppSpacing.md),
            KitCard(
              key: const ValueKey('invoice-page-story'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.sm,
                children: [
                  KitLabel(l.invoicePageWhatHappened),
                  _story(context, ref, r, today),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _Lines(invoice: invoice),
          const SizedBox(height: AppSpacing.md),
          _Pdf(invoice: invoice),
        ],
      ),
    );
  }

  Widget _story(
    BuildContext context,
    WidgetRef ref,
    Receivable r,
    DateTime today,
  ) {
    final l = context.l10n;
    final format = appFormatOf(context);
    String day(DateTime? d) =>
        d == null ? '' : format.dates(DateShape.monthDay).format(d);
    final reminder = ref.watch(invoiceRemindersProvider).value?[r.invoiceId];
    final late = r.isLateOn(today);
    final lines = <StoryLine>[
      (text: l.invoicePageStoryIssued, when: day(r.issuedOn)),
      if (late && r.dueOn != null)
        (text: l.invoicePageStoryDue, when: day(r.dueOn)),
      for (var k = 1; k <= r.remindersSent; k++)
        (
          text: l.invoicePageStoryReminder(k),
          // The last reminder's day is recorded; the earlier ones are counted.
          when: k == r.remindersSent ? day(reminder?.last) : '',
        ),
      if (r.paymentDeclared)
        (
          text: l.invoicePageStoryDeclared(r.customerName),
          when: day(r.declaredOn),
        ),
      if (r.paidOn != null) (text: l.invoicePageStoryPaid, when: day(r.paidOn)),
    ];
    final now = _nowOf(l, format, r, today);
    return Story(
      lines: lines,
      now: now == null ? null : (text: now, when: l.invoicePageToday),
    );
  }

  /// What is awaited today, or null when the story has ended.
  static String? _nowOf(
    AppLocalizations l,
    AppFormat format,
    Receivable r,
    DateTime today,
  ) {
    if (r.stage == ReceivableStage.refundOwed) return l.invoicePageNowRefund;
    if (!r.isOutstanding) return null;
    if (r.eInvoiceRejected) return l.invoicePageNowRejected;
    if (r.paymentDeclared) return l.invoicePageNowDeclared;
    if (r.awaitingSecondApproval) return l.invoicePageNowApproval;
    if (r.paymentToMatch) return l.invoicePageNowToMatch;
    if (r.awaitingCustomerConfirmation) return l.invoicePageNowCustomer;
    if (r.onHold) return l.invoicePageNowHold;
    if (r.isLateOn(today)) {
      if (r.remindersExhausted) return l.invoicePageNowEveryReminder;
      if (r.reminderDueLevel case final level?) {
        return l.invoicePageNowReminder(level);
      }
      return l.invoicePageNowWaiting;
    }
    final due = r.dueOn;
    return due == null
        ? l.invoicePageNowWaiting
        : l.invoicePageNowDue(format.dates(DateShape.monthDay).format(due));
  }

  /// After a confirmation, matches the confirmed payment to [invoice] when
  /// it pays the open amount exactly: what came of it, read back from the
  /// server. A refusal is said in the server's words and the bar keeps
  /// "Match the payment".
  Future<ConfirmOutcome> _matchConfirmed(
    BuildContext context,
    WidgetRef ref,
    Invoice invoice,
    Receivable r,
  ) async {
    final matches = ref.read(invoiceMatchesProvider).value ?? const {};
    final declared = ref
        .read(invoiceEventFactsProvider)(invoice, matches[invoice.id])
        .declaration;
    final amount = declared?.amountCents ?? 0;
    if (amount != r.openMinor) return ConfirmOutcome.confirmedOnly;
    final workspace = ref.read(currentWorkspaceProvider).value;
    try {
      final ledger = await ref
          .read(memberAccountQueriesProvider)
          .fetchLedger(invoice.memberId);
      final consumed = {
        for (final m in matches.values) ?m.paymentLedgerId,
        if (workspace != null)
          ...await ref
              .read(invoiceQueriesProvider)
              .fetchConsumedPaymentIds(workspace.id),
      };
      final payment = confirmedPaymentFor(
        ledger,
        customerId: invoice.memberId,
        amountCents: amount,
        invoiceCurrency: invoice.currency,
        accountCurrency: workspace?.currencyCode ?? '',
        consumed: consumed,
      );
      if (payment == null) return ConfirmOutcome.confirmedOnly;
      await ref
          .read(invoiceCommandsProvider)
          .matchInvoice(
            invoiceId: invoice.id,
            paymentLedgerId: payment,
            resolution: 'exact',
          );
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'money',
        'match after confirmation refused',
        error: e,
        stackTrace: st,
      );
      if (context.mounted) {
        AppSnack.error(
          context,
          serverErrorMessage(e) ?? context.l10n.workspaceGenericError,
        );
      }
      return ConfirmOutcome.confirmedOnly;
    } finally {
      ref
        ..invalidate(invoiceMatchesProvider)
        ..invalidate(invoicesProvider);
    }
    // The match as the server now has it: settled, or waiting for its
    // second approval (0067).
    final now = await ref.read(invoiceMatchesProvider.future);
    return outcomeOfMatch(now[invoice.id]);
  }

  Widget? _bottomBar(
    BuildContext context,
    WidgetRef ref,
    Invoice invoice,
    Receivable r,
    DateTime today,
    ReminderMode mode,
  ) {
    final l = context.l10n;
    Widget filled(String key, String label, VoidCallback onPressed) =>
        FilledButton(
          key: ValueKey(key),
          onPressed: onPressed,
          child: Text(label, textAlign: TextAlign.center),
        );
    if (r.paymentDeclared && r.declaredEventId != null) {
      Future<void> decide({required bool accept}) async {
        final decision = ref.read(declaredPaymentDecisionProvider);
        final error = await decision(ref, r.declaredEventId!, accept: accept);
        if (!context.mounted) return;
        if (error != null) {
          AppSnack.error(context, error);
          return;
        }
        if (!accept) {
          AppSnack.info(context, l.invoicePageMarkedNotReceived);
          return;
        }
        // Confirmed: when it pays the open amount exactly, it settles this
        // invoice in the same gesture; otherwise the bar now offers "Match
        // the payment" and the person chooses.
        final outcome = await _matchConfirmed(context, ref, invoice, r);
        if (!context.mounted) return;
        switch (outcome) {
          case ConfirmOutcome.matched:
            AppSnack.success(context, l.invoicePageConfirmedMatched);
          case ConfirmOutcome.awaitsApproval:
            AppSnack.info(context, l.invoicePageConfirmedAwaitsApproval);
          case ConfirmOutcome.confirmedOnly:
            AppSnack.info(context, l.invoicePageConfirmed);
        }
      }

      return BottomActionBar(
        actions: [
          OutlinedButton(
            key: const ValueKey('invoice-page-not-received'),
            onPressed: () => decide(accept: false),
            child: Text(l.invoicePageNotReceived, textAlign: TextAlign.center),
          ),
          filled(
            'invoice-page-confirm',
            l.invoicePageConfirm,
            () => decide(accept: true),
          ),
        ],
      );
    }
    final button = switch (actionOf(r, today, mode)) {
      InvoiceAction.shareReminder => filled(
        'invoice-page-remind',
        l.invoicePageShareReminder(r.reminderDueLevel ?? 1),
        () => remindInvoice(context, ref, invoice),
      ),
      InvoiceAction.match => filled(
        'invoice-page-match',
        l.invoicePageMatch,
        () => matchInvoiceToPayment(context, ref, invoice),
      ),
      InvoiceAction.payOutRefund => filled(
        'invoice-page-refund',
        l.invoicePageRefund,
        () => settleCreditInvoiceDialog(context, ref, invoice),
      ),
      InvoiceAction.fix => filled(
        'invoice-page-einvoice',
        l.invoicePageMoreEInvoice,
        () => _run(context, ref, sheet.InvoiceAction.eInvoice, invoice),
      ),
      _ => null,
    };
    return button == null ? null : BottomActionBar(actions: [button]);
  }
}

/// Runs one of the invoice's existing actions with the page's context.
Future<void> _run(
  BuildContext context,
  WidgetRef ref,
  sheet.InvoiceAction action,
  Invoice invoice,
) => runInvoiceAction(
  context,
  ref,
  action,
  invoice,
  countryCode: ref.read(currentWorkspaceProvider).value?.countryCode ?? '',
);

/// Who, how much is open of the total, and the status in words.
class _Summary extends StatelessWidget {
  const _Summary({
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
class _Lines extends StatelessWidget {
  const _Lines({required this.invoice});

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
class _Pdf extends ConsumerWidget {
  const _Pdf({required this.invoice});

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
            onPressed: () =>
                _run(context, ref, sheet.InvoiceAction.quickView, invoice),
            child: Text(l.invoicePageView),
          ),
        ],
      ),
    );
  }
}

/// Every other action of the invoice, in worded sections: the document,
/// the reminders, the corrections (section 4 of the final design).
class _More extends ConsumerWidget {
  const _More({required this.invoice, required this.receivable});

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
    final entries = <(String, String?, VoidCallback?)>[
      ('invoice-more-document', l.invoicePageMoreDocument, null),
      (
        'invoice-more-view',
        l.invoicePageMoreQuickView,
        () => _run(context, ref, sheet.InvoiceAction.quickView, invoice),
      ),
      (
        'invoice-more-download',
        l.invoicePageMoreDownload,
        () => _run(context, ref, sheet.InvoiceAction.downloadPdf, invoice),
      ),
      (
        'invoice-more-share',
        l.invoicePageMoreShare,
        () => _run(context, ref, sheet.InvoiceAction.sharePdf, invoice),
      ),
      (
        'invoice-more-einvoice',
        l.invoicePageMoreEInvoice,
        () => _run(context, ref, sheet.InvoiceAction.eInvoice, invoice),
      ),
      if (outstanding) ...[
        ('invoice-more-reminders', l.invoicePageMoreReminders, null),
        (
          'invoice-more-hold',
          r!.onHold ? l.invoicePageMoreRelease : l.invoicePageMoreHold,
          () => _run(context, ref, sheet.InvoiceAction.dunningHold, invoice),
        ),
      ],
      if (open || partly) ...[
        ('invoice-more-corrections', l.invoicePageMoreCorrections, null),
        if (open) ...[
          (
            'invoice-more-replace',
            l.invoicePageMoreReplace,
            () => _run(context, ref, sheet.InvoiceAction.replace, invoice),
          ),
          (
            'invoice-more-cancel',
            l.invoicePageMoreCancel,
            () =>
                _run(context, ref, sheet.InvoiceAction.markErroneous, invoice),
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
