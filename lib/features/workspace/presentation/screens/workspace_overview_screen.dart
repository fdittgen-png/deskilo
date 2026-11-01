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
// C2 (#2580's saved layouts): with the report designer on, a reader of the
// analytics may Customize — pin, unpin and reorder the tiles, copy a
// report's layout, save it as a report. The layout is their own saved
// report (bi_overview_layout.dart), so two people's layouts are independent
// and it survives a restart; without one, the registry's grouped layout.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/attention.dart';
import '../../domain/bi_modules.dart';
import '../../domain/bi_overview_layout.dart';
import '../../domain/bi_query.dart';
import '../../domain/bi_saved_view.dart';
import '../../domain/kpi_contract.dart';
import '../../domain/workspace_feature.dart';
import '../../domain/workspace_permission.dart';
import '../../providers/attention_providers.dart';
import '../../providers/bi_providers.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/bi_module_section.dart';
import '../widgets/overview_layout_editor.dart';
import '../widgets/setup_resume_banner.dart';
import 'attention_screen.dart';

/// The groups of the key indicators, in their order.
@visibleForTesting
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

class WorkspaceOverviewScreen extends ConsumerStatefulWidget {
  const WorkspaceOverviewScreen({super.key});

  @override
  ConsumerState<WorkspaceOverviewScreen> createState() =>
      _WorkspaceOverviewScreenState();
}

class _WorkspaceOverviewScreenState
    extends ConsumerState<WorkspaceOverviewScreen> {
  var _customizing = false;
  final _customize = FocusNode(debugLabel: 'overview-customize');

  @override
  void dispose() {
    _customize.dispose();
    super.dispose();
  }

  void _setCustomizing({required bool on}) {
    setState(() => _customizing = on);
    // Back from customizing, focus returns to the button that opened it.
    if (!on) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _customize.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final features = ref.watch(enabledFeaturesSyncProvider);
    final rights = ref.watch(myPermissionsProvider);
    final attentionAsync = ref.watch(attentionProvider);
    final modules = [
      for (final m in visibleBiModules(features, rights))
        if (biModuleViews.containsKey(m.id)) m,
    ];
    // The person's own layout: only a reader of the analytics keeps views.
    final analytics = rights.contains(WorkspacePermission.viewAnalytics);
    final views = analytics && workspace != null
        ? ref.watch(biViewsProvider(workspace.id)).value ?? const <BiSavedView>[]
        : const <BiSavedView>[];
    final canCustomize =
        analytics &&
        workspace != null &&
        modules.isNotEmpty &&
        features.contains(WorkspaceFeature.biReportDesigner);
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
          if (workspace != null &&
              modules.any((m) => m.id == _pendingActions))
            _SpacePending(workspaceId: workspace.id),
          ..._attentionRows(attentionAsync),
          if (modules.isNotEmpty) ...[
            heading(l10n.overviewIndicators, 'overview-indicators'),
            if (workspace != null)
              ..._indicators(
                workspace.id,
                modules,
                views,
                canCustomize: canCustomize,
              ),
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

  /// What needs the person: loading, the rows, "nothing" only for a read that
  /// really answered nothing, and a failure that says so (#3061) — a failed
  /// or refused read is never the same sentence as an empty inbox.
  List<Widget> _attentionRows(AsyncValue<List<Attention>> async) {
    final items = async.value;
    return [
      if (async.isLoading)
        const LinearProgressIndicator(key: ValueKey('overview-attention-loading')),
      if (async.hasError)
        ReadFailureBanner(
          error: async.error!,
          onRetry: () => ref.invalidate(attentionProvider),
        ),
      if (items != null && items.isEmpty)
        Text(
          context.l10n.decisionSurfaceEmpty,
          key: const ValueKey('overview-attention-empty'),
        )
      else if (items != null)
        for (final (i, item) in items.indexed)
          AttentionRow(key: ValueKey('overview-attention-$i'), item: item),
    ];
  }

  /// The key indicators: Customize, then the person's layout being edited,
  /// their pinned tiles, or the registry's groups.
  List<Widget> _indicators(
    String workspaceId,
    List<BiModule> modules,
    List<BiSavedView> views, {
    required bool canCustomize,
  }) {
    final layout = biOverviewLayoutOf(views);
    final report = layout?.definition?.report;
    return [
      if (canCustomize && !_customizing)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const ValueKey('overview-customize'),
            focusNode: _customize,
            onPressed: () => _setCustomizing(on: true),
            icon: const Icon(Icons.tune),
            label: Text(context.l10n.overviewCustomize),
          ),
        ),
      if (_customizing && canCustomize)
        OverviewLayoutEditor(
          workspaceId: workspaceId,
          modules: modules,
          layout: layout,
          reports: [
            for (final v in views)
              if (v.definition?.report != null && v != layout) v,
          ],
          onClose: () => _setCustomizing(on: false),
        )
      // The person's own layout needs the designer: with it off, the
      // registry's layout returns (and nothing is left nobody can change).
      else if (canCustomize && report != null)
        _Pinned(
          workspaceId: workspaceId,
          modules: [
            for (final id in biTilesOf(report))
              ?modules.where((m) => m.id == id).firstOrNull,
          ],
        )
      else
        _Grouped(workspaceId: workspaceId, modules: modules),
    ];
  }
}

/// The registry's layout: the tiles grouped Capacity / Sales / Purchases /
/// Cash.
class _Grouped extends StatelessWidget {
  const _Grouped({required this.workspaceId, required this.modules});

  final String workspaceId;
  final List<BiModule> modules;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final group in OverviewGroup.values)
        if (modules.where((m) => overviewGroupOf(m) == group).toList()
            case final inGroup when inGroup.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              _groupLabel(context.l10n, group),
              key: ValueKey('overview-group-${group.name}'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final m in inGroup)
                _IndicatorTile(workspaceId: workspaceId, module: m),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
    ],
  );
}

/// The person's pinned tiles, in their order, without the registry groups.
class _Pinned extends StatelessWidget {
  const _Pinned({required this.workspaceId, required this.modules});

  final String workspaceId;
  final List<BiModule> modules;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: modules.isEmpty
        ? Text(
            context.l10n.overviewNoPinned,
            key: const ValueKey('overview-pinned-empty'),
          )
        : Wrap(
            key: const ValueKey('overview-pinned'),
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final m in modules)
                _IndicatorTile(
                  key: ValueKey('overview-pinned-${m.id}'),
                  workspaceId: workspaceId,
                  module: m,
                ),
            ],
          ),
  );
}

/// One module's current-month figure, in the module's own words.
/// The space's registered count of what waits on a decision.
const _pendingActions = 'operations.pending_actions_current';

/// How many requests and join requests wait in the whole space, from the
/// registered figure: the list above it is only what waits on this person.
/// Said only when the figure is known; nothing is guessed.
class _SpacePending extends ConsumerWidget {
  const _SpacePending({required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(
      biModuleResultProvider(
        workspaceId,
        _pendingActions,
        const BiQueryContext(),
      ),
    );
    final total = result.asData?.value.total.current;
    final count = total == null || total.unknown
        ? null
        : total.value(KpiAggregation.lastAtCutoff);
    if (count == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        context.l10n.overviewPendingInSpace(count.round()),
        key: const ValueKey('overview-attention-space'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _IndicatorTile extends ConsumerWidget {
  const _IndicatorTile({
    super.key,
    required this.workspaceId,
    required this.module,
  });

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
