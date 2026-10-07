// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — Me › Home: who I am, and the spaces I can walk into — this
// server's and every linked server's, the last one I used first.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/space_prefs_store.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/ui/empty_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/presentation/widgets/personal_avatar.dart';
import '../../profile/providers/profile_providers.dart';
import '../../visits/presentation/my_visits_section.dart';
import '../../workspace/domain/member.dart';
import '../../workspace/domain/workspace.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../providers/me_providers.dart';
import 'linked_spaces_section.dart';
import 'me_space_card.dart';
import 'space_row_controls.dart';
import '../providers/space_prefs_provider.dart';
import 'me_workspace_row.dart';
import '../../workspace/presentation/member_labels.dart';
import '../../workspace/presentation/widgets/workspace_avatar.dart';

class MeHomeTab extends ConsumerWidget {
  const MeHomeTab({super.key, required this.onDiscover});

  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spaces = ref.watch(myWorkspacesProvider).value ?? const <Workspace>[];
    final memberships =
        ref.watch(myMembershipsProvider).value ?? const <Member>[];
    final last = ref.watch(activeWorkspaceIdProvider).value;
    final linked = ref.watch(linkedServerSpacesProvider).value ?? const [];
    final ordered = [
      ...spaces.where((w) => w.id == last),
      ...spaces.where((w) => w.id != last),
    ];
    final groups = <String, List<Workspace>>{};
    for (final space in ordered) {
      final key = space.pairId.isEmpty
          ? 'space:${space.id}'
          : 'pair:${space.pairId}';
      groups.putIfAbsent(key, () => []).add(space);
    }
    final prefs = ref.watch(spacePrefsProvider).value ?? SpacePrefs.empty;
    final shown = prefs.arrange(groups.keys.toList());
    final nothing = spaces.isEmpty && linked.every((s) => s.spaces.isEmpty);
    return Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            key: const ValueKey('me-home-list'),
            padding: AppSpacing.gutterAll,
            children: [
              const _MeHeader(),
              const SizedBox(height: AppSpacing.xl),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n?.meMySpaces ?? 'My spaces',
                        style: Theme.of(context).textTheme.titleLarge?.strong,
                      ),
                    ),
                    if (groups.isNotEmpty)
                      Text(
                        '${groups.length}',
                        key: const ValueKey('me-home-count'),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (nothing)
                EmptyState(
                  key: const ValueKey('me-home-empty'),
                  icon: Icons.meeting_room_outlined,
                  title: l10n?.meNoSpaceTitle ?? 'You are not in a space yet',
                  subtitle: l10n?.meNoSpaceBody ?? 'Find one near you, join with an invitation code, or create your own.',
                ),
              for (final key in shown)
                if (groups[key] case final group?)
                MeWorkspaceRow(
                  controls: SpaceRowControls(
                    rowKey: key,
                    name: group.first.name,
                    favorite: prefs.favorites.contains(key),
                    rating: prefs.ratings[key],
                    onFavorite: () =>
                        ref.read(spacePrefsProvider.notifier).toggleFavorite(key),
                    onRate: (stars) =>
                        ref.read(spacePrefsProvider.notifier).rate(key, stars),
                    leave: [
                      for (final space in [...group]..sort(
                        (a, b) => b.environment.compareTo(a.environment),
                      ))
                        SpaceLeaveItem(
                          id: space.id,
                          label: (memberships
                                      .where((m) => m.workspaceId == space.id)
                                      .firstOrNull
                                      ?.isOwner ??
                                  false)
                              ? (l10n?.meLeaveOwner ??
                                  'Owners hand the space over before leaving')
                              : group.length == 1
                              ? (l10n?.meLeaveAction ?? 'Leave this space')
                              : (l10n?.meLeaveSide(
                                      space.environment == 'prod'
                                          ? (l10n.profilesPairProd)
                                          : (l10n.profilesPairDev),
                                    ) ??
                                  'Leave ${space.environment}'),
                          enabled: !(memberships
                                  .where((m) => m.workspaceId == space.id)
                                  .firstOrNull
                                  ?.isOwner ??
                              false),
                          onLeave: () => confirmLeaveSpace(
                            context,
                            ref,
                            space,
                            memberships
                                .where((m) => m.workspaceId == space.id)
                                .firstOrNull,
                          ),
                        ),
                    ],
                    onUp: prefs.moved(shown, key, -1) == null
                        ? null
                        : () => ref
                            .read(spacePrefsProvider.notifier)
                            .move(shown, key, -1),
                    onDown: prefs.moved(shown, key, 1) == null
                        ? null
                        : () => ref
                            .read(spacePrefsProvider.notifier)
                            .move(shown, key, 1),
                  ),
                  key: ValueKey('me-space-pair-${group.first.pairId.isEmpty ? group.first.id : group.first.pairId}'),
                  avatar: WorkspaceAvatar(workspace: group.first),
                  name: group.first.name,
                  lastUsed: group.any((space) => space.id == last),
                  detail: {
                    for (final space in group)
                      if (memberships.where((m) => m.workspaceId == space.id).firstOrNull case final member?)
                        member.status == MemberStatus.pending
                            ? (l10n?.meSpacePending ?? 'Waiting for approval')
                            : memberRoleLabel(l10n, member),
                  }.join(' · '),
                  actions: [
                    // A space without a production side keeps development at
                    // the right.
                    if (!group.any((s) => s.environment == 'prod'))
                      const Spacer(flex: MeSpaceCard.prodFlex),
                    for (final space in [...group]..sort(
                      (a, b) => b.environment.compareTo(a.environment),
                    ))
                      MeSpaceCard(
                        space: space,
                        member: memberships.where((m) => m.workspaceId == space.id).firstOrNull,
                        lastUsed: space.id == last,
                      ),
                  ],
                ),
              const LinkedSpacesSection(),
              // #1835 — my guest visits: beside my spaces, never among them.
              const MyVisitsSection(),
              const SizedBox(height: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('me-home-discover'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.lgAll,
                      ),
                    ),
                    icon: const Icon(Icons.travel_explore_outlined),
                    label: Text(l10n?.meFindSpace ?? 'Find a space'),
                    onPressed: onDiscover,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('me-home-join'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppRadius.lgAll,
                            ),
                          ),
                          icon: const Icon(Icons.qr_code_2_outlined),
                          label: Text(
                            l10n?.meJoinSpace ?? 'Join with a code',
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () => context.push('/onboarding?join=1'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('me-home-create'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppRadius.lgAll,
                            ),
                          ),
                          icon: const Icon(Icons.add_business_outlined),
                          label: Text(
                            l10n?.meCreateSpace ?? 'Create a space',
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () => context.push('/onboarding'),
                        ),
                      ),
                    ],
                  ),
                  if (spaces.isNotEmpty)
                    TextButton(
                      key: const ValueKey('me-home-manage'),
                      onPressed: () => context.push('/profiles'),
                      child: Text(l10n?.meManageSpaces ?? 'Manage my spaces'),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Personal identity uses a soft account colour and the global avatar.
class _MeHeader extends ConsumerWidget {
  const _MeHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final profile = ref.watch(myProfileProvider).value;
    final name = profile?.displayName ?? '';
    return Padding(
      key: const ValueKey('me-header'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          const PersonalAvatar(radius: 30),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.strong
                      .copyWith(color: scheme.onSurface),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        l10n?.meHeaderOwned ??
                            'Your account · it belongs only to you',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
