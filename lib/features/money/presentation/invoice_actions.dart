// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/money_format.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/app_snack.dart';
import '../../events/providers/event_providers.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/invoice_action.dart';
import '../application/issue_invoice.dart';
import '../domain/invoice.dart';
import '../providers/money_providers.dart';
import 'dunning_hold_actions.dart';
import 'invoice_einvoice_actions.dart';
import 'invoice_followup_actions.dart';
import 'invoice_pdf_actions.dart';
import 'period_label.dart';
import 'widgets/command_unknown_dialog.dart';
import 'widgets/invoice_detail_sheet.dart';
import 'widgets/invoice_form_sheet.dart';
import 'widgets/invoice_receipt_action_runner.dart';

export '../../workspace/providers/workspace_tax_reference.dart';

export 'invoice_einvoice_actions.dart';
export 'invoice_followup_actions.dart';
export 'invoice_pdf_actions.dart';

/// Everything an issued invoice can be PUT THROUGH, extracted out of the
/// screen (0069): the archive rows, the open cards and the detail sheet all
/// drive the same code, so an action cannot behave differently depending on
/// where it was tapped.

/// #508 — records the REFUND the workspace paid on a NEGATIVE invoice
/// (a credit note / avoir): books the payout charge and closes the
/// document — through the invoice_payment validation policy when one
/// is configured.
Future<void> settleCreditInvoiceDialog(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final l10n = context.l10n;
  final currency = moneyFormat(invoice.currency);
  final noteController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(scrollable: true,
      title: Text(l10n.invoiceRefundButton),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.invoiceRefundExplain(
                  currency.formatMinor(-invoice.totalCents),
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('invoice-refund-note'),
            controller: noteController,
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
          key: const ValueKey('invoice-actions-cancel'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('invoice-refund-submit'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.invoiceRefundButton),
        ),
      ],
    ),
  );
  final note = noteController.text;
  if (confirmed != true || !context.mounted) return;
  if (!await runInvoiceReceiptAction(
    context,
    ref.read(invoiceReceiptActionsProvider),
    InvoiceActionAttempt(
      workspaceId: invoice.workspaceId,
      invoiceId: invoice.id,
      kind: InvoiceActionKind.refundCreditNote,
      requestId: newRequestId(),
      note: note,
    ),
    successText: l10n.invoiceRefunded,
    failureText: l10n.workspaceGenericError,
  )) {
    return;
  }
  ref
    ..invalidate(invoiceMatchesProvider)
    ..invalidate(myAccountProvider)
    ..invalidate(invoicesProvider);
  invalidateBookingData(ref);
}

/// The current workspace when it issues in sales-tax mode (#2362): the
/// feature is on and its seller country's gate row says so; else null.
///
/// #2561 L4 -- the gate row is read from the tax reference the selected
/// workspace's context captured from its own installation; while none is
/// ready the answer is null, never another workspace's data.
({String id, String currency})? salesTaxWorkspace(WidgetRef ref) {
  final workspace = ref.watch(currentWorkspaceProvider).value;
  final captured = ref.watch(readyWorkspaceContextProvider);
  if (workspace == null ||
      captured == null ||
      captured.target.workspaceId != workspace.id ||
      !ref
          .watch(enabledFeaturesSyncProvider)
          .contains(WorkspaceFeature.salesTax) ||
      !(captured.taxReference.set
              .gateOf(workspace.countryCode)
              ?.salesTaxMode ??
          false)) {
    return null;
  }
  return (id: workspace.id, currency: workspace.currencyCode);
}

bool salesTaxModeOn(WidgetRef ref) => salesTaxWorkspace(ref) != null;

