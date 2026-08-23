// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_spacing.dart';
import 'help_hint_providers.dart';

/// Every surface that carries a contextual help hint (#606). The enum
/// name is the persisted dismissal id — renaming a value revives its
/// hint on devices that had dismissed it.
enum HelpHintId {
  reserve,
  plan,
  calendar,
  events,
  editor,
  availability,
  features,
  members,
  money,
  validation,
  workspaceSettings,
  badges,
}

/// One compact, dismissible how-to card at the top of a form/screen
/// (#606): a 1–2 sentence hint for THAT surface, a "Learn more" link
/// that opens the in-app guide at the matching section, and a 48dp
/// dismiss target. Dismissal persists per hint id; Settings can restore
/// all. Rides the [WorkspaceFeature.formHelpHints] flag, so gating lives
/// HERE — every surface just drops the widget in.
class HelpHint extends ConsumerWidget {
  const HelpHint(this.id, {super.key});

  final HelpHintId id;

  /// The hint's how-to sentence, per surface.
  static String text(AppLocalizations? l10n, HelpHintId id) => switch (id) {
        HelpHintId.reserve => l10n?.helpHintReserve ??
            'Pick a day and time window, then tap a free seat to book it.',
        HelpHintId.plan => l10n?.helpHintPlan ??
            'The live floor plan: tap a free seat to book it, tap your '
                'own booking to check in.',
        HelpHintId.calendar => l10n?.helpHintCalendar ??
            'Browse bookings by month; tap a day to see and manage its '
                'reservations.',
        HelpHintId.events => l10n?.helpHintEvents ??
            'Everything that happened, in one feed. Decisions waiting '
                'for you sit on top; the chips filter the rest.',
        HelpHintId.editor => l10n?.helpHintEditor ??
            'Draw rooms and desks, stamp seats onto them — tap a seat '
                'twice to edit its properties.',
        HelpHintId.availability => l10n?.helpHintAvailability ??
            'Set the open weekdays and working hours, and add closure '
                'days nobody can book.',
        HelpHintId.features => l10n?.helpHintFeatures ??
            'Switch workspace functionality on or off — every member\'s '
                'app follows immediately.',
        HelpHintId.members => l10n?.helpHintMembers ??
            'Invite members, set their plan percentage and role, and '
                'manage their badges.',
        HelpHintId.money => l10n?.helpHintMoney ??
            'Your monthly bill: browse months with the arrows; pay, '
                'export or share from here.',
        HelpHintId.validation => l10n?.helpHintValidation ??
            'Decide which actions need confirmation, who confirms, and '
                'how many approvals it takes.',
        HelpHintId.workspaceSettings => l10n?.helpHintWorkspace ??
            'Country, currency, language and billing details — '
                'documents and taxes follow these settings.',
        HelpHintId.badges => l10n?.helpHintBadges ??
            'Issue a printable QR badge or register an NFC card; revoke '
                'lost badges any time.',
      };

  /// A distinctive fragment of the matching guide heading, localized —
  /// the help guides are per-language, so the jump text must be too.
  static String topic(AppLocalizations? l10n, HelpHintId id) => switch (id) {
        HelpHintId.reserve => l10n?.helpHintReserveTopic ?? 'Reserve hub',
        HelpHintId.plan => l10n?.helpHintPlanTopic ?? 'floor plan',
        HelpHintId.calendar => l10n?.helpHintCalendarTopic ?? 'Calendar',
        HelpHintId.events => l10n?.helpHintEventsTopic ?? 'confirmations',
        HelpHintId.editor => l10n?.helpHintEditorTopic ?? 'space editor',
        HelpHintId.availability =>
          l10n?.helpHintAvailabilityTopic ?? 'Availability',
        HelpHintId.features => l10n?.helpHintFeaturesTopic ?? 'Features',
        HelpHintId.members =>
          l10n?.helpHintMembersTopic ?? 'Members & plans',
        HelpHintId.money => l10n?.helpHintMoneyTopic ?? 'Money',
        HelpHintId.validation =>
          l10n?.helpHintValidationTopic ?? 'confirmations',
        HelpHintId.workspaceSettings =>
          l10n?.helpHintWorkspaceTopic ?? 'Workspace settings',
        HelpHintId.badges => l10n?.helpHintBadgesTopic ?? 'NFC badges',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.formHelpHints)) {
      return const SizedBox.shrink();
    }
    // Unknown while the one-time read is in flight: stay hidden — a
    // hint that flashes and vanishes reads as a glitch.
    final dismissed = ref.watch(dismissedHelpHintsProvider).value;
    if (dismissed == null || dismissed.contains(id.name)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: ValueKey('help-hint-${id.name}'),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Icon(
                Icons.lightbulb_outline,
                size: 18,
                color: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Text(
                      text(l10n, id),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSecondaryContainer),
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      key: ValueKey('help-hint-learn-more-${id.name}'),
                      onPressed: () => context.push(
                        Uri(
                          path: '/help',
                          queryParameters: {'topic': topic(l10n, id)},
                        ).toString(),
                      ),
                      child:
                          Text(l10n?.helpHintLearnMore ?? 'Learn more'),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: ValueKey('help-hint-dismiss-${id.name}'),
              tooltip: l10n?.helpHintDismiss ?? 'Dismiss hint',
              icon: const Icon(Icons.close, size: 18),
              color: scheme.onSecondaryContainer,
              onPressed: () => ref
                  .read(dismissedHelpHintsProvider.notifier)
                  .dismiss(id.name),
            ),
          ],
        ),
      ),
    );
  }
}
