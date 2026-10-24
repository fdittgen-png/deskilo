// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2554 — Me › My spaces under the personal shell (`/me/spaces`): every
// workspace my account names, read on my personal home
// (`my_personal_workspace_refs_v1`, #2563), each with its host and whether
// its membership is verified there. A failed read is not "no space": it
// says so and offers Try again. A workspace on another installation stays
// listed, honestly unverified, with no Open it could not honour. With no
// space at all, Join and Discover lead and Create follows.
//
// C3 — visible filters (Requests and visits among them), a grid of cards
// at least 280 wide or a list, one card per test/production pair, the
// favourite heart and My review as separate actions, Move up/down instead
// of a drag, and my guest visits on the page.
//
// The search filters the loaded records only. Managing this server's spaces
// (default, home site, environments, the platform tools) stays on its own
// page, one tap away (`/me/spaces/manage`).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/storage/space_prefs_store.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/personal_theme.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/form_kit.dart';
import '../../../core/ui/inline_banner.dart';
import '../../visits/domain/guest_participation.dart';
import '../../visits/presentation/my_visits_section.dart';
import '../../visits/providers/visits_providers.dart';
import '../../workspace/domain/workspace.dart';
import '../../workspace/providers/workspace_host_providers.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/personal_spaces_view.dart';
import '../domain/personal_workspace_refs.dart';
import '../providers/me_providers.dart';
import '../providers/space_prefs_provider.dart';
import 'create_host_sheet.dart';
import 'me_shell.dart';
import 'personal_space_card.dart';

/// The page under `/me/spaces` that manages this server's spaces.
const String personalSpacesManagePath = '/me/spaces/manage';

class PersonalSpacesView extends ConsumerStatefulWidget {
  const PersonalSpacesView({super.key});

  @override
  ConsumerState<PersonalSpacesView> createState() => _PersonalSpacesState();
}

class _PersonalSpacesState extends ConsumerState<PersonalSpacesView> {
  final _search = TextEditingController();
  String _query = '';
  PersonalSpaceFilter _filter = PersonalSpaceFilter.all;
  bool _grid = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// `refresh`, not `invalidate`: the retry rebuilds on the spot.
  void _retry() =>
      unawaited(ref.refresh(personalWorkspaceRefsProvider.future));

  /// Moves [row] one place among the cards of its rank in [rows].
  PersonalSpaceMove _move(
    List<PersonalSpaceRow> rows,
    PersonalSpaceRow row,
    SpacePrefs prefs,
  ) {
    final scope = personalSpaceMoveScope(rows, row, prefs);
    final at = scope.indexOf(row.key);
    final prefsNotifier = ref.read(spacePrefsProvider.notifier);
    VoidCallback? step(int delta) {
      final to = at + delta;
      if (to < 0 || to >= scope.length) return null;
      return () => unawaited(prefsNotifier.move(scope, row.key, delta));
    }

    return (up: step(-1), down: step(1));
  }

