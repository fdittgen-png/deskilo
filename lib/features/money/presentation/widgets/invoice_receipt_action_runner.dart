// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../application/invoice_action.dart';

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
  if (outcome is InvoiceActionUnknown) {
    if (!context.mounted) return false;
    final resolved = await showDialog<InvoiceActionOutcome>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UnknownAction(
        actions: actions,
        unknown: outcome as InvoiceActionUnknown,
      ),
    );
    if (resolved == null) return false;
    outcome = resolved;
  }
  if (!context.mounted) return false;
  switch (outcome) {
    case InvoiceActionDone():
      AppSnack.success(context, successText);
      return true;
    case InvoiceActionHeld():
      AppSnack.info(context, l10n.validationSentForApproval);
    case InvoiceActionRefused(:final error, :final declined):
      TraceLogger.instance.error(
        'money',
        'invoice action refused',
        error: error,
      );
      AppSnack.error(
        context,
        declined ? l10n.invoiceActionDeclined : failureText,
      );
    case InvoiceActionUnknown():
      break;
  }
  return false;
}

class _UnknownAction extends StatelessWidget {
  _UnknownAction({required this.actions, required InvoiceActionUnknown unknown})
    : _current = ValueNotifier(unknown);

  final InvoiceReceiptActions actions;
  final ValueNotifier<InvoiceActionUnknown> _current;
  final ValueNotifier<bool> _checking = ValueNotifier(false);
  final ValueNotifier<bool> _notFound = ValueNotifier(false);

  Future<void> _check(BuildContext context) async {
    if (_checking.value) return;
    _checking.value = true;
    final outcome = await actions.look(_current.value);
    _checking.value = false;
    if (!context.mounted) return;
    switch (outcome) {
      case InvoiceActionDone() || InvoiceActionHeld() || InvoiceActionRefused():
        Navigator.of(context).pop(outcome);
      case InvoiceActionUnknown():
        _current.value = outcome;
        _notFound.value = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.invoiceIssueUnknownTitle),
      content: ValueListenableBuilder<bool>(
        valueListenable: _notFound,
        builder: (context, notFound, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Text(l10n.invoiceActionUnknownBody),
            if (notFound) Text(l10n.invoiceIssueNotFoundYet),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('invoice-action-unknown-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _checking,
          builder: (context, checking, _) => FilledButton(
            key: const ValueKey('invoice-action-check-again'),
            onPressed: checking ? null : () => _check(context),
            child: Text(l10n.invoiceIssueCheckAgain),
          ),
        ),
      ],
    );
  }
}
