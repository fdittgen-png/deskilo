// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — Me › Me: who I am, who sees it, how the app speaks to me, and
// the doors to my own history — none of it any space's to decide.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../auth/providers/sign_out.dart';
import '../../profile/presentation/screens/settings_screen.dart';
import '../../profile/presentation/widgets/settings_section_header.dart';
import '../../task_recorder/presentation/route_classification.dart'
    show taskWizardRoute;
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
import 'blocked_people_card.dart';
import 'visibility_card.dart';

class MeAccountTab extends ConsumerWidget {
  const MeAccountTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    Widget door(String key, IconData icon, String title, String path) =>
        ListTile(
          key: ValueKey(key),
          leading: Icon(icon),
          title: Text(title),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(path),
        );
    return Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
        key: const ValueKey('me-account-list'),
        children: [
          // #1846 — four groups: who others see, what is private to the
          // account, the spaces it belongs to, the installations it uses.
          SettingsSectionHeader(l10n?.meGroupProfile ?? 'My profile'),
          ...accountSettingsTiles(context, ref, only: AccountTileGroup.profile),
          const VisibilityCard(),
          const BlockedPeopleCard(),
          SettingsSectionHeader(l10n?.settingsSectionAccount ?? 'My account'),
          ...accountSettingsTiles(context, ref, only: AccountTileGroup.account),
          door('me-activity', Icons.account_balance_wallet_outlined,
              l10n?.financesTitle ?? 'Finances',
              '/account-activity'),
          door('me-privacy', Icons.shield_outlined,
              l10n?.privacyTitle ?? 'Privacy & data', '/privacy'),
          // The task wizard: recording, guides and tools in one place.
          if (ref
              .watch(enabledFeaturesSyncProvider)
              .contains(WorkspaceFeature.taskRecorder))
            door('me-task-wizard', Icons.assistant_navigation,
                l10n?.taskWizardTitle ?? 'Task wizard', taskWizardRoute),
          SettingsSectionHeader(l10n?.meGroupWorkspaces ?? 'My workspaces'),
          door('me-workspaces', Icons.workspaces_outline,
              l10n?.meGroupWorkspaces ?? 'My workspaces', '/profiles'),
          SettingsSectionHeader(
              l10n?.meGroupInstallations ?? 'Connected installations'),
          door('me-servers', Icons.dns_outlined,
              l10n?.meWhereSpacesLive ?? 'Where my spaces live', '/connections'),
          ...accountSettingsTiles(context, ref,
              only: AccountTileGroup.installations),
          const Divider(),
          door('me-help', Icons.help_outline, l10n?.helpTitle ?? 'Help', '/help'),
          const Divider(),
          ListTile(
            key: const ValueKey('me-sign-out'),
            leading: Icon(Icons.logout, color: scheme.error),
            title: Text(
              l10n?.authSignOut ?? 'Sign out',
              style: TextStyle(color: scheme.error),
            ),
            onTap: () => signOutAndForget(ref),
          ),
        ],
      ),
        ),
      ),
    );
  }
}
