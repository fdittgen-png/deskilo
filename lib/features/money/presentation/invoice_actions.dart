// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/files/file_names.dart';
import '../../../core/files/file_saver.dart';
import '../../../core/i18n/money_format.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/share/file_sharer.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/time/clock.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_snack.dart';
import '../../../core/vat/tax_reference_active.dart';
import '../../events/providers/event_providers.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/invoice_action.dart';
import '../application/issue_invoice.dart';
import '../application/send_reminder.dart';
import '../domain/channel_einvoice_xml.dart';
import '../domain/dunning.dart';
import '../domain/e_invoice_routing.dart';
import '../domain/einvoice_channel_check.dart';
import '../domain/einvoice_format.dart';
import '../domain/einvoice_gateway.dart';
import '../domain/einvoice_input.dart';
import '../domain/einvoice_mandates.dart';
import '../domain/einvoice_validation.dart';
import '../domain/invoice.dart';
import '../domain/invoice_line_text.dart';
import '../domain/invoice_pdf_template.dart';
import '../domain/invoice_report.dart';
import '../domain/invoice_ubl.dart';
import '../domain/invoice_ubl_check.dart';
import '../domain/ledger_entry.dart';
import '../domain/report_data.dart';
import '../providers/money_providers.dart';
import 'dunning_hold_actions.dart';
import 'e_invoice_identity.dart';
import 'invoice_documents.dart';
import 'invoice_journey.dart' show invoiceRemainingCents;
import 'period_label.dart';
import 'report_defaults.dart';
import 'report_layout_actions.dart';
import 'report_strings_l10n.dart';
import 'widgets/command_unknown_dialog.dart';
import 'widgets/e_invoice_sheet.dart';
import 'widgets/einvoice_environment_picker.dart';
import 'widgets/invoice_detail_sheet.dart';
import 'widgets/invoice_form_sheet.dart';
import 'widgets/invoice_receipt_action_runner.dart';
import 'widgets/invoicing_dashboard.dart';
import 'widgets/report_preview.dart';

part 'invoice_actions_part1.dart';
part 'invoice_actions_part2.dart';
part 'invoice_actions_part3.dart';


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
({String id, String currency})? salesTaxWorkspace(WidgetRef ref) {
  final workspace = ref.watch(currentWorkspaceProvider).value;
  if (workspace == null ||
      !ref
          .watch(enabledFeaturesSyncProvider)
          .contains(WorkspaceFeature.salesTax) ||
      !ActiveTaxReference.isInstalled ||
      !(ActiveTaxReference.current.gateOf(workspace.countryCode)?.salesTaxMode ??
          false)) {
    return null;
  }
  return (id: workspace.id, currency: workspace.currencyCode);
}

bool salesTaxModeOn(WidgetRef ref) => salesTaxWorkspace(ref) != null;
