// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1307 — My account: who I am and how the app looks and speaks to me,
// on every workspace. Never carried by a template.
//
// #1823 — it moved out of the workspace's Settings into Me, the account
// layer, where it can be reached with no workspace at all. A space's
// Settings keep only what is the space's: the badge and PIN of that
// membership, and the per-space override of language, theme and formats,
// shown as the exception it is.
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_classes.dart';
import '../../../../core/files/file_picker.dart';
import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/help/help_hint_providers.dart';
import '../../../../core/i18n/regional_formats_section.dart';
import '../../../../core/navigation/navigation_style.dart';
import '../../../../core/privacy/recording_banner.dart';
import '../../../../core/country/country_catalog.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../mcp/presentation/widgets/mcp_settings_tiles.dart';
import '../../../members/providers/directory_providers.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/presentation/country_names.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/personal_preferences.dart';
import '../../domain/profile.dart';
import '../../providers/personal_appearance_providers.dart';
import '../../providers/personal_preferences_providers.dart';
import '../../providers/profile_providers.dart';
import 'member_avatar.dart';
import 'preference_scope_controls.dart';
import 'whatsapp_dialog.dart';

part 'account_settings_dialogs.dart';

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
    await ref.read(myProfileEditsProvider).setPhoto(bytes, contentType: file.mimeType);
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
    await ref.read(myProfileEditsProvider).removePhoto();
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

/// The language row; [defaultsOnly] writes the account's defaults.
Widget _languageTile(BuildContext context, WidgetRef ref,
    {required bool defaultsOnly}) {
  final l10n = AppLocalizations.of(context);
  final localeOverride = ref.watch(personalLocaleProvider);
  return ListTile(
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
      builder: (_) => _LanguageDialog(defaultsOnly: defaultsOnly),
    ),
  );
}

/// The theme row; [defaultsOnly] writes the account's defaults.
Widget _themeTile(BuildContext context, WidgetRef ref,
    {required bool defaultsOnly}) {
  final l10n = AppLocalizations.of(context);
  return ListTile(
    leading: const Icon(Icons.brightness_6_outlined),
    title: HelpDotTitle(
      l10n?.themeTitle ?? 'Theme',
      l10n?.helpTopicSettings ?? 'Settings & profile',
      anchor: HelpAnchor.profileTheme,
    ),
    subtitle: Text(switch (ref.watch(personalThemeProvider)) {
      ThemeMode.light => l10n?.themeLight ?? 'Light',
      ThemeMode.dark => l10n?.themeDark ?? 'Dark',
      _ => l10n?.themeSystem ?? 'System default',
    }),
    onTap: () => showDialog<void>(
      context: context,
      builder: (_) => _ThemeDialog(defaultsOnly: defaultsOnly),
    ),
  );
}

