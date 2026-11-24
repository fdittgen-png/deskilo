// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4173 -- "Goods put away" on a purchase order or a supplier bill: the exact movements that put goods
// away against it, each opening its movement (and from there its whole trace). The other direction of
// the trace: a document reaches its goods. Only what is recorded is listed; goods the reader may not
// see are `unavailable`; a bill or order with no recorded link says so and is never "no goods"; a long
// list is read a keyset page at a time. Opening it writes nothing.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/format_controller.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/stock_page.dart';
import '../domain/stock_trace.dart';
import '../providers/stock_providers.dart';
import 'stock_read_failed.dart';

/// The goods put away against the [kind] (`order` or `bill`) document [id] of [workspaceId].
class StockDocumentGoodsBlock extends ConsumerWidget {
  const StockDocumentGoodsBlock({required this.workspaceId, required this.kind, required this.id, super.key});

  final String workspaceId;
  final String kind;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // #4401 -- the one stock walk reads the pages; a failed page keeps the rows and is asked again
    final provider = stockDocumentGoodsWalkProvider((workspaceId: workspaceId, kind: kind, id: id));
    final walk = ref.watch(provider);
    final first = walk.first;
    final state = first is DocumentGoods ? first.state : TraceState.notLinked;
    final items = {for (final i in ref.watch(stockItemsProvider(workspaceId)).value ?? const <StockItem>[]) i.id: i}; // empty-ok: a name falls back to its id
    final Widget body;
    if (walk.error != null) {
      body = StockReadFailed(
        keyName: 'stock-goods',
        error: walk.error!,
        onRetry: () => unawaited(walk.rows.isEmpty ? ref.read(provider.notifier).reload() : ref.read(provider.notifier).loadMore()),
      );
    } else if (walk.loading && walk.rows.isEmpty) {
      body = const LinearProgressIndicator();
    } else if (state == TraceState.unavailable) {
      body = Text(l10n.stockGoodsUnavailable, key: const ValueKey('stock-goods-unavailable'));
    } else if (state != TraceState.listed || walk.rows.isEmpty) {
      body = Text(l10n.stockGoodsNone, key: const ValueKey('stock-goods-none'));
    } else {
      body = Column(
        key: const ValueKey('stock-goods'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in walk.rows)
            ListTile(
              key: ValueKey('stock-goods-${r.movementId}'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.stockGoodsRow(
                  items[r.itemId]?.name ?? r.itemId,
                  l10n.stockQuantityWithUnit(appFormatOf(context).quantity(r.enteredQuantity), r.enteredUnit),
                  l10n.stockQuantityWithUnit(appFormatOf(context).quantity(r.quantity), items[r.itemId]?.unit ?? ''),
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/stock/movements/${r.movementId}'),
            ),
          if (!walk.complete && walk.next != null)
            TextButton(
              key: const ValueKey('stock-goods-more'),
              onPressed: walk.loading ? null : () => unawaited(ref.read(provider.notifier).loadMore()),
              child: Text(l10n.stockGoodsMore),
            ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(l10n.stockGoodsTitle, style: Theme.of(context).textTheme.titleSmall), const SizedBox(height: AppSpacing.xs), body],
      ),
    );
  }
}
