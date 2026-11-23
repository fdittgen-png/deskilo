// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 -- taking cash: the amount the customer gave, "exact" for the total, the change said by the till. Answers the
// amount in minor units, or null when it was cancelled.
import 'package:flutter/material.dart';

import '../../../core/i18n/format_controller.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/ui/form_kit.dart';

/// Asks the cash given for [totalMinor] of [currency]; a typed amount that is not a number is said under its field.
Future<int?> showTillCashDialog(BuildContext context, {required int totalMinor, required String currency}) =>
    showDialog<int>(context: context, builder: (_) => _CashDialog(totalMinor: totalMinor, currency: currency));

class _CashDialog extends StatefulWidget {
  const _CashDialog({required this.totalMinor, required this.currency});

  final int totalMinor;
  final String currency;

  @override
  State<_CashDialog> createState() => _CashDialogState();
}

class _CashDialogState extends State<_CashDialog> {
  final _given = TextEditingController();
  final _error = ValueNotifier<String?>(null);

  @override
  void dispose() {
    _given.dispose();
    _error.dispose();
    super.dispose();
  }

  void _confirm() {
    final minor = appFormatOf(context).parseMinor(_given.text);
    if (minor == null || minor <= 0) {
      _error.value = context.l10n.tillCashInvalid;
      return;
    }
    Navigator.of(context).pop(minor);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final money = appFormatOf(context).moneyIn(widget.currency);
    return AlertDialog(
      title: Text(l10n.tillPayCash),
      content: ValueListenableBuilder<String?>(
        valueListenable: _error,
        builder: (context, error, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${l10n.tillTotalDue}: ${money.formatMinor(widget.totalMinor)}', style: Theme.of(context).textTheme.titleMedium),
            const FormGap(),
            AppTextField(
              key: const ValueKey('till-cash-given'),
              controller: _given,
              label: l10n.tillCashGiven,
              error: error,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
            const FormGap.small(),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey('till-cash-exact'),
                onPressed: () => Navigator.of(context).pop(widget.totalMinor),
                child: Text(l10n.tillCashExact),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
        FilledButton(key: const ValueKey('till-cash-confirm'), onPressed: _confirm, child: Text(l10n.tillPayCash)),
      ],
    );
  }
}
