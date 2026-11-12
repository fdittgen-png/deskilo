// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — the follow-up actions of an issued invoice: write-off request, void,
// reminder and matching a payment. Split out of invoice_actions.dart (was
// invoice_actions_part1/2); same behaviour.
import 'dart:async';
import 'dart:typed_data';

import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/format_controller.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/share/file_sharer.dart';
import '../../../core/state/policy_read.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_snack.dart';
import '../../events/providers/event_providers.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/credit_move_commands.dart';
import '../application/invoice_action.dart';
import '../application/payment_candidates.dart';
import '../application/send_reminder.dart';
import '../application/unassigned_money.dart';
import '../domain/dunning.dart';
import '../providers/credit_move_providers.dart';
import '../providers/money_providers.dart';
import 'invoice_actions.dart' show requireWorkspaceTaxReference;
import 'invoice_documents.dart';
import 'invoice_journey.dart' show invoiceRemainingCents;
import 'reminder_email_actions.dart';
import 'widgets/invoice_receipt_action_runner.dart';
import 'widgets/invoicing_dashboard.dart';

/// #504 — asks the validators to CANCEL the outstanding remainder of a
/// partially paid invoice. Explains that this is a request, takes an
/// optional reason, files the pending 'invoice_writeoff' event.
Future<void> requestInvoiceWriteoffDialog(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final l10n = context.l10n;
  final reasonController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(scrollable: true,
      title: Text(l10n.invoiceWriteoffButton),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.invoiceWriteoffExplain,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('invoice-writeoff-reason'),
            controller: reasonController,
            maxLength: 300,
            maxLines: 2,
            decoration: InputDecoration(
              labelText:
                  l10n.reservationDeleteReasonLabel,
              counterText: '',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('invoice-actions-cancel-2'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('invoice-writeoff-submit'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.reservationDeleteSubmit),
        ),
      ],
    ),
  );
  final reason = reasonController.text;
  if (confirmed != true || !context.mounted) return;
  if (!await runGuarded(
    context,
    domain: 'money',
    message: 'invoice writeoff request failed',
    errorText:
        l10n.workspaceGenericError,
    action: () => ref
        .read(eventRepositoryProvider)
        .requestInvoiceWriteoff(invoice.id, reason: reason),
  )) {
    return;
  }
  ref.invalidate(eventsProvider);
  invalidateBookingData(ref);
  if (!context.mounted) return;
  AppSnack.success(
    context,
    l10n.invoiceWriteoffRequested,
  );
}


