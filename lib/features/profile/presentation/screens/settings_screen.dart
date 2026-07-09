// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/locale/locale_controller.dart';
import '../../../../core/trace/dev_mode.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isOwner = ref.watch(myMemberProvider).value?.isOwner ?? false;
    final devMode = ref.watch(devModeProvider).value ?? false;
    final localeOverride = ref.watch(localeControllerProvider).value;
    final features = ref.watch(enabledFeaturesSyncProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n?.settingsTitle ?? 'Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.switch_account_outlined),
            title: Text(l10n?.profilesTitle ?? 'Profiles'),
            onTap: () => context.push('/profiles'),
          ),
          if (isOwner)
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
          if (isOwner && features.contains(WorkspaceFeature.services))
            ListTile(
              leading: const Icon(Icons.local_cafe_outlined),
              title: Text(l10n?.servicesTitle ?? 'Services'),
              onTap: () => context.push('/services'),
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
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l10n?.authSignOut ?? 'Sign out'),
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
