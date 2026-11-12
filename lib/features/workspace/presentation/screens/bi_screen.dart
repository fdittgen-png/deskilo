// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1923 A — Web-BI: the registered analytics modules, grouped by area.
// Areas without a module are not shown; each module renders its own
// consumer, which the server authorizes again.
//
// #1923 B — one toolbar above every module, one context in the address
// (so Back, Forward, Reload and a shared link restore it). An address
// that does not parse is refused and nothing is read.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../core/ui/kit/dashboard_grid.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/bi_modules.dart';
import '../../domain/bi_query.dart';
import '../../domain/bi_saved_view.dart';
import '../../providers/bi_providers.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/bi_export_sheet.dart';
import '../widgets/bi_module_section.dart';
import '../widgets/bi_report_section.dart';
import '../widgets/bi_toolbar.dart';
import '../widgets/bi_views_bar.dart';

/// The narrowest an analysis is drawn on the page's grid.
@visibleForTesting
// content-fit: an analysis holds its figure, its compared rows and its charts in a phone's 340 dp card
const double biAnalysisMinWidth = 340;

String _biAreaName(AppLocalizations l10n, BiArea area) => switch (area) {
  BiArea.overview => l10n.biAreaOverview,
  BiArea.capacity => l10n.biAreaCapacity,
  BiArea.people => l10n.biAreaPeople,
  BiArea.finance => l10n.biAreaFinance,
  BiArea.treasury => l10n.biAreaTreasury,
  BiArea.operations => l10n.biAreaOperations,
  BiArea.planning => l10n.biAreaPlanning,
  BiArea.saved => l10n.biAreaSaved,
};

class BiScreen extends ConsumerWidget {
  const BiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final modules = visibleBiModules(
      ref.watch(enabledFeaturesSyncProvider),
      ref.watch(myPermissionsProvider),
    );
    final params = GoRouterState.of(context).uri.queryParameters;
    // #1923 C — `saved` names the open view (or `standard`); the rest is
    // the analysis itself.
    final saved = params['saved'];
    final query = saved != null && !_savedId.hasMatch(saved)
        ? null
        : BiQueryContext.tryParse(Map.of(params)..remove('saved'));
    final workspaceId = ref.watch(currentWorkspaceProvider).value?.id;
    // go: the address IS the analysis — Reload and a shared link restore
    // it, and the browser's Back and Forward step through what was asked.
    void go(BiQueryContext next, String? savedId) {
      final q = {...next.toQuery(), 'saved': ?savedId};
      context.go(
        Uri(path: '/bi', queryParameters: q.isEmpty ? null : q).toString(),
      );
    }

    void ask(BiQueryContext next) => go(next, saved);
    final today = WorkspaceTime.dateOf(ref.watch(clockProvider).now());
    final visibleIds = {for (final m in modules) m.id};

