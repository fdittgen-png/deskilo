// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/member_account.dart';

/// #512 — the member's REAL position, above the per-month bill: months
/// are not islands. Credit on account (spendable on any outstanding
/// invoice), open remainders from past months, refunds the workspace
/// owes, and the resulting net. Invisible while there is nothing
/// notable — a settled account needs no extra card.
class AccountCard extends StatelessWidget {
  const AccountCard({
    super.key,
    required this.account,
    required this.currencyCode,
  });

  final MemberAccount account;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currency = NumberFormat.simpleCurrency(name: currencyCode);
    String money(int cents) => currency.format(cents / 100);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final net = account.netPositionCents;
    final netColor = net >= 0 ? scheme.primary : scheme.error;

    Widget row(String label, String value,
        {String? detail, Color? color, bool bold = false}) {
      final style = (bold ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium)
          ?.copyWith(
        color: color,
        fontWeight: bold ? FontWeight.bold : null,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: style),
                  if (detail != null)
                    Text(
                      detail,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            Text(value, style: style),
          ],
        ),
      );
    }

    return Card(
      key: const ValueKey('account-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n?.accountCardTitle ?? 'Your account',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            if (account.creditCents != 0)
              row(
                l10n?.accountCredit ?? 'Credit on account',
                '+${money(account.creditCents)}',
                color: scheme.primary,
              ),
            if (account.refundsDueCents != 0)
              row(
                l10n?.accountRefundDue ?? 'Refund due from the workspace',
                '+${money(account.refundsDueCents)}',
                color: scheme.primary,
              ),
            for (final open in account.openInvoices)
              row(
                open.number,
                '-${money(open.remainingCents)}',
                detail: open.paidCents > 0
                    ? (l10n?.accountOpenPartial(
                            open.period, money(open.paidCents)) ??
                        '${open.period} · ${money(open.paidCents)} paid')
                    : open.period,
                color: scheme.error,
              ),
            const Divider(height: 12),
            row(
              l10n?.accountNet ?? 'Net position',
              money(net),
              color: netColor,
              bold: true,
            ),
            if (account.creditCents > 0 && account.openInvoices.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n?.accountImputationHint ??
                      'Your credit can settle open invoices — the '
                          'workspace applies it when matching payments.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
