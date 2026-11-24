// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/failure/app_failure.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../application/invoice_action.dart';
import 'command_unknown_dialog.dart';

/// #2585 C2 — sends [attempt] once and tells the person what is true: done,
/// held for validation, refused (or declined), or UNKNOWN — in which case the
/// dialog offers only to look for the receipt of THIS request, never to send
/// the act again. Returns whether the act is known to have been applied.
Future<bool> runInvoiceReceiptAction(
  BuildContext context,
  InvoiceReceiptActions actions,
  InvoiceActionAttempt attempt, {
  required String successText,
  required String failureText,
}) async {
  final l10n = context.l10n;
  var outcome = await actions.run(attempt);
  if (outcome is CommandUnreached<void>) {
    if (!context.mounted) return false;
    var current = outcome;
    final resolved = await showCommandUnknownDialog<CommandOutcome<void>>(
      context,
      body: l10n.invoiceActionUnknownBody,
      check: () async {
        final looked = await actions.look(attempt, current);
        if (looked is CommandUnreached<void>) {
          current = looked;
          return null;
        }
        return looked;
      },
    );
    if (resolved == null) return false;
    outcome = resolved;
  }
  if (!context.mounted) return false;
  switch (outcome) {
    case CommandDone():
      AppSnack.success(context, successText);
      return true;
    case CommandHeld():
      AppSnack.info(context, l10n.validationSentForApproval);
    case CommandRefused(:final refusal):
      TraceLogger.instance.error(
        'money',
        'invoice action refused',
        error: refusal,
      );
      AppSnack.error(
        context,
        refusal.cause is InvoiceActionDeclined
            ? l10n.invoiceActionDeclined
            : failureText,
      );
    case CommandUnreached():
      break;
  }
  return false;
}
