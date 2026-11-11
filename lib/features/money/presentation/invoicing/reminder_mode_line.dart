// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-f -- the one line that says how reminders go out: by themselves, in
// the app, or by hand -- and "Rules", the entry to the existing reminder rules
// (automatic on/off, days to the first, days between, number of levels). The
// invoicing home places it at the foot of its To-do card.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../providers/money_providers.dart';
import '../widgets/dunning_rules_dialog.dart';

class ReminderModeLine extends ConsumerWidget {
  const ReminderModeLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final rules = ref.watch(dunningRulesProvider).value;
    // Not known yet: no claim about how reminders go out.
    if (rules == null) return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(
          child: Text(
            rules.automatic
                ? l10n.reminderModeAutomatic
                : l10n.reminderModeByHand,
            key: const ValueKey('reminder-mode-text'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextButton(
          key: const ValueKey('reminder-mode-rules'),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => showDunningRulesDialog(context, ref),
          child: Text(l10n.reminderModeRules),
        ),
      ],
    );
  }
}
