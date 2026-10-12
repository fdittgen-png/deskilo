// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'invoicing_dashboard.dart';

// #2386 — part 1 of OpenInvoicesTab, split out of invoicing_dashboard.dart so no
// file holds the whole class.
extension _OpenInvoicesTabPart1 on OpenInvoicesTab {

  /// Issue date · age · reminders — with the AGE in error colors once the
  /// invoice has been waiting too long, so a collections list can be read
  /// at a glance instead of parsed word by word.
  Widget _openSubtitle(
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
          style: days >= _overdueDays
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
}
