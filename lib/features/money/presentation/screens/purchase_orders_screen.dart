// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — the space's purchase orders (`/money/purchase-orders`): the list,
// the latest first, each with its supplier, state and total; a buyer
// (managePurchases) drafts, edits, prints, marks sent, records what
// arrived and cancels; a
// finance reader reads and prints. The server decides every write.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/adaptive/task_surface.dart';
import '../../../../core/ui/adaptive/window_class.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../../core/ui/kit/records_table.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/purchase_order_commands.dart';
import '../../domain/purchase.dart';
import '../../domain/purchase_order.dart';
import '../../providers/purchase_order_providers.dart';
import '../purchase_order_print.dart';
import '../widgets/purchase_order_receipt_actions.dart';
import '../widgets/purchase_order_send_actions.dart';
import '../widgets/purchase_order_sheet.dart';
import 'money_view_data.dart';

/// The words of an order's [state].
String _stateLabel(AppLocalizations l10n, PurchaseOrderState state) =>
    switch (state) {
      PurchaseOrderState.draft => l10n.purchasesStateDraft,
      PurchaseOrderState.sent => l10n.purchaseOrderStateSent,
      PurchaseOrderState.partlyReceived =>
        l10n.purchaseOrderStatePartlyReceived,
      PurchaseOrderState.received => l10n.purchaseOrderStateReceived,
      PurchaseOrderState.cancelled => l10n.purchaseOrderStateCancelled,
    };

class PurchaseOrdersScreen extends ConsumerWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspace = MoneyViewData.gates(ref).workspace;
    final canWrite = MoneyViewData.purchasePermissionNames(ref)
        .contains(purchaseManagePermission);
    final orders = workspace == null
        ? null
        : ref.watch(purchaseOrdersProvider(workspace.id));
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.purchaseOrdersTitle),
        actions: [
          // #3307 — how the space e-mails its orders, for its billing
          // manager. #3673: the business's one sender is set in its own
          // settings; this opens them.
          if (workspace != null &&
              MoneyViewData.purchasePermissionNames(
                ref,
              ).contains('manageBilling'))
            IconButton(
              key: const ValueKey('purchase-order-mail-settings'),
              tooltip: l10n.businessMailSenderWhere,
              icon: const Icon(Icons.forward_to_inbox_outlined),
              onPressed: () => context.push('/workspace-settings'),
            ),
        ],
      ),
      floatingActionButton: workspace == null || !canWrite
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('purchase-order-new'),
              onPressed: () => PurchaseOrderSheet(
                context,
                ref,
              ).open(workspaceId: workspace.id),
              icon: const Icon(Icons.add),
              label: Text(l10n.purchaseOrderNew),
            ),
      body: switch (orders) {
        null => const SizedBox.shrink(),
        AsyncValue(:final value?) when value.isEmpty => Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            l10n.purchaseOrdersEmpty,
            key: const ValueKey('purchase-orders-empty'),
          ),
        ),
        // #3615 — at the desk, a records table; an order opens beside it
        // as a side panel with its actions.
        AsyncValue(:final value?)
            when WindowClass.of(context).index >=
                WindowClass.expanded.index =>
          _OrdersTable(
            orders: value,
            open: (o) => showTask<void>(
              context,
              size: TaskSize.standard,
              builder: (_) => SingleChildScrollView(
                child: _OrderTile(
                  order: o,
                  workspaceId: workspace!.id,
                  canWrite: canWrite,
                  letterhead: (
                    name: workspace.name,
                    address: workspace.address,
                  ),
                ),
              ),
            ),
          ),
        AsyncValue(:final value?) => ListView(
          padding: const EdgeInsets.only(bottom: kFabSafeBottom),
          children: [
            for (final o in value)
              _OrderTile(
                order: o,
                workspaceId: workspace!.id,
                canWrite: canWrite,
                letterhead: (name: workspace.name, address: workspace.address),
              ),
          ],
        ),
        AsyncValue(:final error?) => Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(l10n.purchaseOrderRefused, semanticsLabel: '$error'),
        ),
        _ => const LoadingView(),
      },
    );
  }
}

class _OrderTile extends ConsumerWidget {
  const _OrderTile({
    required this.order,
    required this.workspaceId,
    required this.canWrite,
    required this.letterhead,
  });

  final PurchaseOrder order;
  final String workspaceId;
  final bool canWrite;

