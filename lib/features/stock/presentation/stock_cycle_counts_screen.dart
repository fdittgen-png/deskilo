// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4295 -- Cycle counts (`/stock/cycle-counts`): scheduled spot checks of chosen places, items or
// high-value goods while the shop stays open. Whoever counts (the right `countStock`, or managing
// the stock) sees what is TO COUNT and opens a task to count it blind; whoever manages the stock also
// keeps the PLANS and reads the HISTORY (when each item at each place was last counted, how exact the
// counts were). Nothing here moves a balance: a difference goes through the counts of #4172 and their
// approval. A failed read says so and can be asked again, never shown as empty.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show isoDay;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/i18n/app_format.dart';
import '../../../core/i18n/format_controller.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/time/clock.dart';
import '../../../core/ui/loading_view.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/stock_config.dart';
import '../domain/stock_cycle_counts.dart';
import '../domain/stock_page.dart';
import '../providers/stock_providers.dart';
import 'stock_cycle_plan_sheet.dart';
import 'stock_day.dart';
import 'stock_page_shell.dart';
import 'stock_read_failed.dart';
import 'stock_sheet_opener.dart';

class StockCycleCountsScreen extends ConsumerWidget {
  const StockCycleCountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final manages = ref.watch(myPermissionsProvider).contains(WorkspacePermission.manageStock);
    final tabs = [
      (l10n.stockCycleTabTasks, 'tasks', _Tasks.new),
      if (manages) ...[
        (l10n.stockCycleTabPlans, 'plans', _Plans.new),
        (l10n.stockCycleTabHistory, 'history', _History.new),
      ],
    ];
    return DefaultTabController(
      length: tabs.length,
      child: StockPageShell(
        title: l10n.stockCycleTitle,
        anchor: HelpAnchor.moneyStockCycleCounts,
        helpTopic: l10n.permModuleStock,
        // a counter who only counts has one page: no tabs to choose between
        bottom: tabs.length < 2 ? null : TabBar(tabs: [for (final t in tabs) Tab(key: ValueKey('stock-cycle-tab-${t.$2}'), text: t.$1)]),
        body: (context, ref, workspaceId) => TabBarView(children: [for (final t in tabs) t.$3(workspaceId: workspaceId)]),
      ),
    );
  }
}

String _day(BuildContext context, String iso) {
  final at = DateTime.tryParse(iso);
  return at == null ? iso : appFormatOf(context).dates(DateShape.date).format(at);
}

/// A read that failed says so and can be asked again.
Widget _failed(Object error, String key, VoidCallback retry) =>
    StockReadFailed(keyName: key, error: error, onRetry: retry);

class _Tasks extends ConsumerWidget {
  const _Tasks({required this.workspaceId});

  final String? workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final id = workspaceId;
    if (id == null) return const LoadingView();
    final provider = stockCountTasksProvider(id);
    return ref
        .watch(provider)
        .when(
          loading: () => const LoadingView(),
          error: (e, _) => _failed(e, 'stock-cycle-tasks', () => ref.invalidate(provider)),
          data: (tasks) => tasks.isEmpty
              ? Center(child: Text(l10n.stockCycleNoTasks, key: const ValueKey('stock-cycle-no-tasks')))
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [for (final t in tasks) _TaskTile(task: t)],
                ),
        );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});

  final CountTaskSummary task;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final open = task.state == CountTaskState.open;
    return ListTile(
      key: ValueKey('stock-cycle-task-${task.taskId}'),
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.stockCycleTaskRow(task.planName, _day(context, task.dueOn))),
      subtitle: Text(
        switch (task.state) {
          CountTaskState.open => l10n.stockCycleTaskProgress('${task.pending}', '${task.lines}'),
          CountTaskState.complete => l10n.stockCycleTaskComplete,
          CountTaskState.cancelled => l10n.stockCycleTaskCancelled,
          CountTaskState.unknown => l10n.stockStateUnknown,
        },
      ),
      trailing: open ? const Icon(Icons.chevron_right) : null,
      onTap: open ? () => context.push('/stock/cycle-counts/${task.taskId}') : null,
    );
  }
}

class _Plans extends ConsumerWidget {
  const _Plans({required this.workspaceId});

  final String? workspaceId;

