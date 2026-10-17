// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';

/// #2585 C2 — the one dialog for a financial command whose answer was lost.
/// It offers only to LOOK ([check]); nothing here can send the command
/// again. [check] returns the resolved outcome, or null while the receipt of
/// the attempt is still not observed (the dialog then says "not found yet").
/// Returns the resolved outcome, or null when the person leaves it.
Future<T?> showCommandUnknownDialog<T extends Object>(
  BuildContext context, {
  required String body,
  required Future<T?> Function() check,
}) => showDialog<T>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _CommandUnknown<T>(body: body, check: check),
);

class _CommandUnknown<T extends Object> extends StatelessWidget {
  _CommandUnknown({required this.body, required this.check});

  final String body;
  final Future<T?> Function() check;
  final ValueNotifier<bool> _checking = ValueNotifier(false);
  final ValueNotifier<bool> _notFound = ValueNotifier(false);

  Future<void> _check(BuildContext context) async {
    if (_checking.value) return;
    _checking.value = true;
    final resolved = await check();
    _checking.value = false;
    if (!context.mounted) return;
    if (resolved == null) {
      _notFound.value = true;
    } else {
      Navigator.of(context).pop(resolved);
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
            Text(body),
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
