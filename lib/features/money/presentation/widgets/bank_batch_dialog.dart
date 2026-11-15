// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4053 — before the matches by reference are confirmed together, the
// person sees each movement with the invoice it would settle and its
// amount, and a total per currency (amounts of different currencies are
// never added). Confirming writes exactly the listed matches; cancelling
// writes nothing. When some were refused, the result is said per movement.
import 'package:flutter/material.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../domain/bank/bank_match.dart';

/// Shows [batch] and answers whether the person confirms it.
Future<bool> showBankBatchDialog(
  BuildContext context,
  List<BankWorkItem> batch,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _BankBatchDialog(batch: batch),
    ) ??
    false;

/// Says, per movement of [lines], whether it was confirmed.
Future<void> showBankBatchResult(
  BuildContext context,
  List<BankBatchLine> lines,
) => showDialog<void>(
  context: context,
  builder: (context) {
    final l10n = context.l10n;
    final confirmed = lines
        .where((l) => l.result == BankBatchResult.confirmed)
        .length;
    return AlertDialog(
      key: const ValueKey('bank-batch-result'),
      title: Text(l10n.bankBatchResultTitle(confirmed)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final line in lines)
              ListTile(
                key: ValueKey('bank-batch-result-${line.item.line.id}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  line.result == BankBatchResult.confirmed
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                ),
                title: Text(
                  line.result == BankBatchResult.confirmed
                      ? l10n.bankBatchLineConfirmed(_number(line.item))
                      : l10n.bankBatchLineRefused(_number(line.item)),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('bank-batch-result-ok'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  },
);

String _number(BankWorkItem item) => item.referenceMatch?.invoice.number ?? '';

class _BankBatchDialog extends StatelessWidget {
  const _BankBatchDialog({required this.batch});

  final List<BankWorkItem> batch;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = appFormatOf(context);
    final day = format.dates(DateShape.date);
    final totals = bankBatchTotals(batch);
    return AlertDialog(
      key: const ValueKey('bank-batch'),
      title: Text(l10n.bankBatchTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final item in batch)
              ListTile(
                key: ValueKey('bank-batch-line-${item.line.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.bankBatchLine(
                    format
                        .moneyIn(item.line.currency)
                        .formatMinor(item.line.amountCents),
                    day.format(item.line.valueDate),
                  ),
                ),
                subtitle: Text(
                  l10n.bankBatchSettles(
                    _number(item),
                    item.referenceMatch?.invoice.memberName ?? '',
                  ),
                ),
              ),
            const Divider(),
            for (final MapEntry(key: currency, value: cents) in totals.entries)
              ListTile(
                key: ValueKey('bank-batch-total-$currency'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.bankBatchTotal(
                    currency,
                    format.moneyIn(currency).formatMinor(cents),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('bank-batch-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('bank-batch-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.bankConfirmReferences(batch.length)),
        ),
      ],
    );
  }
}