  /// The banners, then the page's state: reading, failed, empty, or the
  /// search and the filters over what was loaded.
  List<Widget> _status(
    BuildContext context, {
    required bool localFailed,
    required bool failed,
    required bool loading,
    required bool empty,
    required bool noMatch,
  }) {
    final l10n = context.l10n;
    return [
      if (localFailed) ...[
        InlineBanner(
          key: const ValueKey('my-spaces-local-unavailable'),
          icon: Icons.cloud_off_outlined,
          text: l10n.profilesUnavailable,
          actionLabel: l10n.commonRetry,
          onAction: () => unawaited(ref.refresh(myWorkspacesProvider.future)),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      if (failed)
        InlineBanner(
          key: const ValueKey('my-spaces-unavailable'),
          icon: Icons.cloud_off_outlined,
          text: l10n.mySpacesUnavailable,
          actionLabel: l10n.commonRetry,
          onAction: _retry,
        )
      else if (loading)
        const LinearProgressIndicator(key: ValueKey('my-spaces-loading'))
      else if (empty)
        EmptyState(
          key: const ValueKey('my-spaces-empty'),
          icon: Icons.meeting_room_outlined,
          title: l10n.meNoSpaceTitle,
          subtitle: l10n.meNoSpaceBody,
        )
      else ...[
        AppTextField(
          key: const ValueKey('my-spaces-search'),
          controller: _search,
          label: l10n.meSpacesSearch,
          textInputAction: TextInputAction.search,
          onChanged: (q) => setState(() => _query = q),
        ),
        const SizedBox(height: AppSpacing.sm),
        _Filters(
          selected: _filter,
          // recorder-key-exempt: a data callback; each chip is keyed
          onSelected: (f) => setState(() => _filter = f),
        ),
        const SizedBox(height: AppSpacing.md),
        if (noMatch)
          Padding(
            key: const ValueKey('my-spaces-no-match'),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text(
              l10n.mySpacesNoMatch,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: PersonalTheme.of(context).secondaryText,
              ),
            ),
          ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final answer = ref.watch(personalWorkspaceRefsProvider);
    final localAsync = ref.watch(myWorkspacesProvider);
    final local = localAsync.value ?? const <Workspace>[];
    final prefs = ref.watch(spacePrefsProvider).value ?? SpacePrefs.empty;
    final visits =
        ref.watch(myGuestVisitsProvider).value ?? const <GuestParticipation>[];
    // #1650 — this server's spaces could not be read: entry needs them, so
    // the page says so beside the references it could read.
    final localFailed = localAsync.hasError && !localAsync.hasValue;
    // A failed read is never an empty list; a refresh keeps what was shown.
    final failed = answer.hasError && !answer.isLoading;
    final loaded = failed ? null : answer.value;
    final all = loaded?.refs ?? const <PersonalWorkspaceRef>[];
    final ordered = loaded == null
        ? const <PersonalSpaceRow>[]
        : personalSpaceRows(loaded, local, prefs: prefs);
    final rows = loaded == null
        ? const <PersonalSpaceRow>[]
        : personalSpaceRows(
            loaded,
            local,
            prefs: prefs,
            query: _query,
            filter: _filter,
          );
    final showVisits = _filter.showsVisits && visits.isNotEmpty;
    final hostsHere = all.any((r) => r.hostedHere && r.status != null);

    final children = <Widget>[
      _Header(
        count: loaded == null ? null : all.length,
        grid: _grid,
        // recorder-key-exempt: a data callback; its two buttons are keyed
        onGrid: (grid) => setState(() => _grid = grid),
      ),
      const SizedBox(height: AppSpacing.md),
      ..._status(
        context,
        localFailed: localFailed,
        failed: failed,
        loading: loaded == null,
        empty: all.isEmpty && visits.isEmpty,
        noMatch: rows.isEmpty && !showVisits,
      ),
    ];

    final footer = <Widget>[
      // #1835 — my guest visits: on this page, never as a membership.
      if (showVisits) const MyVisitsSection(),
      const SizedBox(height: AppSpacing.lg),
      _Actions(empty: loaded != null && all.isEmpty),
      if (hostsHere)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const ValueKey('my-spaces-manage'),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, PersonalShellMetrics.minTarget),
            ),
            onPressed: () => context.push(personalSpacesManagePath),
            child: Text(l10n.mySpacesManage),
          ),
        ),
      const SizedBox(height: AppSpacing.xl),
    ];

    return Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: PersonalShellMetrics.contentMaxWidth,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = _grid
                  ? personalSpaceColumns(
                      constraints.maxWidth - 2 * AppSpacing.screenGutter,
                    )
                  : 1;
              final lines = [
                for (var i = 0; i < rows.length; i += columns)
                  rows.sublist(i, (i + columns).clamp(0, rows.length)),
              ];
              Widget card(PersonalSpaceRow row) => PersonalSpaceCard(
                row: row,
                move: _move(ordered, row, prefs),
              );
              return ListView.builder(
                key: const ValueKey('my-spaces-list'),
                padding: AppSpacing.gutterAll,
                itemCount: children.length + lines.length + footer.length,
                itemBuilder: (context, i) {
                  if (i < children.length) return children[i];
                  final l = i - children.length;
                  if (l < lines.length) {
                    return _Line(columns: columns, cards: lines[l].map(card));
                  }
                  return footer[l - lines.length];
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The narrowest a card of the grid may be.
const double _cardMinWidth = 280;

/// How many cards of at least 280 fit side by side in [width]; one at
/// least, so a narrow window lists them.
@visibleForTesting
int personalSpaceColumns(double width) =>
    ((width + AppSpacing.md) / (_cardMinWidth + AppSpacing.md))
        .floor()
        .clamp(1, 4);

/// One line of the grid: [columns] equal slots, the last ones left empty.
class _Line extends StatelessWidget {
  const _Line({required this.columns, required this.cards});

  final int columns;
  final Iterable<Widget> cards;

  @override
  Widget build(BuildContext context) {
    final list = cards.toList();
    if (columns == 1) return list.single;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < columns; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.md),
          Expanded(child: i < list.length ? list[i] : const SizedBox.shrink()),
        ],
      ],
    );
  }
}