  /// The space's name and address, printed at the top of the order.
  final ({String name, String address}) letterhead;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final reason = FormControllers();
    final requestId = newRequestId();
    await showAppFormSheet(
      context,
      AppFormSheet(
        title: l10n.purchaseOrderCancel,
        submitLabel: l10n.purchaseOrderCancel,
        submitKey: const ValueKey('purchase-order-cancel-confirm'),
        onDispose: reason.dispose,
        validate: () => reason.values['reason']!.isEmpty
            ? {'reason': l10n.purchaseOrderCancelReason}
            : const {},
        onSubmit: () async {
          final ok = await runGuarded(
            context,
            domain: 'money',
            message: 'purchase order cancel failed',
            errorText: l10n.purchaseOrderRefused,
            action: () async {
              await ref
                  .read(purchaseOrderCommandsProvider)
                  .cancel(
                    workspaceId,
                    order,
                    reason.values['reason']!,
                    requestId,
                  );
            },
          );
          return ok ? null : l10n.purchaseOrderRefused;
        },
        builder: (context, refresh) => [
          AppTextField(
            key: const ValueKey('purchase-order-cancel-reason'),
            controller: reason['reason'],
            fieldKey: 'reason',
            label: l10n.purchaseOrderCancelReason,
            maxLength: 300,
          ),
        ],
      ),
    );
  }

  Future<void> _markSent(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final requestId = newRequestId();
    await runGuarded(
      context,
      domain: 'money',
      message: 'purchase order mark sent failed',
      errorText: l10n.purchaseOrderRefused,
      action: () async {
        await ref
            .read(purchaseOrderCommandsProvider)
            .markSent(workspaceId, order, requestId);
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final total = appFormatOf(context).moneyIn(order.currency).formatMinor(order.totalCents);
    final draft = order.state == PurchaseOrderState.draft;
    return Card(
      key: ValueKey('purchase-order-${order.reference}'),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.reference,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  key: ValueKey('purchase-order-state-${order.reference}'),
                  label: Text(_stateLabel(l10n, order.state)),
                ),
              ],
            ),
            Text(l10n.purchaseOrderSummary(order.supplierName, total)),
            if (order.expectedOn case final d?)
              Text(
                l10n.labelWithValue(
                  l10n.purchaseOrderExpected,
                  MaterialLocalizations.of(context).formatMediumDate(d),
                ),
              ),
            const FormGap.small(),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  key: ValueKey('purchase-order-print-${order.reference}'),
                  onPressed: () => PurchaseOrderPrint(context, ref).show(
                    workspaceId: workspaceId,
                    order: order,
                    letterhead: letterhead,
                  ),
                  icon: const Icon(Icons.print_outlined),
                  label: Text(l10n.purchaseOrderPrint),
                ),
                if (canWrite && draft) ...[
                  OutlinedButton.icon(
                    key: ValueKey('purchase-order-edit-${order.reference}'),
                    onPressed: () => PurchaseOrderSheet(
                      context,
                      ref,
                    ).open(workspaceId: workspaceId, orderId: order.id),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l10n.purchaseOrderEdit),
                  ),
                  OutlinedButton.icon(
                    key: ValueKey('purchase-order-sent-${order.reference}'),
                    onPressed: () => _markSent(context, ref),
                    icon: const Icon(Icons.outbox_outlined),
                    label: Text(l10n.purchaseOrderMarkSent),
                  ),
                ],
                if (canWrite && order.state.open)
                  TextButton(
                    key: ValueKey('purchase-order-cancel-${order.reference}'),
                    onPressed: () => _cancel(context, ref),
                    child: Text(l10n.purchaseOrderCancel),
                  ),
              ],
            ),
            PurchaseOrderSendActions(
              order: order,
              workspaceId: workspaceId,
              canWrite: canWrite,
              letterhead: letterhead,
            ),
            PurchaseOrderReceiptActions(
              order: order,
              workspaceId: workspaceId,
              canWrite: canWrite,
            ),
          ],
        ),
      ),
    );
  }
}

/// #3615 — the orders as a records table: reference, supplier, state,
/// expected and total, one total per currency of what is shown.
class _OrdersTable extends StatelessWidget {
  const _OrdersTable({required this.orders, required this.open});

  final List<PurchaseOrder> orders;
  final ValueChanged<PurchaseOrder> open;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = appFormatOf(context);
    final dates = format.dates(DateShape.numeric);
    return RecordsTable<PurchaseOrder>(
      tableId: 'purchase-orders',
      rows: orders,
      keyOf: (o) => o.id,
      searchText: (o) => '${o.reference} ${o.supplierName}',
      onOpen: open,
      empty: Center(child: Text(l10n.purchaseOrdersEmpty)),
      initialQuery: const RecordsQuery(sortColumn: 'reference', ascending: false),
      chips: [
        RecordChip(
          id: 'open',
          label: l10n.invoicingFilterOpen,
          keeps: (o) => o.state.open,
        ),
      ],
      amountOf: (o) => (currency: o.currency, minor: o.totalCents),
      formatAmount: (c, m) => format.moneyIn(c).formatMinor(m),
      columns: [
        RecordColumn(
          id: 'reference',
          label: l10n.invoiceRegisterNumber,
          flex: 2,
          hideable: false,
          sortKey: (o) => o.reference,
          cell: (_, o) => Text(o.reference),
        ),
        RecordColumn(
          id: 'supplier',
          label: l10n.purchaseOrderSupplier,
          flex: 3,
          sortKey: (o) => o.supplierName.toLowerCase(),
          cell: (_, o) => Text(o.supplierName, overflow: TextOverflow.ellipsis),
        ),
        RecordColumn(
          id: 'state',
          label: l10n.invoicingColStatus,
          flex: 2,
          sortKey: (o) => o.state.index,
          cell: (_, o) => Text(_stateLabel(l10n, o.state)),
        ),
        RecordColumn(
          id: 'expected',
          label: l10n.purchaseOrderExpected,
          flex: 2,
          sortKey: (o) => o.expectedOn ?? DateTime(0),
          cell: (_, o) => Text(
            o.expectedOn == null ? '' : dates.format(o.expectedOn!),
          ),
        ),
        RecordColumn(
          id: 'total',
          label: l10n.purchasesTotal,
          numeric: true,
          flex: 2,
          sortKey: (o) => o.totalCents,
          cell: (_, o) =>
              Text(format.moneyIn(o.currency).formatMinor(o.totalCents)),
        ),
      ],
      cardBuilder: (context, o) => ListTile(
        title: Text(o.reference),
        subtitle: Text(o.supplierName),
        trailing: Text(format.moneyIn(o.currency).formatMinor(o.totalCents)),
      ),
    );
  }
}
