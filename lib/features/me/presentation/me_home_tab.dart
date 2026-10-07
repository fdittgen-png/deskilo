// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — Me › Home: who I am, and the spaces I can walk into — this
// server's and every linked server's, the last one I used first.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../../core/i18n/money_format.dart';
import '../../../core/time/clock.dart';
import '../../money/presentation/my_finances_route.dart';
import '../../money/providers/finance_overview_provider.dart';
import '../providers/me_providers.dart';
import 'linked_spaces_section.dart';
import 'me_spaces_list.dart';
import '../providers/space_prefs_provider.dart';

class MeHomeTab extends ConsumerWidget {
  const MeHomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spaces = ref.watch(myWorkspacesProvider).value ?? const <Workspace>[];
    final memberships =
        ref.watch(myMembershipsProvider).value ?? const <Member>[];
    final last = ref.watch(activeWorkspaceIdProvider).value;
    final linked = ref.watch(linkedServerSpacesProvider).value ?? const [];
    final rows = {for (final s in spaces) spaceRowKeyOf(s)}.length;
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
              const _FinanceGlance(),
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
                  title: l10n?.meNoSpaceTitle ?? 'You are not in a space yet',
                  subtitle:
                      l10n?.meNoSpaceBody ??
                      'Find one near you, join with an invitation code, or create your own.',
                )
              else if (spaces.isNotEmpty)
                MeSpacesList(
                  spaces: spaces,
                  memberships: memberships,
                  lastUsedId: last,
                ),
              const LinkedSpacesSection(),
              // #1835 — my guest visits: beside my spaces, never among them.
              const MyVisitsSection(),
              const SizedBox(height: AppSpacing.md),
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
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

/// What I owe, across every space, and a way into Me › Finances. Nothing at
/// all while there is nothing to pay (or the read fails): the home is not a
/// dashboard of empty states.
class _FinanceGlance extends ConsumerWidget {
  const _FinanceGlance();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final data = ref.watch(financeOverviewProvider).value;
    if (data == null || data.outstanding.isEmpty) return const SizedBox.shrink();
    final now = ref.watch(clockProvider).now();
    final overdue = data.outstanding.where((i) => i.overdueAt(now)).length;
    final scheme = Theme.of(context).colorScheme;
    final amount = [
      for (final e in data.owedByCurrency.entries)
        moneyFormat(e.key).formatMinor(e.value),
    ].join(' · ');
    final tone = overdue > 0 ? scheme.error : scheme.primary;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Material(
        key: const ValueKey('me-home-finance-glance'),
        color: tone.withValues(alpha: .10),
        borderRadius: AppRadius.xlAll,
        child: InkWell(
          borderRadius: AppRadius.xlAll,
          onTap: () => context.push(myFinancesRoute()),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined, color: tone),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n?.meFinanceGlanceOwed(amount) ?? 'To pay: $amount',
                        style: Theme.of(context).textTheme.titleSmall?.strong,
                      ),
                      if (overdue > 0)
                        Text(
                          l10n?.financesOverdueCount(overdue) ??
                              '$overdue overdue',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.error),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
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