/// Tags [invoice] erroneous (0061) after an explicit confirm — the stamp is
/// one-way, so the dialog says so.
Future<void> voidInvoiceWithConfirm(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.invoiceVoidAction),
      content: Text(
        l10n.invoiceVoidConfirm(invoice.number),
      ),
      actions: [
        TextButton(
          key: const ValueKey('invoice-actions-cancel-3'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('invoice-void-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.invoiceVoidAction),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  if (!await runInvoiceReceiptAction(
    context,
    ref.read(invoiceReceiptActionsProvider),
    InvoiceActionAttempt(
      workspaceId: invoice.workspaceId,
      invoiceId: invoice.id,
      kind: InvoiceActionKind.voidInvoice,
      requestId: newRequestId(),
    ),
    successText: l10n.invoiceVoided,
    failureText: l10n.workspaceGenericError,
  )) {
    return;
  }
  ref.invalidate(invoicesProvider);
}


Future<void> remindInvoice(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final l10n = context.l10n;
  final currency = appFormatOf(context).moneyIn(invoice.currency);
  // #1913 — the message states what is still owed, never the total of a
  // half-paid invoice; the server records the same remainder.
  final owed = invoiceRemainingCents(
    invoice,
    ref.read(invoiceMatchesProvider).value?[invoice.id],
  );
  final message =
      l10n.invoiceReminderMessage(
        invoice.number,
        currency.formatMinor(owed),
      );
  // #472: the level of THIS send — one past what was already sent,
  // capped at the configured maximum (extra sends reuse the last
  // letter).
  // #3742 — the level comes from the business's own rules, read now; when
  // they cannot be read, nothing is sent and the reader is told.
  final DunningRules rules;
  try {
    // #3742 — a remembered failure is asked again: the next tap can send.
    await readPolicy(ref, invoicePdfTemplateProvider, invoicePdfTemplateProvider.future);
    rules = await readPolicy(ref, dunningRulesProvider, dunningRulesProvider.future);
  } on Object catch (e, st) {
    TraceLogger.instance.error('money', 'reminder rules read failed',
        error: e, stackTrace: st);
    if (context.mounted) {
      AppSnack.error(context, context.l10n.readStateFailed);
    }
    return;
  }
  if (!context.mounted) return;
  final sent =
      ref.read(invoiceRemindersProvider).value?[invoice.id]?.count ?? 0;
  final level = (sent + 1).clamp(1, rules.levels);
  // #3673 — by e-mail or shared: asked only while reminders by e-mail are on.
  final flow = ReminderEmailFlow(context, ref);
  final channel = await flow.choose(invoice);
  if (channel == null || !context.mounted) return;
  if (channel == ReminderChannel.email) {
    return flow.build(
      invoice,
      level: level,
      owedCents: owed,
      letter: () => buildReminderPdfFile(
        context,
        ref,
        invoice,
        level: level,
        reference: requireWorkspaceTaxReference(ref),
      ),
    );
  }
  SendReminderOutcome? outcome;
  if (!await runGuarded(
    context,
    domain: 'money',
    message: 'invoice reminder failed',
    errorText:
        l10n.workspaceGenericError,
    action: () async {
      // PDF first — it captures its context-derived values before any
      // await (use_build_context_synchronously).
      final pdf = await buildReminderPdfFile(
        context,
        ref,
        invoice,
        level: level,
        reference: requireWorkspaceTaxReference(ref),
      );
      // The ORDER is the decision, so it lives in the command (#1532):
      // the letter goes out, and the level is recorded only if it did.
      outcome = await sendReminder(
        repository: ref.read(invoiceCommandsProvider),
        share: ref.read(fileSharerProvider),
        invoiceId: invoice.id,
        level: level,
        bytes: Uint8List.fromList(pdf.bytes),
        fileName: pdf.fileName,
        message: message,
      );
    },
  )) {
    return;
  }
  // Nothing left the device and nothing was recorded. "Reminder
  // recorded." would be false, and an error would be false too.
  if (outcome is ReminderNotSent) {
    if (!context.mounted) return;
    AppSnack.info(
        context,
        l10n.invoiceReminderNotSent);
    return;
  }
  ref.invalidate(invoiceRemindersProvider);
  if (!context.mounted) return;
  AppSnack.success(context, l10n.invoiceReminded);
}


/// Matches an open invoice to its payment (0067) — the only way an invoice
/// closes and archives. Over/under payments resolve in the dialog; the
/// server re-validates and files the invoice_payment event (pending when a
/// validation rule exists). [paymentId] opens the dialog on that payment
/// (Payments to match passes the one of the card that was tapped).
Future<void> matchInvoiceToPayment(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice, {
  String? paymentId,
}) async {
  final l10n = context.l10n;
  final currency = appFormatOf(context).moneyIn(invoice.currency);
  // 0068 — the candidates: the member's registered payments (incl. settled
  // online payments) not yet consumed by another match.
  final invoiceQueries = ref.read(invoiceQueriesProvider);
  final ledger = await ref
      .read(memberAccountQueriesProvider)
      .fetchLedger(invoice.memberId);
  final matches = await ref.read(invoiceMatchesProvider.future);
  // #506/#3671 — the junction knows what EVERY match used of each payment.
  // #3349 — a credit moved to another member is no longer this member's
  // money: neither the original nor its reversal is offered. The one
  // definition of what is left (`paymentUseOf`).
  final workspace = ref.read(currentWorkspaceProvider).value;
  final use = workspace == null
      ? PaymentUse.none
      : await readPaymentUse(
          invoices: invoiceQueries,
          moves: ref.read(creditMoveCommandsProvider),
          workspaceId: workspace.id,
        );
  // A standing PARTIAL match shifts the target: further payments are
  // measured against what is STILL DUE.
  final existing = matches[invoice.id];
  final dueCents =
      existing != null &&
          !existing.pending &&
          existing.resolution == 'under_accepted' &&
          existing.writeoffAt == null
      ? invoice.totalCents - existing.paidCents
      : invoice.totalCents;
  // #512 — a credit BAKED into an issued invoice was spent there, and
  // account credits (avoir excess) settle too; newest payment first by the
  // day the money moved (0070): `unmatchedPaymentsOf`, as Payments to match.
  final memberInvoices = await ref.read(invoicesProvider.future);
  final payments = unmatchedPaymentsOf(
    memberId: invoice.memberId,
    ledger: ledger,
    use: use,
    invoices: memberInvoices,
  );
  if (!context.mounted) return;
  final choice = await showDialog<MatchChoice>(
    context: context,
    builder: (context) => MatchInvoiceDialog(
      dueCents: dueCents,
      currency: currency,
      payments: payments,
      selected: paymentId,
    ),
  );
  if (choice == null || !context.mounted) return;
  var movedMeanwhile = false;
  if (!await runGuarded(
    context,
    domain: 'money',
    message: 'invoice match failed',
    errorText:
        l10n.workspaceGenericError,
    action: () async {
      try {
        await ref
            .read(invoiceCommandsProvider)
            .matchInvoice(
              invoiceId: invoice.id,
              paymentLedgerId: choice.paymentLedgerId,
              resolution: choice.resolution,
              note: choice.note,
            );
      } catch (e, st) {
        // #3349 — a stale screen: the credit was moved after the list was
        // read. Said in its own words, not as a generic failure.
        if (!CreditMoveCommands.refusedAsMoved(e)) {
          // trace-exempt: rethrown for the caller's runGuarded to trace.
          Error.throwWithStackTrace(e, st);
        }
        movedMeanwhile = true;
      }
    },
  )) {
    return;
  }
  if (movedMeanwhile) {
    if (context.mounted) AppSnack.error(context, l10n.invoiceMatchCreditMoved);
    return;
  }
  ref
    ..invalidate(invoiceMatchesProvider)
    ..invalidate(myAccountProvider)
    ..invalidate(invoicesProvider);
  invalidateBookingData(ref);
  if (!context.mounted) return;
  AppSnack.success(context, l10n.invoiceMatched);
}
