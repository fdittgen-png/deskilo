// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_dot.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/dunning.dart';
import '../../providers/money_providers.dart';

/// Owner dialog for the dunning policy (#472): how many reminder
/// levels, days until the first suggestion, days between levels. The
/// Open tab derives its "Reminder N due" flags from these.
Future<void> showDunningRulesDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final rules = await ref.read(dunningRulesProvider.future);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => _DunningDialog(initial: rules),
  );
}

class _DunningDialog extends ConsumerStatefulWidget {
  const _DunningDialog({required this.initial});

  final DunningRules initial;

  @override
  ConsumerState<_DunningDialog> createState() => _DunningDialogState();
}

class _DunningDialogState extends ConsumerState<_DunningDialog> {
  late DunningRules _rules = widget.initial;
  bool _busy = false;

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(moneyRepositoryProvider)
          .setDunningRules(workspace.id, _rules);
    } catch (e, st) {
      TraceLogger.instance.error('money', 'set dunning rules failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnack.error(
        context,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      );
      return;
    }
    ref.invalidate(dunningRulesProvider);
    if (!mounted) return;
    Navigator.of(context).pop();
    AppSnack.info(
      context,
      l10n?.dunningSaved ?? 'Reminder rules saved.',
      replace: true,
    );
  }

  Widget _countRow(
    String label, {
    required String key,
    required int value,
    required List<int> options,
    required ValueChanged<int> onChanged,
  }) =>
      Row(children: [
        Expanded(child: Text(label)),
        HelpDot(
          AppLocalizations.of(context)?.helpHintMoneyInvoicesTip2Topic ??
              'Automatic payment reminders',
        ),
        DropdownButton<int>(
          key: ValueKey(key),
          value: options.contains(value) ? value : options.first,
          underline: const SizedBox.shrink(),
          items: [
            for (final v in options)
              DropdownMenuItem(value: v, child: Text(v.toString())),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const dayOptions = [3, 5, 7, 10, 14, 21, 30, 45, 60];
    return AlertDialog(
      title: Text(l10n?.dunningSettingsTitle ?? 'Reminder rules'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _countRow(
            l10n?.dunningLevels ?? 'Number of reminder levels',
            key: 'dunning-levels',
            value: _rules.levels,
            options: const [1, 2, 3, 4, 5],
            onChanged: (v) =>
                setState(() => _rules = _rules.copyWith(levels: v)),
          ),
          _countRow(
            l10n?.dunningFirstAfterDays ?? 'Days until the first reminder',
            key: 'dunning-first-days',
            value: _rules.firstAfterDays,
            options: dayOptions,
            onChanged: (v) => setState(
                () => _rules = _rules.copyWith(firstAfterDays: v)),
          ),
          _countRow(
            l10n?.dunningBetweenDays ?? 'Days between reminders',
            key: 'dunning-between-days',
            value: _rules.betweenDays,
            options: dayOptions,
            onChanged: (v) =>
                setState(() => _rules = _rules.copyWith(betweenDays: v)),
          ),
          // #726 — the sweep applies the levels by itself.
          SwitchListTile(
            key: const ValueKey('dunning-automatic'),
            contentPadding: EdgeInsets.zero,
            title: HelpDotTitle(
              l10n?.dunningAutomatic ?? 'Automatic reminders',
              l10n?.helpHintMoneyInvoicesTip2Topic ??
                  'Automatic payment reminders',
            ),
            subtitle: Text(l10n?.dunningAutomaticHint ??
                'Once a day, open invoices past the term get their next '
                    'reminder level by themselves — an alert in the '
                    'member\'s feed and a push. Off: you send each '
                    'reminder yourself.'),
            value: _rules.automatic,
            onChanged: (v) =>
                setState(() => _rules = _rules.copyWith(automatic: v)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          key: const ValueKey('dunning-save'),
          onPressed: _busy ? null : _save,
          child: Text(l10n?.commonSave ?? 'Save'),
        ),
      ],
    );
  }
}
