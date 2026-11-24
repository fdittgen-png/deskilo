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

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/stock_page.dart';
import '../domain/stock_trace.dart';
import '../providers/stock_providers.dart';

/// The goods put away against the [kind] (`order` or `bill`) document [id] of [workspaceId].
class StockDocumentGoodsBlock extends ConsumerStatefulWidget {
  const StockDocumentGoodsBlock({required this.workspaceId, required this.kind, required this.id, super.key});

  final String workspaceId;
  final String kind;
  final String id;

  @override
  ConsumerState<StockDocumentGoodsBlock> createState() => _State();
}

class _State extends ConsumerState<StockDocumentGoodsBlock> {
  TraceState _state = TraceState.notLinked;
  final List<DocumentGoodsRow> _rows = [];
  bool _more = false;
  Map<String, Object?>? _next;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load(first: true));
  }

  Future<void> _load({required bool first}) async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await ref.read(stockTraceReaderProvider).documentGoods(widget.workspaceId, widget.kind, widget.id, after: first ? null : _next);
      if (!mounted) return;
      setState(() {
        if (first) _rows.clear();
        _state = page.state;
        _rows.addAll(page.rows);
        _more = page.more;
        _next = page.next;
        _loading = false;
      });
    } on Object catch (e, st) {
      TraceLogger.instance.log(TraceLevel.info, 'stock', 'stock_document_goods_block: Object handled', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = {for (final i in ref.watch(stockItemsProvider(widget.workspaceId)).value ?? const <StockItem>[]) i.id: i}; // empty-ok: a name falls back to its id
    final Widget body;
    if (_failed) {
      body = Row(
        key: const ValueKey('stock-goods-failed'),
        children: [
          Flexible(child: Text(l10n.stockReadFailed)),
          TextButton(key: const ValueKey('stock-goods-retry'), onPressed: () => _load(first: _rows.isEmpty), child: Text(l10n.identityConnectRetry)),
        ],
      );
    } else if (_loading && _rows.isEmpty) {
      body = const LinearProgressIndicator();
    } else if (_state == TraceState.unavailable) {
      body = Text(l10n.stockGoodsUnavailable, key: const ValueKey('stock-goods-unavailable'));
    } else if (_state != TraceState.listed || _rows.isEmpty) {
      body = Text(l10n.stockGoodsNone, key: const ValueKey('stock-goods-none'));
    } else {
      body = Column(
        key: const ValueKey('stock-goods'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in _rows)
            ListTile(
              key: ValueKey('stock-goods-${r.movementId}'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.stockGoodsRow(
                  items[r.itemId]?.name ?? r.itemId,
                  l10n.stockQuantityWithUnit(r.enteredQuantity.text, r.enteredUnit),
                  l10n.stockQuantityWithUnit(r.quantity.text, items[r.itemId]?.unit ?? ''),
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/stock/movements/${r.movementId}'),
            ),
          if (_more)
            TextButton(key: const ValueKey('stock-goods-more'), onPressed: _loading ? null : () => _load(first: false), child: Text(l10n.stockGoodsMore)),
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
