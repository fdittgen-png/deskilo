// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-e -- "Invoice the month": the customers with something to invoice,
// ticked by default, ONE filled action that issues them, and a result page
// that says exactly what happened. Three taps from the home: Review, Issue,
// Done. A button carries its own progress and locks while it works; nothing
// full-screen waits.
//
// Issuing uses the existing rules (`issueMonth` -> `InvoiceIssuance`): each
// customer once under its own request id, a lost answer looked up and never
// resent. The screens never claim a delivery: an issued invoice is in the
// customer's account (they are notified); no e-mail leaves the server.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/kit/bottom_action_bar.dart';
import '../../../../core/ui/kit/kit_card.dart';
import '../../../../core/ui/kit/result_page.dart';
import '../../../../core/ui/kit/select_row.dart';
import '../../../../core/ui/kit/two_line_row.dart';
import '../../application/issue_invoice.dart';
import '../../application/issue_month.dart';
import '../../providers/money_providers.dart';
import '../invoice_proforma.dart';
import '../period_label.dart';

class InvoiceMonthFlow extends ConsumerStatefulWidget {
  const InvoiceMonthFlow({
    super.key,
    required this.period,
    required this.entries,
    required this.currency,
    required this.workspaceId,
  });

  /// The month being invoiced, `yyyy-MM`.
  final String period;

  /// The customers with something to invoice, as the overview reads them.
  final List<ToInvoiceEntry> entries;

  /// The business whose month is invoiced.
  final String workspaceId;

  /// The business's currency code: the amounts are never summed across any
  /// other.
  final String currency;

  @override
  ConsumerState<InvoiceMonthFlow> createState() => _InvoiceMonthFlowState();
}

class _InvoiceMonthFlowState extends ConsumerState<InvoiceMonthFlow> {
  late final Set<String> _selected = {
    for (final e in widget.entries) e.memberId,
  };
  final Map<String, MonthLineProgress> _progress = {};
  MonthIssueReport? _report;
  bool _busy = false;

  InvoiceIssuance get _issuance => InvoiceIssuance(
    ref.read(invoiceCommandsProvider),
    ref.read(invoiceQueriesProvider),
    ref.read(invoiceActionCommandsProvider),
  );

  void _onProgress(String memberId, MonthLineProgress p) {
    if (mounted) setState(() => _progress[memberId] = p);
  }

  Future<void> _issue() async {
    if (_selected.isEmpty || _busy) return;
    setState(() => _busy = true);
    final report = await issueMonth(
      issuance: _issuance,
      workspaceId: widget.workspaceId,
      period: widget.period,
      // In the order the list shows them.
      memberIds: [
        for (final e in widget.entries)
          if (_selected.contains(e.memberId)) e.memberId,
      ],
      onProgress: _onProgress,
    );
    _finish(report);
  }

  Future<void> _retry() async {
    final report = _report;
    if (report == null || _busy) return;
    setState(() => _busy = true);
    _finish(
      await retryNotDone(
        issuance: _issuance,
        report: report,
        onProgress: _onProgress,
      ),
    );
  }

  void _finish(MonthIssueReport report) {
    ref
      ..invalidate(invoicesProvider)
      ..invalidate(invoicingOverviewProvider);
    if (!mounted) return;
    setState(() {
      _report = report;
      _busy = false;
      _progress.clear();
    });
  }

