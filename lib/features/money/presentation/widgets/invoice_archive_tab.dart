// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/invoice.dart';
import '../../providers/money_providers.dart';
import '../invoice_actions.dart';
import '../invoice_status.dart';
import '../period_label.dart';
import 'invoice_detail_sheet.dart';

/// Archive sort orders (field request: sort and filter by member and
/// period).
enum InvoiceSort { newest, member, period }

/// The invoice ARCHIVE (0060): every member sees their own invoices, admins
/// the workspace's. For issuers the archive holds CLOSED invoices only
/// (paid or erroneous) — what is still open lives on the Open tab.
///
/// A row is a summary, not a control panel: number, status, month, amount.
/// Reading the document and acting on it happen in the detail sheet one tap
/// away — the archive used to offer three cramped icon buttons and no way to
/// see what an invoice actually contained.
class InvoiceArchiveTab extends ConsumerStatefulWidget {
  const InvoiceArchiveTab({
    super.key,
    required this.canIssue,
    required this.showMemberNames,
    required this.countryCode,
    required this.isEu,
  });

  /// Whether the viewer may issue/correct (owner, or admin with the
  /// adminInvoicing delegation) — also what splits the hub's archive from a
  /// member's plain one.
  final bool canIssue;

  /// Admins see whose invoice a row is; members do not need to be told.
  final bool showMemberNames;

  final String countryCode;

  /// 2014/55/EU: the e-invoice affordance shows for EU workspaces.
  final bool isEu;

  @override
  ConsumerState<InvoiceArchiveTab> createState() => _InvoiceArchiveTabState();
}

class _InvoiceArchiveTabState extends ConsumerState<InvoiceArchiveTab> {
  String? _filterMemberId;
  String? _filterPeriod;
  InvoiceSort _sort = InvoiceSort.newest;

  /// Cancelled (voided) invoices are hidden BY DEFAULT (#452, field
  /// request) — the chip lets issuers pull the correction trail back in.
  bool _hideVoided = true;

  bool get _filtering => _filterMemberId != null || _filterPeriod != null;

  void _clearFilters() => setState(() {
        _filterMemberId = null;
        _filterPeriod = null;
      });

