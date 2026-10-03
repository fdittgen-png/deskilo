// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — Me › Home: who I am, and the spaces I can walk into — this
// server's and every linked server's, the last one I used first.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/empty_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/presentation/widgets/personal_avatar.dart';
import '../../profile/providers/profile_providers.dart';
import '../../workspace/domain/member.dart';
import '../../workspace/domain/workspace.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../providers/me_providers.dart';
import 'linked_spaces_section.dart';
import 'me_space_card.dart';
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
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n?.meMySpaces ?? 'My spaces',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (nothing)
                EmptyState(
                  key: const ValueKey('me-home-empty'),
                  icon: Icons.meeting_room_outlined,
                  title: l10n?.meNoSpaceTitle ?? 'You are not in a space yet',
                  subtitle: l10n?.meNoSpaceBody ?? 'Find one near you, join with an invitation code, or create your own.',
                ),
              for (final group in groups.values)
                if (group.length == 1)
                  MeSpaceCard(
                    space: group.first,
                    member: memberships
                        .where((m) => m.workspaceId == group.first.id)
                        .firstOrNull,
                    lastUsed: group.first.id == last,
                  )
                else
                  Card(
                    key: ValueKey('me-space-pair-${group.first.pairId}'),
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Column(
                      children: [
                        ListTile(
                          leading: WorkspaceAvatar(workspace: group.first),
                          title: Text(group.first.name),
                        ),
                        for (final space
                            in [...group]..sort(
                              (a, b) => b.environment.compareTo(a.environment),
                            ))
                          MeSpaceCard(
                            space: space,
                            member: memberships
                                .where((m) => m.workspaceId == space.id)
                                .firstOrNull,
                            lastUsed: space.id == last,
                            grouped: true,
                          ),
                      ],
                    ),
                  ),
              const LinkedSpacesSection(),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  FilledButton.tonalIcon(
                    key: const ValueKey('me-home-discover'),
                    icon: const Icon(Icons.travel_explore_outlined),
                    label: Text(l10n?.meFindSpace ?? 'Find a space'),
                    onPressed: onDiscover,
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('me-home-join'),
                    icon: const Icon(Icons.qr_code_2_outlined),
                    label: Text(l10n?.meJoinSpace ?? 'Join with a code'),
                    onPressed: () => context.push('/onboarding?join=1'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('me-home-create'),
                    icon: const Icon(Icons.add_business_outlined),
                    label: Text(l10n?.meCreateSpace ?? 'Create a space'),
                    onPressed: () => context.push('/onboarding'),
                  ),
                  if (spaces.isNotEmpty)
                    TextButton(
                      key: const ValueKey('me-home-manage'),
                      onPressed: () => context.push('/profiles'),
                      child: Text(l10n?.meManageSpaces ?? 'Manage my spaces'),
                    ),
                ],
              ),
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
    return DecoratedBox(
      key: const ValueKey('me-header'),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: AppRadius.lgAll,
      ),
      child: Padding(
        padding: AppSpacing.gutterAll,
        child: Row(
          children: [
            const PersonalAvatar(radius: 24),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: scheme.onPrimaryContainer),
                  ),
                  Text(
                    l10n?.meHeaderOwned ??
                        'Your account · it belongs only to you',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