  Future<void> _proforma(String memberId) async {
    final invoice = await proformaForMonth(
      ref,
      memberId: memberId,
      period: widget.period,
    );
    if (!mounted) return;
    if (invoice == null) return;
    await shareProforma(context, ref, invoice);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final report = _report;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.invoiceMonthTitle(monthLabel(context, widget.period))),
      ),
      body: report == null ? _review(context) : _result(context, report),
    );
  }

  Widget _review(BuildContext context) {
    final l10n = context.l10n;
    final money = ref.watch(appFormatProvider).moneyIn(widget.currency);
    final month = monthLabel(context, widget.period);
    final chosen = [
      for (final e in widget.entries)
        if (_selected.contains(e.memberId)) e,
    ];
    final total = chosen.fold<int>(0, (sum, e) => sum + e.totalCents);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: AppSpacing.mdAll,
            children: [
              QuietLine(l10n.invoiceMonthNote, icon: Icons.info_outline),
              const SizedBox(height: AppSpacing.md),
              KitLabel(
                l10n.invoiceMonthSummary(
                  chosen.length,
                  money.formatMinor(total),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              RowList(
                rows: [
                  for (final e in widget.entries)
                    Row(
                      key: ValueKey('invoice-month-line-${e.memberId}'),
                      children: [
                        Expanded(
                          child: SelectRow(
                            key: ValueKey('invoice-month-select-${e.memberId}'),
                            selected: _selected.contains(e.memberId),
                            onChanged: _busy
                                ? (_) {}
                                : (on) => setState(() {
                                    on
                                        ? _selected.add(e.memberId)
                                        : _selected.remove(e.memberId);
                                  }),
                            title: e.name,
                            caption: Text(
                              _progress[e.memberId] == MonthLineProgress.issuing
                                  ? l10n.invoiceMonthIssuing
                                  : l10n.invoiceMonthLineCaption(month),
                            ),
                            amount: money.formatMinor(e.totalCents),
                          ),
                        ),
                        IconButton(
                          key: ValueKey('invoice-month-proforma-${e.memberId}'),
                          tooltip: l10n.invoiceMonthProforma,
                          constraints: const BoxConstraints.tightFor(
                            width: 48,
                            height: 48,
                          ),
                          icon: const Icon(Icons.visibility_outlined),
                          onPressed: _busy ? null : () => _proforma(e.memberId),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
        BottomActionBar(
          actions: [
            FilledButton(
              key: const ValueKey('invoice-month-issue'),
              onPressed: _busy || chosen.isEmpty ? null : _issue,
              child: Text(
                _busy
                    ? l10n.invoiceMonthIssuing
                    : l10n.invoiceMonthIssue(chosen.length),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _result(BuildContext context, MonthIssueReport report) {
    final l10n = context.l10n;
    final money = ref.watch(appFormatProvider).moneyIn(widget.currency);
    final byId = {for (final e in widget.entries) e.memberId: e};
    ResultLine line(String memberId, String detail, String outcome) => (
      title: byId[memberId]?.name ?? memberId,
      detail: detail,
      outcome: outcome,
    );
    String amount(String id) => money.formatMinor(byId[id]?.totalCents ?? 0);
    final done = [
      for (final id in report.issued)
        line(id, amount(id), l10n.invoiceMonthIssued),
      for (final id in report.held) line(id, amount(id), l10n.invoiceMonthHeld),
    ];
    final notDone = [
      for (final entry in report.outcomes.entries)
        if (entry.value is InvoiceIssueRefused)
          line(
            entry.key,
            report.refusalTextOf(entry.key) ??
                l10n.invoiceMonthNotIssued,
            '',
          )
        else if (entry.value is InvoiceIssueUnknown)
          line(entry.key, l10n.invoiceMonthUnknown, ''),
    ];
    final issued = report.issued.length;
    final onlyLost = report.refused.isEmpty && report.unknown.isNotEmpty;
    return Column(
      children: [
        Expanded(
          child: ResultPage(
            title: issued == 0 && report.held.isEmpty
                ? l10n.invoiceMonthResultNone
                : l10n.invoiceMonthResultTitle(issued),
            subtitle: issued == 0
                ? l10n.invoiceMonthResultNoneSubtitle
                : l10n.invoiceMonthResultSubtitle,
            done: done,
            notDone: notDone,
            notDoneHeading: l10n.invoiceMonthNotDone,
            staysNote: l10n.invoiceMonthStays,
            doneLabel: l10n.invoiceMonthDone,
            onDone: () => Navigator.of(context).maybePop(),
          ),
        ),
        if (notDone.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                key: const ValueKey('invoice-month-retry'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _busy ? null : _retry,
                child: Text(
                  onlyLost
                      ? l10n.invoiceMonthCheckAgain
                      : l10n.invoiceMonthRetry,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
