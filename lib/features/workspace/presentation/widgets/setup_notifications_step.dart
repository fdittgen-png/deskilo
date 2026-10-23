// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup step "notifications": who the app tells about what, and by
// which channel, read from the switched-on features ([notificationLines]);
// whether phone notifications are on; and the one thing the owner sets
// here, how long before a booking its check-in reminder appears — the
// settings registry's own value, prefilled and saved through
// [SettingsCommands]. The preview is the reminder a member's phone shows.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/settings/setting_defaults.g.dart';
import '../../../../core/settings/settings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/ui/setup_step_layout.dart';
import '../../domain/notification_lines.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/settings_providers.dart';
import '../../providers/workspace_providers.dart';
import 'availability_tiles.dart';
import 'setup_limit_row.dart';

/// The registry key of the check-in reminder's lead time, in minutes.
const _leadKey = 'booking.check_in_reminder_lead_minutes';

class SetupNotificationsStep extends ConsumerStatefulWidget {
  const SetupNotificationsStep({super.key, required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<SetupNotificationsStep> createState() =>
      _SetupNotificationsStepState();
}

class _SetupNotificationsStepState
    extends ConsumerState<SetupNotificationsStep> {
  /// The lead time the owner picked; null until they pick one, so the row
  /// shows the effective value until then.
  final _draft = ValueNotifier<int?>(null);
  final _busy = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _draft.dispose();
    _busy.dispose();
    super.dispose();
  }

  Future<void> _save(SettingDefinition definition, int minutes) async {
    final l10n = context.l10n;
    _busy.value = true;
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'setup notification lead time failed',
      errorText: l10n.setupNotificationsSaveFailed,
      action: () => ref
          .read(settingsCommandsProvider)
          .save(
            workspaceId: widget.workspace.id,
            definition: definition,
            text: '$minutes',
          ),
    );
    ref
      ..invalidate(settingsSetProvider(widget.workspace.id))
      ..invalidate(currentSettingsProvider);
    if (!mounted) return;
    _busy.value = false;
    if (!ok) return;
    _draft.value = null;
    AppSnack.success(context, l10n.workspaceSettingsSaved);
  }

  @override
  Widget build(BuildContext context) {
    final on = ref.watch(enabledFeaturesSyncProvider);
    final read = ref.watch(settingsSetProvider(widget.workspace.id));
    if (read.isLoading && !read.hasValue) return const LoadingView();
    // Unreadable settings leave the lead time the registry falls back to.
    final settings = read.value;
    final definition = settings?.definitions[_leadKey];
    // A registry read from the app's own bundle holds defaults only: it is
    // shown, never written over (the settings editor does the same).
    final editable =
        definition != null &&
        definition.editable &&
        settings!.revision != 'defaults';
    final stored = definition == null
        ? SettingDefaults.bookingCheckInReminderLeadMinutes
        : settings!.read<int>(_leadKey);
    return ListenableBuilder(
      listenable: Listenable.merge([_draft, _busy]),
      builder: (context, _) {
        final lead = _draft.value ?? stored;
        return SetupStepLayout(
          form: _form(
            context,
            lines: notificationLines(on),
            push: on.contains(WorkspaceFeature.pushNotifications),
            lead: lead,
            definition: editable ? definition : null,
          ),
          preview: _Preview(lead: lead),
        );
      },
    );
  }

  Widget _form(
    BuildContext context, {
    required List<NotificationLine> lines,
    required bool push,
    required int lead,
    required SettingDefinition? definition,
  }) {
    final l10n = context.l10n;
    final busy = _busy.value;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.setupStepHint('notifications')),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.setupNotificationsWho, style: theme.textTheme.titleMedium),
        for (final line in lines)
          ListTile(
            key: ValueKey('setup-notifications-line-${line.event}'),
            contentPadding: EdgeInsets.zero,
            leading: Icon(switch (line.audience) {
              NotifiedAudience.deciders => Icons.how_to_reg_outlined,
              NotifiedAudience.members => Icons.people_outline,
            }),
            title: Text(l10n.setupNotificationsEvent(line.event)),
            subtitle: Text(
              l10n.setupNotificationsLineHow(
                l10n.setupNotificationsAudience(line.audience.name),
                // The channels in their declared order, as one choice:
                // `app`, `app_push` or `device`.
                l10n.setupNotificationsChannels(
                  [
                    for (final c in NotificationChannel.values)
                      if (line.channels.contains(c)) c.name,
                  ].join('_'),
                ),
              ),
            ),
          ),
        Text(
          push ? l10n.setupNotificationsPushOn : l10n.setupNotificationsPushOff,
          key: const ValueKey('setup-notifications-push'),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        if (definition != null) ...[
          SetupLimitRow(
            key: const ValueKey('setup-notifications-lead'),
            icon: Icons.alarm_outlined,
            title: l10n.settingLabelBookingCheckInReminderLeadMinutes,
            description: l10n.settingHintBookingCheckInReminderLeadMinutes,
            control: SetupLimitDropdown(
              dropdownKey: 'setup-notifications-lead-dropdown',
              value: lead,
              options: [
                for (final m in durationOptions)
                  if (definition.check(m) == null) m,
              ],
              format: (v) => formatDuration(l10n, v),
              onChanged: (v) {
                if (!busy) _draft.value = v;
              },
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton(
              key: const ValueKey('setup-notifications-save'),
              onPressed: busy || _draft.value == null
                  ? null
                  : () => _save(definition, lead),
              child: Text(l10n.commonSave),
            ),
          ),
        ] else
          Text(
            l10n.setupNotificationsLeadFixed(formatDuration(l10n, lead)),
            key: const ValueKey('setup-notifications-lead-fixed'),
          ),
      ],
    );
  }
}

/// The check-in reminder as the member's phone shows it, for a booking at
/// nine.
class _Preview extends StatelessWidget {
  const _Preview({required this.lead});

  final int lead;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    // A wall-clock example, not an instant: the member's clock preference
    // and nothing else.
    final at = appFormatOf(context).wallTime(DateTime(2000, 1, 1, 9));
    return Column(
      key: const ValueKey('setup-notifications-preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.setupNotificationsPreviewWhen(formatDuration(l10n, lead)),
          key: const ValueKey('setup-notifications-preview-when'),
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(l10n.reminderTitle, style: theme.textTheme.titleSmall),
            subtitle: Text(
              l10n.reminderBody(l10n.setupNotificationsPreviewPlace, at),
              key: const ValueKey('setup-notifications-preview-body'),
            ),
          ),
        ),
      ],
    );
  }
}
