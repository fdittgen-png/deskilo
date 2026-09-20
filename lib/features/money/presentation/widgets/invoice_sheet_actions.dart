// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/invoice.dart';
import '../invoice_status.dart';
import 'invoice_detail_sheet.dart';

/// The invoice sheet's action list (#1217).
///
/// Extracted from the sheet itself: it is the longest thing in that
/// file and the half that grows every time an invoice learns a new
/// verb, while the sheet around it is a header, some rows and a total.
class InvoiceSheetActions {
  const InvoiceSheetActions({
    required this.invoice,
    required this.canIssue,
    required this.isEu,
    required this.replacedByNumber,
    required this.onAction,
  });

  final Invoice invoice;
  final bool canIssue;
  final bool isEu;

  /// The credit note that superseded this invoice, when one did.
  final String replacedByNumber;

  /// What a button does: hand the chosen action back to the sheet,
  /// which pops with it.
  final ValueChanged<InvoiceAction> onAction;

/// #831 — a regrouped source keeps reading and the stamped PDF only.
bool allowed(InvoiceAction action) =>
    !invoice.isFolded ||
    action == InvoiceAction.quickView ||
    action == InvoiceAction.downloadPdf ||
    action == InvoiceAction.sharePdf;

/// The permitted actions in their historical order, each tagged so
/// the build can pull the expected one to the front.
List<(InvoiceAction, Widget)> build(
  BuildContext context,
  AppLocalizations? l10n,
  InvoiceLifecycle status,
  InvoiceAction expected,
) =>
    [
      // #514 — see it on screen before any PDF exists.
      (
        InvoiceAction.quickView,
        _button(
          context,
          key: 'invoice-quick-${invoice.id}',
          icon: Icons.bolt_outlined,
          label: l10n?.reportQuickView ?? 'Quick view',
          action: InvoiceAction.quickView,
        ),
      ),
      (
        InvoiceAction.downloadPdf,
        _button(
          context,
          key: 'invoice-download-${invoice.id}',
          icon: Icons.download_outlined,
          label: l10n?.invoiceDownload ?? 'Download PDF',
          action: InvoiceAction.downloadPdf,
          primary: expected == InvoiceAction.downloadPdf,
        ),
      ),
      (
        InvoiceAction.sharePdf,
        _button(
          context,
          key: 'invoice-share-${invoice.id}',
          icon: Icons.share_outlined,
          label: l10n?.invoiceShare ?? 'Share PDF',
          action: InvoiceAction.sharePdf,
        ),
      ),
      // 2014/55/EU: the e-invoice affordance is for EU workspaces.
      if (isEu)
        (
          InvoiceAction.eInvoice,
          _button(
            context,
            key: 'invoice-einvoice-action',
            icon: Icons.code_outlined,
            label: l10n?.invoiceEInvoiceAction ?? 'E-invoice (XML)',
            action: InvoiceAction.eInvoice,
          ),
        ),
      if (canIssue && status == InvoiceLifecycle.open) ...[
        if (invoice.totalCents > 0)
          (
            InvoiceAction.remind,
            _button(
              context,
              key: 'invoice-remind-action',
              icon: Icons.notifications_outlined,
              label: l10n?.invoiceRemindAction ?? 'Send a reminder',
              action: InvoiceAction.remind,
              primary: expected == InvoiceAction.remind,
            ),
          ),
        (
          InvoiceAction.markPaid,
          _button(
            context,
            key: 'invoice-match-action',
            icon: Icons.price_check_outlined,
            label: l10n?.invoiceMatchAction ?? 'Mark as paid',
            action: InvoiceAction.markPaid,
            primary: expected == InvoiceAction.markPaid,
          ),
        ),
        (
          InvoiceAction.markErroneous,
          _button(
            context,
            key: 'invoice-void-action',
            icon: Icons.block_outlined,
            label: l10n?.invoiceVoidAction ?? 'Mark erroneous',
            action: InvoiceAction.markErroneous,
            danger: true,
          ),
        ),
      ],
      // A correction chain, never a fork (0061): only an erroneous
      // invoice that nothing replaces yet can be re-issued.
      if (canIssue &&
          status == InvoiceLifecycle.erroneous &&
          replacedByNumber.isEmpty)
        (
          InvoiceAction.replace,
          _button(
            context,
            key: 'invoice-replace-action',
            icon: Icons.published_with_changes_outlined,
            label: l10n?.invoiceReplaceAction ?? 'Issue replacement',
            action: InvoiceAction.replace,
            primary: expected == InvoiceAction.replace,
          ),
        ),
    ];

Widget _button(
  BuildContext context, {
  required String key,
  required IconData icon,
  required String label,
  required InvoiceAction action,
  bool primary = false,
  bool danger = false,
}) {
  final colors = Theme.of(context).colorScheme;
  final child = Row(children: [
    Icon(icon, size: 20, color: danger ? colors.error : null),
    const SizedBox(width: AppSpacing.md),
    Expanded(
      child: Text(
        label,
        style: danger ? TextStyle(color: colors.error) : null,
      ),
    ),
  ]);
  void onPressed() => onAction(action);
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: primary
        ? FilledButton(
            key: ValueKey(key),
            onPressed: onPressed,
            child: child,
          )
        : OutlinedButton(
            key: ValueKey(key),
            onPressed: onPressed,
            child: child,
          ),
  );
}
}
