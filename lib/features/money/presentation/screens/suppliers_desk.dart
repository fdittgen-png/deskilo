// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3615 (desk M2) — the suppliers at the desk: a records table (#3606) of
// number, name, what is still open per currency and the last purchase,
// with Active and Archived as chips; a supplier's payables open beside it
// at its address, `/money/suppliers/<id>` (#3607); edit, bank and archive
// are the row's actions, the same flows as the list on a phone.
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
import '../../../../core/time/clock.dart';
import '../../../../core/ui/kit/list_detail_scaffold.dart';
import '../../../../core/ui/kit/records_table.dart';
import '../../domain/purchase.dart';
import '../../domain/supplier_standing.dart';
import '../../providers/purchase_providers.dart';
import '../../providers/supplier_providers.dart';
import '../widgets/supplier_payables_view.dart';
import '../widgets/suppliers_sheet.dart';
import 'purchases_desk.dart';

/// The suppliers' address; a supplier is `/money/suppliers/<id>`.
const String suppliersPath = '/money/suppliers';

/// The suppliers table, with the open supplier's payables beside it.
class SuppliersDesk extends ConsumerWidget {
  const SuppliersDesk({super.key, required this.view, required this.held});

  /// The suppliers list of the phone: its add, edit, bank and archive.
  final SuppliersView view;

  /// The wire names of the permissions the person holds.
  final Set<String> held;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OpenRecord(
    listPath: suppliersPath,
    builder: (context, id) => ListDetailScaffold(
      id: 'suppliers',
      paneStore: ref.watch(paneWidthStoreProvider),
      list: _table(context, ref),
      selected: recordBesideList(context) ? id : null,
      onClose: () => closeRecord(context, suppliersPath),
      onMove: (id) => moveToRecord(context, suppliersPath, id),
      detail: (context, id) => SupplierRecord(
        key: ValueKey('supplier-panel-$id'),
        workspaceId: view.workspaceId,
        supplierId: id,
        held: held,
        onClose: () => closeRecord(context, suppliersPath),
      ),
    ),
  );

  Widget _table(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final format = appFormatOf(context);
    final workspaceId = view.workspaceId;
    final read = ref.watch(suppliersProvider(workspaceId));
    final standings = supplierStandings(
      ref.watch(purchasesProvider(workspaceId)).value ?? // empty-ok: a failed read leaves the last purchase blank
          const <PurchaseSummary>[],
      year: ref.watch(clockProvider).now().year,
    );
    // What each supplier is still owed, per currency; null while unread.
    final payables = ref
        .watch(payablesProvider(workspaceId))
        .value; // empty-ok: an unread payable leaves the open column empty
    final open = <String, Map<String, int>>{};
    for (final p in payables ?? const <PayableRow>[]) {
      final o = p.obligation;
      if (o.creditorKind != CreditorKind.supplier) continue;
      final byCurrency = open[o.creditorId] ??= {};
      byCurrency[o.currency] = (byCurrency[o.currency] ?? 0) + o.remainingCents;
    }
    return RecordsTable<Supplier>(
      tableId: 'suppliers',
      rows: read.value ?? const <Supplier>[], // empty-ok: the table shows loading or failed while it is not read
      state: switch (read) {
        AsyncData() => RecordsState.ready,
        AsyncError() => RecordsState.failed,
        _ => RecordsState.loading,
      },
      onRetry: () => ref.invalidate(suppliersProvider(workspaceId)),
      keyOf: (s) => s.id,
      searchText: (s) => '${s.number} ${s.name} ${s.taxIdEntered}',
      onOpen: (s) => openRecord(context, suppliersPath, s.id),
      empty: Center(child: Text(l.suppliersEmpty)),
      initialQuery: const RecordsQuery(chip: 'active', sortColumn: 'name'),
      chips: [
        RecordChip(
          id: 'active',
          label: l.servicesActive,
          keeps: (s) => s.isActive,
        ),
        RecordChip(
          id: 'archived',
          label: l.suppliersArchivedChip,
          keeps: (s) => !s.isActive,
        ),
      ],
      columns: [
        RecordColumn(
          id: 'number',
          label: l.suppliersFieldNumber,
          flex: 2,
          sortKey: (s) => s.number,
          cell: (_, s) => Text(s.number),
        ),
        RecordColumn(
          id: 'name',
          label: l.suppliersFieldName,
          flex: 4,
          hideable: false,
          sortKey: (s) => s.name.toLowerCase(),
          cell: (_, s) => Text(s.name, overflow: TextOverflow.ellipsis),
        ),
        RecordColumn(
          id: 'open',
          label: l.invoicingColOpen,
          numeric: true,
          flex: 3,
          // One line per currency, never one sum across them.
          cell: (_, s) => Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final e in (open[s.id] ?? const <String, int>{}).entries)
                if (e.value > 0)
                  Text(format.moneyIn(e.key).formatMinor(e.value)),
            ],
          ),
        ),
        RecordColumn(
          id: 'last',
          label: l.suppliersLastPurchase,
          flex: 2,
          sortKey: (s) => standings[s.id]?.lastBillOn ?? DateTime(0),
          cell: (_, s) => Text(switch (standings[s.id]?.lastBillOn) {
            final on? => format.dates(DateShape.numeric).format(on),
            null => '',
          }),
        ),
      ],
      rowActions: (s) => [
        RecordAction(
          id: 'edit',
          label: l.suppliersEdit,
          icon: Icons.edit_outlined,
          onRun: (s) => view.edit(context, ref, s),
        ),
        RecordAction(
          id: 'bank',
          label: l.suppliersBank,
          icon: Icons.account_balance_outlined,
          onRun: (s) => view.bank(context, ref, s),
        ),
        RecordAction(
          id: 'archive',
          label: s.isActive ? l.suppliersArchive : l.suppliersRestore,
          icon: s.isActive ? Icons.archive_outlined : Icons.unarchive_outlined,
          onRun: (s) => view.archive(context, ref, s),
        ),
      ],
      cardBuilder: (context, s) => ListTile(
        title: Text(s.name, overflow: TextOverflow.ellipsis),
        subtitle: Text(s.number),
      ),
    );
  }
}

/// A supplier at its address: what the space owes them, each document
/// opening at its own address.
class SupplierRecord extends ConsumerWidget {
  const SupplierRecord({
    super.key,
    required this.workspaceId,
    required this.supplierId,
    required this.held,
    this.onClose,
  });

  final String workspaceId;
  final String supplierId;

  /// The wire names of the permissions the person holds.
  final Set<String> held;

  /// Set when the supplier stands beside the table: its close button.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers = ref.watch(suppliersProvider(workspaceId)).value;
    final supplier = suppliers?.where((s) => s.id == supplierId).firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(supplier?.name ?? ''),
        automaticallyImplyLeading: onClose == null,
        actions: [
          if (onClose case final close?)
            CloseButton(
              key: const ValueKey('supplier-close'),
              onPressed: close,
            ),
        ],
      ),
      // A supplier the reader cannot read, or none of that id, is said in
      // words; nothing is shown as if it were theirs.
      body: suppliers != null && supplier == null
          ? Center(
              child: Text(
                context.l10n.searchRecordUnreadable,
                key: const ValueKey('search-record-unreadable'),
              ),
            )
          : SupplierPayablesView(
              workspaceId: workspaceId,
              supplierId: supplierId,
              canPay: held.contains(purchasePayPermission),
              canOffset: held.contains(purchaseOffsetPermission),
              onOpen: (id) async => context.push('$purchaseDocPath/$id'),
            ),
    );
  }
}
