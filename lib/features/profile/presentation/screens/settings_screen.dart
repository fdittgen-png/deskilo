// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:file_selector/file_selector.dart';
import '../../../../core/l10n/lexicon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/files/file_picker.dart';
import '../../../../core/help/help_anchors.dart';
import '../../../../core/privacy/recording_banner.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/help/help_hint_providers.dart';
import '../../../../core/locale/locale_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/navigation/navigation_style.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/country/country_catalog.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/i18n/regional_formats_section.dart';
import '../../../workspace/presentation/country_names.dart';
import '../../../members/providers/directory_providers.dart';
import '../../../reservations/domain/default_booking_period.dart';
import '../../../reservations/providers/default_period_controller.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/domain/member.dart';
import '../../../auth/presentation/widgets/badge_pin_tile.dart';
import '../../../workspace/presentation/widgets/my_badge_tile.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/profile.dart';
import '../../providers/profile_providers.dart';
import '../widgets/member_avatar.dart';
import '../widgets/whatsapp_dialog.dart';
import '../widgets/settings_advanced_section.dart';
import '../widgets/settings_about_section.dart';
import '../widgets/settings_workspace_sections.dart';
import '../widgets/settings_section_header.dart';

/// Endonyms are proper nouns, identical in every UI language — deliberately
/// const strings, not l10n keys (#147). Order matches the issue spec.
const _endonyms = <String, String>{
  'de': 'Deutsch',
  'en': 'English',
  'fr': 'Français',
  'es': 'Español',
  'it': 'Italiano',
};

/// Radio sentinel for "follow the system locale" (the override itself is
/// null, which a radio group cannot use as a selectable value).
const _systemDefault = 'system';

