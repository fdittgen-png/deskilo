// SPDX-License-Identifier: 0BSD
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/files/file_picker.dart';
import '../../../../core/locale/locale_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/trace/dev_mode.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../members/providers/directory_providers.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/profile.dart';
import '../../providers/profile_providers.dart';
import '../widgets/member_avatar.dart';

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
      final file = await pick(XTypeGroup(
        label: l10n?.profilePhotoFileType ?? 'Image',
        extensions: const ['jpg', 'jpeg', 'png', 'webp'],
        mimeTypes: const ['image/jpeg', 'image/png', 'image/webp'],
      ));
      if (file == null) return; // cancelled
      final bytes = await file.readAsBytes();
      await ref.read(profileRepositoryProvider).setAvatar(
            bytes: bytes,
            contentType: file.mimeType ?? 'image/jpeg',
          );
      _invalidateAvatar(ref, userId);
      if (!context.mounted) return;
      AppSnack.success(context, l10n?.profilePhotoSaved ?? 'Photo updated');
    } catch (e, st) {
      debugPrint('profile photo upload failed: $e\n$st');
      TraceLogger.instance.error('profile', 'profile photo upload failed',
          error: e, stackTrace: st);
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
      TraceLogger.instance.error('profile', 'profile photo removal failed',
          error: e, stackTrace: st);
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final myProfile = ref.watch(myProfileProvider).value;
    final isOwner = ref.watch(myMemberProvider).value?.isOwner ?? false;
    final canAdminister =
        ref.watch(myMemberProvider).value?.canAdminister ?? false;
    final devMode = ref.watch(devModeProvider).value ?? false;
    final localeOverride = ref.watch(localeControllerProvider).value;
    final themeOverride = ref.watch(themeControllerProvider).value;
    final features = ref.watch(enabledFeaturesSyncProvider);
    // The administration section header is hidden when the member would see
    // none of its entries (#188). All entries are owner-only except
    // Accessories, which is canAdminister (#167).
    final showAdminSection = isOwner || canAdminister;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n?.settingsTitle ?? 'Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.switch_account_outlined),
            title: Text(l10n?.profilesTitle ?? 'Profiles'),
            onTap: () => context.push('/profiles'),
          ),
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
          // Member directory (#224): visible to EVERY member — it lives in
          // the ungrouped personal section, not under Administration. Kept
          // for discovery even though the directory is a bottom tab since
          // #230: go() switches to the Members branch (closing settings)
          // instead of pushing a second copy.
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: Text(l10n?.directoryTitle ?? 'Members'),
            onTap: () => context.go('/directory'),
          ),
          // Opt-in WhatsApp number on my profile (#223): shared with
          // members of my workspaces, consumed by the directory (#224).
          // Sits with Profiles in the ungrouped personal area on top.
          ListTile(
            leading: const Icon(Icons.chat_outlined),
            title: Text(l10n?.whatsappTitle ?? 'WhatsApp'),
            subtitle: Text(
              (myProfile?.sharesWhatsapp ?? false)
                  ? myProfile!.whatsapp
                  : (l10n?.whatsappNotShared ?? 'Not shared'),
            ),
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => const _WhatsappDialog(),
            ),
          ),
          // Self-set status line on my profile (#231): shown next to me
          // in the member directory (#232). Sits with WhatsApp in the
          // ungrouped personal area on top.
          ListTile(
            leading: const Icon(Icons.mood_outlined),
            title: Text(l10n?.profileStatusTitle ?? 'Status'),
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
          if (showAdminSection) ...[
            const Divider(),
            _SectionHeader(
              l10n?.settingsSectionAdministration ?? 'Administration',
            ),
          ],
          if (isOwner)
            ListTile(
              leading: const Icon(Icons.business_outlined),
              title: Text(l10n?.workspaceSettingsTitle ?? 'Workspace'),
              onTap: () => context.push('/workspace-settings'),
            ),
          if (showAdminSection)
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: Text(l10n?.membersTitle ?? 'Members & plans'),
              onTap: () => context.push('/members'),
            ),
          if (isOwner)
            ListTile(
              leading: const Icon(Icons.event_busy_outlined),
              title: Text(l10n?.availabilityTitle ?? 'Availability'),
              onTap: () => context.push('/availability'),
            ),
          // Feature-gated admin surfaces (#146 rule): the config screen for a
          // feature appears only while that feature is on — enable it in
          // Features to reveal its settings, disable it and the entry (and its
          // route) go with it. The master Features toggle below is always
          // reachable so a disabled feature can be switched back on.
          if (isOwner && features.contains(WorkspaceFeature.onlinePayments))
            ListTile(
              leading: const Icon(Icons.credit_card_outlined),
              title: Text(l10n?.payConfigTitle ?? 'Online payments'),
              onTap: () => context.push('/payment-config'),
            ),
          if (isOwner && features.contains(WorkspaceFeature.nfcBadges))
            ListTile(
              leading: const Icon(Icons.contactless_outlined),
              title: Text(l10n?.nfcConfigTitle ?? 'RFID / NFC badges'),
              onTap: () => context.push('/nfc-config'),
            ),
          if (isOwner && features.contains(WorkspaceFeature.services))
            ListTile(
              leading: const Icon(Icons.local_cafe_outlined),
              title: Text(l10n?.servicesTitle ?? 'Services'),
              onTap: () => context.push('/services'),
            ),
          // Accessory catalog (#167): owner AND admins, per the epic #163
          // decision — deliberately canAdminister, not owner-only. Gated on the
          // accessorySupplements feature (#170): the catalog only bites when
          // supplements bill, so no feature → no catalog surface.
          if (canAdminister &&
              features.contains(WorkspaceFeature.accessorySupplements))
            ListTile(
              leading: const Icon(Icons.devices_other_outlined),
              title: Text(l10n?.accessoriesTitle ?? 'Accessories'),
              onTap: () => context.push('/accessories'),
            ),
          if (isOwner)
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: Text(l10n?.billingTitle ?? 'Billing'),
              onTap: () => context.push('/billing'),
            ),
          if (isOwner)
            ListTile(
              leading: const Icon(Icons.toggle_on_outlined),
              title: Text(l10n?.featuresTitle ?? 'Features'),
              onTap: () => context.push('/features'),
            ),
          if (isOwner)
            ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: Text(l10n?.validationTitle ?? 'Validation rules'),
              onTap: () => context.push('/validation'),
            ),
          if (isOwner)
            ListTile(
              leading: const Icon(Icons.qr_code_2),
              title: Text(l10n?.workspaceCodeTitle ?? 'Workspace ID & QR'),
              onTap: () => context.push('/workspace-code'),
            ),
          const Divider(),
          _SectionHeader(l10n?.settingsSectionPreferences ?? 'Preferences'),
          // In-app language override (#147); null follows the system locale.
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n?.languageTitle ?? 'Language'),
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
            title: Text(l10n?.themeTitle ?? 'Theme'),
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
          // The dev-mode switch below is visible to everyone, so this
          // section header is never empty and needs no gating.
          const Divider(),
          _SectionHeader(l10n?.settingsSectionAdvanced ?? 'Advanced'),
          // Local diagnostics (#144) — deliberately visible to ALL users,
          // not just owners: the trace never leaves the device unless the
          // user exports it.
          SwitchListTile(
            secondary: const Icon(Icons.developer_mode_outlined),
            title: Text(l10n?.developerMode ?? 'Developer mode'),
            value: devMode,
            onChanged: (v) =>
                ref.read(devModeProvider.notifier).setEnabled(v),
          ),
          if (devMode)
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(l10n?.developerTitle ?? 'Developer'),
              onTap: () => context.push('/developer'),
            ),
          // Sign out sits apart from the sections, with the destructive
          // foreground treatment used elsewhere (colorScheme.error, as in
          // the billing validation message).
          const Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: colorScheme.error),
            title: Text(
              l10n?.authSignOut ?? 'Sign out',
              style: TextStyle(color: colorScheme.error),
            ),
            onTap: () async {
              await ref.read(authRepositoryProvider).signOut();
              // The router's auth redirect takes over from here.
            },
          ),
        ],
      ),
    );
  }
}

