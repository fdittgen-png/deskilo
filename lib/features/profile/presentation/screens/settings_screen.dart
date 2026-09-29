// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../../core/l10n/lexicon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../reservations/domain/default_booking_period.dart';
import '../../../reservations/providers/default_period_controller.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/domain/workspace_permission.dart';
import '../../../auth/presentation/widgets/badge_pin_tile.dart';
import '../../../workspace/presentation/widgets/my_badge_tile.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/profile.dart';
import '../../providers/profile_providers.dart';
import '../widgets/account_settings_tiles.dart';
import '../widgets/settings_advanced_section.dart';
import '../widgets/settings_about_section.dart';
import '../widgets/settings_workspace_sections.dart';
import '../widgets/settings_section_header.dart';


/// App settings. Sign-out lives here; more sections arrive with their Epics.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Reverts THIS kiosk profile to a regular member (0056): confirm,
  /// call the self RPC, refresh the membership so the router's kiosk
  /// gate never comes back.
  Future<void> _revertKiosk(
    BuildContext context,
    WidgetRef ref,
    String workspaceId,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n?.kioskRevertTitle ?? 'Kiosk device'),
        content: Text(
          l10n?.kioskRevertDesc ??
              'This profile is set up as the workspace kiosk. Revert it '
                  'to a regular member to stop the kiosk question at '
                  'start.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('kiosk-revert-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n?.commonCancel ?? 'Cancel'),
          ),
          FilledButton(
            key: const ValueKey('kiosk-revert-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n?.memberUnmakeKiosk ?? 'Revert kiosk to member'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(workspaceRepositoryProvider).unsetMyKiosk(workspaceId);
    } catch (e, st) {
      debugPrint('kiosk revert failed: $e\n$st');
      TraceLogger.instance.error(
        'workspace',
        'kiosk revert failed',
        error: e,
        stackTrace: st,
      );
      if (!context.mounted) return;
      AppSnack.error(
        context,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      );
      return;
    }
    ref
      ..invalidate(myMemberProvider)
      ..invalidate(workspaceMembersProvider);
    if (!context.mounted) return;
    AppSnack.success(
      context,
      l10n?.kioskRevertDone ?? 'This profile is a regular member again.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final myProfile = ref.watch(myProfileProvider).value;
    final myMember = ref.watch(myMemberProvider).value;
    final canAdminister =
        ref.watch(myMemberProvider).value?.canAdminister ?? false;
    // #982/#1307 — the matrix decides what the sections show, never
    // `isOwner || canAdminister`.
    final perms = ref.watch(myPermissionsProvider);
    final devMode = ref.watch(devModeProvider).value ?? false;
    final features = ref.watch(enabledFeaturesSyncProvider);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      // #1598 — the screen answers to the name the entry used. It is the
      // same screen and the same route either way: the sections below
      // have asked the permission matrix since #1307, so a member who
      // administers nothing was always shown their account alone — this
      // stops calling that page Settings.
      appBar: AppBar(
        title: Text(showsMemberAccountMenu(
                features: features, permissions: perms)
            ? (l10n?.memberAccountTitle ?? 'My account')
            : (l10n?.settingsTitle ?? 'Settings')),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.switch_account_outlined),
            title: Text(l10n?.profilesTitle ?? 'Profiles'),
            onTap: () => context.push('/profiles'),
          ),
          const Divider(),
          SettingsSectionHeader(l10n?.settingsSectionAccount ?? 'My account'),
          // #1823 — the account's own rows live in Me; this space keeps
          // its exception and the way there.
          ...spaceAccountTiles(context, ref),
          ..._membershipTiles(context, ref, l10n: l10n, myProfile: myProfile, myMember: myMember, features: features),
          ...workspaceSettingsTiles(context, ref, l10n: l10n, canAdminister: canAdminister, perms: perms, features: features,
              isOwner: myMember?.isOwner ?? false,
              hasTwin: ref.watch(currentWorkspaceProvider).value?.pairId.isNotEmpty ?? false),
          ...advancedSettingsTiles(context, ref, l10n: l10n, devMode: devMode),
          ...aboutSettingsTiles(context, ref, l10n: l10n, colorScheme: colorScheme),
        ],
      ),
    );
  }

  /// #1307 — My membership: my standing in THIS workspace.
  List<Widget> _membershipTiles(
    BuildContext context,
    WidgetRef ref, {
    required AppLocalizations? l10n,
    required Profile? myProfile,
    required Member? myMember,
    required Set<WorkspaceFeature> features,
  }) =>
      [
          const Divider(),
          SettingsSectionHeader(l10n?.settingsSectionMembership ?? 'My membership'),
          // #662 — the member's own half of badge sign-in: the card and
          // the PIN are two halves of one credential of THIS membership,
          // so they stay with the space (#1823). #763 — the help dot rides
          // beside the tiles under their own visibility rule.
          if (myMember case final me?
              when me.status == MemberStatus.active && !me.isKiosk) ...[
            Row(
              children: [
                const Expanded(child: MyBadgeTile()),
                HelpDot(l10n?.helpHintBadgesTopic ?? 'NFC badges',
                  anchor: HelpAnchor.profileBadge,
                ),
              ],
            ),
            Row(
              children: [
                const Expanded(child: BadgePinTile()),
                HelpDot(l10n?.helpHintBadgesTopic ?? 'NFC badges',
                  anchor: HelpAnchor.profileBadgePin,
                ),
              ],
            ),
          ],
          // Self-set status line on my profile (#231): shown next to me
          // in the member directory (#232). Sits with WhatsApp in the
          // ungrouped personal area on top.
          ListTile(
            leading: const Icon(Icons.mood_outlined),
            title: HelpDotTitle(
              l10n?.profileStatusTitle ?? 'Status',
              l10n?.helpTopicSettings ?? 'Settings & profile',
              anchor: HelpAnchor.profileStatus,
            ),
            subtitle: Text(
              (myProfile?.hasStatus ?? false)
                  ? myProfile!.statusText
                  : (l10n?.profileStatusNone ?? 'No status'),
            ),
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => const _StatusDialog(),
            ),
          ),
          // #586 — the member's default reservation period; only shown
          // when the workspace's booking configuration offers a choice.
          if (defaultPeriodChoicesFor(
            ref.watch(bookingGranularityProvider).value ??
                BookingGranularity.flexible,
          ).isNotEmpty)
            ListTile(
              key: const ValueKey('settings-default-period'),
              leading: const Icon(Icons.schedule_outlined),
              title: HelpDotTitle(
                l10n?.defaultPeriodTitle ?? 'Default booking period',
                l10n?.helpTopicSettings ?? 'Settings & profile',
                anchor: HelpAnchor.profileDefaultPeriod,
              ),
              subtitle: Text(switch (ref.watch(defaultPeriodProvider).value) {
                DefaultBookingPeriod.morning =>
                  lexiconText(context, key: 'planMorningChip', fallback: l10n?.planMorningChip ?? 'Morning'),
                DefaultBookingPeriod.afternoon =>
                  lexiconText(context, key: 'planAfternoonChip', fallback: l10n?.planAfternoonChip ?? 'Afternoon'),
                DefaultBookingPeriod.fullDay =>
                  lexiconText(context, key: 'reserveFullDayChip', fallback: l10n?.reserveFullDayChip ?? 'Full day'),
                null => l10n?.defaultPeriodNone ?? 'No preference (full day)',
              }),
              onTap: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => SimpleDialog(
                  title: HelpDotTitle(
                    l10n?.defaultPeriodTitle ?? 'Default booking period',
                    l10n?.helpTopicSettings ?? 'Settings & profile',
                    anchor: HelpAnchor.profileDefaultPeriod,
                  ),
                  children: [
                    for (final (period, label) in [
                      (
                        null,
                        l10n?.defaultPeriodNone ?? 'No preference (full day)',
                      ),
                      (
                        DefaultBookingPeriod.morning,
                        lexiconText(context, key: 'planMorningChip', fallback: l10n?.planMorningChip ?? 'Morning'),
                      ),
                      (
                        DefaultBookingPeriod.afternoon,
                        lexiconText(context, key: 'planAfternoonChip', fallback: l10n?.planAfternoonChip ?? 'Afternoon'),
                      ),
                      (
                        DefaultBookingPeriod.fullDay,
                        lexiconText(context, key: 'reserveFullDayChip', fallback: l10n?.reserveFullDayChip ?? 'Full day'),
                      ),
                    ])
                      SimpleDialogOption(
                        key: ValueKey(
                          'default-period-${period?.wire ?? 'none'}',
                        ),
                        onPressed: () {
                          ref
                              .read(defaultPeriodProvider.notifier)
                              .select(period);
                          Navigator.of(dialogContext).pop();
                        },
                        child: Text(label),
                      ),
                  ],
                ),
              ),
            ),
          // #881/#902 — the conditions this member's documents print.
          // The workspace sets the default (Workspace → Legal identity);
          // an authorised admin changes a member's own through
          // validation; the member reads them here.
          if (myMember != null &&
              features.contains(WorkspaceFeature.memberPaymentTerms))
            ListTile(
              key: const ValueKey('settings-payment-terms'),
              leading: const Icon(Icons.request_quote_outlined),
              title: HelpDotTitle(
                l10n?.paymentTermsTitle ?? 'Payment conditions',
                l10n?.helpTopicSettings ?? 'Settings & profile',
                anchor: HelpAnchor.profilePaymentTerms,
              ),
              subtitle: Text(myMember.paymentTerms == null
                  ? (l10n?.paymentTermsInherited ?? 'Workspace default')
                  : (l10n?.paymentTermsOverridden ?? "Member's own")),
              onTap: () => context.push('/settings/payment-terms'),
            ),
          // #500 — the document library: everyone sees it (their role
          // filters the content server-side).
          if (features.contains(WorkspaceFeature.documents))
            ListTile(
              key: const ValueKey('settings-documents'),
              leading: const Icon(Icons.folder_open_outlined),
              title: Text(l10n?.documentsTitle ?? 'Documents'),
              onTap: () => context.push('/documents'),
            ),
          // Kiosk escape hatch (0056, field report: "cannot be undone"):
          // a profile flagged as kiosk reverts ITSELF to a regular
          // member right here — the kiosk gate stops appearing on start.
          if (ref.watch(myMemberProvider).value case final me? when me.isKiosk)
            ListTile(
              key: const ValueKey('settings-kiosk-revert'),
              leading: const Icon(Icons.tablet_mac_outlined),
              title: Text(l10n?.kioskRevertTitle ?? 'Kiosk device'),
              subtitle: Text(
                l10n?.kioskRevertDesc ??
                    'This profile is set up as the workspace kiosk. '
                        'Revert it to a regular member to stop the kiosk '
                        'question at start.',
              ),
              onTap: () => _revertKiosk(context, ref, me.workspaceId),
            ),
      ];

  /// #1154 — the Advanced section — backend, push, developer, demo mode. One of the four slices of a build() that was 723
  /// lines long; the tiles are unchanged, only the list is cut.
}



