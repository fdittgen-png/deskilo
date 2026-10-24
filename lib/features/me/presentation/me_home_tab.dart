// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — Me › Home: who I am, and the spaces I can walk into — this
// server's and every linked server's, the last one I used first.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/ui/empty_state.dart';
import '../../profile/presentation/widgets/personal_avatar.dart';
import '../../profile/providers/profile_providers.dart';
import '../../visits/presentation/my_visits_section.dart';
import '../../workspace/domain/member.dart';
import '../../workspace/domain/workspace.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/space_pairs.dart';
import '../providers/me_providers.dart';
import '../providers/personal_shell_providers.dart';
import 'linked_spaces_section.dart';
import 'me_spaces_list.dart';
import 'personal_overview.dart';
import 'personal_overview_attention.dart';
import 'personal_refs_section.dart';

/// One of the two ways to a new space under the list: join, or create.
class _HomeAction extends StatelessWidget {
  const _HomeAction({
    required this.actionKey,
    required this.icon,
    required this.label,
    required this.route,
  });

  final String actionKey;
  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) => Expanded(
    child: OutlinedButton.icon(
      key: ValueKey(actionKey),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),
      icon: Icon(icon),
      label: Text(label, overflow: TextOverflow.ellipsis),
      onPressed: () => context.push(route),
    ),
  );
}

class MeHomeTab extends ConsumerWidget {
  const MeHomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // #2554 — under the personal shell the Overview is its own page: the
    // day in one place, three sections each with its own state.
    if (ref.watch(personalShellEnabledProvider)) {
      return const PersonalOverview();
    }
    final l10n = context.l10n;
    final spaces = ref.watch(myWorkspacesProvider).value ?? const <Workspace>[];
    final memberships =
        ref.watch(myMembershipsProvider).value ?? const <Member>[];
    final last = ref.watch(activeWorkspaceIdProvider).value;
    final linked = ref.watch(linkedServerSpacesProvider).value ?? const [];
    final rows = pairSides(spaces).length;
    // #2563 — a workspace my account names elsewhere is not "nothing".
    final elsewhere = ref.watch(personalWorkspaceRefsProvider).value;
    final nothing = spaces.isEmpty &&
        linked.every((s) => s.spaces.isEmpty) &&
        (elsewhere?.beyondLocalSpaces.isEmpty ?? true);
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
              const FinanceGlance(),
              const SizedBox(height: AppSpacing.xl),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.meMySpaces,
                        style: Theme.of(context).textTheme.titleLarge?.strong,
                      ),
                    ),
                    if (rows > 0)
                      Text(
                        '$rows',
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
                  title: l10n.meNoSpaceTitle,
                  subtitle:
                      l10n.meNoSpaceBody,
                )
              else if (spaces.isNotEmpty)
                MeSpacesList(
                  spaces: spaces,
                  memberships: memberships,
                  lastUsedId: last,
                ),
              const LinkedSpacesSection(),
              const PersonalRefsSection(),
              // #1835 — my guest visits: beside my spaces, never among them.
              const MyVisitsSection(),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  _HomeAction(
                    actionKey: 'me-home-join',
                    icon: Icons.qr_code_2_outlined,
                    label: l10n.meJoinSpace,
                    route: '/onboarding?join=1',
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _HomeAction(
                    actionKey: 'me-home-create',
                    icon: Icons.add_business_outlined,
                    label: l10n.meCreateSpace,
                    route: '/onboarding',
                  ),
                ],
              ),
              if (spaces.isNotEmpty)
                TextButton(
                  key: const ValueKey('me-home-manage'),
                  onPressed: () => context.push('/profiles'),
                  child: Text(l10n.meManageSpaces),
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
    final l10n = context.l10n;
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
                        l10n.meHeaderOwned,
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
