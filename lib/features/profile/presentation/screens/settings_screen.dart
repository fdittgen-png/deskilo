// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';

/// App settings. Sign-out lives here; more sections arrive with their Epics.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isOwner = ref.watch(myMemberProvider).value?.isOwner ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(l10n?.settingsTitle ?? 'Settings')),
      body: ListView(
        children: [
          if (isOwner)
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: Text(l10n?.membersTitle ?? 'Members & plans'),
              onTap: () => context.push('/members'),
            ),
          if (isOwner)
            ListTile(
              leading: const Icon(Icons.qr_code_2),
              title: Text(l10n?.workspaceCodeTitle ?? 'Workspace ID & QR'),
              onTap: () => context.push('/workspace-code'),
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
