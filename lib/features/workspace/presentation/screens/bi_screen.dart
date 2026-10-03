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

import '../../../../core/navigation/navigation_style.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/workspace_time.dart';
import '../../domain/bi_modules.dart';
import '../../../../core/ui/loading_view.dart';
import '../../domain/bi_query.dart';
import '../../domain/bi_saved_view.dart';
import '../../providers/bi_providers.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/bi_module_section.dart';
import '../widgets/bi_toolbar.dart';
import '../widgets/bi_views_bar.dart';

String biAreaName(AppLocalizations? l10n, BiArea area) => switch (area) {
  BiArea.overview => l10n?.biAreaOverview ?? 'Overview',
  BiArea.capacity => l10n?.biAreaCapacity ?? 'Space and capacity',
  BiArea.people => l10n?.biAreaPeople ?? 'People and business',
  BiArea.finance => l10n?.biAreaFinance ?? 'Finance',
  BiArea.treasury => l10n?.biAreaTreasury ?? 'Treasury',
  BiArea.operations => l10n?.biAreaOperations ?? 'Operations',
  BiArea.planning => l10n?.biAreaPlanning ?? 'Planning',
  BiArea.saved => l10n?.biAreaSaved ?? 'Saved analyses',
};

class BiScreen extends ConsumerWidget {
  const BiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final modules = ref.watch(platformIsWebProvider)
        ? visibleBiModules(
            ref.watch(enabledFeaturesSyncProvider),
            ref.watch(myPermissionsProvider),
          )
        : const <BiModule>[];
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
      final check = chosen == null
          ? null
          : checkView(chosen.definition, visibleIds).query;
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
        title: Text(l10n?.biTitle ?? 'Business analytics'),
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
      body: ListView(
        key: const ValueKey('bi-page'),
        children: [
          if (query == null)
            Card(
              key: const ValueKey('bi-invalid-address'),
              margin: AppSpacing.mdAll,
              child: Padding(
                padding: AppSpacing.mdAll,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n?.biInvalidAddress ??
                          'This address asks for an analysis that does not '
                              'exist; nothing was read.',
                    ),
                    TextButton(
                      key: const ValueKey('bi-reset'),
                      onPressed: () => go(BiQueryContext.standard, 'standard'),
                      child: Text(l10n?.biReset ?? 'Show the standard view'),
                    ),
                  ],
                ),
              ),
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
            BiToolbar(
              query: query,
              modules: modules,
              today: today,
              onChanged: ask,
              cardTitle: (id) => biModuleViews[id]?.title(l10n) ?? id,
            ),
            if (unavailable > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  l10n?.biCardsUnavailable('$unavailable') ??
                      '$unavailable analyses of this view are not available '
                          'to you and are left out.',
                  key: const ValueKey('bi-cards-unavailable'),
                ),
              ),
            for (final (i, m) in shown.indexed) ...[
              if (i == 0 || shown[i - 1].area != m.area)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    0,
                  ),
                  child: Text(
                    biAreaName(l10n, m.area),
                    key: ValueKey('bi-area-${m.area.name}'),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              BiModuleSection(module: m, query: query),
            ],
          ],
        ],
      ),
    );
  }
}

/// A view id (uuid) or `standard`; anything else is a manipulated
/// address.
final _savedId = RegExp(r'^[A-Za-z0-9-]{1,64}$');
