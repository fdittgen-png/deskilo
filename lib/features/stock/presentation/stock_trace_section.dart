// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4173 -- "Where this came from" on a movement: the receipt, the order, the bills linked to that
// order, what each bill owes and how it was settled. Only what is RECORDED is shown (nothing is
// matched on a name, a date or an amount); a layer the reader may not see says so and is never
// "unpaid"; a layer with nothing recorded says "not linked"; a list cut short says so. Opening it
// writes nothing. A failed read can be asked again and is never shown as an empty trace.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/format_controller.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/navigation/list_detail_route.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/stock_trace.dart';
import '../providers/stock_providers.dart';
import 'stock_read_failed.dart';

/// The trace of the movement [movementId] of [workspaceId], as a block of the movement's page.
class StockTraceSection extends ConsumerWidget {
  const StockTraceSection({required this.workspaceId, required this.movementId, super.key});

  final String workspaceId;
  final String movementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = stockTraceProvider((workspaceId: workspaceId, movementId: movementId));
    final body = switch (ref.watch(provider)) {
      AsyncLoading() => const Padding(padding: EdgeInsets.all(AppSpacing.md), child: LinearProgressIndicator()),
      AsyncError(:final error) => StockReadFailed(keyName: 'stock-trace', error: error, onRetry: () => ref.invalidate(provider)),
      AsyncData(:final value) => value.traces.isEmpty
          ? Text(l10n.stockTraceNoPurchase, key: const ValueKey('stock-trace-none'))
          : _Purchase(purchase: value.traces.first.purchase),
    };
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        key: const ValueKey('stock-trace'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.stockTraceTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          body,
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.stockTraceNote, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

String _day(BuildContext context, String? iso) {
  final at = iso == null ? null : DateTime.tryParse(iso);
  return at == null ? (iso ?? '') : MaterialLocalizations.of(context).formatMediumDate(at);
}

class _Purchase extends StatelessWidget {
  const _Purchase({required this.purchase});

  final TracePurchase purchase;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return switch (purchase.state) {
      TraceState.unavailable => Text(l10n.stockTracePurchaseUnavailable, key: const ValueKey('stock-trace-purchase-unavailable')),
      TraceState.linked => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.stockTraceReceived(_day(context, purchase.receivedOn)), key: const ValueKey('stock-trace-received')),
          ListTile(
            key: const ValueKey('stock-trace-order'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.stockTraceOrder(purchase.orderReference ?? '', purchase.supplierName ?? '')),
            trailing: const Icon(Icons.chevron_right),
            onTap: purchase.orderId == null ? null : () => openRecordFrom(context, '/money/purchase-orders/order/${purchase.orderId}'),
          ),
          _Bills(purchase: purchase),
        ],
      ),
      _ => Text(l10n.stockTraceNoPurchase, key: const ValueKey('stock-trace-not-linked')),
    };
  }
}

class _Bills extends StatelessWidget {
  const _Bills({required this.purchase});

  final TracePurchase purchase;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return switch (purchase.billsState) {
      TraceState.unavailable => Text(l10n.stockTraceBillsUnavailable, key: const ValueKey('stock-trace-bills-unavailable')),
      TraceState.listed => Column(
        key: const ValueKey('stock-trace-bills'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final bill in purchase.bills) _Bill(bill: bill),
          if (purchase.billsTruncated) Text(l10n.stockTraceMore, key: const ValueKey('stock-trace-bills-more')),
        ],
      ),
      _ => Text(l10n.stockTraceNoBill, key: const ValueKey('stock-trace-no-bill')),
    };
  }
}

class _Bill extends StatelessWidget {
  const _Bill({required this.bill});

  final TraceBill bill;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final money = appFormatOf(context).moneyIn(bill.currency);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          key: ValueKey('stock-trace-bill-${bill.id}'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.stockTraceBill(bill.reference)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openRecordFrom(context, '/money/purchases/doc/${bill.id}'),
        ),
        for (final o in bill.obligations)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.stockTraceOwed(money.formatMinor(o.amountCents))),
                ..._settlement(context, l10n, o),
              ],
            ),
          ),
        if (bill.obligationsTruncated) Text(l10n.stockTraceMore),
      ],
    );
  }

  List<Widget> _settlement(BuildContext context, AppLocalizations l10n, TraceObligation o) {
    if (o.settlementState == TraceState.unavailable) {
      return [Text(l10n.stockTracePaymentsUnavailable, key: ValueKey('stock-trace-payments-unavailable-${o.id}'))];
    }
    if (o.settlement.isEmpty) return [Text(l10n.stockTraceNoPayment, key: ValueKey('stock-trace-no-payment-${o.id}'))];
    final money = appFormatOf(context).moneyIn(o.currency);
    return [
      for (final a in o.settlement)
        Text(
          key: ValueKey('stock-trace-allocation-${a.id}'),
          a.reversal
              ? l10n.stockTraceReversed(money.formatMinor(-a.amountCents), _day(context, a.reportedPaidOn))
              : l10n.stockTracePaid(money.formatMinor(a.amountCents), _day(context, a.reportedPaidOn)),
        ),
      if (o.settlementTruncated) Text(l10n.stockTraceMore),
    ];
  }
}
