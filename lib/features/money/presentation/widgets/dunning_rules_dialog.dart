// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../workspace/providers/settings_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/save_dunning_rules.dart';
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
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(saveDunningRulesProvider).save(workspace.id, _rules);
    } on Object catch (e, st) {
      TraceLogger.instance.error('money', 'set dunning rules failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnack.error(
        context,
        l10n.workspaceGenericError,
      );
      return;
    }
    // #2484 — the first reminder's delay is stored as a setting.
    ref
      ..invalidate(settingsSetProvider(workspace.id))
      ..invalidate(currentSettingsProvider)
      ..invalidate(dunningRulesProvider);
    if (!mounted) return;
    Navigator.of(context).pop();
    AppSnack.info(
      context,
      l10n.dunningSaved,
      replace: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(scrollable: true,
      title: Text(l10n.dunningSettingsTitle),
      // The long automatic-reminder text must scroll, not spill over the
      // buttons on a phone.
      content: SingleChildScrollView(
        child: DunningRulesFields(
          key: const ValueKey('dunning-rules-fields'),
          rules: _rules,
          onChanged: (rules) => setState(() => _rules = rules),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('dunning-rules-dialog-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('dunning-save'),
          onPressed: _busy ? null : _save,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}

/// The dunning policy's fields — levels, the two delays, the automatic
/// sweep — for the reminder rules dialog and the setup guide's reminders
/// step. It holds nothing: every change is handed to [onChanged].
class DunningRulesFields extends StatelessWidget {
  const DunningRulesFields({
    super.key,
    required this.rules,
    required this.onChanged,
  });

  final DunningRules rules;
  final ValueChanged<DunningRules> onChanged;

  static const _dayOptions = [3, 5, 7, 10, 14, 21, 30, 45, 60];

  Widget _countRow(
    BuildContext context,
    String label, {
    required String key,
    required int value,
    required List<int> options,
    required ValueChanged<int> onChanged,
  }) =>
      Row(children: [
        Expanded(child: Text(label)),
        HelpDot(
          context.l10n.helpHintMoneyInvoicesTip2Topic,
          anchor: HelpAnchor.remindersRules,
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
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _countRow(
          context,
          l10n.dunningLevels,
          key: 'dunning-levels',
          value: rules.levels,
          options: const [1, 2, 3, 4, 5],
          onChanged: (v) => onChanged(rules.copyWith(levels: v)),
        ),
        _countRow(
          context,
          l10n.dunningFirstAfterDays,
          key: 'dunning-first-days',
          value: rules.firstAfterDays,
          options: _dayOptions,
          onChanged: (v) => onChanged(rules.copyWith(firstAfterDays: v)),
        ),
        _countRow(
          context,
          l10n.dunningBetweenDays,
          key: 'dunning-between-days',
          value: rules.betweenDays,
          options: _dayOptions,
          onChanged: (v) => onChanged(rules.copyWith(betweenDays: v)),
        ),
        // #726 — the sweep applies the levels by itself.
        SwitchListTile(
          key: const ValueKey('dunning-automatic'),
          contentPadding: EdgeInsets.zero,
          title: HelpDotTitle(
            l10n.dunningAutomatic,
            l10n.helpHintMoneyInvoicesTip2Topic,
            anchor: HelpAnchor.remindersAutomatic,
          ),
          // #2332 — and when "once a day" actually happens.
          subtitle: Text([
            l10n.dunningAutomaticHint,
            l10n.paymentRemindersWhen,
          ].join(' ')),
          value: rules.automatic,
          onChanged: (v) => onChanged(rules.copyWith(automatic: v)),
        ),
      ],
    );
  }
}
