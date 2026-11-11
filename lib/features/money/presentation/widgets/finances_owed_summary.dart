// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3599 — Me › Finances, the card above my open documents: what I owe, one
// figure per currency and never one across currencies; a credit taken off
// the invoices of the business that issued it only; a credit a business
// still holds for me said apart; a figure marked late only where an invoice
// in that currency is.
import 'package:flutter/material.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/finance_overview.dart';

class FinancesOwedSummary extends StatelessWidget {
  const FinancesOwedSummary({super.key, required this.data, required this.now});

  /// My production documents, as the lists below show them.
  final FinanceOverview data;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final money = personalFormatOf(context);
    final toPay = data.owedByCurrency;
    final credit = data.inMyFavourByCurrency;
    final validating = data.beingValidatedByCurrency;
    final late = data.overdueCurrencies(now);
    final overdue = data.payable.where((i) => i.overdueAt(now)).length;
    return Card(
      key: const ValueKey('finances-summary'),
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (toPay.isNotEmpty) ...[
              Text(l10n.cashHubToPay, style: theme.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
            ],
            for (final e in toPay.entries)
              Text(
                money.moneyNamed(e.key).formatMinor(e.value),
                key: ValueKey('finances-to-pay-${e.key}'),
                style: theme.textTheme.headlineSmall?.strong.copyWith(
                  color: late.contains(e.key) ? theme.colorScheme.error : null,
                ),
              ),
            if (overdue > 0)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  l10n.financesOverdueCount(overdue),
                  key: const ValueKey('finances-overdue'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            // #3682 — paid, the business has not confirmed yet: its own
            // line per currency, outside To pay.
            if (validating.isNotEmpty) ...[
              if (toPay.isNotEmpty) const SizedBox(height: AppSpacing.sm),
              Text(l10n.financesBeingValidated,
                  style: theme.textTheme.labelLarge),
              for (final e in validating.entries)
                Text(
                  money.moneyNamed(e.key).formatMinor(e.value),
                  key: ValueKey('finances-being-validated-${e.key}'),
                  style: theme.textTheme.titleMedium?.strong,
                ),
            ],
            if (credit.isNotEmpty) ...[
              if (toPay.isNotEmpty || validating.isNotEmpty)
                const SizedBox(height: AppSpacing.sm),
              Text(l10n.financesYourCredit, style: theme.textTheme.labelLarge),
              for (final e in credit.entries)
                Text(
                  money.moneyNamed(e.key).formatMinor(e.value),
                  key: ValueKey('finances-credit-${e.key}'),
                  style: theme.textTheme.titleMedium?.strong,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
