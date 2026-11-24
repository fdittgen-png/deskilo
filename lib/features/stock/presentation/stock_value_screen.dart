// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4173 -- the operational value of the stock on hand, at `/stock/value`: the known-cost total, and
// the goods whose cost is unknown, listed by quantity and left OUT of the total (a mixed selection is
// never shown as a complete total). It says what it is: a qualified calculation from the recorded
// movements at their recorded lot costs, as of a cutoff and the time it was calculated, never a
// posted stock-book balance and never a cost of goods. Seeing what goods cost needs the right to
// manage purchases or to read the finances; a failed read can be asked again.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/i18n/app_format.dart';
import '../../../core/i18n/format_controller.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/ui/loading_view.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/stock_page.dart';
import '../domain/stock_trace.dart';
import '../providers/stock_providers.dart';
import 'stock_day.dart';
import 'stock_page_shell.dart';
import 'stock_read_failed.dart';

class StockValueScreen extends ConsumerWidget {
  const StockValueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final held = ref.watch(myPermissionsProvider);
    final seesCost = held.contains(WorkspacePermission.viewFinances) || held.contains(WorkspacePermission.managePurchases);
    return StockPageShell(
      title: l10n.stockValueTitle,
      anchor: HelpAnchor.moneyStockValue,
      helpTopic: l10n.permModuleStock,
      body: (context, ref, workspaceId) {
        if (!seesCost) {
          return Center(key: const ValueKey('stock-value-needs-right'), child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Text(l10n.stockValueNeedsRight)));
        }
        final provider = stockValuationProvider(workspaceId);
        return switch (ref.watch(provider)) {
          AsyncLoading() => const LoadingView(),
          AsyncError(:final error) => StockReadFailed(keyName: 'stock-value', error: error, onRetry: () => ref.invalidate(provider)),
          AsyncData(:final value) => _Value(valuation: value, workspaceId: workspaceId),
        };
      },
    );
  }
}

class _Value extends ConsumerWidget {
  const _Value({required this.valuation, required this.workspaceId});

  final StockValuation valuation;
  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final v = valuation;
    final fmt = appFormatOf(context);
    final money = fmt.moneyIn(v.currency);
    final items = {for (final i in ref.watch(stockItemsProvider(workspaceId)).value ?? const <StockItem>[]) i.id: i}; // empty-ok: a name falls back to its id
    String name(String id) => items[id]?.name ?? id;
    String unit(String id) => items[id]?.unit ?? '';
    final dates = appFormatOf(context).dates(DateShape.date);
    String stamp(DateTime at) => dates.format(stockDayOf(ref, at));
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(l10n.stockValueBasis, key: const ValueKey('stock-value-basis'), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.stockValueKnownTotal(money.formatMinor(v.knownTotalMinor)), key: const ValueKey('stock-value-total'), style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          v.complete ? l10n.stockValueComplete : l10n.stockValueIncomplete,
          key: ValueKey(v.complete ? 'stock-value-complete' : 'stock-value-incomplete'),
          style: v.complete ? null : TextStyle(color: Theme.of(context).colorScheme.error).emphasised,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(l10n.stockValueCutoff(stamp(v.cutoff), stamp(v.calculatedAt), v.movementsCounted), key: const ValueKey('stock-value-cutoff')),
        Text(l10n.stockValueMovesLater, style: Theme.of(context).textTheme.bodySmall),
        if (v.uncosted.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(l10n.stockValueUncostedTitle, style: Theme.of(context).textTheme.titleMedium),
          for (final u in v.uncosted)
            ListTile(
              key: ValueKey('stock-value-uncosted-${u.itemId}-${u.variantId ?? ''}'),
              contentPadding: EdgeInsets.zero,
              title: Text(name(u.itemId)),
              subtitle: Text('${l10n.stockQuantityWithUnit(u.quantity.text, unit(u.itemId))} · ${u.noLot ? l10n.stockValueUncostedNoLot : l10n.stockValueUncostedNoCost}'),
            ),
          if (v.uncostedTruncated) Text(l10n.stockTraceMore),
        ],
        if (v.lines.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(l10n.stockValueLinesTitle, style: Theme.of(context).textTheme.titleMedium),
          for (final line in v.lines)
            ListTile(
              key: ValueKey('stock-value-line-${line.lotId ?? line.itemId}'),
              contentPadding: EdgeInsets.zero,
              title: Text(name(line.itemId)),
              subtitle: Text(l10n.stockValueLine(l10n.stockQuantityWithUnit(line.quantity.text, unit(line.itemId)), money.formatMinor(line.valueMinor))),
            ),
          if (v.linesTruncated) Text(l10n.stockTraceMore),
        ],
      ],
    );
  }
}
