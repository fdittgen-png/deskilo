// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3616 (desk M3) — the files handed to the accountant, as records (#3606):
// when, the period, the format, who made it, its rows and its fingerprint,
// and whether the period was closed (then the same file every time). The
// log keeps no file, so no row offers a Download (the decision on #3616):
// "Export again" makes a NEW export of that period, with its own entry in
// this log, and "New export" one of every invoice, as the register does.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show BookExport;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../../core/ui/kit/records_table.dart';
import '../../providers/book_period_providers.dart';
import '../../providers/money_providers.dart';
import '../accounting_export.dart';

/// `/money/accounting/exports`.
class AccountingExportsScreen extends ConsumerWidget {
  const AccountingExportsScreen({super.key});

  /// The invoices a file of [from]–[to] holds: those issued in it, never
  /// the voided ones, as the register's export takes them.
  static List<Invoice> _issuedIn(
    List<Invoice> invoices,
    DateTime from,
    DateTime to,
  ) => [
    for (final i in invoices)
      if (!i.isVoided &&
          !i.issuedAt.isBefore(from) &&
          !i.issuedAt.isAfter(to.add(const Duration(days: 1))))
        i,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final workspaceId = ref.watch(invoicingBusinessProvider).id;
    final read = workspaceId.isEmpty
        ? null
        : ref.watch(bookPeriodsProvider(workspaceId));
    final invoices = ref.watch(invoicesProvider);
    final names = ref.watch(memberLabelsProvider);
    final format = appFormatOf(context);
    final dates = format.dates(DateShape.numeric);
    String period(BookExport e) =>
        '${dates.format(e.from)} – ${dates.format(e.to)}';
    Future<void> again(BookExport e) => exportAccountingFile(
      context,
      ref,
      _issuedIn(invoices.requireValue, e.from, e.to),
      label: period(e),
    );
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l.bookPeriodsExports),
        actions: [
          OutlinedButton.icon(
            key: const ValueKey('accounting-exports-new'),
            onPressed: invoices.hasValue
                ? () => exportAccountingFile(context, ref, [
                    for (final i in invoices.requireValue)
                      if (!i.isVoided) i,
                  ], label: l.invoiceRegisterAllYears)
                : null,
            icon: const Icon(Icons.file_download_outlined),
            label: Text(l.invoiceAccountingExport),
          ),
        ],
      ),
      body: RecordsTable<BookExport>(
        tableId: 'accounting-exports',
        rows: read?.value?.exports ?? const <BookExport>[], // empty-ok: the table shows loading or failed while it is not read
        state: switch (read) {
          AsyncData() => RecordsState.ready,
          AsyncError() => RecordsState.failed,
          _ => RecordsState.loading,
        },
        onRetry: workspaceId.isEmpty
            ? null
            : () => ref.invalidate(bookPeriodsProvider(workspaceId)),
        keyOf: (e) => e.id,
        searchText: (e) => e.formatId,
        onOpen: (_) {},
        empty: Center(child: Text(l.bookPeriodsNoExports)),
        initialQuery: const RecordsQuery(sortColumn: 'when', ascending: false),
        columns: [
          RecordColumn(
            id: 'when',
            label: l.numberSequenceDatePart,
            flex: 2,
            sortKey: (e) => e.exportedAt,
            cell: (_, e) => Text(dates.format(e.exportedAt)),
          ),
          RecordColumn(
            id: 'period',
            label: l.vatDeclPeriod,
            flex: 3,
            hideable: false,
            sortKey: (e) => e.from,
            cell: (_, e) => Text(period(e)),
          ),
          RecordColumn(
            id: 'format',
            label: l.taxRefFormat,
            flex: 2,
            sortKey: (e) => e.formatId,
            cell: (_, e) => Text(e.formatId.toUpperCase()),
          ),
          RecordColumn(
            id: 'who',
            label: l.accountingExportsBy,
            flex: 3,
            cell: (_, e) => Text(
              names[e.exportedByMemberId] ?? '',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          RecordColumn(
            id: 'rows',
            label: l.accountingExportsRows,
            numeric: true,
            flex: 2,
            sortKey: (e) => e.rowCount,
            cell: (_, e) => Text(format.number(e.rowCount)),
          ),
          RecordColumn(
            id: 'fingerprint',
            label: l.accountingExportsFingerprint,
            flex: 3,
            // The first characters of the file's sha256: what the log
            // proves, and what a file of a closed period repeats.
            cell: (_, e) => Tooltip(
              message: e.closedPeriod ? l.bookPeriodsExportClosed : e.sha256,
              child: Text(
                e.sha256.length > _fingerprintShown
                    ? e.sha256.substring(0, _fingerprintShown)
                    : e.sha256,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
        rowActions: (e) => [
          RecordAction(
            id: 'again',
            label: l.accountingExportsAgain,
            icon: Icons.replay,
            unavailable: invoices.hasValue ? null : l.accountingStatusNotRead,
            onRun: again,
          ),
        ],
        cardBuilder: (context, e) => ListTile(
          title: Text(period(e)),
          subtitle: Text(e.formatId.toUpperCase()),
          trailing: Text(dates.format(e.exportedAt)),
        ),
      ),
    );
  }
}

/// How many characters of a file's fingerprint the table shows.
const int _fingerprintShown = 12;
