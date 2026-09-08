// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../workspace/domain/workspace.dart';
import '../../../workspace/domain/site.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/presentation/member_admin_actions.dart';
import '../../../workspace/domain/workspace_overview.dart';
import '../widgets/pair_card.dart';
import '../widgets/workspace_owners_sheet.dart';

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
    final defaultId = ref.watch(defaultWorkspaceIdProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.profilesTitle ?? 'Profiles'),
        actions: [
          // #763 — one dot for the whole switcher, in the app bar.
          HelpDot(l10n?.helpTopicSettings ?? 'Settings & profile',
            anchor: HelpAnchor.profileProfiles,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/onboarding'),
        icon: const Icon(Icons.add),
        label: Text(l10n?.profilesAdd ?? 'Add a profile'),
      ),
      body: ListView(
        padding: AppSpacing.mdAll,
        children: [
          // #987 — a paired workspace renders once, as the couple, at
          // the dev's place; the prod row steps aside.
          for (final workspace in workspaces)
            if (_pairedTwin(workspaces, workspace) case final twin?)
              if (workspace.isDevelopment)
                WorkspacePairCard(
                  dev: workspace,
                  prod: twin,
                  activeId: active?.id,
                  roleLabel: memberships
                      .where((m) =>
                          m.workspaceId == (active?.id == twin.id ? twin.id : workspace.id))
                      .map((m) => _roleLabel(l10n, m))
                      .firstOrNull,
                  onSelect: (id) => ref
                      .read(activeWorkspaceIdProvider.notifier)
                      .select(id),
                )
              else
                const SizedBox.shrink()
            else
            Builder(
              builder: (context) {
                final member = memberships
                    .where((m) => m.workspaceId == workspace.id)
                    .firstOrNull;
                final isActive = workspace.id == active?.id;
                return Card(
                  child: ListTile(
                    // #917 — the environment, at a glance and before
                    // the tap: green is a real workspace, orange one to
                    // try things out in. Colour alone never carries a
                    // state (spec §11), so the tooltip names it too.
                    leading: Tooltip(
                      message: workspace.isDevelopment
                          ? (l10n?.environmentDev ?? 'Development')
                          : (l10n?.environmentProd ?? 'Production'),
                      child: CircleAvatar(
                        key: ValueKey('profile-env-${workspace.id}'),
                        backgroundColor: workspace.isDevelopment
                            ? AppEnvironmentColors.developmentOf(
                                Theme.of(context).brightness)
                            : AppEnvironmentColors.productionOf(
                                Theme.of(context).brightness),
                        foregroundColor: Colors.white,
                        child: Text(
                          workspace.name.isEmpty
                              ? '?'
                              : workspace.name.substring(0, 1).toUpperCase(),
                        ),
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
                        // #974 — the home site, and a tap to change it,
                        // once the workspace has more than one.
                        if (member != null &&
                            effectiveFeatures(resolveEnabledFeatures(
                                    workspace.featureFlags))
                                .contains(WorkspaceFeature.multiSite))
                          _HomeSiteLine(member: member),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Default-at-startup star (#322): radio
                        // semantics — checking one replaces the
                        // previous; tapping the checked star clears it
                        // (last-active behavior returns).
                        IconButton(
                          key: ValueKey('profile-default-${workspace.id}'),
                          tooltip: workspace.id == defaultId
                              ? (l10n?.profilesDefault ??
                                  'Default at startup')
                              : (l10n?.profilesMakeDefault ??
                                  'Use as default at startup'),
                          icon: Icon(
                            workspace.id == defaultId
                                ? Icons.star
                                : Icons.star_border,
                            color: workspace.id == defaultId
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          onPressed: () => ref
                              .read(defaultWorkspaceIdProvider.notifier)
                              .toggle(workspace.id),
                        ),
                        if (isActive)
                          Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                            semanticLabel:
                                l10n?.profilesActive ?? 'Active profile',
                          ),
                      ],
                    ),
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
          // #937 — the platform owner sees every other workspace in the
          // database, greyed out: not theirs to enter, but theirs to
          // know about. Tapping one names its owners.
          if (ref.watch(isPlatformOwnerProvider).value ?? false) ...[
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.lg,
                bottom: AppSpacing.sm,
              ),
              child: Text(
                l10n?.profilesAllWorkspaces ?? 'Every workspace (platform owner)',
                key: const ValueKey('profiles-platform-section'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final overview
                in (ref.watch(allWorkspacesProvider).value ??
                        const <WorkspaceOverview>[])
                    .where((w) => !w.isMember))
              Opacity(
                opacity: 0.55,
                child: Card(
                  child: ListTile(
                    key: ValueKey('platform-workspace-${overview.id}'),
                    leading: const Icon(Icons.lock_outline),
                    title: Text(overview.name),
                    subtitle: Text(
                      '${overview.isDevelopment ? (l10n?.environmentDev ?? 'Development') : (l10n?.environmentProd ?? 'Production')}'
                      ' · ${l10n?.profilesNotMember(overview.memberCount) ?? 'Not a member · ${overview.memberCount} members'}',
                    ),
                    onTap: () => showWorkspaceOwnersSheet(context, ref, overview),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// #974 — "Site: Pézenas" under the profile, tappable when there is a
/// choice. Nothing at all while the workspace has a single site: one
/// site is not a choice and not worth a line.
class _HomeSiteLine extends ConsumerWidget {
  const _HomeSiteLine({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sites = ref.watch(sitesOfProvider(member.workspaceId)).value ??
        const <Site>[];
    if (sites.length < 2) return const SizedBox.shrink();
    final home = sites
            .where((s) => s.id == member.homeSiteId)
            .firstOrNull ??
        sites.where((s) => s.isDefault).firstOrNull ??
        sites.first;
    return ActionChip(
      key: ValueKey('profile-site-${member.workspaceId}'),
      avatar: const Icon(Icons.location_city_outlined, size: 16),
      label: Text(l10n?.profilesSiteLine(home.name) ?? 'Site: ${home.name}'),
      tooltip: l10n?.profilesSitePick ?? 'Change your site',
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onPressed: () => pickOwnHomeSite(context, ref, member),
    );
  }
}

/// #987 — the other side of [workspace]'s pair when it is in the list
/// and the couple is switched on; null for a lone workspace.
Workspace? _pairedTwin(List<Workspace> all, Workspace workspace) {
  if (workspace.pairId.isEmpty) return null;
  if (!effectiveFeatures(resolveEnabledFeatures(workspace.featureFlags))
      .contains(WorkspaceFeature.environmentPairs)) {
    return null;
  }
  return all
      .where((w) => w.pairId == workspace.pairId && w.id != workspace.id)
      .firstOrNull;
}
