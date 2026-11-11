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

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/kit/bottom_action_bar.dart';
import '../../../../core/ui/kit/kit_card.dart';
import '../../../../core/ui/kit/story.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/confirmed_payment.dart';
import '../../application/receivables.dart';
import '../../domain/dunning.dart';
import '../../providers/money_providers.dart';
import '../invoice_actions.dart';
import '../widgets/invoice_detail_sheet.dart' as sheet show InvoiceAction;
import '../widgets/invoice_journey_view.dart';
import 'invoice_page_parts.dart';
import 'invoicing_reads.dart';

/// Opens [invoiceId]'s page over the current one (a phone, a narrow
/// window), full screen.
Future<void> openInvoicePage(BuildContext context, String invoiceId) =>
    showDialog<void>(
      context: context,
      // Its own messenger: what an action says is said once, on the page,
      // not also on the home under it.
      builder: (_) => Dialog.fullscreen(
        child: ScaffoldMessenger(child: InvoicePage(invoiceId: invoiceId)),
      ),
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
    final today = ref
        .watch(invoicingBusinessProvider)
        .dayOf(ref.watch(clockProvider).now());
    final rules =
        ref.watch(dunningRulesProvider).value ?? DunningRules.defaults;
    final mode = rules.automatic ? ReminderMode.automatic : ReminderMode.byHand;
    return Scaffold(
      key: ValueKey('invoice-page-$invoiceId'),
      appBar: AppBar(
        automaticallyImplyLeading: onClose == null,
        title: Text(l.invoicePageTitle(invoice.number)),
        actions: [
          InvoiceMoreMenu(invoice: invoice, receivable: r),
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
            InvoiceSummaryCard(invoice: invoice, receivable: r, today: today),
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
          InvoiceLinesCard(invoice: invoice),
          const SizedBox(height: AppSpacing.md),
          InvoicePdfCard(invoice: invoice),
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
    final business = ref.read(invoicingBusinessProvider);
    var outcome = ConfirmOutcome.confirmedOnly;
    final done = await runGuarded(
      context,
      domain: 'money',
      message: 'match after confirmation failed',
      errorText: context.l10n.invoicePageMatchRefused,
      action: () async {
        final ledger = await ref
            .read(memberAccountQueriesProvider)
            .fetchLedger(invoice.memberId);
        final consumed = {
          for (final m in matches.values) ?m.paymentLedgerId,
          ...await ref
              .read(invoiceQueriesProvider)
              .fetchConsumedPaymentIds(business.id),
        };
        final payment = confirmedPaymentFor(
          ledger,
          customerId: invoice.memberId,
          amountCents: amount,
          invoiceCurrency: invoice.currency,
          accountCurrency: business.currency,
          consumed: consumed,
        );
        if (payment == null) return;
        await ref
            .read(invoiceCommandsProvider)
            .matchInvoice(
              invoiceId: invoice.id,
              paymentLedgerId: payment,
              resolution: 'exact',
            );
        outcome = ConfirmOutcome.matched;
      },
    );
    ref
      ..invalidate(invoiceMatchesProvider)
      ..invalidate(invoicesProvider);
    if (!done || outcome == ConfirmOutcome.confirmedOnly) {
      return ConfirmOutcome.confirmedOnly;
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
        () => InvoicePageActions.run(
          context,
          ref,
          sheet.InvoiceAction.eInvoice,
          invoice,
        ),
      ),
      _ => null,
    };
    return button == null ? null : BottomActionBar(actions: [button]);
  }
}
