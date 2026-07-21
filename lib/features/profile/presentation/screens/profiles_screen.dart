// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/providers/workspace_providers.dart';

/// Profile switcher à la tankstellen (#89): each membership is a profile —
/// a workspace plus the role held there. The active profile shapes the
/// whole app; the choice persists across restarts.
class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  String _roleLabel(AppLocalizations? l10n, Member member) {
    if (member.isOwner) return l10n?.memberRoleOwner ?? 'Owner';
    if (member.isAdmin) return l10n?.memberRoleAdmin ?? 'Admin';
    return l10n?.memberRoleMember ?? 'Member';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final workspaces = ref.watch(myWorkspacesProvider).value ?? const [];
    final memberships = ref.watch(myMembershipsProvider).value ?? const [];
    final active = ref.watch(currentWorkspaceProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.profilesTitle ?? 'Profiles')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/onboarding'),
        icon: const Icon(Icons.add),
        label: Text(l10n?.profilesAdd ?? 'Add a profile'),
      ),
      body: ListView(
        padding: AppSpacing.mdAll,
        children: [
          for (final workspace in workspaces)
            Builder(
              builder: (context) {
                final member = memberships
                    .where((m) => m.workspaceId == workspace.id)
                    .firstOrNull;
                final isActive = workspace.id == active?.id;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        workspace.name.isEmpty
                            ? '?'
                            : workspace.name.substring(0, 1).toUpperCase(),
                      ),
                    ),
                    title: Text(workspace.name),
                    subtitle: Wrap(
                      spacing: 8,
                      children: [
                        if (member != null)
                          Chip(
                            label: Text(_roleLabel(l10n, member)),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        Text(
                          workspace.inviteCode,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    trailing: isActive
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                            semanticLabel:
                                l10n?.profilesActive ?? 'Active profile',
                          )
                        : null,
                    onTap: isActive
                        ? null
                        : () async {
                            await ref
                                .read(activeWorkspaceIdProvider.notifier)
                                .select(workspace.id);
                          },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
