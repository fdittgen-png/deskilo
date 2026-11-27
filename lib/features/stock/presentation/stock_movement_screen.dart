// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4161 (B) -- one movement at its own address (`/stock/movements/:id`): what
// moved, between which places, the quantity stored and the quantity entered,
// and the cost for a reader who may see costs. A reader who may not is told
// "cost not shown", never shown a zero; a movement that is none (an id of
// nothing, or of another business) says so, and a failed read can be asked
// again.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/i18n/app_format.dart';
import '../../../core/i18n/format_controller.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/stock_page.dart';
import '../domain/stock_reversals.dart';
import '../providers/stock_providers.dart';
import 'stock_chain_section.dart';
import 'stock_day.dart';
import 'stock_loss_text.dart';
import 'stock_page_shell.dart';
import 'stock_place_text.dart';
import 'stock_read_failed.dart';
import 'stock_reversal_sheet.dart';
import 'stock_sheet_opener.dart';
import 'stock_trace_section.dart';

class StockMovementScreen extends ConsumerWidget {
  const StockMovementScreen({required this.movementId, super.key});

  final String movementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final held = ref.watch(myPermissionsProvider);
    final seesCost = held.contains(WorkspacePermission.viewFinances) ||
        held.contains(WorkspacePermission.managePurchases);
    return StockPageShell(
      title: l10n.stockMovementTitle,
      anchor: HelpAnchor.moneyStockReversals,
      helpTopic: l10n.permModuleStock,
      body: (context, ref, workspaceId) {
        final provider = stockMovementProvider((workspaceId: workspaceId, id: movementId));
        return switch (ref.watch(provider)) {
          AsyncLoading() => const LoadingView(),
          AsyncError(:final error) => StockReadFailed(keyName: 'stock-movement', error: error, onRetry: () => ref.invalidate(provider)),
          AsyncData(value: null) => Center(
            key: const ValueKey('stock-movement-none'),
            child: Text(l10n.stockMovementNotFound),
          ),
          AsyncData(:final value?) => _Detail(
            movement: value,
            seesCost: seesCost,
            currency: ref.watch(currentWorkspaceProvider).value?.currencyCode ?? '',
          ),
        };
      },
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({
    required this.movement,
    required this.seesCost,
    required this.currency,
  });

  final StockMovementRow movement;
  final bool seesCost;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final m = movement;
    final addresses = ref.watch(stockAddressesProvider(m.workspaceId));
    final day = appFormatOf(context).dates(DateShape.fullDate).format(stockDayOf(ref, m.occurredAt));
    final cost = !seesCost
        ? l10n.stockCostNotShown
        : m.unitCost == null
        ? l10n.stockCostUnknown
        : appFormatOf(context).exactMinor(m.unitCost!, currency);
    Widget row(String key, String label, String value) => ListTile(
      key: ValueKey('stock-movement-$key'),
      title: Text(label),
      subtitle: Text(value),
    );
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        row('item', l10n.expenseSupplyItem, m.itemLabel),
        row('from', l10n.planFromLabel, addresses[m.fromLocationId] ?? m.fromLocationCode),
        row('to', l10n.planToLabel, addresses[m.toLocationId] ?? m.toLocationCode),
        row(
          'lot',
          l10n.stockLotTitle,
          m.lotCode == null ? l10n.stockNoLot : l10n.stockLotLabel(m.lotCode!),
        ),
        row(
          'stored',
          l10n.stockStoredLabel,
          l10n.stockQuantityWithUnit(appFormatOf(context).quantity(m.quantity), m.unit),
        ),
        row(
          'entered',
          l10n.stockEnteredLabel,
          l10n.stockQuantityWithUnit(appFormatOf(context).quantity(m.enteredQuantity), m.enteredUnit),
        ),
        row('when', l10n.stockWhenLabel, day),
        row('reason', l10n.creditMoveReasonLabel, stockMoveReasonText(l10n, m.reason)),
        // a loss says why; one recorded without its cause says that it has none
        if (m.reason == StockTakeOutReason.loss.name) row('loss-cause', l10n.stockLossCauseLabel, m.lossCause == null ? l10n.stockLossCauseNone : stockLossCauseText(l10n, m.lossCause!)),
        if (m.lossNote case final note?) row('loss-note', l10n.stockLossNoteRow, note),
        row('cost', l10n.stockCostLabel, cost),
        _Reversals(movement: m),
        // #4173 — where it came from: the receipt, the order, the bills and their payments, as recorded.
        StockTraceSection(workspaceId: m.workspaceId, movementId: m.id),
        StockChainSection(workspaceId: m.workspaceId, movementId: m.id),
      ],
    );
  }
}

