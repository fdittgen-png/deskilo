// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2484 -- THE editor of the settings registry: grouped by the registry's
// group key, one row per setting with its value, where it comes from, its
// bounds and unit, its security floor, and a history. A new setting adds a
// registry row and a label and appears here; there is no screen per setting.
// A guardrail (not editable) is shown with its reason and no edit button.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/settings/settings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../core/ui/loading_view.dart';
import '../../providers/settings_providers.dart';
import '../settings_labels.dart';

/// The settings of [scope] (and [group], when given). [workspaceId] is null
/// for the platform's own values; [canEdit] is whether the signed-in person
/// holds the permission (the server decides again).
@visibleForTesting
class SettingsEditor extends ConsumerWidget {
  const SettingsEditor({
    super.key,
    required this.scope,
    this.workspaceId,
    this.group,
    this.canEdit = false,
  });

  final SettingScope scope;
  final String? workspaceId;
  final String? group;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(settingsSetProvider(workspaceId));
    return async.when(
      loading: () => const LoadingView(),
      error: (e, st) => Text(l10n.settingsLoadFailed),
      data: (set) {
        final offline = set.revision == 'defaults' && set.definitions.isNotEmpty;
        final shown = [
          for (final d in set.definitions.values)
            if (d.allows(scope) && (group == null || d.group == group)) d,
        ]..sort((a, b) {
            final byGroup = a.group.compareTo(b.group);
            return byGroup != 0 ? byGroup : a.key.compareTo(b.key);
          });
        if (shown.isEmpty) return Text(l10n.settingsEmpty);
        String? lastGroup;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (offline) Text(l10n.settingsOfflineRegistry),
            for (final d in shown) ...[
              if (d.group != lastGroup)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    settingGroupLabel(l10n, lastGroup = d.group),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              _SettingTile(
                definition: d,
                set: set,
                workspaceId: workspaceId,
                canEdit: canEdit && !offline && d.editable,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SettingTile extends ConsumerWidget {
  const _SettingTile({
    required this.definition,
    required this.set,
    required this.workspaceId,
    required this.canEdit,
  });

  final SettingDefinition definition;
  final SettingsSet set;
  final String? workspaceId;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final d = definition;
    final unit = settingUnitLabel(l10n, d.unit);
    final value = set.effective[d.key] ?? d.defaultValue;
    final lines = [
      ?settingHint(l10n, d.key),
      ?settingRangeLabel(l10n, d),
      if (d.floor != null) l10n.settingFloorNote('${d.floor}', unit),
      settingOriginLabel(l10n, set.originOf(d.key)),
      if (!d.editable) '${l10n.settingGuardrail}: ${d.note.isEmpty ? l10n.settingGuardrailFallback : d.note}',
    ];
    final theme = Theme.of(context);
    // The label and its text take the full width; the value and its buttons
    // sit on a line of their own, so a long label never shrinks to a sliver.
    return Padding(
      key: ValueKey('setting-${d.key}'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!d.editable)
                const Padding(
                  padding: EdgeInsets.only(right: AppSpacing.sm),
                  child: Icon(Icons.lock_outline),
                ),
              Expanded(
                child: Text(
                  settingLabel(l10n, d.key),
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          if (lines.isNotEmpty)
            Text(lines.join('\n'), style: theme.textTheme.bodySmall),
          Row(
            children: [
              Expanded(
                child: Text(l10n.settingCurrentValue('$value', unit)),
              ),
              IconButton(
                key: ValueKey('setting-history-${d.key}'),
                tooltip: l10n.settingHistory,
                icon: const Icon(Icons.history),
                onPressed: () => _showHistory(context, ref),
              ),
              if (canEdit)
                IconButton(
                  key: ValueKey('setting-edit-${d.key}'),
                  tooltip: l10n.settingEdit,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _edit(context, ref, value),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showHistory(BuildContext context, WidgetRef ref) async {
    final versions = await ref.read(settingsSourceProvider).history(workspaceId, definition.key);
    if (!context.mounted) return;
    final l10n = context.l10n;
    final unit = settingUnitLabel(l10n, definition.unit);
    await showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SheetShell(
        title: '${l10n.settingHistory} · ${settingLabel(l10n, definition.key)}',
        children: [
          if (versions.isEmpty) Text(l10n.settingHistoryEmpty),
          for (final v in versions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.settingVersionLine('${v.value}', unit, v.validFrom)),
              subtitle: Text([
                if (v.validTo != null) l10n.settingVersionUntil(v.validTo!),
                if (v.note.isNotEmpty) v.note,
              ].join(' · ')),
            ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Object current) async {
    final l10n = context.l10n;
    final commands = ref.read(settingsCommandsProvider);
    final fields = FormControllers({'value': '$current', 'note': ''});
    final d = definition;
    final saved = await showAppFormSheet(
      context,
      AppFormSheet(
        title: settingLabel(l10n, d.key),
        submitLabel: l10n.settingSave,
        submitKey: const ValueKey('setting-save'),
        onDispose: fields.dispose,
        validate: () {
          final problem = commands.problemOf(d, fields.text('value'));
          return {if (problem != null) 'value': settingProblemLabel(l10n, problem)};
        },
        onSubmit: () async {
          try {
            await commands.save(
              workspaceId: workspaceId,
              definition: d,
              text: fields.text('value'),
              note: fields.text('note'),
            );
            return null;
          } on Object catch (e, st) {
            TraceLogger.instance.error('settings', 'save ${d.key} failed',
                error: e, stackTrace: st);
            return l10n.settingCouldNotSave;
          }
        },
        builder: (context, refresh) => [
          AppTextField(
            key: const ValueKey('setting-value'),
            controller: fields['value'],
            fieldKey: 'value',
            label: l10n.settingValueField,
            suffixText: settingUnitLabel(l10n, d.unit),
            keyboardType: TextInputType.text,
            helper: settingRangeLabel(l10n, d),
          ),
          const FormGap(),
          AppTextField(
            key: const ValueKey('setting-note'),
            controller: fields['note'],
            label: l10n.settingNoteField,
          ),
        ],
      ),
    );
    if (saved) {
      ref
        ..invalidate(settingsSetProvider(workspaceId))
        ..invalidate(currentSettingsProvider);
    }
  }
}

/// Opens the editor of [scope] in a full-height sheet: the two entry points
/// (the workspace settings and the platform-owner list) share it.
Future<void> showSettingsEditorSheet(
  BuildContext context, {
  required String title,
  required SettingScope scope,
  String? workspaceId,
  required bool canEdit,
}) =>
    showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SheetShell(
        title: title,
        children: [
          SettingsEditor(scope: scope, workspaceId: workspaceId, canEdit: canEdit),
        ],
      ),
    );
