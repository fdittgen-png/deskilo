// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2583 C1 — the workspace overview: what needs the person, then the figures
// they may read, on one page.
//
//   * Needs attention: the decision surface's own lines (#1247), each
//     opening the screen where the decision is made.
//   * Key indicators: one compact tile per analytics module the reader may
//     see (the module registry, never a separate list), grouped Capacity /
//     Sales / Purchases / Cash, each the module's own current-month result
//     in its own words; a figure that is unknown says so, never 0. A tile
//     opens the analytics page; it never decides, pays or sends anything.
//   * People: the active memberships (0536), a module like the others.
//
// No customising here yet (#2579/#2580 own saved layouts): a fixed,
// registry-defined layout, no dead button.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/attention.dart';
import '../../domain/bi_modules.dart';
import '../../domain/bi_query.dart';
import '../../domain/kpi_contract.dart';
import '../../domain/workspace_permission.dart';
import '../../providers/attention_providers.dart';
import '../../providers/bi_providers.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/bi_module_section.dart';
import '../widgets/setup_resume_banner.dart';
import 'attention_screen.dart';

/// The groups of the key indicators, in their order.
enum OverviewGroup { people, capacity, sales, purchases, cash }

/// The group [module] is shown in.
@visibleForTesting
OverviewGroup overviewGroupOf(BiModule module) => switch (module) {
  BiModule(area: BiArea.people) => OverviewGroup.people,
  BiModule(area: BiArea.capacity) => OverviewGroup.capacity,
  BiModule(area: BiArea.treasury) => OverviewGroup.cash,
  BiModule(id: 'finance.invoiced' || 'finance.collected') =>
    OverviewGroup.sales,
  BiModule(:final id) when id.startsWith('sales.') => OverviewGroup.sales,
  _ => OverviewGroup.purchases,
};

String _groupLabel(AppLocalizations l10n, OverviewGroup g) => switch (g) {
  OverviewGroup.people => l10n.overviewGroupPeople,
  OverviewGroup.capacity => l10n.overviewGroupCapacity,
  OverviewGroup.sales => l10n.overviewGroupSales,
  OverviewGroup.purchases => l10n.overviewGroupPurchases,
  OverviewGroup.cash => l10n.overviewGroupCash,
};

class WorkspaceOverviewScreen extends ConsumerWidget {
  const WorkspaceOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final features = ref.watch(enabledFeaturesSyncProvider);
    final rights = ref.watch(myPermissionsProvider);
    final attention = ref.watch(attentionProvider).value ?? const <Attention>[];
    final modules = [
      for (final m in visibleBiModules(features, rights))
        if (biModuleViews.containsKey(m.id)) m,
    ];
    // #2869 — a configurer whose space is not set up yet sees where to
    // resume first.
    final setup = setupResumeBannerFor(ref, workspace?.id,
        configures: rights.contains(WorkspacePermission.manageConfiguration));
    final title = Theme.of(context).textTheme.titleMedium;
    Widget heading(String text, String key) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Text(text, key: ValueKey(key), style: title),
    );
    return Scaffold(
      appBar: AppBar(title: Text(workspace?.name ?? l10n.overviewTitle)),
      body: ListView(
        key: const ValueKey('workspace-overview'),
        padding: AppSpacing.gutterAll,
        children: [
          ?setup,
          heading(l10n.overviewNeedsAttention, 'overview-attention'),
          if (attention.isEmpty)
            Text(
              l10n.decisionSurfaceEmpty,
              key: const ValueKey('overview-attention-empty'),
            )
          else
            for (final (i, item) in attention.indexed)
              AttentionRow(key: ValueKey('overview-attention-$i'), item: item),
          if (modules.isNotEmpty) ...[
            heading(l10n.overviewIndicators, 'overview-indicators'),
            for (final group in OverviewGroup.values)
              if (modules.where((m) => overviewGroupOf(m) == group).toList()
                  case final inGroup when inGroup.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    _groupLabel(l10n, group),
                    key: ValueKey('overview-group-${group.name}'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final m in inGroup)
                      if (workspace != null)
                        _IndicatorTile(workspaceId: workspace.id, module: m),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const ValueKey('overview-all-indicators'),
                onPressed: () => context.push('/bi'),
                icon: const Icon(Icons.insights_outlined),
                label: Text(l10n.overviewAllIndicators),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One module's current-month figure, in the module's own words.
class _IndicatorTile extends ConsumerWidget {
  const _IndicatorTile({required this.workspaceId, required this.module});

  final String workspaceId;
  final BiModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final view = biModuleViews[module.id]!;
    final result = ref.watch(
      biModuleResultProvider(workspaceId, module.id, const BiQueryContext()),
    );
    final value = switch (result) {
      AsyncData(:final value)
          when !value.total.current.quality.contains(KpiQuality.unavailable) =>
        view.value(
          value.total.current.value(module.aggregation),
          locale,
          value.currency,
        ),
      AsyncData() || AsyncError() => l10n.overviewUnavailable,
      _ => '…',
    };
    return SizedBox(
      width: 168,
      child: Card(
        key: ValueKey('overview-tile-${module.id}'),
        margin: EdgeInsets.zero,
        child: InkWell(
          key: ValueKey('overview-open-${module.id}'),
          onTap: () => context.push('/bi'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  view.title(l10n),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  value,
                  key: ValueKey('overview-value-${module.id}'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  l10n.overviewThisMonth,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