/// The title, the loaded count, and the grid/list choice.
class _Header extends StatelessWidget {
  const _Header({
    required this.count,
    required this.grid,
    required this.onGrid,
  });

  /// Null while nothing was loaded.
  final int? count;
  final bool grid;
  final ValueChanged<bool> onGrid;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tokens = PersonalTheme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(l10n.meMySpaces, style: theme.textTheme.titleLarge?.strong),
        ),
        if (count case final count?)
          Text(
            l10n.mySpacesCount(count),
            key: const ValueKey('my-spaces-count'),
            style: theme.textTheme.labelLarge?.copyWith(
              color: tokens.secondaryText,
            ),
          ),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          key: const ValueKey('my-spaces-layout-grid'),
          tooltip: l10n.mySpacesLayoutGrid,
          isSelected: grid,
          icon: const Icon(Icons.grid_view_outlined),
          selectedIcon: const Icon(Icons.grid_view),
          onPressed: () => onGrid(true),
        ),
        IconButton(
          key: const ValueKey('my-spaces-layout-list'),
          tooltip: l10n.mySpacesLayoutList,
          isSelected: !grid,
          icon: const Icon(Icons.view_agenda_outlined),
          selectedIcon: const Icon(Icons.view_agenda),
          onPressed: () => onGrid(false),
        ),
      ],
    );
  }
}

/// The visible filters: every loaded space, or the ones in one state.
class _Filters extends StatelessWidget {
  const _Filters({required this.selected, required this.onSelected});

  final PersonalSpaceFilter selected;
  final ValueChanged<PersonalSpaceFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String label(PersonalSpaceFilter f) => switch (f) {
      PersonalSpaceFilter.all => l10n.mySpacesFilterAll,
      PersonalSpaceFilter.active => l10n.mySpacesFilterActive,
      PersonalSpaceFilter.requests => l10n.mySpacesFilterRequests,
      PersonalSpaceFilter.history => l10n.mySpacesFilterHistory,
    };
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (final f in PersonalSpaceFilter.values)
          ChoiceChip(
            key: ValueKey('my-spaces-filter-${f.name}'),
            label: Text(label(f)),
            selected: f == selected,
            onSelected: (_) => onSelected(f),
          ),
      ],
    );
  }
}

/// Join and Discover lead while there is no space; Create follows.
class _Actions extends ConsumerWidget {
  const _Actions({required this.empty});

  final bool empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // #2562 C2c -- read ahead, so Create knows whether there is a choice.
    ref.watch(workspaceHostsProvider);
    const target = Size(0, PersonalShellMetrics.minTarget);
    final join = empty
        ? FilledButton.icon(
            key: const ValueKey('my-spaces-join'),
            style: FilledButton.styleFrom(minimumSize: target),
            icon: const Icon(Icons.qr_code_2_outlined),
            label: Text(l10n.meJoinSpace),
            onPressed: () => context.push('/onboarding?join=1'),
          )
        : OutlinedButton.icon(
            key: const ValueKey('my-spaces-join'),
            style: OutlinedButton.styleFrom(minimumSize: target),
            icon: const Icon(Icons.qr_code_2_outlined),
            label: Text(l10n.meJoinSpace),
            onPressed: () => context.push('/onboarding?join=1'),
          );
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        join,
        OutlinedButton.icon(
          key: const ValueKey('my-spaces-discover'),
          style: OutlinedButton.styleFrom(minimumSize: target),
          icon: const Icon(Icons.travel_explore_outlined),
          label: Text(l10n.mySpacesDiscover),
          onPressed: () => context.go(MeTab.discover.path),
        ),
        TextButton.icon(
          key: const ValueKey('my-spaces-create'),
          style: TextButton.styleFrom(minimumSize: target),
          icon: const Icon(Icons.add_business_outlined),
          label: Text(l10n.meCreateSpace),
          onPressed: () => unawaited(CreateHostSheet.start(context, ref)),
        ),
      ],
    );
  }
}
