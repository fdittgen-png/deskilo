// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/failure/app_failure.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../application/issue_invoice.dart';

/// The answer to issuing an invoice was lost. The draft is kept in the
/// attempt, and the only action is to LOOK for the invoice in the archive
/// of the attempt's own workspace: nothing here can send the command again.
/// Returns the resolved outcome (issued, held or declined), or null when
/// the person leaves it.
Future<CommandOutcome<String>?> showInvoiceUnknownOutcomeDialog(
  BuildContext context, {
  required InvoiceIssuance issuance,
  required InvoiceIssueAttempt attempt,
  required CommandUnreached<String> unknown,
}) => showDialog<CommandOutcome<String>>(
  context: context,
  barrierDismissible: false,
  builder: (_) =>
      _UnknownOutcome(issuance: issuance, attempt: attempt, unknown: unknown),
);

class _UnknownOutcome extends StatelessWidget {
  _UnknownOutcome({
    required this.issuance,
    required this.attempt,
    required CommandUnreached<String> unknown,
  }) : _current = ValueNotifier(unknown);

  final InvoiceIssuance issuance;
  final InvoiceIssueAttempt attempt;
  final ValueNotifier<CommandUnreached<String>> _current;
  final ValueNotifier<bool> _checking = ValueNotifier(false);
  final ValueNotifier<bool> _notFound = ValueNotifier(false);

  Future<void> _check(BuildContext context) async {
    if (_checking.value) return;
    _checking.value = true;
    final outcome = await issuance.look(attempt, _current.value);
    _checking.value = false;
    if (!context.mounted) return;
    switch (outcome) {
      case CommandDone() || CommandHeld() || CommandRefused():
        Navigator.of(context).pop(outcome);
      case CommandUnreached():
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
            Text(l10n.invoiceIssueUnknownBody),
            if (notFound) Text(l10n.invoiceIssueNotFoundYet),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('invoice-issue-unknown-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _checking,
          builder: (context, checking, _) => FilledButton(
            key: const ValueKey('invoice-issue-check-again'),
            onPressed: checking ? null : () => _check(context),
            child: Text(l10n.invoiceIssueCheckAgain),
          ),
        ),
      ],
    );
  }
}
