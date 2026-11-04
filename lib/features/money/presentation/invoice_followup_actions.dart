// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — the follow-up actions of an issued invoice: write-off request, void,
// reminder and matching a payment. Split out of invoice_actions.dart (was
// invoice_actions_part1/2); same behaviour.
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/money_format.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/share/file_sharer.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../../events/providers/event_providers.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/invoice_action.dart';
import '../application/send_reminder.dart';
import '../domain/dunning.dart';
import '../domain/invoice.dart';
import '../domain/ledger_entry.dart';
import '../providers/money_providers.dart';
import 'invoice_documents.dart';
import 'invoice_journey.dart' show invoiceRemainingCents;
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
  final currency = moneyFormat(invoice.currency);
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
  final rules = ref.read(dunningRulesProvider).value ?? DunningRules.defaults;
  final sent =
      ref.read(invoiceRemindersProvider).value?[invoice.id]?.count ?? 0;
  final level = (sent + 1).clamp(1, rules.levels);
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
/// validation rule exists).
Future<void> matchInvoiceToPayment(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final l10n = context.l10n;
  final currency = moneyFormat(invoice.currency);
  // 0068 — the candidates: the member's registered payments (incl. settled
  // online payments) not yet consumed by another match.
  final invoiceQueries = ref.read(invoiceQueriesProvider);
  final ledger = await ref
      .read(memberAccountQueriesProvider)
      .fetchLedger(invoice.memberId);
  final matches = ref.read(invoiceMatchesProvider).value ?? const {};
  // #506 — the junction knows EVERY consumed payment (an aggregate
  // match only remembers its last one).
  final workspace = ref.read(currentWorkspaceProvider).value;
  final consumed = {
    for (final match in matches.values) ?match.paymentLedgerId,
    if (workspace != null) ...await invoiceQueries.fetchConsumedPaymentIds(workspace.id),
  };
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
  // #512 — a credit BAKED into an issued invoice (negative line at
  // derivation) was spent there; the server refuses it too.
  final memberInvoices = ref.read(invoicesProvider).value ?? const <Invoice>[];
  bool baked(LedgerEntry entry) => memberInvoices.any(
    (i) =>
        i.memberId == invoice.memberId &&
        !i.isVoided &&
        i.period == entry.period &&
        i.issuedAt.isAfter(entry.createdAt),
  );
  final payments = [
    for (final entry in ledger)
      if (entry.kind == LedgerKind.credit &&
          // #512 — account credits (avoir excess) settle too: the
          // imputation of a credit note on any outstanding invoice.
          (entry.category == LedgerCategory.payment ||
              entry.category == LedgerCategory.adjustment) &&
          !consumed.contains(entry.id) &&
          !baked(entry))
        entry,
    // Newest PAYMENT first — by the day the money moved (0070), not by
    // the day it happened to be typed in.
  ]..sort((a, b) => b.on.compareTo(a.on));
  if (!context.mounted) return;
  final choice = await showDialog<MatchChoice>(
    context: context,
    builder: (context) => MatchInvoiceDialog(
      dueCents: dueCents,
      currency: currency,
      payments: payments,
    ),
  );
  if (choice == null || !context.mounted) return;
  if (!await runGuarded(
    context,
    domain: 'money',
    message: 'invoice match failed',
    errorText:
        l10n.workspaceGenericError,
    action: () => ref
        .read(invoiceCommandsProvider)
        .matchInvoice(
          invoiceId: invoice.id,
          paymentLedgerId: choice.paymentLedgerId,
          resolution: choice.resolution,
          note: choice.note,
        ),
  )) {
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