/// #4172 (B) -- what was reversed on this movement and what can still be, and
/// the actions that reverse it: a return from the customer of a sale, a return
/// to the supplier of a receipt, a correction of the others. Only where the
/// feature is on; the actions only for whoever manages the stock.
class _Reversals extends ConsumerWidget {
  const _Reversals({required this.movement});

  final StockMovementRow movement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final on = ref.watch(enabledFeaturesSyncProvider).contains(WorkspaceFeature.stockReturns);
    final kind = stockReturnKindOf(movement);
    if (!on || kind == null) return const SizedBox.shrink();
    final mayManage = ref.watch(myPermissionsProvider).contains(WorkspacePermission.manageStock);
    final key = (workspaceId: movement.workspaceId, movementId: movement.id);
    final allows = ref.watch(stockReversibleProvider(key));
    return Column(
      key: const ValueKey('stock-reversals'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(l10n.stockReversalSection, style: Theme.of(context).textTheme.titleSmall),
        ),
        switch (allows) {
          AsyncLoading() => const Padding(padding: EdgeInsets.all(AppSpacing.md), child: LoadingView()),
          AsyncError(:final error) => StockReadFailed(
            keyName: 'stock-reversals',
            error: error,
            onRetry: () => ref.invalidate(stockReversibleProvider(key)),
          ),
          AsyncData(value: final a?) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                key: const ValueKey('stock-reversals-remaining'),
                title: Text(
                  a.fullyReversed
                      ? l10n.stockReversalFully
                      : l10n.stockReversalRemaining(appFormatOf(context).quantity(a.remaining), movement.unit, appFormatOf(context).quantity(a.reversed)),
                ),
              ),
              for (final r in a.reversals)
                ListTile(
                  dense: true,
                  key: ValueKey('stock-reversal-${r.lineId}'),
                  title: Text(l10n.stockReversalEntry(_kindText(l10n, r.kind), appFormatOf(context).quantity(r.quantity), movement.unit)),
                ),
              if (mayManage && !a.fullyReversed)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: FilledButton(
                    key: const ValueKey('stock-reversal-open'),
                    onPressed: () => _open(context, ref, a, kind),
                    child: Text(switch (kind) {
                      StockReturnKind.customer => l10n.stockReversalCustomerOpen,
                      StockReturnKind.supplier => l10n.stockReversalSupplierOpen,
                      StockReturnKind.correction => l10n.stockReversalCorrectionOpen,
                    }),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  movement.causes.containsKey('invoice') ? l10n.stockReversalMoneyInvoice : l10n.stockReversalMoneyUnavailable,
                  key: const ValueKey('stock-reversal-money'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          _ => const SizedBox.shrink(),
        },
      ],
    );
  }

  String _kindText(AppLocalizations l10n, String kind) => switch (kind) {
    'customer' => l10n.stockReversalKindCustomer,
    'supplier' => l10n.stockReversalKindSupplier,
    _ => l10n.stockReversalKindCorrection,
  };

  Future<void> _open(BuildContext context, WidgetRef ref, StockReversible allows, StockReturnKind kind) => StockSheetOpener(ref).open(
    context,
    movement.workspaceId,
    what: 'return',
    sheet: (choices) => showStockReversalSheet(
      context,
      ref.read(stockReversalsProvider),
      source: movement,
      allows: allows,
      kind: kind,
      places: choices.places,
    ),
    reads: [
      stockReversibleProvider((workspaceId: movement.workspaceId, movementId: movement.id)),
      stockMovementsWalkProvider,
      stockOnHandWalkProvider,
    ],
  );
}
