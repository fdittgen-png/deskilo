// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4161 (B) -- one movement at its own address (`/stock/movements/:id`): what
// moved, between which places, the quantity stored and the quantity entered,
// and the cost for a reader who may see costs. A reader who may not is told
// "cost not shown", never shown a zero; a movement that is none (an id of
// nothing, or of another business) says so, and a failed read can be asked
// again.

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show exponentOf;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/help/help_dot.dart';
import '../../../core/i18n/app_format.dart';
import '../../../core/i18n/format_controller.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_snack.dart';
import '../../../core/ui/kit/page_title.dart';
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
import 'stock_place_text.dart';
import 'stock_reversal_sheet.dart';
import 'stock_trace_section.dart';

@visibleForTesting
/// A cost in minor units of [currency] (`250.5`) as the major amount it is
/// (`2.505`), moving the decimal point and nothing else: no float.
String stockCostText(String minor, String currency) {
  final exponent = exponentOf(currency);
  final negative = minor.startsWith('-');
  final body = negative ? minor.substring(1) : minor;
  final point = body.indexOf('.');
  final whole = point < 0 ? body : body.substring(0, point);
  final fraction = point < 0 ? '' : body.substring(point + 1);
  final digits = (whole + fraction).padLeft(exponent + 1 + fraction.length, '0');
  final cut = digits.length - fraction.length - exponent;
  var text = '${digits.substring(0, cut)}.${digits.substring(cut)}';
  text = text
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  final padded = exponent > 0 && !text.contains('.') ? '$text.${'0' * exponent}' : text;
  final trimmedLeading = padded.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  return '${negative ? '-' : ''}$trimmedLeading $currency';
}

class StockMovementScreen extends ConsumerWidget {
  const StockMovementScreen({required this.movementId, super.key});

  final String movementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final provider = stockMovementProvider((
      workspaceId: workspace?.id ?? '',
      id: movementId,
    ));
    final movement = workspace == null ? null : ref.watch(provider);
    final held = ref.watch(myPermissionsProvider);
    final seesCost = held.contains(WorkspacePermission.viewFinances) ||
        held.contains(WorkspacePermission.managePurchases);
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.stockMovementTitle),
        actions: [HelpDot(l10n.permModuleStock, anchor: HelpAnchor.moneyStockReversals)],
      ),
      body: switch (movement) {
        null => const LoadingView(),
        AsyncLoading() => const LoadingView(),
        AsyncError() => Center(
          key: const ValueKey('stock-movement-failed'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.stockReadFailed),
              TextButton(
                key: const ValueKey('stock-movement-retry'),
                onPressed: () => ref.invalidate(provider),
                child: Text(l10n.identityConnectRetry),
              ),
            ],
          ),
        ),
        AsyncData(value: null) => Center(
          key: const ValueKey('stock-movement-none'),
          child: Text(l10n.stockMovementNotFound),
        ),
        AsyncData(:final value?) => _Detail(
          movement: value,
          seesCost: seesCost,
          currency: workspace?.currencyCode ?? '',
        ),
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
        : stockCostText(m.unitCost!, currency);
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
          l10n.stockQuantityWithUnit(m.quantity.text, m.unit),
        ),
        row(
          'entered',
          l10n.stockEnteredLabel,
          l10n.stockQuantityWithUnit(m.enteredQuantity.text, m.enteredUnit),
        ),
        row('when', l10n.stockWhenLabel, day),
        row('reason', l10n.creditMoveReasonLabel, stockMoveReasonText(l10n, m.reason)),
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
          AsyncError() => ListTile(
            key: const ValueKey('stock-reversals-failed'),
            title: Text(l10n.stockReadFailed),
            trailing: TextButton(
              key: const ValueKey('stock-reversals-retry'),
              onPressed: () => ref.invalidate(stockReversibleProvider(key)),
              child: Text(l10n.identityConnectRetry),
            ),
          ),
          AsyncData(value: final a?) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                key: const ValueKey('stock-reversals-remaining'),
                title: Text(
                  a.fullyReversed
                      ? l10n.stockReversalFully
                      : l10n.stockReversalRemaining(a.remaining.text, movement.unit, a.reversed.text),
                ),
              ),
              for (final r in a.reversals)
                ListTile(
                  dense: true,
                  key: ValueKey('stock-reversal-${r.lineId}'),
                  title: Text(l10n.stockReversalEntry(_kindText(l10n, r.kind), r.quantity.text, movement.unit)),
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

  Future<void> _open(BuildContext context, WidgetRef ref, StockReversible allows, StockReturnKind kind) async {
    try {
      final places = await ref.read(stockPlaceConfigsProvider(movement.workspaceId).future);
      if (!context.mounted) return;
      final done = await showStockReversalSheet(
        context,
        ref.read(stockReversalsProvider),
        source: movement,
        allows: allows,
        kind: kind,
        places: places,
      );
      if (done) {
        ref
          ..invalidate(stockReversibleProvider((workspaceId: movement.workspaceId, movementId: movement.id)))
          ..invalidate(stockMovementsWalkProvider)
          ..invalidate(stockOnHandWalkProvider);
      }
    } on Object catch (e, st) {
      TraceLogger.instance.warn('stock', 'the return sheet could not read the stock: $e', stackTrace: st);
      if (context.mounted) AppSnack.error(context, context.l10n.stockReadFailed);
    }
  }
}
