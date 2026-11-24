// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4294 (G8, client) -- Reorder: what is at or below its reorder point, per site, and what to
// order from whom. "Low" is the server's reading of the ledger; the list of what to order groups it
// by the supplier whose article is preferred, in that article's purchase unit. A group becomes a
// DRAFT purchase order: nothing is ordered, priced or sent. A list that could not be read says so:
// it is never shown as "nothing is low".
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/i18n/format_controller.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_snack.dart';
import '../../../core/ui/form_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/stock_config.dart' show StockPlaceConfig, stockAddress;
import '../domain/stock_reorder.dart';
import '../providers/stock_providers.dart';
import 'stock_config_text.dart';
import 'stock_page_shell.dart';
import 'stock_reorder_point_sheet.dart';
import 'stock_sheet_opener.dart';

class StockReorderScreen extends ConsumerWidget {
  const StockReorderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return StockPageShell(
      title: l10n.stockReorderTitle,
      anchor: HelpAnchor.moneyStockReorder,
      helpTopic: l10n.permModuleStock,
      reloadKey: const ValueKey('stock-reorder-reload'),
      reloads: (workspaceId) => [stockLowProvider(workspaceId), stockReplenishmentProvider(workspaceId)],
      reading: true,
      body: (context, ref, workspaceId) => ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(l10n.stockReorderIntro, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.stockReorderLowTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _LowList(workspaceId: workspaceId),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.stockReorderToOrderTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _ToOrder(workspaceId: workspaceId),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.stockReorderPointsTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _PointsList(workspaceId: workspaceId),
        ],
      ),
    );
  }
}

