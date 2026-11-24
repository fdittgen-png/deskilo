// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4185 -- the card at the till, through a payment terminal that is not connected to the app: the till records that the
// authorization is asked (its reference is keyed in on the terminal), then the operator records what the terminal
// answered. Accepted makes the sale with that tender; declined leaves the sale to be paid another way; no answer leaves
// it waiting in the receipts, where someone who may see the finances reads the terminal's journal by the same reference
// and settles it. The card is never asked twice for one sale.
import 'package:flutter/material.dart';

import '../../../core/i18n/money_format.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/form_kit.dart';
import 'till_session.dart';
import 'till_text.dart';

class TillCardPanel extends StatelessWidget {
  const TillCardPanel({super.key, required this.state, required this.money, required this.onAnswer, required this.onNext});

  final TillState state;
  final MoneyFormat money;
  final void Function(String outcome)? onAnswer;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final card = state.card!;
    final problem = state.problem;
    final answer = state.busy || onAnswer == null ? null : onAnswer;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.counterSaleCardAskedTitle(money.formatMinor(card.amountMinor)), key: const ValueKey('till-card-asked'), style: theme.textTheme.titleLarge),
        const FormGap.small(),
        if (state.cardUnknown)
          Text(l10n.counterSaleCardWaiting(card.providerKey), key: const ValueKey('till-card-waiting'))
        else
          Text(l10n.counterSaleCardAskedHint(card.providerKey)),
        if (problem != null) ...[
          const FormGap.small(),
          Text(tillProblemText(l10n, problem), key: const ValueKey('till-problem'), style: TextStyle(color: theme.colorScheme.error)),
        ],
        const FormGap(),
        if (state.cardUnknown)
          FilledButton(
            key: const ValueKey('till-next'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: state.busy ? null : onNext,
            child: Text(l10n.tillNextCustomer),
          )
        else ...[
          FilledButton(
            key: const ValueKey('till-card-accepted'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: answer == null ? null : () => answer('accepted'),
            child: Text(l10n.counterSaleCardAccepted),
          ),
          const FormGap.small(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('till-card-refused'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: answer == null ? null : () => answer('refused'),
                  child: Text(l10n.counterSaleCardRefused),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('till-card-unknown'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: answer == null ? null : () => answer('unknown'),
                  child: Text(l10n.counterSaleCardNoAnswer),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
