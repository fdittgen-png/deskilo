// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4450 -- the terminal console of the till drawer: what a till terminal is ringing up now. The business's newest open
// draft is read again on a short beat, so a product chosen on the terminal appears here with the price, the tax and the
// total the server gave it -- the same draft the terminal's receipt roll shows. Nothing is computed here.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/counter_book.dart';
import '../../providers/counter_book_providers.dart';
import 'drawer_text.dart';

/// How often the console reads the open draft again: a tap on a terminal shows within moments, for one small read.
const Duration terminalConsoleBeat = Duration(seconds: 2);

class TerminalConsole extends ConsumerStatefulWidget {
  const TerminalConsole({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<TerminalConsole> createState() => _TerminalConsoleState();
}

class _TerminalConsoleState extends ConsumerState<TerminalConsole> {
  Timer? _beat;

  @override
  void initState() {
    super.initState();
    _beat = Timer.periodic(terminalConsoleBeat, (_) => ref.invalidate(counterOpenDraftProvider(widget.workspaceId)));
  }

  @override
  void dispose() {
    _beat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final draft = ref.watch(counterOpenDraftProvider(widget.workspaceId));
    // a read in flight keeps the last answer on screen: the console does not blink on every beat
    final shown = draft.value;
    return Card(
      key: const ValueKey('terminal-console'),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.point_of_sale_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(l10n.tillDrawerConsoleTitle, style: theme.textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (draft.hasError && !draft.isLoading)
              Text(drawerProblemText(l10n, draft.error!), key: const ValueKey('terminal-console-problem'))
            else if (shown == null)
              Text(l10n.tillDrawerConsoleEmpty, key: const ValueKey('terminal-console-empty'), style: theme.textTheme.bodyMedium)
            else
              _Draft(draft: shown),
          ],
        ),
      ),
    );
  }
}

class _Draft extends StatelessWidget {
  const _Draft({required this.draft});

  final CounterBookReceipt draft;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final money = appFormatOf(context).moneyIn(draft.currency);
    return Column(
      key: ValueKey('terminal-console-draft-${draft.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.tillDrawerConsoleRevision('${draft.revision}'), style: theme.textTheme.bodySmall),
        const Divider(),
        for (final line in draft.lines)
          Padding(
            key: ValueKey('terminal-console-line-${line.lineNo}'),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(child: Text(l10n.tillDrawerConsoleLine(line.quantity, line.label))),
                Text(money.formatMinor(line.grossMinor)),
              ],
            ),
          ),
        const Divider(),
        Text(
          l10n.counterSaleTotal(money.formatMinor(draft.totalMinor)),
          key: const ValueKey('terminal-console-total'),
          textAlign: TextAlign.end,
          style: theme.textTheme.titleMedium,
        ),
        if (draft.taxMinor != 0) Text(l10n.counterSaleTax(money.formatMinor(draft.taxMinor)), textAlign: TextAlign.end, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