/// A read that failed: said as such, with its retry; never an empty list.
class _LowList extends ConsumerWidget {
  const _LowList({required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return StockRead(
      keyName: 'stock-reorder-low',
      value: ref.watch(stockLowProvider(workspaceId)),
      onRetry: () => ref.invalidate(stockLowProvider(workspaceId)),
      isEmpty: (rows) => rows.isEmpty,
      empty: l10n.stockReorderLowEmpty,
      emptyIcon: Icons.check_circle_outline,
      data: (rows) => Column(
        children: [
          for (final r in rows)
            ListTile(
              key: ValueKey('stock-low-${r.pointId}'),
              contentPadding: EdgeInsets.zero,
              title: Text(r.itemName),
              subtitle: Text(
                l10n.stockReorderLowRow(
                  r.siteCode,
                  l10n.stockQuantityWithUnit(appFormatOf(context).quantity(r.onHand), r.unit),
                  l10n.stockQuantityWithUnit(appFormatOf(context).quantity(r.reorderPoint), r.unit),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToOrder extends ConsumerWidget {
  const _ToOrder({required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mayBuy = ref.watch(myPermissionsProvider).contains(WorkspacePermission.managePurchases);
    return StockRead(
      keyName: 'stock-reorder-order',
      value: ref.watch(stockReplenishmentProvider(workspaceId)),
      onRetry: () => ref.invalidate(stockReplenishmentProvider(workspaceId)),
      isEmpty: (list) => list.isEmpty,
      empty: l10n.stockReorderToOrderEmpty,
      emptyIcon: Icons.shopping_cart_outlined,
      data: (list) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final g in list.groups)
            _GroupCard(workspaceId: workspaceId, group: g, mayBuy: mayBuy),
          if (list.noSupplier.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.stockReorderNoSupplierTitle,
              key: const ValueKey('stock-reorder-no-supplier'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(l10n.stockReorderNoSupplierHelp, style: Theme.of(context).textTheme.bodySmall),
            for (final g in list.noSupplier)
              ListTile(
                key: ValueKey('stock-gap-${g.itemId}-${g.siteCode}'),
                contentPadding: EdgeInsets.zero,
                title: Text(g.itemName),
                subtitle: Text(
                  l10n.stockReorderGapRow(g.siteCode, l10n.stockQuantityWithUnit(appFormatOf(context).quantity(g.quantity), g.unit)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// The reorder points: each opens its sheet for whoever may manage the stock; a point is added from
/// the button. A list that could not be read says so, never "no point is set".
class _PointsList extends ConsumerWidget {
  const _PointsList({required this.workspaceId});

  final String workspaceId;

  Future<void> _edit(BuildContext context, WidgetRef ref, StockReorderPoint? point) => openStockSheet(
    context,
    ref,
    workspaceId,
    what: 'reorder point',
    open: (choices) => showStockReorderPointSheet(
      context,
      ref.read(stockReorderProvider),
      ref.read(stockConfigCommandsProvider),
      workspaceId: workspaceId,
      choices: choices,
      point: point,
    ),
    reads: [stockReorderPointsProvider(workspaceId), stockLowProvider(workspaceId), stockReplenishmentProvider(workspaceId)],
  );

  String _rule(BuildContext context, AppLocalizations l10n, StockReorderPoint p, String unit) {
    if (p.targetQuantity != null) return l10n.stockReorderRuleTarget(l10n.stockQuantityWithUnit(appFormatOf(context).quantity(p.targetQuantity!), unit));
    if (p.reorderQuantity != null) return l10n.stockReorderRuleQuantity(l10n.stockQuantityWithUnit(appFormatOf(context).quantity(p.reorderQuantity!), unit));
    return l10n.stockReorderRuleNone;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mayManage = ref.watch(myPermissionsProvider).contains(WorkspacePermission.manageStock);
    final items = ref.watch(stockItemsProvider(workspaceId)).value ?? const []; // empty-ok: a name falls back to its id
    final places = ref.watch(stockPlaceConfigsProvider(workspaceId)).value ?? const <StockPlaceConfig>[]; // empty-ok: a site falls back to its id
    final separator = ref.watch(stockAddressSeparatorProvider);
    return StockRead(
      keyName: 'stock-reorder-points',
      value: ref.watch(stockReorderPointsProvider(workspaceId)),
      onRetry: () => ref.invalidate(stockReorderPointsProvider(workspaceId)),
      data: (points) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (points.isEmpty)
            Text(l10n.stockReorderPointsEmpty, key: const ValueKey('stock-reorder-points-empty'))
          else
            for (final p in points)
              () {
                final item = items.where((i) => i.id == p.itemId).firstOrNull;
                final site = places.where((s) => s.id == p.siteId).firstOrNull;
                final unit = item?.unit ?? '';
                return ListTile(
                  key: ValueKey('stock-point-${p.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(item?.name ?? p.itemId),
                  subtitle: Text(
                    [
                      l10n.stockReorderPointRow(
                        site == null ? p.siteId : stockAddress(site, separator),
                        l10n.stockQuantityWithUnit(appFormatOf(context).quantity(p.reorderPoint), unit),
                        _rule(context, l10n, p, unit),
                      ),
                      if (!p.active) l10n.stockReorderPointInactive,
                    ].join(' · '),
                  ),
                  onTap: mayManage ? () => _edit(context, ref, p) : null,
                );
              }(),
          if (mayManage)
            TextButton.icon(
              key: const ValueKey('stock-point-add'),
              icon: const Icon(Icons.add),
              label: Text(l10n.stockReorderPointAdd),
              onPressed: () => _edit(context, ref, null),
            ),
        ],
      ),
    );
  }
}

class _GroupCard extends ConsumerStatefulWidget {
  const _GroupCard({required this.workspaceId, required this.group, required this.mayBuy});

  final String workspaceId;
  final ReplenishmentGroup group;
  final bool mayBuy;

  @override
  ConsumerState<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends ConsumerState<_GroupCard> {
  /// One per draft: a retry after a lost answer is the same request and answers once; it is renewed
  /// when a draft was made, so asking again later makes another deliberately.
  var _requestId = newRequestId();
  bool _busy = false;

  Future<void> _draft(AppLocalizations l10n) async {
    setState(() => _busy = true);
    try {
      final draft = await ref.read(stockReorderProvider).createDraft(
        widget.workspaceId,
        supplierId: widget.group.supplierId,
        lines: widget.group.lines,
        requestId: _requestId,
      );
      _requestId = newRequestId();
      if (!mounted) return;
      AppSnack.success(context, l10n.stockReorderDraftCreated(draft.number ?? ''));
      ref.invalidate(stockReplenishmentProvider(widget.workspaceId));
    } on Object catch (e, st) {
      TraceLogger.instance.warn('stock', 'a replenishment draft was not made', error: e, stackTrace: st);
      if (mounted) AppSnack.error(context, stockSaveProblem(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final g = widget.group;
    return Card(
      key: ValueKey('stock-order-group-${g.supplierId}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(g.supplierName, style: Theme.of(context).textTheme.titleSmall),
            const FormGap.small(),
            for (final line in g.lines)
              Text(
                l10n.stockReorderGroupLine(
                  line.itemName,
                  l10n.stockQuantityWithUnit(appFormatOf(context).quantity(line.quantity), line.unit),
                  line.siteCode,
                ),
                key: ValueKey('stock-order-line-${line.pointId}'),
              ),
            const FormGap.small(),
            Text(l10n.stockReorderDraftHelp, style: Theme.of(context).textTheme.bodySmall),
            if (widget.mayBuy)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  key: ValueKey('stock-order-draft-${g.supplierId}'),
                  onPressed: _busy ? null : () => _draft(l10n),
                  child: Text(l10n.stockReorderCreateDraft),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