/// Editor for the self-set status line on my profile (#231). The raw
/// input is trimmed + hard-capped by [normalizeStatusText] on save (the
/// field's maxLength already blocks typing past the cap); an emptied
/// field clears the status. Follows the settings dialog pattern
/// (_WhatsappDialog) with an explicit Save.
class _StatusDialog extends ConsumerStatefulWidget {
  const _StatusDialog();

  @override
  ConsumerState<_StatusDialog> createState() => _StatusDialogState();
}

class _StatusDialogState extends ConsumerState<_StatusDialog> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(myProfileProvider).value?.statusText ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateStatusText(normalizeStatusText(_controller.text));
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnack.success(context, l10n?.profileStatusSaved ?? 'Status saved');
    } catch (e, st) {
      debugPrint('status save failed: $e\n$st');
      TraceLogger.instance.error(
        'profile',
        'status save failed',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnack.error(
        context,
        l10n?.profileStatusSaveFailed ?? 'Could not save the status',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n?.profileStatusTitle ?? 'Status'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: StatusTextRules.maxLength,
        decoration: InputDecoration(
          labelText: l10n?.profileStatusFieldLabel ?? 'Status',
          hintText: l10n?.profileStatusHint ?? 'In a call · back at 14:00',
          helperText:
              l10n?.profileStatusHelper ??
              'Optional. Visible to members of your workspaces in the '
                  'member directory. Leave empty to clear it.',
          helperMaxLines: 3,
          suffixIcon: HelpDot(l10n?.helpTopicSettings ?? 'Settings & profile',
            anchor: HelpAnchor.profileStatus,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(l10n?.commonSave ?? 'Save'),
        ),
      ],
    );
  }
}



