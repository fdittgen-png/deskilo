// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3556 (1b) — before anything is sent, the selection month by month: each
// month with its invoices and what they still owe, in the business's one
// currency (named, as everywhere in Me). Paying online pays the oldest
// month and says which months follow; declaring records one declaration per
// month, all on this one confirmation.
import 'package:flutter/material.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../domain/finance_selection.dart';

/// A month of `yyyy-MM` in words ("November 2026").
String monthLabel(BuildContext context, String period) {
  final parts = period.split('-');
  final year = int.tryParse(parts.first);
  final month = parts.length > 1 ? int.tryParse(parts[1]) : null;
  if (year == null || month == null) return period;
  return personalFormatOf(context)
      .dates(DateShape.monthYear)
      .format(DateTime(year, month));
}

/// True once the person confirmed; null or false when they did not.
Future<bool?> confirmFinanceSelection(
  BuildContext context,
  FinanceSelection selection, {
  required bool declare,
}) => showAppSheet<bool>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _Confirm(selection: selection, declare: declare),
);

class _Confirm extends StatelessWidget {
  const _Confirm({required this.selection, required this.declare});

  final FinanceSelection selection;
  final bool declare;

  /// #4165 — invoices without a month: their list and one amount, paid or
  /// declared at once.
  Widget _standalone(BuildContext context, MoneyFormat money, String business) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      key: ValueKey(
        declare ? 'finances-declare-confirm' : 'finances-pay-confirm',
      ),
      child: ListView(
        shrinkWrap: true,
        padding: AppSpacing.lgAll,
        children: [
          Text(
            declare
                ? l10n.financesDeclareTitle(business)
                : l10n.financesPayTitle(business),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final invoice in selection.standaloneInvoices)
            Text(
              l10n.financesSelectionInvoiceAmount(
                invoice.number,
                money.formatMinor(FinanceSelection.dueOf(invoice)),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.financesStandaloneTotal(money.formatMinor(selection.cents)),
            key: const ValueKey('finances-confirm-standalone-total'),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const ValueKey('finances-confirm-send'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              declare
                  ? l10n.financesDeclareSend
                  : l10n.financesPayAmount(money.formatMinor(selection.cents)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final money = personalFormatOf(context).moneyNamed(selection.currency!);
    final months = selection.months;
    final business = selection.workspaceName ?? '';
    if (selection.isStandalone) return _standalone(context, money, business);
    final first = months.first;
    final then = [
      for (final m in months.skip(1))
        l10n.financesSelectionMonthAmount(
          monthLabel(context, m.period),
          money.formatMinor(m.cents),
        ),
    ];
    return SafeArea(
      key: ValueKey(
        declare ? 'finances-declare-confirm' : 'finances-pay-confirm',
      ),
      child: ListView(
        shrinkWrap: true,
        padding: AppSpacing.lgAll,
        children: [
          Text(
            declare
                ? l10n.financesDeclareTitle(business)
                : l10n.financesPayTitle(business),
            style: theme.textTheme.titleMedium,
          ),
          for (final (i, m) in months.indexed) ...[
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text(
                l10n.financesSelectionMonthAmount(
                  monthLabel(context, m.period),
                  money.formatMinor(m.cents),
                ),
                key: ValueKey('finances-confirm-month-$i'),
                style: theme.textTheme.titleSmall,
              ),
            ),
            for (final invoice in m.invoices)
              Text(
                l10n.financesSelectionInvoiceAmount(
                  invoice.number,
                  money.formatMinor(FinanceSelection.dueOf(invoice)),
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (declare && months.length > 1)
            Text(
              l10n.financesDeclareEachMonth,
              style: theme.textTheme.bodySmall,
            )
          else if (!declare && then.isNotEmpty)
            Text(
              l10n.financesPayThen(then.join('; ')),
              key: const ValueKey('finances-pay-then'),
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const ValueKey('finances-confirm-send'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              declare
                  ? l10n.financesDeclareSend
                  : l10n.financesPayAmount(money.formatMinor(first.cents)),
            ),
          ),
        ],
      ),
    );
  }
}