  Future<void> _edit(BuildContext context, WidgetRef ref, String workspaceId, CountPlan? plan) => openStockSheet(
    context,
    ref,
    workspaceId,
    what: 'plan',
    open: (choices) => showCountPlanSheet(
      context,
      ref.read(stockCycleCountsProvider),
      workspaceId: workspaceId,
      choices: (
        items: choices.items,
        places: choices.places,
        separator: choices.separator,
        currency: ref.read(currentWorkspaceProvider).value?.currencyCode ?? '',
      ),
      today: isoDay(stockDayOf(ref, ref.read(clockProvider).now())),
      plan: plan,
    ),
    reads: [stockCountPlansProvider(workspaceId)],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final id = workspaceId;
    if (id == null) return const LoadingView();
    final provider = stockCountPlansProvider(id);
    return ref
        .watch(provider)
        .when(
          loading: () => const LoadingView(),
          error: (e, _) => _failed(e, 'stock-cycle-plans', () => ref.invalidate(provider)),
          data: (plans) => ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (plans.isEmpty) Text(l10n.stockCycleNoPlans, key: const ValueKey('stock-cycle-no-plans')),
              for (final p in plans)
                ListTile(
                  key: ValueKey('stock-cycle-plan-${p.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(p.name),
                  subtitle: Text(_summary(context, ref, p)),
                  onTap: () => _edit(context, ref, id, p),
                ),
              TextButton.icon(
                key: const ValueKey('stock-cycle-add-plan'),
                icon: const Icon(Icons.add),
                label: Text(l10n.stockCycleAddPlan),
                onPressed: () => _edit(context, ref, id, null),
              ),
            ],
          ),
        );
  }

  /// What a plan counts, how often and when next: one line.
  String _summary(BuildContext context, WidgetRef ref, CountPlan p) {
    final l10n = context.l10n;
    final money = appFormatOf(context).moneyIn(ref.read(currentWorkspaceProvider).value?.currencyCode);
    return [
      switch (p.scope) {
        CountScope.places => l10n.stockCyclePlanPlacesCount(p.locationIds.length),
        CountScope.items => l10n.stockCyclePlanItemsCount(p.itemIds.length),
        CountScope.highValue => switch (p.highValueMinor) {
          final minor? => l10n.stockCyclePlanValue(money.formatMinor(minor)),
          null => l10n.stockCyclePlanValueSetting,
        },
        CountScope.unknown => l10n.stockStateUnknown,
      },
      if (p.intervalDays case final days?) l10n.stockCyclePlanEvery(days) else l10n.stockCyclePlanOnce,
      l10n.stockCyclePlanNext(_day(context, p.nextDueOn)),
      if (!p.active) l10n.stockCyclePlanOff,
    ].join(' · ');
  }
}

class _History extends ConsumerWidget {
  const _History({required this.workspaceId});

  final String? workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final id = workspaceId;
    if (id == null) return const LoadingView();
    final provider = stockCountHistoryProvider(id);
    final items = {for (final i in ref.watch(stockItemsProvider(id)).value ?? const <StockItem>[]) i.id: i}; // empty-ok: a name falls back to its id
    final separator = ref.watch(stockAddressSeparatorProvider);
    final places = {
      for (final p in ref.watch(stockPlaceConfigsProvider(id)).value ?? const <StockPlaceConfig>[]) p.id: stockAddress(p, separator), // empty-ok: a place falls back to its id
    };
    return ref
        .watch(provider)
        .when(
          loading: () => const LoadingView(),
          error: (e, _) => _failed(e, 'stock-cycle-history', () => ref.invalidate(provider)),
          data: (rows) => rows.isEmpty
              ? Center(child: Text(l10n.stockCycleHistoryEmpty, key: const ValueKey('stock-cycle-history-empty')))
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    for (final r in rows)
                      ListTile(
                        key: ValueKey('stock-cycle-history-${r.itemId}-${r.locationId}'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.stockCycleHistoryRow(items[r.itemId]?.name ?? r.itemId, places[r.locationId] ?? r.locationId)),
                        subtitle: Text(
                          [
                            if (r.lastCountedAt != null) l10n.stockCycleHistoryLast(appFormatOf(context).date(r.lastCountedAt!)),
                            if (r.accuracyPercent != null) l10n.stockCycleHistoryAccuracy(r.counts, appFormatOf(context).ratePercent(r.accuracyPercent!)),
                          ].join(' · '),
                        ),
                      ),
                  ],
                ),
        );
  }
}
