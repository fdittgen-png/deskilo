// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/issue_invoice.dart';
import 'invoice_unknown_outcome_dialog.dart';

/// Sends [attempt] once and tells the person what is true: issued, held for
/// validation, refused in the server's words, or UNKNOWN — in which case the
/// dialog offers only to look for the invoice, never to send it again.
/// Returns whether the invoice is known to exist (the caller refreshes).
Future<bool> runInvoiceIssue(
  BuildContext context,
  InvoiceIssuance issuance,
  InvoiceIssueAttempt attempt,
) async {
  final l10n = context.l10n;
  var outcome = await issuance.issue(attempt);
  if (outcome is InvoiceIssueUnknown) {
    if (!context.mounted) return false;
    final found = await showInvoiceUnknownOutcomeDialog(
      context,
      issuance: issuance,
      unknown: outcome,
    );
    if (found == null) return false;
    outcome = found;
  }
  if (!context.mounted) return false;
  switch (outcome) {
    case InvoiceIssued():
      AppSnack.success(context, l10n.invoiceIssued);
      return true;
    case InvoiceIssueHeld():
      AppSnack.info(context, l10n.validationSentForApproval);
    case InvoiceIssueRefused(:final error):
      TraceLogger.instance.error('money', 'invoice issue refused', error: error);
      AppSnack.error(context, _refusalText(l10n, error.toString()));
    case InvoiceIssueUnknown():
      break;
  }
  return false;
}

// 0067 — one active invoice per member+month (pinned substring).
String _refusalText(AppLocalizations l10n, String text) {
  if (text.contains('already invoiced')) return l10n.invoiceAlreadyInvoiced;
  if (text.contains('invoice_feature_disabled')) {
    return l10n.invoiceFeatureDisabled;
  }
  if (text.contains('invoice_essentials_missing')) {
    return l10n.invoiceEssentialsRefused;
  }
  return l10n.workspaceGenericError;
}
