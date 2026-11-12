// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/files/file_delivery.dart';
import '../../../../core/files/file_delivery_notice.dart';
import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../../core/ui/kit/records_table.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/workspace_permission.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/accounting_view.dart';
import '../../domain/register_csv.dart';
import '../../domain/register_period.dart';
import '../../providers/money_providers.dart';
import '../accounting_export.dart';
import '../invoice_actions.dart' show workspaceIsEu;
import '../invoice_status.dart';
import '../period_label.dart';
import '../widgets/invoice_detail_sheet.dart';
import '../widgets/invoice_integrity_chip.dart';

/// The REGISTER: every invoice on one line — date, name, amount, status —
/// sorted by date, newest or oldest first.
///
/// The archive is a browsing surface (cards, filters, per-row actions);
/// this is the ledger view an accountant or a member scanning "what have I
/// been invoiced, what is settled" actually wants. The **name** column
/// follows the reader: an issuer scans MEMBERS, a member scans their own
/// invoice numbers — showing someone their own name in every row tells
/// them nothing.
///
/// A member sees only what concerns them: issued and not tagged erroneous
/// (RLS already scopes the rows to their own).
/// What the register's table reads beside the invoices.
typedef _RegisterView = ({
  Map<String, InvoiceMatch> matches,
  Map<String, ({int count, DateTime last})> reminders,
  DateFormat dateFormat,
  bool showMemberNames,
  bool canIssue,
  bool canExport,
});

class InvoiceRegisterScreen extends ConsumerStatefulWidget {
  const InvoiceRegisterScreen({super.key, this.from, this.to});

  /// #2578 — the days a drill-through narrows the register to (`YYYY-MM`
  /// or `YYYY-MM-DD`); anything missing or malformed shows every invoice.
  final String? from;
  final String? to;

  @override
  ConsumerState<InvoiceRegisterScreen> createState() =>
      _InvoiceRegisterScreenState();
}