/// App settings. Sign-out lives here; more sections arrive with their Epics.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Chooser for the profile photo (0038): pick a new one, or remove the
  /// current one when set.
  Future<void> _photoSheet(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
  ) async {
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_a_photo_outlined),
              title: Text(l10n?.profilePhotoChoose ?? 'Choose a photo'),
              onTap: () => Navigator.of(sheetContext).pop('choose'),
            ),
            if (profile.hasAvatar)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n?.profilePhotoRemove ?? 'Remove photo'),
                onTap: () => Navigator.of(sheetContext).pop('remove'),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'choose') {
      await _pickPhoto(context, ref, profile.id);
    } else {
      await _removePhoto(context, ref, profile.id);
    }
  }

  Future<void> _pickPhoto(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      final pick = ref.read(filePickerProvider);
      final file = await pick(
        XTypeGroup(
          label: l10n?.profilePhotoFileType ?? 'Image',
          extensions: const ['jpg', 'jpeg', 'png', 'webp'],
          mimeTypes: const ['image/jpeg', 'image/png', 'image/webp'],
        ),
      );
      if (file == null) return; // cancelled
      final bytes = await file.readAsBytes();
      await ref
          .read(profileRepositoryProvider)
          .setAvatar(bytes: bytes, contentType: file.mimeType ?? 'image/jpeg');
      _invalidateAvatar(ref, userId);
      if (!context.mounted) return;
      AppSnack.success(context, l10n?.profilePhotoSaved ?? 'Photo updated');
    } catch (e, st) {
      debugPrint('profile photo upload failed: $e\n$st');
      TraceLogger.instance.error(
        'profile',
        'profile photo upload failed',
        error: e,
        stackTrace: st,
      );
      if (!context.mounted) return;
      AppSnack.error(
        context,
        l10n?.profilePhotoSaveFailed ?? 'Could not update the photo',
      );
    }
  }

  Future<void> _removePhoto(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(profileRepositoryProvider).clearAvatar();
      _invalidateAvatar(ref, userId);
      if (!context.mounted) return;
      AppSnack.success(context, l10n?.profilePhotoRemoved ?? 'Photo removed');
    } catch (e, st) {
      debugPrint('profile photo removal failed: $e\n$st');
      TraceLogger.instance.error(
        'profile',
        'profile photo removal failed',
        error: e,
        stackTrace: st,
      );
      if (!context.mounted) return;
      AppSnack.error(
        context,
        l10n?.profilePhotoSaveFailed ?? 'Could not update the photo',
      );
    }
  }

  /// Refresh every surface that shows the avatar: my profile, the
  /// directory's profile map, and the cached bytes for this user.
  void _invalidateAvatar(WidgetRef ref, String userId) {
    ref
      ..invalidate(myProfileProvider)
      ..invalidate(memberProfilesProvider)
      ..invalidate(memberAvatarProvider(userId));
  }

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
    final localeOverride = ref.watch(localeControllerProvider).value;
    final themeOverride = ref.watch(themeControllerProvider).value;
    final features = ref.watch(enabledFeaturesSyncProvider);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n?.settingsTitle ?? 'Settings')),
      body: ListView(
        children: [
          ..._accountTiles(context, ref, l10n: l10n, myProfile: myProfile, features: features, localeOverride: localeOverride, themeOverride: themeOverride),
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

  /// #1307 — Profiles, then My account: who I am and how the app looks and
  /// speaks to me, on every workspace. Never carried by a template.
  List<Widget> _accountTiles(
    BuildContext context,
    WidgetRef ref, {
    required AppLocalizations? l10n,
    required Profile? myProfile,
    required Set<WorkspaceFeature> features,
    required Locale? localeOverride,
    required ThemeMode? themeOverride,
  }) =>
      [
          ListTile(
            leading: const Icon(Icons.switch_account_outlined),
            title: Text(l10n?.profilesTitle ?? 'Profiles'),
            onTap: () => context.push('/profiles'),
          ),
          const Divider(),
          SettingsSectionHeader(l10n?.settingsSectionAccount ?? 'My account'),
          // Profile photo (0038): shown on my directory row and detail
          // sheet. Tapping opens a chooser to set or remove it.
          if (myProfile != null)
            ListTile(
              key: const ValueKey('settings-photo'),
              leading: MemberAvatar(
                userId: myProfile.id,
                name: myProfile.displayName,
                hasAvatar: myProfile.hasAvatar,
                radius: 20,
              ),
              title: Text(l10n?.profilePhotoTitle ?? 'Photo'),
              subtitle: Text(
                myProfile.hasAvatar
                    ? (l10n?.profilePhotoSet ?? 'Tap to change')
                    : (l10n?.profilePhotoNone ?? 'Tap to add a photo'),
              ),
              onTap: () => _photoSheet(context, ref, myProfile),
            ),
          // #886 — the structured identity: name, postal block, contacts.
          // The legacy free-text address dialog stays while the flag is off.
          if (features.contains(WorkspaceFeature.personalInfo))
            ListTile(
              key: const ValueKey('settings-personal-info'),
              leading: const Icon(Icons.contact_mail_outlined),
              title: HelpDotTitle(
                l10n?.personalInfoTitle ?? 'Personal information',
                l10n?.helpTopicSettings ?? 'Settings & profile',
                anchor: HelpAnchor.profilePersonalInfo,
              ),
              subtitle: Text(
                _identitySummary(myProfile) ??
                    (l10n?.personalInfoNone ?? 'Not filled in yet'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => context.push('/settings/personal-info'),
            )
          else
            // Postal address (0060): printed on the member's invoices.
            ListTile(
              key: const ValueKey('settings-address'),
              leading: const Icon(Icons.home_outlined),
              title: HelpDotTitle(
                l10n?.addressTitle ?? 'Address',
                l10n?.helpTopicSettings ?? 'Settings & profile',
                anchor: HelpAnchor.profileAddress,
              ),
              subtitle: Text(
                (myProfile?.address.isNotEmpty ?? false)
                    ? myProfile!.address
                    : (l10n?.addressNone ?? 'No address'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => const _AddressDialog(),
              ),
            ),
          // Opt-in WhatsApp number on my profile (#223): shared with
          // members of my workspaces, consumed by the directory (#224).
          // Rides the whatsappIntegration feature (hierarchy pass).
          if (features.contains(WorkspaceFeature.whatsappIntegration))
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: HelpDotTitle(
                l10n?.whatsappTitle ?? 'WhatsApp',
                l10n?.helpTopicSettings ?? 'Settings & profile',
                anchor: HelpAnchor.profileWhatsapp,
              ),
              subtitle: Text(
                (myProfile?.sharesWhatsapp ?? false)
                    ? myProfile!.whatsapp
                    : (l10n?.whatsappNotShared ?? 'Not shared'),
              ),
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => const WhatsappDialog(),
              ),
            ),
          // #711 — Region & formats: numbers, dates, clock, zone. Gated by
          // the regionalFormats feature like every member preference the
          // owner may switch off.
          if (features.contains(WorkspaceFeature.regionalFormats))
            const RegionalFormatsSection(),
          // Linked accounts (0051): attach Google/Microsoft/Apple/
          // Facebook to this account for password-less sign-in.
          ListTile(
            key: const ValueKey('settings-linked-accounts'),
            leading: const Icon(Icons.link),
            title: Text(l10n?.linkedAccountsTitle ?? 'Linked accounts'),
            onTap: () => context.push('/linked-accounts'),
          ),
          // #662 — the member's own half of badge sign-in. Beside My
          // badge, because the card and the PIN are two halves of one
          // credential and a member who has one and not the other
          // cannot sign in. #763 — both tiles live in their own files;
          // the help dot rides beside them under the tiles' own
          // visibility rule so it never floats alone.
          if (ref.watch(myMemberProvider).value case final me?
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
          // In-app language override (#147); null follows the system locale.
          ListTile(
            leading: const Icon(Icons.language),
            title: HelpDotTitle(
              l10n?.languageTitle ?? 'Language',
              l10n?.helpTopicSettings ?? 'Settings & profile',
              anchor: HelpAnchor.profileLanguage,
            ),
            subtitle: Text(
              localeOverride == null
                  ? (l10n?.languageSystemDefault ?? 'System default')
                  : _endonyms[localeOverride.languageCode] ??
                        localeOverride.languageCode,
            ),
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => const _LanguageDialog(),
            ),
          ),
          // In-app theme override (#160); null follows the system.
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: HelpDotTitle(
              l10n?.themeTitle ?? 'Theme',
              l10n?.helpTopicSettings ?? 'Settings & profile',
              anchor: HelpAnchor.profileTheme,
            ),
            subtitle: Text(switch (themeOverride) {
              ThemeMode.light => l10n?.themeLight ?? 'Light',
              ThemeMode.dark => l10n?.themeDark ?? 'Dark',
              _ => l10n?.themeSystem ?? 'System default',
            }),
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => const _ThemeDialog(),
            ),
          ),
          // #969 — how the app navigates: the classic bar or the menu.
          // Never on the web, which has the menu and only the menu.
          if (!ref.watch(platformIsWebProvider) &&
              ref
                  .watch(enabledFeaturesSyncProvider)
                  .contains(WorkspaceFeature.navigationStyle))
            ListTile(
              key: const ValueKey('settings-navigation'),
              leading: const Icon(Icons.menu_open_outlined),
              title: HelpDotTitle(
                l10n?.navigationTitle ?? 'Navigation',
                l10n?.helpTopicSettings ?? 'Settings & profile',
                anchor: HelpAnchor.profileNavigation,
              ),
              subtitle: Text(switch (
                  ref.watch(navigationStyleControllerProvider).value) {
                NavigationStyle.classic =>
                  l10n?.navigationClassic ??
                      'Classic: the bottom bar and the round button',
                NavigationStyle.menu =>
                  l10n?.navigationMenu ?? 'Menu: the hamburger, like the web',
                _ => l10n?.navigationDefault ?? 'Default for this device',
              }),
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => const _NavigationDialog(),
              ),
            ),
          // #606 — bring every dismissed contextual hint back. Rides
          // the same flag as the hints themselves: no hints, no row.
          if (ref
              .watch(enabledFeaturesSyncProvider)
              .contains(WorkspaceFeature.formHelpHints))
            ListTile(
              key: const ValueKey('settings-restore-hints'),
              leading: const Icon(Icons.lightbulb_outline),
              title: HelpDotTitle(
                l10n?.helpHintRestoreTitle ?? 'Show help hints again',
                l10n?.helpTopicSettings ?? 'Settings & profile',
                anchor: HelpAnchor.profileRestoreHints,
              ),
              onTap: () async {
                await ref
                    .read(dismissedHelpHintsProvider.notifier)
                    .restoreAll();
                if (!context.mounted) return;
                AppSnack.success(
                  context,
                  l10n?.helpHintRestored ?? 'Help hints will be shown again.',
                );
              },
            ),
      ];

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

