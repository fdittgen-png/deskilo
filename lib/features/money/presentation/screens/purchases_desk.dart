// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3615 (desk M2) — the purchases at the desk: a records table (#3606) of
// date, supplier, category, document number, net, VAT, gross, what is
// still open and a mark when a receipt is filed; the chips Open, This month
// and Without receipt with their counts; the footer adds the gross per
// currency, never across. A row opens its document beside the table at its
// address, `/money/purchases/doc/<id>` (#3607). N records a purchase: the
// same "Add a purchase" as on a phone, its supplier bill a side panel
// (#3608). The other doors of the purchases page stand above the table.
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart'
    show Supplier;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/navigation/list_detail_route.dart';
import '../../../../core/storage/pane_width_store.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/adaptive/window_class.dart';
import '../../../../core/ui/kit/list_detail_scaffold.dart';
import '../../../../core/ui/kit/records_table.dart';
import '../../domain/purchase.dart';
import '../../providers/money_providers.dart';
import '../../providers/purchase_providers.dart';
import '../../providers/supplier_providers.dart';
import '../widgets/purchase_labels.dart';
import '../widgets/purchases_sheet.dart';

/// The purchases list's address; a document opens under [purchaseDocPath].
const String _purchasesPath = '/money/purchases';

/// Where a document opens: `/money/purchases/doc/<id>`.
const String purchaseDocPath = '/money/purchases/doc';

/// One row: the document, its supplier's name and what is still open of
/// it (null while the payables are not read).
typedef _Row = ({PurchaseSummary doc, String supplier, int? open});

/// The purchases table, with the open document beside it.
class PurchasesDesk extends ConsumerWidget {
  const PurchasesDesk({
    super.key,
    required this.workspaceId,
    required this.held,
    required this.doors,
  });

  final String workspaceId;

  /// The wire names of the permissions the person holds.
  final Set<String> held;

  /// The purchases page's other doors (suppliers, lease, equipment…).
  final List<Widget> doors;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OpenRecord(
    listPath: purchaseDocPath,
    builder: (context, id) => ListDetailScaffold(
      id: 'purchases',
      paneStore: ref.watch(paneWidthStoreProvider),
      list: _list(context, ref),
      selected: recordBesideList(context) ? id : null,
      onClose: () => context.go(_purchasesPath),
      onMove: (id) => moveToRecord(context, purchaseDocPath, id),
      detail: (context, id) => PurchaseRecord(
        key: ValueKey('purchase-panel-$id'),
        workspaceId: workspaceId,
        purchaseId: id,
        held: held,
        onClose: () => context.go(_purchasesPath),
      ),
    ),
  );

  Widget _list(BuildContext context, WidgetRef ref) {
    final purchases = ref.watch(purchasesProvider(workspaceId));
    // What is open is read from the payables, for who may read them; a
    // payables read that fails leaves the column empty, never at zero.
    final payables = ref
        .watch(payablesProvider(workspaceId))
        .value; // empty-ok: an unread payable leaves the open column empty
    final suppliers = {
      for (final s
          in ref.watch(suppliersProvider(workspaceId)).value ?? // empty-ok: a name is a label; an unread one is left blank
              const <Supplier>[])
        s.id: s.name,
    };
    final open = <String, int>{};
    for (final p in payables ?? const <PayableRow>[]) {
      final id = p.obligation.purchaseId;
      open[id] = (open[id] ?? 0) + p.obligation.remainingCents;
    }
    final rows = <_Row>[
      for (final d in purchases.value ?? const <PurchaseSummary>[]) // empty-ok: the table shows loading or failed while it is not read
        (
          doc: d,
          supplier: suppliers[d.supplierId] ?? '',
          open: payables == null ? null : open[d.id] ?? 0,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (doors.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: doors,
            ),
          ),
        Expanded(
          child: _PurchasesTable(
            rows: rows,
            state: switch (purchases) {
              AsyncData() => RecordsState.ready,
              AsyncError() => RecordsState.failed,
              _ => RecordsState.loading,
            },
            onRetry: () => ref.invalidate(purchasesProvider(workspaceId)),
            today: ref
                .watch(invoicingBusinessProvider)
                .dayOf(ref.watch(clockProvider).now()),
            onOpen: (id) => openRecord(context, purchaseDocPath, id),
          ),
        ),
      ],
    );
  }
}

class _PurchasesTable extends StatelessWidget {
  const _PurchasesTable({
    required this.rows,
    required this.state,
    required this.onRetry,
    required this.today,
    required this.onOpen,
  });