/// Material list-subheader for a titled settings section (#188). Matches
/// the ListTile content inset so headers align with the tiles below them.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Text(
        label,
        style: theme.textTheme.titleSmall
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
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
      title: Text(l10n?.languageTitle ?? 'Language'),
      children: [
        RadioGroup<String>(
          groupValue: current,
          onChanged: (code) {
            ref.read(localeControllerProvider.notifier).set(
                  code == null || code == _systemDefault
                      ? null
                      : Locale(code),
                );
            Navigator.of(context).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                value: _systemDefault,
                title:
                    Text(l10n?.languageSystemDefault ?? 'System default'),
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

/// Editor for the opt-in WhatsApp number on my profile (#223). The raw
/// input is normalized to `+` + digits by [normalizeWhatsapp] on save;
/// an emptied field clears the number (opt-out). Follows the settings
/// dialog pattern (_LanguageDialog/_ThemeDialog) with an explicit Save.
class _WhatsappDialog extends ConsumerStatefulWidget {
  const _WhatsappDialog();

  @override
  ConsumerState<_WhatsappDialog> createState() => _WhatsappDialogState();
}

class _WhatsappDialogState extends ConsumerState<_WhatsappDialog> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(myProfileProvider).value?.whatsapp ?? '',
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
          .updateWhatsapp(normalizeWhatsapp(_controller.text));
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnack.success(
        context,
        l10n?.whatsappSaved ?? 'WhatsApp number saved',
      );
    } catch (e, st) {
      debugPrint('WhatsApp save failed: $e\n$st');
      TraceLogger.instance.error('profile', 'WhatsApp save failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnack.error(
        context,
        l10n?.whatsappSaveFailed ?? 'Could not save the WhatsApp number',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n?.whatsappTitle ?? 'WhatsApp'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(
          labelText: l10n?.whatsappFieldLabel ?? 'WhatsApp number',
          hintText: l10n?.whatsappHint ?? '+33612345678',
          helperText: l10n?.whatsappHelper ??
              'Optional. Visible to members of your workspaces. '
                  'Leave empty to stop sharing it.',
          helperMaxLines: 3,
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _saving ? null : () => Navigator.of(context).pop(),
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
      AppSnack.success(
        context,
        l10n?.profileStatusSaved ?? 'Status saved',
      );
    } catch (e, st) {
      debugPrint('status save failed: $e\n$st');
      TraceLogger.instance.error('profile', 'status save failed',
          error: e, stackTrace: st);
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
          hintText:
              l10n?.profileStatusHint ?? 'In a call · back at 14:00',
          helperText: l10n?.profileStatusHelper ??
              'Optional. Visible to members of your workspaces in the '
                  'member directory. Leave empty to clear it.',
          helperMaxLines: 3,
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _saving ? null : () => Navigator.of(context).pop(),
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
      title: Text(l10n?.themeTitle ?? 'Theme'),
      children: [
        RadioGroup<ThemeMode>(
          groupValue: current,
          onChanged: (mode) {
            ref.read(themeControllerProvider.notifier).set(
                  mode == null || mode == ThemeMode.system ? null : mode,
                );
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
