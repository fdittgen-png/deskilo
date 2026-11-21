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

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/kit/page_title.dart';
import '../../../core/ui/loading_view.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/stock_page.dart';
import '../providers/stock_providers.dart';
import 'stock_day.dart';

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
      appBar: AppBar(title: PageTitle(l10n.stockMovementTitle)),
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
    final day = MaterialLocalizations.of(context)
        .formatFullDate(stockDayOf(ref, m.occurredAt));
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
        row('from', l10n.planFromLabel, m.fromLocationCode),
        row('to', l10n.planToLabel, m.toLocationCode),
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
        row('reason', l10n.creditMoveReasonLabel, m.reason),
        row('cost', l10n.stockCostLabel, cost),
      ],
    );
  }
}
