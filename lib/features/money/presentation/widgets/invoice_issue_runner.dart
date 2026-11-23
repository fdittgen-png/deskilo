// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/codes/dk_code.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/refusal_text.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/issue_invoice.dart';
import 'invoice_unknown_outcome_dialog.dart';

/// Sends [attempt] once and tells the person what is true: issued, held for
/// validation, refused in the server's words, or UNKNOWN — in which case the
/// dialog offers only to look for the invoice, never to send it again.
/// Returns whether the invoice is known to exist (the caller refreshes).
/// #3853 — [afterIssue] runs once the invoice exists, in the same flow: it
/// keeps the invoice's original.
Future<bool> runInvoiceIssue(
  BuildContext context,
  InvoiceIssuance issuance,
  InvoiceIssueAttempt attempt, {
  Future<void> Function(String invoiceId)? afterIssue,
}) async {
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
    case InvoiceIssued(:final invoiceId):
      AppSnack.success(context, l10n.invoiceIssued);
      await afterIssue?.call(invoiceId);
      return true;
    case InvoiceIssueHeld():
      AppSnack.info(context, l10n.validationSentForApproval);
    case InvoiceIssueRefused(:final error):
      TraceLogger.instance.error(
        'money',
        'invoice issue refused',
        error: error,
      );
      AppSnack.error(context, invoiceRefusalText(l10n, error));
    case InvoiceIssueUnknown():
      break;
  }
  return false;
}

/// The words of a refused issue, ONE helper for every surface that issues:
/// a request a validator declined, an already-invoiced month (0067, pinned
/// substring), the feature switched off, essentials missing, or [fallback]
/// (the generic sentence when none is given).
String invoiceRefusalText(
  AppLocalizations l10n,
  Object error, {
  String? fallback,
}) {
  if (error is InvoiceIssueDeclined) return l10n.invoiceIssueDeclined;
  // #3811 — read by the server's codes (0396, 0740), never its sentences.
  final refusal = refusalCodeOf(error);
  return switch (refusal.code) {
    DkCode.dki07 => l10n.invoiceAlreadyInvoiced,
    // #3994 — a correction is of the kind of the invoice it replaces.
    DkCode.dki08 => l10n.invoiceCorrectionKeepsKind,
    DkCode.dki01 when refusal.details == 'invoice_feature_disabled' =>
      l10n.invoiceFeatureDisabled,
    DkCode.dki01 => l10n.invoiceEssentialsRefused,
    _ => fallback ?? l10n.workspaceGenericError,
  };
}