/// Radio picker for the app language. Selecting an option applies it
/// instantly (the MaterialApp rebuilds via [localeControllerProvider])
/// and persists it locally.
class _LanguageDialog extends ConsumerWidget {
  const _LanguageDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current =
        ref.watch(localeControllerProvider).value?.languageCode ??
        _systemDefault;
    return SimpleDialog(
      title: HelpDotTitle(
        l10n?.languageTitle ?? 'Language',
        l10n?.helpTopicSettings ?? 'Settings & profile',
        anchor: HelpAnchor.profileLanguage,
      ),
      children: [
        RadioGroup<String>(
          groupValue: current,
          onChanged: (code) {
            ref
                .read(localeControllerProvider.notifier)
                .set(
                  code == null || code == _systemDefault ? null : Locale(code),
                );
            Navigator.of(context).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                value: _systemDefault,
                title: Text(l10n?.languageSystemDefault ?? 'System default'),
              ),
              for (final entry in _endonyms.entries)
                RadioListTile<String>(
                  value: entry.key,
                  // Render each endonym under its own locale.
                  title: Text(entry.value, locale: Locale(entry.key)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Editor for the self-set status line on my profile (#231). The raw
/// input is trimmed + hard-capped by [normalizeStatusText] on save (the
/// field's maxLength already blocks typing past the cap); an emptied
/// field clears the status. Follows the settings dialog pattern
/// (_WhatsappDialog) with an explicit Save.
/// Edits the member's postal address (0060) — printed on invoices;
/// blank clears it.
class _AddressDialog extends ConsumerStatefulWidget {
  const _AddressDialog();

  @override
  ConsumerState<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends ConsumerState<_AddressDialog> {
  late final TextEditingController _controller;
  late final TextEditingController _vatId;
  String? _countryCode;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(myProfileProvider).value;
    _controller = TextEditingController(text: profile?.address ?? '');
    _vatId = TextEditingController(text: profile?.vatId ?? '');
    // 0069 — the country an EN 16931 invoice must state about the
    // customer (BT-55); unset means "wherever the workspace is".
    final stored = profile?.countryCode ?? '';
    _countryCode = stored.isEmpty ? null : stored;
  }

  @override
  void dispose() {
    _controller.dispose();
    _vatId.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // #1514 — this form was prefilled from the recording seam.
    if (refusedWhileRecording(context, ref)) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    if (!await runGuarded(
      context,
      domain: 'profile',
      message: 'address update failed',
      errorText:
          l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        // One write: one invoice block (#1532, and its repository doc).
        await ref.read(profileRepositoryProvider).updateInvoiceIdentity(
              address: _controller.text,
              countryCode: _countryCode ?? '',
              vatId: _vatId.text,
            );
      },
    )) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    ref.invalidate(myProfileProvider);
    if (!mounted) return;
    Navigator.of(context).pop();
    AppSnack.success(context, l10n?.addressSaved ?? 'Address saved');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      // The dot on the title covers the country dropdown too, whose
      // decoration already carries the dropdown arrow.
      title: HelpDotTitle(
        l10n?.addressTitle ?? 'Address',
        l10n?.helpTopicSettings ?? 'Settings & profile',
        anchor: HelpAnchor.profileAddress,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('address-field'),
              controller: _controller,
              maxLines: 3,
              maxLength: 400,
              decoration: InputDecoration(
                labelText: l10n?.addressTitle ?? 'Address',
                suffixIcon: HelpDot(
                  l10n?.helpTopicSettings ?? 'Settings & profile',
                  anchor: HelpAnchor.profileAddress,
                ),
              ),
            ),
            // 0069 — what the e-invoice needs beyond the street: the
            // country, and the VAT id of a member who invoices as a
            // business.
            DropdownButtonFormField<String>(
              key: const ValueKey('address-country'),
              initialValue: _countryCode,
              isExpanded: true,
              items: [
                for (final country in CountryCatalog.countries)
                  DropdownMenuItem(
                    value: country.code,
                    child: Text(localizedCountryName(l10n, country.code)),
                  ),
              ],
              onChanged: (value) => setState(() => _countryCode = value),
              decoration: InputDecoration(
                labelText: l10n?.addressCountryLabel ?? 'Country',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('address-vat-id'),
              controller: _vatId,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: l10n?.addressVatIdLabel ?? 'VAT number',
                suffixIcon: HelpDot(
                  l10n?.helpTopicSettings ?? 'Settings & profile',
                  anchor: HelpAnchor.profileVatId,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          key: const ValueKey('address-save'),
          onPressed: _saving ? null : _save,
          child: Text(l10n?.commonSave ?? 'Save'),
        ),
      ],
    );
  }
}

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

/// Radio picker for the app theme (#160). Selecting an option applies it
/// instantly (the MaterialApp rebuilds via [themeControllerProvider])
/// and persists it locally. [ThemeMode.system] doubles as the radio
/// sentinel for "no override" (the override itself is null).
class _ThemeDialog extends ConsumerWidget {
  const _ThemeDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current =
        ref.watch(themeControllerProvider).value ?? ThemeMode.system;
    return SimpleDialog(
      title: HelpDotTitle(
        l10n?.themeTitle ?? 'Theme',
        l10n?.helpTopicSettings ?? 'Settings & profile',
        anchor: HelpAnchor.profileTheme,
      ),
      children: [
        RadioGroup<ThemeMode>(
          groupValue: current,
          onChanged: (mode) {
            ref
                .read(themeControllerProvider.notifier)
                .set(mode == null || mode == ThemeMode.system ? null : mode);
            Navigator.of(context).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                value: ThemeMode.system,
                title: Text(l10n?.themeSystem ?? 'System default'),
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.light,
                title: Text(l10n?.themeLight ?? 'Light'),
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.dark,
                title: Text(l10n?.themeDark ?? 'Dark'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// #419: writes the workspace-wide dev mode and refreshes the row.

/// "Guilhem MARTIN · SASU KaloA, 209 rue Jean Bart…, 31670 LABÈGE" — the
/// tile's one-glance summary; null when nothing is filled in yet.
String? _identitySummary(Profile? profile) {
  if (profile == null || profile.identity.isEmpty) return null;
  final parts = [
    profile.fullName,
    profile.postalBlock().replaceAll('\n', ', '),
  ].where((p) => p.isNotEmpty);
  return parts.isEmpty ? null : parts.join(' · ');
}

/// #969 — radio picker for the shell's navigation. Null (the first
/// option) is the platform's default; a choice applies instantly, the
/// shell watches the controller.
class _NavigationDialog extends ConsumerWidget {
  const _NavigationDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(navigationStyleControllerProvider).value;
    return SimpleDialog(
      title: HelpDotTitle(
        l10n?.navigationTitle ?? 'Navigation',
        l10n?.helpTopicSettings ?? 'Settings & profile',
        anchor: HelpAnchor.profileNavigation,
      ),
      children: [
        RadioGroup<NavigationStyle?>(
          groupValue: current,
          onChanged: (style) {
            ref.read(navigationStyleControllerProvider.notifier).set(style);
            Navigator.of(context).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<NavigationStyle?>(
                key: const ValueKey('navigation-default'),
                value: null,
                title: Text(
                    l10n?.navigationDefault ?? 'Default for this device'),
              ),
              RadioListTile<NavigationStyle?>(
                key: const ValueKey('navigation-classic'),
                value: NavigationStyle.classic,
                title: Text(l10n?.navigationClassic ??
                    'Classic: the bottom bar and the round button'),
              ),
              RadioListTile<NavigationStyle?>(
                key: const ValueKey('navigation-menu'),
                value: NavigationStyle.menu,
                title: Text(l10n?.navigationMenu ??
                    'Menu: the hamburger, like the web'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
