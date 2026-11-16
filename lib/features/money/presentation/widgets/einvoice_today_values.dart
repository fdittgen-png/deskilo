// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4120 -- before an older invoice is sent: the values that are today's, not
// its own (it was issued before they were kept with it), named one by one, and
// sent only once the person confirms.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../domain/einvoice_sent_from_stored.dart';

/// True when nothing of the sending is today's, or the person confirms it.
Future<bool> confirmTodayValues(
  BuildContext context,
  EInvoiceSendBasis basis,
) async {
  if (!basis.anyToday) return true;
  final l10n = context.l10n;
  final values = [
    if (basis.paymentToday) l10n.eInvoiceSendTodayAccount,
    if (basis.referenceToday) l10n.eInvoiceSendTodayReference,
  ];
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const ValueKey('einvoice-today-values'),
      content: Text(
        [
          l10n.eInvoiceSendTodayTitle,
          for (final v in values) '• $v',
        ].join('\n'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('einvoice-today-values-send'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.eInvoiceSendTodayConfirm),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