    // A bare /bi opens the reader's default view (theirs, else the
    // team's); until the list is known nothing is read.
    if (params.isEmpty && workspaceId != null) {
      final views = ref.watch(biViewsProvider(workspaceId));
      if (views.isLoading) return const Scaffold(body: LoadingView());
      final chosen = defaultView(views.value ?? const []);
      final check = chosen?.check(visibleIds).query;
      if (chosen != null && check != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) go(check, chosen.id);
        });
        return const Scaffold(body: LoadingView());
      }
    }
    final cards = query?.cards ?? const <String>[];
    final shown = cards.isEmpty
        ? [
            for (final area in BiArea.values)
              ...modules.where((m) => m.area == area),
          ]
        : [for (final c in cards) ...modules.where((m) => m.id == c)];
    final unavailable = cards.where((c) => !visibleIds.contains(c)).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.biTitle),
        // Opened from an address (or after a toolbar change) there is no
        // page below: offer the way home instead of a dead end.
        leading: context.canPop()
            ? null
            : IconButton(
                key: const ValueKey('bi-home'),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/reserve'),
              ),
      ),
      body: DashboardScrollView(
        key: const ValueKey('bi-page'),
        header: [
          if (query == null)
            _InvalidAddress(
              onReset: () => go(BiQueryContext.standard, 'standard'),
            )
          else ...[
            if (workspaceId != null)
              BiViewsBar(
                workspaceId: workspaceId,
                query: query,
                openId: saved,
                visibleModules: visibleIds,
                today: today,
                onOpen: (view, q) => go(q, view?.id ?? 'standard'),
              ),
            if (workspaceId != null)
              BiReportSection(
                workspaceId: workspaceId,
                query: query,
                openId: saved,
                visibleModules: visibleIds,
                onOpen: (view, q) => go(q, view?.id ?? 'standard'),
              ),
          ],
        ],
        // The analysis' one context stays in view while its figures scroll.
        filterBar: query == null
            ? null
            : FilterBar(
                key: const ValueKey('bi-filter-bar'),
                filters: BiToolbar(
                  key: const ValueKey('bi-bi-toolbar'),
                  query: query,
                  modules: modules,
                  today: today,
                  onChanged: ask,
                  cardTitle: (id) => biModuleViews[id]?.title(l10n) ?? id,
                ),
                actions: [
                  if (workspaceId != null && shown.isNotEmpty)
                    BiExportActions(
                      workspaceId: workspaceId,
                      openId: saved,
                      query: query,
                      modules: shown,
                    ),
                ],
              ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        children: [
          if (query != null)
            _Analyses(shown: shown, query: query, unavailable: unavailable),
        ],
      ),
    );
  }
}

/// The analyses on the page's grid, under the heading of their area, after
/// the count of the chosen ones the reader may not see.
class _Analyses extends StatelessWidget {
  const _Analyses({
    required this.shown,
    required this.query,
    required this.unavailable,
  });

  final List<BiModule> shown;
  final BiQueryContext query;
  final int unavailable;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = Theme.of(context).textTheme.titleMedium;
    // A table or a chart lays its rows out beside the compared period: it
    // takes two columns where the grid has them.
    final span = query.view == BiView.dashboard ? 1 : 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (unavailable > 0)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(
              l10n.biCardsUnavailable(unavailable),
              key: const ValueKey('bi-cards-unavailable'),
            ),
          ),
        for (final (area, inArea) in _byArea(shown)) ...[
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.md,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              _biAreaName(l10n, area),
              key: ValueKey('bi-area-${area.name}'),
              style: style,
            ),
          ),
          DashboardGrid(
            key: ValueKey('bi-grid-${area.name}'),
            minTileWidth: biAnalysisMinWidth,
            children: [
              for (final m in inArea)
                DashboardTile(
                  span: span,
                  child: BiModuleSection(module: m, query: query),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// [shown] cut into runs of one area, in the page's order: a chosen order
/// that returns to an area starts a new run under its heading again.
List<(BiArea, List<BiModule>)> _byArea(List<BiModule> shown) {
  final runs = <(BiArea, List<BiModule>)>[];
  for (final m in shown) {
    if (runs.isNotEmpty && runs.last.$1 == m.area) {
      runs.last.$2.add(m);
    } else {
      runs.add((m.area, [m]));
    }
  }
  return runs;
}

/// A view id (uuid) or `standard`; anything else is a manipulated
/// address.
final _savedId = RegExp(r'^[A-Za-z0-9-]{1,64}$');

/// An address that does not parse: refused, with the way back.
class _InvalidAddress extends StatelessWidget {
  const _InvalidAddress({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      key: const ValueKey('bi-invalid-address'),
      margin: AppSpacing.mdAll,
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.biInvalidAddress),
            TextButton(
              key: const ValueKey('bi-reset'),
              onPressed: onReset,
              child: Text(l10n.biReset),
            ),
          ],
        ),
      ),
    );
  }
}
