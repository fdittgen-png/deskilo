// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2554 C2 — the Overview under the personal shell: "Your day, in one
// place" and three sections, each read on its own and each with its own
// state (reading, failed with Try again, unavailable), so one failing
// source never hides the others:
//
// * Next commitment — the earliest own booking still to come across every
//   workspace host my account names (#2553's composition);
// * Needs attention — my unpaid documents, my undecided requests and my
//   unread conversations, each record once;
// * My spaces — the first spaces of My spaces (favourites, then the most
//   recently entered) and the way to all of them; with none, Join and
//   Discover lead and Create follows.
//
// Below the sections, once I have a space, Discover and Join are a small
// entry of their own.
//
// Wide, the page is 2:1: Next commitment and My spaces on the left, Needs
// attention on the right. Compact, the order is Next commitment, Needs
// attention, My spaces.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/storage/space_prefs_store.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/personal_theme.dart';
import '../../../core/ui/empty_state.dart';
import '../../visits/presentation/my_visits_section.dart';
import '../../workspace/domain/workspace.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/personal_spaces_view.dart';
import '../domain/my_spaces.dart';
import '../domain/personal_workspace_refs.dart';
import '../providers/me_providers.dart';
import '../providers/space_prefs_provider.dart';
import 'me_shell.dart';
import 'personal_overview_attention.dart';
import 'personal_overview_sections.dart';
import 'personal_space_card.dart';

/// The narrowest the right-hand column may be in the 2:1 layout.
const double _rightMinWidth = 290;

/// The gap between the two columns, and between sections.
const double _columnGap = AppSpacing.xl;

/// How many spaces the Overview previews: a composition choice of this
/// page; All my spaces always reaches the full list.
const int _spacesPreview = 2;

/// Whether a content area [width] wide lays the Overview out 2:1: the
/// right-hand third must keep its minimum width.
bool _overviewExpanded(double width) =>
    width >= _rightMinWidth * 3 + _columnGap;

class PersonalOverview extends StatelessWidget {
  const PersonalOverview({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: PersonalShellMetrics.contentMaxWidth,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The shell places the page; its own gutter is the one every
              // personal page keeps, and the columns share what is inside it.
              final expanded = _overviewExpanded(
                constraints.maxWidth - 2 * AppSpacing.screenGutter,
              );
              final sections = expanded
                  ? [
                      Row(
                        key: const ValueKey('me-overview-expanded'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                NextCommitmentSection(expanded: expanded),
                                const SizedBox(height: _columnGap),
                                _SpacesSection(expanded: expanded),
                              ],
                            ),
                          ),
                          const SizedBox(width: _columnGap),
                          Expanded(
                            child: NeedsAttentionSection(expanded: expanded),
                          ),
                        ],
                      ),
                    ]
                  : [
                      NextCommitmentSection(expanded: expanded),
                      const SizedBox(height: _columnGap),
                      NeedsAttentionSection(expanded: expanded),
                      const SizedBox(height: _columnGap),
                      _SpacesSection(expanded: expanded),
                    ];
              final children = <Widget>[
                _Header(expanded: expanded),
                const SizedBox(height: _columnGap),
                ...sections,
                const _DiscoverJoinEntry(),
                const SizedBox(height: AppSpacing.xl),
              ];
              return ListView.builder(
                key: const ValueKey('me-home-list'),
                padding: AppSpacing.gutterAll,
                itemCount: children.length,
                itemBuilder: (context, i) => children[i],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tokens = PersonalTheme.of(context);
    return Column(
      key: const ValueKey('me-overview-header'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.meOverviewTitle,
          style:
              (expanded
                      ? theme.textTheme.displaySmall
                      : theme.textTheme.headlineSmall)
                  ?.copyWith(color: tokens.text),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.meOverviewSubtitle,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: tokens.secondaryText,
          ),
        ),
      ],
    );
  }
}

/// A space of this server, of a linked one, or one my account names
/// elsewhere is not "nothing" (#2563); this server's own spaces come from
/// its list, as everywhere else on Me.
bool _noSpace(
  PersonalWorkspaceRefs refs,
  List<Workspace> local,
  List<LinkedServerSpaces> linked,
) =>
    refs.beyondLocalSpaces.isEmpty &&
    local.isEmpty &&
    linked.every((s) => s.spaces.isEmpty);

