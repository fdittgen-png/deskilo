// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../providers/money_providers.dart';

/// An open invoice is overdue once it has waited this many days.
const openInvoiceOverdueDays = 30;

/// Issue date · age · reminders — with the AGE in error colors once the
/// invoice has been waiting too long, so a collections list can be read
/// at a glance instead of parsed word by word.
Widget openInvoiceSubtitle(
  BuildContext context,
  AppLocalizations l10n,
  OpenInvoiceEntry entry,
  Map<String, ({int count, DateTime last})> reminders,
  DateFormat dateFormat,
  DateTime now,
) {
  final theme = Theme.of(context);
  final muted = theme.textTheme.bodySmall?.copyWith(
    color: theme.colorScheme.onSurfaceVariant,
  );
  final days = now.difference(entry.invoice.issuedAt).inDays;
  final reminder = reminders[entry.invoice.id];
  return Text.rich(
    TextSpan(style: muted, children: [
      TextSpan(text: dateFormat.format(entry.invoice.issuedAt)),
      const TextSpan(text: ' · '),
      TextSpan(
        text: l10n.invoiceOpenAge(days),
        style: days >= openInvoiceOverdueDays
            ? muted?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              )
            : null,
      ),
      if (reminder != null) ...[
        const TextSpan(text: ' · '),
        TextSpan(
          text: l10n.invoiceRemindedBadge(reminder.count),
        ),
      ],
    ]),
  );
}
