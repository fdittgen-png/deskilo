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
import '../../domain/bi_query.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/bi_module_section.dart';
import '../widgets/bi_toolbar.dart';

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
    final query = BiQueryContext.tryParse(params);
    // go: the address IS the analysis — Reload and a shared link restore
    // it, and the browser's Back and Forward step through what was asked.
    void ask(BiQueryContext next) {
      final q = next.toQuery();
      context.go(
        Uri(path: '/bi', queryParameters: q.isEmpty ? null : q).toString(),
      );
    }

    final today = WorkspaceTime.dateOf(ref.watch(clockProvider).now());
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
                      onPressed: () => ask(BiQueryContext.standard),
                      child: Text(l10n?.biReset ?? 'Show the standard view'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            BiToolbar(
              query: query,
              modules: modules,
              today: today,
              onChanged: ask,
            ),
            for (final area in BiArea.values)
              if (modules.any((m) => m.area == area)) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    0,
                  ),
                  child: Text(
                    biAreaName(l10n, area),
                    key: ValueKey('bi-area-${area.name}'),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                for (final m in modules.where((m) => m.area == area))
                  BiModuleSection(module: m, query: query),
              ],
          ],
        ],
      ),
    );
  }
}