/// Me › Me: the account's own rows. Rows that need a space (personal
/// information with its space's questions, formats) appear once there is
/// one; a space's feature that is off keeps its row off, as in Settings.
List<Widget> accountSettingsTiles(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context);
  final myProfile = ref.watch(myProfileProvider).value;
  final features = ref.watch(enabledFeaturesSyncProvider);
  final inSpace = ref.watch(currentWorkspaceProvider).value != null;
  return [
    // Profile photo (0038): shown on my directory row and detail sheet.
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
    // #886 — the structured identity: name, postal block, contacts. The
    // legacy free-text address dialog stays while the flag is off.
    if (inSpace && features.contains(WorkspaceFeature.personalInfo))
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
    // Opt-in WhatsApp number on my profile (#223), shared with members of
    // my workspaces. Rides the whatsappIntegration feature.
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
    // In-app language (#147) and theme (#160) overrides: the defaults.
    _languageTile(context, ref, defaultsOnly: true),
    _themeTile(context, ref, defaultsOnly: true),
    // #711 — Region & formats, behind the regionalFormats feature.
    if (inSpace && features.contains(WorkspaceFeature.regionalFormats))
      const RegionalFormatsSection(),
    // Linked accounts (0051): Google/Microsoft/Apple/Facebook sign-in.
    ListTile(
      key: const ValueKey('settings-linked-accounts'),
      leading: const Icon(Icons.link),
      title: Text(l10n?.linkedAccountsTitle ?? 'Linked accounts'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/linked-accounts'),
    ),
    const McpSettingsTiles(),
    // #969 — how the app navigates: the classic bar or the menu. Never on
    // the web, which has the menu and only the menu.
    if (!ref.watch(platformIsWebProvider) &&
        features.contains(WorkspaceFeature.navigationStyle))
      ListTile(
        key: const ValueKey('settings-navigation'),
        leading: const Icon(Icons.menu_open_outlined),
        title: HelpDotTitle(
          l10n?.navigationTitle ?? 'Navigation',
          l10n?.helpTopicSettings ?? 'Settings & profile',
          anchor: HelpAnchor.profileNavigation,
        ),
        subtitle: Text(switch (ref.watch(navigationStyleControllerProvider).value) {
          NavigationStyle.classic =>
            l10n?.navigationClassic ?? 'Classic: the bottom bar and the round button',
          NavigationStyle.menu =>
            l10n?.navigationMenu ?? 'Menu: the hamburger, like the web',
          _ => l10n?.navigationDefault ?? 'Default for this device',
        }),
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => const _NavigationDialog(),
        ),
      ),
    // #606 — bring every dismissed contextual hint back. Rides the same
    // flag as the hints themselves: no hints, no row.
    if (features.contains(WorkspaceFeature.formHelpHints))
      ListTile(
        key: const ValueKey('settings-restore-hints'),
        leading: const Icon(Icons.lightbulb_outline),
        title: HelpDotTitle(
          l10n?.helpHintRestoreTitle ?? 'Show help hints again',
          l10n?.helpTopicSettings ?? 'Settings & profile',
          anchor: HelpAnchor.profileRestoreHints,
        ),
        onTap: () async {
          await ref.read(dismissedHelpHintsProvider.notifier).restoreAll();
          if (!context.mounted) return;
          AppSnack.success(
            context,
            l10n?.helpHintRestored ?? 'Help hints will be shown again.',
          );
        },
      ),
  ];
}

/// #1823 — what a space's Settings keep of My account: the way to Me,
/// the per-space override named as the exception it is, and — while the
/// scope switch is on — the rows that edit it.
List<Widget> spaceAccountTiles(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context);
  final features = ref.watch(enabledFeaturesSyncProvider);
  final scoped = ref.watch(workspacePreferenceEditingProvider);
  final overrides =
      ref.watch(personalSettingsProvider).value?.overrides ?? const {};
  final named = <String>[
    if (overrides[PersonalPreference.uiLocale] case final code?)
      '${l10n?.languageTitle ?? 'Language'}: ${_endonyms[code] ?? code}',
    if (overrides[PersonalPreference.theme] case final mode?)
      '${l10n?.themeTitle ?? 'Theme'}: ${switch (mode) {
        'light' => l10n?.themeLight ?? 'Light',
        'dark' => l10n?.themeDark ?? 'Dark',
        _ => l10n?.themeSystem ?? 'System default',
      }}',
    if (overrides.keys.any(const {
      PersonalPreference.formatLocale,
      PersonalPreference.clock,
      PersonalPreference.timeZoneMode,
    }.contains))
      l10n?.regionalFormatsTitle ?? 'Region & formats',
  ];
  final exception = named.join(' · ');
  return [
    ListTile(
      key: const ValueKey('settings-open-me'),
      leading: const Icon(Icons.person_outline),
      title: Text(l10n?.meAccountInMe ?? 'My account is in Me'),
      subtitle: Text(l10n?.meAccountInMeBody ??
          'Photo, language, theme and sign-ins are yours in every space.'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.go('$kMeHome?tab=me'),
    ),
    if (named.isNotEmpty)
      ListTile(
        key: const ValueKey('settings-space-exception'),
        leading: const Icon(Icons.rule_outlined),
        title: Text(l10n?.meSpaceException ?? 'In this space'),
        subtitle: Text(exception),
      ),
    const PreferenceScopeControls(),
    if (scoped) ...[
      _languageTile(context, ref, defaultsOnly: false),
      _themeTile(context, ref, defaultsOnly: false),
      if (features.contains(WorkspaceFeature.regionalFormats))
        const RegionalFormatsSection(),
    ],
  ];
}