/// Runs what the detail sheet decided on, with the SCREEN's context — the
/// sheet is already gone by then.
Future<void> runInvoiceAction(
  BuildContext context,
  WidgetRef ref,
  InvoiceAction action,
  Invoice invoice, {
  required String countryCode,
}) {
  // #831 — a regrouped source is documentation: reading and the
  // stamped PDF stay, every operation happens on the settlement.
  if (invoice.isFolded &&
      action != InvoiceAction.quickView &&
      action != InvoiceAction.downloadPdf &&
      action != InvoiceAction.sharePdf) {
    final l10n = context.l10n;
    AppSnack.info(
      context,
      l10n.settlementDocumentationOnly,
      replace: true,
    );
    return Future.value();
  }
  return switch (action) {
    InvoiceAction.quickView => quickViewInvoice(context, ref, invoice),
    InvoiceAction.downloadPdf => downloadInvoicePdf(context, ref, invoice),
    InvoiceAction.sharePdf => shareInvoicePdf(context, ref, invoice),
    InvoiceAction.eInvoice => exportEInvoice(
      context,
      ref,
      invoice,
      countryCode: countryCode,
    ),
    InvoiceAction.remind => remindInvoice(context, ref, invoice),
    InvoiceAction.dunningHold => toggleDunningHold(context, ref, invoice),
    InvoiceAction.markPaid => matchInvoiceToPayment(context, ref, invoice),
    InvoiceAction.markErroneous => voidInvoiceWithConfirm(
      context,
      ref,
      invoice,
    ),
    InvoiceAction.replace => showInvoiceIssueSheet(
      context,
      ref,
      replaces: invoice,
    ),
  };
}

/// One tap invoices every listed member for [period] — behind a confirm
/// naming what is about to become N immutable documents. Per-member
/// guarded, so one failing statement neither stops the sweep nor hides
/// itself: the snack reports what did NOT go through.
Future<void> issueInvoicesForAll(
  BuildContext context,
  WidgetRef ref,
  List<ToInvoiceEntry> entries,
  String period,
  MoneyFormat currency,
) async {
  final l10n = context.l10n;
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (workspace == null || entries.isEmpty) return;
  final total = entries.fold(0, (sum, e) => sum + e.totalCents);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.invoiceIssueAll),
      content: Text(
        l10n.invoiceIssueAllConfirm(
              entries.length,
              monthLabel(context, period),
              currency.formatMinor(total),
            ),
      ),
      actions: [
        TextButton(
          key: ValueKey('invoice-actions-cancel-4-$period'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('invoice-issue-all-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.invoiceIssueAll),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  // #2585 C2 — each entry is sent ONCE under its own request id. An entry
  // whose answer was lost is looked up by that id afterwards, never sent
  // again, so it can neither double nor be reported as a plain failure.
  final issuance = InvoiceIssuance(
    ref.read(invoiceCommandsProvider),
    ref.read(invoiceQueriesProvider),
    ref.read(invoiceActionCommandsProvider),
  );
  var issued = 0;
  final lost = <InvoiceIssueUnknown>[];
  for (final entry in entries) {
    final outcome = await issuance.issue(
      InvoiceIssueAttempt(
        workspaceId: workspace.id,
        memberId: entry.memberId,
        period: period,
        requestId: newRequestId(),
        direct: true,
      ),
    );
    switch (outcome) {
      case InvoiceIssued():
        issued++;
      case InvoiceIssueUnknown():
        lost.add(outcome);
      case InvoiceIssueHeld() || InvoiceIssueRefused():
        break;
    }
  }
  for (var unknown in lost) {
    if (!context.mounted) break;
    final resolved = await showCommandUnknownDialog<InvoiceIssueOutcome>(
      context,
      body: l10n.invoiceIssueUnknownBody,
      check: () async {
        final looked = await issuance.look(unknown);
        if (looked is InvoiceIssueUnknown) {
          unknown = looked;
          return null;
        }
        return looked;
      },
    );
    if (resolved is InvoiceIssued) issued++;
  }
  ref.invalidate(invoicesProvider);
  if (!context.mounted) return;
  final failed = entries.length - issued;
  if (failed > 0) {
    AppSnack.error(
      context,
      l10n.invoiceIssuedPartial(issued, failed),
    );
    return;
  }
  AppSnack.success(
    context,
    l10n.invoiceIssuedCount(issued),
  );
}