  /// Opens the detail sheet and runs whatever it decided on.
  Future<void> _open(
    Invoice invoice, {
    required InvoiceMatch? match,
    required ({int count, DateTime last})? reminder,
    required String replacedByNumber,
  }) async {
    final action = await showInvoiceDetailSheet(
      context,
      invoice: invoice,
      match: match,
      canIssue: widget.canIssue,
      isEu: widget.isEu,
      reminder: reminder,
      replacedByNumber: replacedByNumber,
      showMemberName: widget.showMemberNames,
      transmission: ref.read(invoiceTransmissionsProvider).value?[invoice.id],
    );
    if (action == null || !mounted) return;
    await runInvoiceAction(
      context,
      ref,
      action,
      invoice,
      countryCode: widget.countryCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final invoicesAsync = ref.watch(invoicesProvider);
    return switch (invoicesAsync) {
      AsyncData(value: final invoices) =>
        _body(context, l10n, invoices),
      AsyncError() => Center(
          child: Text(
            l10n?.workspaceGenericError ??
                'Something went wrong. Please try again.',
          ),
        ),
      _ => const LoadingView(),
    };
  }

  Widget _body(
    BuildContext context,
    AppLocalizations? l10n,
    List<Invoice> invoices,
  ) {
    if (invoices.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: l10n?.invoicesEmpty ?? 'No invoices yet.',
      );
    }
    final matches = ref.watch(invoiceMatchesProvider).value ?? const {};
    final reminders = ref.watch(invoiceRemindersProvider).value ?? const {};
    final dateFormat = DateFormat.yMMMd(
      Localizations.maybeLocaleOf(context)?.toString(),
    );

    // A correction chain, never a fork (0061): who replaced whom.
    final replacedBy = <String, String>{
      for (final invoice in invoices)
        if (invoice.replacesInvoiceId != null)
          invoice.replacesInvoiceId!: invoice.number,
    };
    // Filter options come from the ARCHIVE itself: member names are the
    // invoices' snapshots (departed members keep working), periods the
    // distinct issued months.
    final memberOptions = <String, String>{};
    for (final invoice in invoices) {
      memberOptions.putIfAbsent(invoice.memberId, () => invoice.memberName);
    }
    final periodOptions = {
      for (final invoice in invoices) ?invoice.period,
    }.toList()
      ..sort((a, b) => b.compareTo(a));

    // 0067 — in the hub the archive holds only CLOSED invoices: paid
    // (validated) or erroneous; open ones live on the Open tab. Members
    // (no tabs) see all of their invoices here.
    bool closed(Invoice invoice) => switch (
        invoiceLifecycleOf(invoice, matches[invoice.id])) {
      // #504 — a PARTIAL payment is not closed: the remainder is owed
      // until its validated write-off (remainderCancelled).
      InvoiceLifecycle.paid ||
      InvoiceLifecycle.remainderCancelled ||
      InvoiceLifecycle.erroneous =>
        true,
      _ => false,
    };
    // A member's list holds the documents that concern THEM: issued, and
    // not tagged erroneous — a cancelled invoice owes nobody anything and
    // only confuses (field decision 0072). Issuers keep seeing everything
    // closed, erroneous included, because correcting is their job.
    // #452: cancelled invoices are filtered out by default for
    // EVERYONE; the chip (issuers only — a member's cancelled invoice
    // stays hidden, field decision 0072) shows them again on demand.
    final visible = [
      for (final invoice in invoices)
        if ((widget.canIssue
                ? closed(invoice) &&
                    !(_hideVoided && invoice.isVoided)
                : !invoice.isVoided) &&
            (_filterMemberId == null ||
                invoice.memberId == _filterMemberId) &&
            (_filterPeriod == null || invoice.period == _filterPeriod))
          invoice,
    ]..sort((a, b) => switch (_sort) {
        InvoiceSort.newest => b.issuedAt.compareTo(a.issuedAt),
        InvoiceSort.member => a.memberName
                    .toLowerCase()
                    .compareTo(b.memberName.toLowerCase()) !=
                0
            ? a.memberName
                .toLowerCase()
                .compareTo(b.memberName.toLowerCase())
            : b.issuedAt.compareTo(a.issuedAt),
        InvoiceSort.period =>
          (b.period ?? '').compareTo(a.period ?? '') != 0
              ? (b.period ?? '').compareTo(a.period ?? '')
              : b.issuedAt.compareTo(a.issuedAt),
      });

    return Column(children: [
      _filterBar(context, l10n, memberOptions, periodOptions, visible.length),
      Expanded(
        child: visible.isEmpty
            ? EmptyState(
                icon: _filtering
                    ? Icons.filter_alt_off_outlined
                    : Icons.receipt_long_outlined,
                // A filtered-empty list is not an empty archive — saying
                // "no invoices yet" there sent people looking for a bug.
                title: _filtering
                    ? (l10n?.invoiceFilterNoMatch ??
                        'No invoice matches these filters.')
                    : (l10n?.invoicesEmpty ?? 'No invoices yet.'),
              )
            : ListView.builder(
                padding: AppSpacing.mdAll,
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final invoice = visible[index];
                  return _row(
                    context,
                    l10n,
                    invoice,
                    match: matches[invoice.id],
                    reminder: reminders[invoice.id],
                    replacedByNumber: replacedBy[invoice.id] ?? '',
                    dateFormat: dateFormat,
                  );
                },
              ),
      ),
    ]);
  }

  Widget _filterBar(
    BuildContext context,
    AppLocalizations? l10n,
    Map<String, String> memberOptions,
    List<String> periodOptions,
    int shown,
  ) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.sm,
          0,
        ),
        child: Column(children: [
          Row(children: [
            if (widget.showMemberNames) ...[
              Expanded(
                child: DropdownButtonFormField<String?>(
                  key: const ValueKey('invoice-filter-member'),
                  initialValue: _filterMemberId,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(
                        l10n?.invoiceFilterAllMembers ?? 'All members',
                      ),
                    ),
                    for (final entry in memberOptions.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value,
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _filterMemberId = value),
                  decoration: InputDecoration(
                    labelText: l10n?.invoiceMemberLabel ?? 'Member',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: DropdownButtonFormField<String?>(
                key: const ValueKey('invoice-filter-period'),
                initialValue: _filterPeriod,
                isExpanded: true,
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(
                      l10n?.invoiceFilterAllMonths ?? 'All months',
                    ),
                  ),
                  for (final period in periodOptions)
                    DropdownMenuItem(
                      value: period,
                      child: Text(
                        monthLabel(context, period),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _filterPeriod = value),
                decoration: InputDecoration(
                  labelText: l10n?.invoiceFilterMonthLabel ?? 'Month',
                ),
              ),
            ),
            PopupMenuButton<InvoiceSort>(
              key: const ValueKey('invoice-sort'),
              tooltip: l10n?.invoiceSortTooltip ?? 'Sort',
              icon: const Icon(Icons.sort),
              initialValue: _sort,
              onSelected: (value) => setState(() => _sort = value),
              itemBuilder: (context) => [
                PopupMenuItem(
                  key: const ValueKey('invoice-sort-newest'),
                  value: InvoiceSort.newest,
                  child: Text(l10n?.invoiceSortNewest ?? 'Newest first'),
                ),
                if (widget.showMemberNames)
                  PopupMenuItem(
                    key: const ValueKey('invoice-sort-member'),
                    value: InvoiceSort.member,
                    child: Text(l10n?.invoiceSortByMember ?? 'By member'),
                  ),
                PopupMenuItem(
                  key: const ValueKey('invoice-sort-period'),
                  value: InvoiceSort.period,
                  child: Text(l10n?.invoiceSortByMonth ?? 'By month'),
                ),
              ],
            ),
          ]),
          // How much of the archive is on screen, and one tap back to all
          // of it. Issuers can pull the cancelled correction trail back
          // in (#452 — hidden by default).
          Row(children: [
            if (widget.canIssue)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: FilterChip(
                  key: const ValueKey('invoice-filter-hide-voided'),
                  label: Text(
                    l10n?.invoiceShowCancelled ?? 'Show cancelled',
                  ),
                  selected: !_hideVoided,
                  onSelected: (show) =>
                      setState(() => _hideVoided = !show),
                ),
              ),
            Expanded(
              child: Text(
                l10n?.invoiceCountShown(shown) ?? '$shown invoices',
                key: const ValueKey('invoice-count'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            if (_filtering)
              TextButton(
                key: const ValueKey('invoice-filter-clear'),
                onPressed: _clearFilters,
                child: Text(l10n?.invoiceFilterClear ?? 'Clear filters'),
              ),
          ]),
        ]),
      );

  Widget _row(
    BuildContext context,
    AppLocalizations? l10n,
    Invoice invoice, {
    required InvoiceMatch? match,
    required ({int count, DateTime last})? reminder,
    required String replacedByNumber,
    required DateFormat dateFormat,
  }) {
    final currency = NumberFormat.simpleCurrency(name: invoice.currency);
    final status = invoiceLifecycleOf(invoice, match);
    return Card(
      child: ListTile(
        key: ValueKey('invoice-${invoice.id}'),
        onTap: () => _open(
          invoice,
          match: match,
          reminder: reminder,
          replacedByNumber: replacedByNumber,
        ),
        // 0068 field report: the number must stay READABLE — wrap instead
        // of ellipsizing.
        title: Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              invoice.number,
              style: invoice.isVoided
                  ? const TextStyle(decoration: TextDecoration.lineThrough)
                  : null,
            ),
            InvoiceStatusChip(status: status),
          ],
        ),
        subtitle: Text([
          invoicePeriodLabel(context, invoice),
          if (widget.showMemberNames) invoice.memberName,
          dateFormat.format(invoice.issuedAt),
          if (widget.showMemberNames && reminder != null)
            l10n?.invoiceRemindedBadge(reminder.count) ??
                'Reminded ×${reminder.count}',
        ].join(' · ')),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
            currency.format(invoice.totalCents / 100),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          // The one action frequent enough to stay on the row.
          IconButton(
            key: ValueKey('invoice-download-row-${invoice.id}'),
            tooltip: l10n?.invoiceDownload ?? 'Download PDF',
            icon: const Icon(Icons.download_outlined),
            onPressed: () => downloadInvoicePdf(context, ref, invoice),
          ),
        ]),
      ),
    );
  }
}
