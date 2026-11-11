// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-d -- the invoice page's bottom bar: the one main action under
// the thumb (Share reminder n, Confirm / Not received, Match the payment,
// Record the refund, the e-invoice to fix). While one action runs, every
// action of the bar waits: a second tap never sends a second call.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/kit/bottom_action_bar.dart';
import '../../../../core/ui/kit/kit_action_button.dart';
import '../../application/confirmed_payment.dart';
import '../../application/receivables.dart';
import '../../providers/money_providers.dart';
import '../invoice_actions.dart';
import '../widgets/invoice_detail_sheet.dart' as sheet show InvoiceAction;
import '../widgets/invoice_journey_view.dart';
import 'invoice_page_parts.dart';

class InvoicePageBar extends ConsumerStatefulWidget {
  const InvoicePageBar({
    super.key,
    required this.invoice,
    required this.receivable,
    required this.today,
    required this.mode,
  });

  final Invoice invoice;
  final Receivable receivable;

  /// The business's calendar day.
  final DateTime today;
  final ReminderMode mode;

  @override
  ConsumerState<InvoicePageBar> createState() => _InvoicePageBarState();
}

class _InvoicePageBarState extends ConsumerState<InvoicePageBar> {
  /// True while an action of the bar runs: every action waits for it.
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Confirm or Not received on the customer's declared payment. A yes
  /// that leaves the payment waiting for other approvers says so and
  /// matches nothing; only an approved payment is matched.
  Future<void> _decide(
    Invoice invoice,
    Receivable r, {
    required bool accept,
  }) async {
    final l = context.l10n;
    final decision = ref.read(declaredPaymentDecisionProvider);
    var decided = DeclaredPaymentDecided.ended;
    final done = await runGuarded(
      context,
      domain: 'money',
      message: 'declared payment decision failed',
      errorText: l.invoicePageDecisionRefused,
      action: () async {
        decided = await decision(ref, r.declaredEventId!, accept: accept);
      },
    );
    if (!done || !mounted) return;
    if (!accept) {
      AppSnack.info(
        context,
        decided == DeclaredPaymentDecided.waitsForOthers
            ? l.invoicePageDecisionRecorded
            : l.invoicePageMarkedNotReceived,
      );
      return;
    }
    switch (decided) {
      case DeclaredPaymentDecided.waitsForOthers:
        AppSnack.info(context, l.invoicePageApprovalRecorded);
        return;
      case DeclaredPaymentDecided.ended:
        AppSnack.info(context, l.invoicePageConfirmed);
        return;
      case DeclaredPaymentDecided.approved:
        break;
    }
    // Approved: when it pays the open amount exactly, it settles this
    // invoice in the same gesture; otherwise the bar now offers "Match the
    // payment" and the person chooses.
    final outcome = await _matchConfirmed(invoice, r);
    if (!mounted) return;
    switch (outcome) {
      case ConfirmOutcome.matched:
        AppSnack.success(context, l.invoicePageConfirmedMatched);
      case ConfirmOutcome.awaitsApproval:
        AppSnack.info(context, l.invoicePageConfirmedAwaitsApproval);
      case ConfirmOutcome.confirmedOnly:
        AppSnack.info(context, l.invoicePageConfirmed);
    }
  }

  /// After a confirmation, matches the confirmed payment to [invoice] when
  /// it pays the open amount exactly: what came of it, read back from the
  /// server. A refusal is said in the server's words and the bar keeps
  /// "Match the payment".
  Future<ConfirmOutcome> _matchConfirmed(Invoice invoice, Receivable r) async {
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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final invoice = widget.invoice;
    final r = widget.receivable;
    // While an action runs, every action of the bar is off.
    VoidCallback? guard(Future<void> Function() action) =>
        _busy ? null : () => _run(action);
    // The kit button holds itself busy while its action runs (#3679); the
    // bar's own flag keeps the OTHER actions off meanwhile.
    Widget filled(String key, String label, Future<void> Function() action) =>
        KitActionButton(
          key: ValueKey(key),
          label: label,
          showProgress: false,
          onPressed: _busy ? null : () => _run(action),
        );
    if (r.paymentDeclared && r.declaredEventId != null) {
      return BottomActionBar(
        actions: [
          OutlinedButton(
            key: const ValueKey('invoice-page-not-received'),
            onPressed: guard(() => _decide(invoice, r, accept: false)),
            child: Text(l.invoicePageNotReceived, textAlign: TextAlign.center),
          ),
          filled(
            'invoice-page-confirm',
            l.invoicePageConfirm,
            () => _decide(invoice, r, accept: true),
          ),
        ],
      );
    }
    final button = switch (actionOf(r, widget.today, widget.mode)) {
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
    return button == null
        ? const SizedBox.shrink()
        : BottomActionBar(actions: [button]);
  }
}