  final List<_Row> rows;
  final RecordsState state;
  final VoidCallback onRetry;

  /// The business's day: what "this month" is.
  final DateTime today;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final format = appFormatOf(context);
    final dates = format.dates(DateShape.numeric);
    // Net and VAT from a large window; below it the gross says the amount.
    final wide = WindowClass.of(context).index >= WindowClass.large.index;
    String figure(_Row r, int? minor) =>
        minor == null ? '' : format.moneyIn(r.doc.currency).formatMinor(minor);
    return RecordsTable<_Row>(
      tableId: 'purchases',
      rows: rows,
      state: state,
      onRetry: onRetry,
      keyOf: (r) => r.doc.id,
      searchText: (r) => '${r.supplier} ${r.doc.category} ${r.doc.reference}',
      onOpen: (r) => onOpen(r.doc.id),
      empty: Center(child: Text(l.purchasesEmpty)),
      initialQuery: const RecordsQuery(sortColumn: 'date', ascending: false),
      chips: [
        RecordChip(
          id: 'open',
          label: l.invoicingFilterOpen,
          keeps: (r) => (r.open ?? 0) > 0,
        ),
        RecordChip(
          id: 'month',
          label: l.overviewThisMonth,
          keeps: (r) =>
              r.doc.dated != null &&
              r.doc.dated!.year == today.year &&
              r.doc.dated!.month == today.month,
        ),
        RecordChip(
          id: 'no-receipt',
          label: l.purchasesWithoutReceipt,
          keeps: (r) => r.doc.receipts == 0,
        ),
      ],
      amountOf: (r) => (currency: r.doc.currency, minor: r.doc.grossCents),
      formatAmount: (c, m) => format.moneyIn(c).formatMinor(m),
      columns: [
        RecordColumn(
          id: 'date',
          label: l.numberSequenceDatePart,
          flex: 3,
          sortKey: (r) => r.doc.dated ?? DateTime(0),
          cell: (_, r) =>
              Text(r.doc.dated == null ? '' : dates.format(r.doc.dated!)),
        ),
        RecordColumn(
          id: 'supplier',
          label: l.purchasesSupplier,
          flex: 4,
          hideable: false,
          sortKey: (r) => r.supplier.toLowerCase(),
          cell: (_, r) => Text(r.supplier, overflow: TextOverflow.ellipsis),
        ),
        RecordColumn(
          id: 'category',
          label: l.servicesCategory,
          staysBeside: false,
          flex: 3,
          sortKey: (r) => r.doc.category.toLowerCase(),
          cell: (_, r) => Text(r.doc.category, overflow: TextOverflow.ellipsis),
        ),
        RecordColumn(
          id: 'number',
          label: l.invoiceRegisterNumber,
          staysBeside: false,
          flex: 3,
          cell: (_, r) => Text(
            r.doc.reference.isEmpty
                ? purchaseKindLabel(l, r.doc.kind)
                : r.doc.reference,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (wide)
          RecordColumn(
            id: 'net',
            label: l.purchaseOrderSummaryNet,
            staysBeside: false,
            numeric: true,
            flex: 3,
            cell: (_, r) => Text(figure(r, r.doc.netCents)),
          ),
        if (wide)
          RecordColumn(
            id: 'vat',
            label: l.vatTitle,
            staysBeside: false,
            numeric: true,
            flex: 3,
            cell: (_, r) => Text(figure(r, r.doc.taxCents)),
          ),
        RecordColumn(
          id: 'gross',
          label: l.purchasesTotal,
          numeric: true,
          flex: 3,
          sortKey: (r) => r.doc.grossCents,
          cell: (_, r) => Text(figure(r, r.doc.grossCents)),
        ),
        RecordColumn(
          id: 'open',
          label: l.invoicingColOpen,
          numeric: true,
          flex: 3,
          sortKey: (r) => r.open ?? -1,
          cell: (_, r) => Text(figure(r, r.open)),
        ),
        RecordColumn(
          id: 'receipt',
          label: l.purchasesReceiptColumn,
          staysBeside: false,
          flex: 3,
          cell: (_, r) => r.doc.receipts == 0
              ? const SizedBox.shrink()
              : Icon(
                  Icons.attach_file,
                  size: 18,
                  semanticLabel: l.purchasesReceiptColumn,
                ),
        ),
      ],
      cardBuilder: (context, r) => ListTile(
        title: Text(r.supplier, overflow: TextOverflow.ellipsis),
        subtitle: Text(r.doc.category),
        trailing: Text(figure(r, r.doc.grossCents)),
      ),
    );
  }
}
