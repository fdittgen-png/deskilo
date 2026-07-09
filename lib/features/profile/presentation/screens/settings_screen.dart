// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/trace/dev_mode.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';

/// App settings. Sign-out lives here; more sections arrive with their Epics.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isOwner = ref.watch(myMemberProvider).value?.isOwner ?? false;
    final devMode = ref.watch(devModeProvider).value ?? false;
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