class _InvoiceRegisterScreenState
    extends ConsumerState<InvoiceRegisterScreen> {
  /// The window the register was opened on; cleared by the chip.
  late RegisterPeriod? _period = RegisterPeriod.parse(widget.from, widget.to);

  @override
  void didUpdateWidget(InvoiceRegisterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The same route reopened with another window (a drill from a figure).
    if (oldWidget.from != widget.from || oldWidget.to != widget.to) {
      _period = RegisterPeriod.parse(widget.from, widget.to);
    }
  }

  /// null = every year. An accountant works a fiscal year at a time, and
  /// the SAF-T export takes exactly what the register shows.
  int? _year;

  /// An export is running: the one command the register owns.
  bool _exporting = false;

  Future<void> _export(List<Invoice> shown, {required String label}) async {
    setState(() => _exporting = true);
    try {
      await exportAccountingFile(context, ref, shown, label: label);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final invoicesAsync = ref.watch(invoicesProvider);
    final matchesAsync = ref.watch(invoiceMatchesProvider);
    final remindersAsync = ref.watch(invoiceRemindersProvider);
    // #3680 — a row's status reads the matches and reminders: the table is
    // drawn only when they answered (an unread match is not "open").
    final statuses = ReadsAnswer.of([matchesAsync, remindersAsync]);
    final rawMatches = matchesAsync.value ?? const {}; // empty-ok: the table waits for `statuses`
    // #831 — a regrouped invoice reads paid through its settlement; the
    // settlement row keeps its own status.
    final matches = {
      ...rawMatches,
      ...accountingView(
              invoicesAsync.value ?? const [], rawMatches) // empty-ok: the table waits for the invoices (AsyncReadBody)
          .matches,
    };
    final reminders = remindersAsync.value ?? const {}; // empty-ok: the table waits for `statuses`
    final me = ref.watch(myMemberProvider).value;
    final permissions = ref.watch(myPermissionsProvider);
    // #2137 — the matrix decides, as on the invoices screen; it already
    // folds the legacy adminInvoicing grant in.
    final canIssue =
        me != null && permissions.contains(WorkspacePermission.issueInvoices);
    final showMemberNames = (me?.canAdminister ?? false) ||
        permissions.contains(WorkspacePermission.viewFinances);
    // #2365 — the accountant: reads the finances and exports, issues nothing.
    final canExport = permissions.contains(WorkspacePermission.exportData) &&
        (canIssue || permissions.contains(WorkspacePermission.viewFinances));
    final dateFormat = appFormatOf(context).dates(DateShape.numeric);

    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.invoiceRegisterTitle),
        actions: [
          // #1310 S0 — an accounting export (and the archive bundle
          // behind it) is a bulk export: exportData governs it, beside
          // the issuing right that decides whose invoices are visible.
          if (canExport)
            IconButton(
              key: const ValueKey('invoice-accounting-export'),
              // Named for the ACTION, not for one of the seven formats
              // behind it (#669). It said "(SAF-T)" until an owner
              // hunting for the accounting export walked past it.
              tooltip: l10n.invoiceAccountingExport,
              icon: const Icon(Icons.plagiarism_outlined),
              // #3061 — one export at a time: the button is off from the
              // tap until the run ends, however it ends.
              // #3680 — nothing to export before the invoices answered.
              onPressed: _exporting || !invoicesAsync.hasValue
                  ? null
                  : () => _export(
                      _visible(invoicesAsync.requireValue, canIssue || canExport),
                      label: _year?.toString() ??
                          (_period == null
                              ? l10n.invoiceRegisterAllYears
                              : _periodText(l10n, dateFormat, _period!)),
                    ),
            ),
        ],
      ),
      body: Column(children: [
        if (_period case final period?)
          _periodChip(l10n, dateFormat, period),
        Expanded(
          child: AsyncReadBody<List<Invoice>>(
            value: invoicesAsync,
            onRetry: () => ref.invalidate(invoicesProvider),
            data: (invoices) =>
                statuses.standIn(
                  onRetry: () => ref
                    ..invalidate(invoiceMatchesProvider)
                    ..invalidate(invoiceRemindersProvider),
                ) ??
                _table(
              context,
              invoices: _visible(invoices, canIssue),
              years: {for (final i in invoices) i.issuedAt.year}.toList()
                ..sort((a, b) => b.compareTo(a)),
              view: (
                matches: matches,
                reminders: reminders,
                dateFormat: dateFormat,
                showMemberNames: showMemberNames,
                canIssue: canIssue,
                canExport: canExport,
              ),
            ),
          ),
        ),
      ]),
    );
  }

  String _periodText(
    AppLocalizations l10n,
    DateFormat dateFormat,
    RegisterPeriod period,
  ) => l10n.invoiceRegisterPeriod(
    dateFormat.format(period.first),
    dateFormat.format(period.last),
  );

  /// #2578 — says which days the rows are, and takes the narrowing off.
  Widget _periodChip(
    AppLocalizations l10n,
    DateFormat dateFormat,
    RegisterPeriod period,
  ) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: InputChip(
        key: const ValueKey('invoice-register-period'),
        label: Text(_periodText(l10n, dateFormat, period)),
        deleteIcon: const Icon(Icons.close, key: ValueKey('invoice-register-period-clear')),
        deleteButtonTooltipMessage: l10n.invoiceRegisterPeriodClear,
        onDeleted: () => setState(() => _period = null),
      ),
    ),
  );

  /// What this reader may see, narrowed to the picked year. Erroneous
  /// documents stay with the people who correct them; a member's register
  /// only carries what they owe or have paid.
  List<Invoice> _visible(List<Invoice> invoices, bool canIssue) => [
        for (final invoice in invoices)
          if ((canIssue || !invoice.isVoided) &&
              (_year == null || invoice.issuedAt.year == _year) &&
              (_period?.contains(invoice.issuedAt) ?? true))
            invoice,
      ];

  Widget _table(
    BuildContext context, {
    required List<Invoice> invoices,
    required List<int> years,
    required _RegisterView view,
  }) {
    final l10n = context.l10n;
    final format = appFormatOf(context);
    void open(Invoice i) => _open(
      i,
      match: view.matches[i.id],
      reminder: view.reminders[i.id],
      canIssue: view.canIssue,
      showMemberName: view.showMemberNames,
    );
    return Column(children: [
      if (years.length > 1) _yearPicker(l10n, years),
      // #3606 — the register is a records table: sorted, filtered,
      // selected; one total per currency, never one sum across them.
      Expanded(
        child: RecordsTable<Invoice>(
          tableId: 'invoice-register',
          rows: invoices,
          keyOf: (i) => i.id,
          initialQuery: const RecordsQuery(
            sortColumn: 'date',
            ascending: false,
          ),
          searchText: (i) =>
              '${i.memberName} ${i.number} ${invoicePeriodLabel(context, i)}',
          onOpen: open,
          empty: EmptyState(
            icon: Icons.receipt_long_outlined,
            title: l10n.invoicesEmpty,
          ),
          amountOf: (i) => (currency: i.currency, minor: i.totalCents),
          formatAmount: (c, m) => format.moneyIn(c).formatMinor(m),
          columns: _columns(context, view),
          bulkActions: [
            // #3606 — the selection as a CSV of the register's columns,
            // behind the register's export permission. Not an accounting
            // file: the year's audit export stays whole, on the app bar.
            if (view.canExport)
              RecordBulkAction(
                id: 'download',
                label: l10n.invoiceRegisterDownloadSelected,
                icon: Icons.file_download_outlined,
                onRun: (keys) => _download(
                  context,
                  [
                    for (final i in invoices)
                      if (keys.contains(i.id)) i,
                  ],
                  matches: view.matches,
                ),
              ),
          ],
          cardBuilder: (context, i) => _card(context, i, view),
        ),
      ),
    ]);
  }

  /// The year's narrowing, when the register spans more than one.
  Widget _yearPicker(AppLocalizations l10n, List<int> years) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.lg,
      0,
    ),
    child: DropdownButtonFormField<int?>(
      key: const ValueKey('invoice-register-year'),
      initialValue: _year,
      isExpanded: true,
      items: [
        DropdownMenuItem(child: Text(l10n.invoiceRegisterAllYears)),
        for (final year in years)
          // A year is a number, not copy — but the lint reads the
          // literal, so the digits go through a variable.
          DropdownMenuItem(value: year, child: Text(year.toString())),
      ],
      onChanged: (value) => setState(() => _year = value),
      decoration: InputDecoration(labelText: l10n.numberSequenceDateYear),
    ),
  );

  /// The register's columns.
  List<RecordColumn<Invoice>> _columns(
    BuildContext context,
    _RegisterView view,
  ) {
    final l10n = context.l10n;
    final format = appFormatOf(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    String name(Invoice i) => _nameOf(i, view);
    return [
      RecordColumn(
        id: 'date',
        label: l10n.numberSequenceDatePart,
        flex: 2,
        sortKey: (i) => i.issuedAt,
        cell: (_, i) => Text(view.dateFormat.format(i.issuedAt)),
      ),
      RecordColumn(
        id: 'name',
        label: l10n.invoiceRegisterName,
        flex: 3,
        hideable: false,
        sortKey: (i) => name(i).toLowerCase(),
        cell: (_, i) => Text(name(i), overflow: TextOverflow.ellipsis),
      ),
      RecordColumn(
        id: 'period',
        label: l10n.invoiceRegisterPeriodColumn,
        flex: 2,
        cell: (context, i) => Text(
          invoicePeriodLabel(context, i),
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: muted),
        ),
      ),
      RecordColumn(
        id: 'amount',
        label: l10n.invoiceRegisterAmount,
        numeric: true,
        flex: 2,
        sortKey: (i) => i.totalCents,
        cell: (_, i) =>
            Text(format.moneyIn(i.currency).formatMinor(i.totalCents)),
      ),
      RecordColumn(
        id: 'status',
        label: l10n.invoiceRegisterStatus,
        flex: 2,
        cell: (_, i) => InvoiceStatusChip(
          status: invoiceLifecycleOf(i, view.matches[i.id]),
        ),
      ),
      // #956 — the fingerprint, checked on demand.
      RecordColumn(
        id: 'integrity',
        label: l10n.invoiceRegisterIntegrity,
        flex: 3,
        cell: (_, i) => InvoiceIntegrityChip(invoiceId: i.id),
      ),
    ];
  }

  /// The name that means something to THIS reader.
  static String _nameOf(Invoice i, _RegisterView view) =>
      view.showMemberNames ? i.memberName : i.number;

  /// An invoice as a card, on a phone.
  Widget _card(BuildContext context, Invoice i, _RegisterView view) {
    final format = appFormatOf(context);
    return Card(
      child: ListTile(
        title: Text(_nameOf(i, view), overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${view.dateFormat.format(i.issuedAt)} · '
          '${invoicePeriodLabel(context, i)}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(format.moneyIn(i.currency).formatMinor(i.totalCents)),
            InvoiceStatusChip(
              status: invoiceLifecycleOf(i, view.matches[i.id]),
            ),
          ],
        ),
      ),
    );
  }

  /// #3606 — [selected] as the register's CSV, through the platform's
  /// file delivery.
  Future<void> _download(
    BuildContext context,
    List<Invoice> selected, {
    required Map<String, InvoiceMatch> matches,
  }) async {
    final l10n = context.l10n;
    final bytes = registerCsv(
      selected,
      header: (
        date: l10n.numberSequenceDatePart,
        number: l10n.invoiceRegisterNumber,
        member: l10n.invoiceRegisterMember,
        period: l10n.invoiceRegisterPeriodColumn,
        amount: l10n.invoiceRegisterAmount,
        currency: l10n.invoiceRegisterCurrency,
        status: l10n.invoiceRegisterStatus,
      ),
      period: (i) => invoicePeriodLabel(context, i),
      status: (i) =>
          invoiceLifecycleLabel(l10n, invoiceLifecycleOf(i, matches[i.id])),
    );
    final name = registerCsvName(
      ref.read(currentWorkspaceProvider).value?.name ?? '',
      ref.read(clockProvider).now(),
    );
    Future<void> deliver() async {
      final delivery = await deliverFile(
        context,
        ref,
        bytes: bytes,
        fileName: name,
      );
      if (!context.mounted) return;
      announceFileDelivery(context, delivery, retry: deliver);
    }

    await deliver();
  }

  Future<void> _open(
    Invoice invoice, {
    required InvoiceMatch? match,
    required ({int count, DateTime last})? reminder,
    required bool canIssue,
    required bool showMemberName,
  }) async {
    final countryCode =
        ref.read(currentWorkspaceProvider).value?.countryCode ?? '';
    await showInvoiceDetailSheet(
      context,
      ref: ref,
      view: InvoiceDetailView(
        invoice: invoice,
        match: match,
        canIssue: canIssue,
        isEu: workspaceIsEu(ref, countryCode),
        reminder: reminder,
        showMemberName: showMemberName,
        transmission: ref.read(invoiceTransmissionsProvider).value?[invoice.id],
      ),
    );
  }
}