/// The first spaces of My spaces, and the way to all of them. With no
/// space at all, the ways to one lead.
class _SpacesSection extends ConsumerWidget {
  const _SpacesSection({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final answer = ref.watch(personalWorkspaceRefsProvider);
    final local = ref.watch(myWorkspacesProvider).value ?? const <Workspace>[];
    final linked = ref.watch(linkedServerSpacesProvider).value ?? const [];
    final failed = answer.hasError && !answer.isLoading;
    final refs = failed ? null : answer.value;
    final nothing = refs != null && _noSpace(refs, local, linked);
    final prefs = ref.watch(spacePrefsProvider).value ?? SpacePrefs.empty;
    // Favourites first, then the spaces I entered most recently here.
    final preview = refs == null
        ? const <PersonalSpaceRow>[]
        : personalSpacePreview(
            refs,
            local,
            prefs: prefs,
            count: _spacesPreview,
          );
    return OverviewSection(
      sectionKey: 'me-overview-spaces',
      title: l10n.meMySpaces,
      expanded: expanded,
      children: [
        if (failed)
          SourceUnavailable(
            key: const ValueKey('me-overview-spaces-unavailable'),
            text: l10n.mySpacesUnavailable,
            onRetry: () => ref.invalidate(personalWorkspaceRefsProvider),
          )
        else if (refs == null)
          const SectionLoading(key: ValueKey('me-overview-spaces-loading'))
        else if (nothing) ...[
          EmptyState(
            key: const ValueKey('me-home-empty'),
            icon: Icons.meeting_room_outlined,
            title: l10n.meNoSpaceTitle,
            subtitle: l10n.meNoSpaceBody,
          ),
          // With no space, the ways to one lead, here.
          const _SpaceActions(empty: true),
        ] else
          for (final row in preview) PersonalSpaceCard(row: row),
        // #1835 — my guest visits: beside my spaces, never among them.
        const MyVisitsSection(),
        if (refs != null && !nothing) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonalIcon(
              key: const ValueKey('me-home-all-spaces'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, PersonalShellMetrics.minTarget),
              ),
              icon: const Icon(Icons.workspaces_outlined),
              label: Text(l10n.mySpacesAll),
              onPressed: () => context.go(MeTab.spaces.path),
            ),
          ),
        ],
      ],
    );
  }
}

/// Discover and Join as a small entry of its own below the sections, once
/// I have a space (with none, they lead inside My spaces).
class _DiscoverJoinEntry extends ConsumerWidget {
  const _DiscoverJoinEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refs = ref.watch(personalWorkspaceRefsProvider).value;
    final local = ref.watch(myWorkspacesProvider).value ?? const <Workspace>[];
    final linked = ref.watch(linkedServerSpacesProvider).value ?? const [];
    if (refs == null || _noSpace(refs, local, linked)) return const SizedBox.shrink();
    return const Padding(
      key: ValueKey('me-overview-discover-join'),
      padding: EdgeInsets.only(top: AppSpacing.lg),
      child: _SpaceActions(empty: false),
    );
  }
}

/// Join, Discover and Create. With no space they lead, inside My spaces;
/// otherwise they are a small entry of their own below the sections.
class _SpaceActions extends StatelessWidget {
  const _SpaceActions({required this.empty});

  final bool empty;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const target = Size(0, PersonalShellMetrics.minTarget);
    void join() => context.push('/onboarding?join=1');
    void discover() => context.go(MeTab.discover.path);
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (empty)
          FilledButton.icon(
            key: const ValueKey('me-home-join'),
            style: FilledButton.styleFrom(minimumSize: target),
            icon: const Icon(Icons.qr_code_2_outlined),
            label: Text(l10n.meJoinSpace),
            onPressed: join,
          )
        else
          TextButton.icon(
            key: const ValueKey('me-home-join'),
            style: TextButton.styleFrom(minimumSize: target),
            icon: const Icon(Icons.qr_code_2_outlined),
            label: Text(l10n.meJoinSpace),
            onPressed: join,
          ),
        // A small entry, not a call to action, once I have a space.
        if (empty)
          OutlinedButton.icon(
            key: const ValueKey('me-home-discover'),
            style: OutlinedButton.styleFrom(minimumSize: target),
            icon: const Icon(Icons.travel_explore_outlined),
            label: Text(l10n.mySpacesDiscover),
            onPressed: discover,
          )
        else
          TextButton.icon(
            key: const ValueKey('me-home-discover'),
            style: TextButton.styleFrom(minimumSize: target),
            icon: const Icon(Icons.travel_explore_outlined),
            label: Text(l10n.mySpacesDiscover),
            onPressed: discover,
          ),
        TextButton.icon(
          key: const ValueKey('me-home-create'),
          style: TextButton.styleFrom(minimumSize: target),
          icon: const Icon(Icons.add_business_outlined),
          label: Text(l10n.meCreateSpace),
          onPressed: () => context.push('/onboarding'),
        ),
      ],
    );
  }
}
