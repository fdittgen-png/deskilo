// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-e -- "Invoice the month": the customers with something to invoice,
// ticked by default, ONE filled action that issues them, and a result page
// that says exactly what happened. Three taps from the home: Review, Issue,
// Done. A button carries its own progress and locks while it works; nothing
// full-screen waits.
//
// Before anything is ticked and issued, each listed customer is read once for
// what would stop their invoice (the existing dry run, `invoice_issue_readiness`):
// a customer with a gap is unticked, marked "Needs a fix" and gets a Fix; a gap
// that is the business's own is said ONCE, on top, with one Fix, and the bar
// waits. A read that fails leaves the row free: the server still refuses at
// issue time, in words, and the result page says so.
//
// Issuing uses the existing rules (`issueMonth` -> `InvoiceIssuance`): each
// customer once under its own request id, a lost answer looked up and never
// resent. The screens never claim a delivery: an issued invoice is in the
// customer's account (they are notified); no e-mail leaves the server.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/kit/bottom_action_bar.dart';
import '../../../../core/ui/kit/kit_action_button.dart';
import '../../../../core/ui/kit/kit_card.dart';
import '../../../../core/ui/kit/page_bar.dart';
import '../../../../core/ui/kit/select_row.dart';
import '../../../../core/ui/kit/two_line_row.dart';
import '../../application/issue_invoice.dart';
import '../../application/issue_month.dart';
import '../../application/issue_month_readiness.dart';
import '../../providers/money_providers.dart';
import '../invoice_proforma.dart';
import '../period_label.dart';
import 'invoice_month_parts.dart';
import 'invoice_month_result.dart';
import 'invoice_month_state.dart';

class InvoiceMonthFlow extends ConsumerStatefulWidget {
  const InvoiceMonthFlow({
    super.key,
    required this.period,
    required this.entries,
    required this.currency,
    required this.workspaceId,
    required this.onFixCustomer,
    required this.onFixBusiness,
  });

  /// The month being invoiced, `yyyy-MM`.
  final String period;

  /// The customers with something to invoice, as the overview reads them.
  final List<ToInvoiceEntry> entries;

  /// The business's currency code: amounts are never summed across any other.
  final String currency;

  /// The business whose month is invoiced.
  final String workspaceId;

  /// Opens the place where a customer's billing details are completed; the
  /// list reads that customer again when it returns.
  final Future<void> Function(String memberId) onFixCustomer;

  /// Opens the place where the business's own details are completed; every
  /// customer is read again when it returns.
  final Future<void> Function() onFixBusiness;

  @override
  ConsumerState<InvoiceMonthFlow> createState() => _InvoiceMonthFlowState();
}

class _InvoiceMonthFlowState extends ConsumerState<InvoiceMonthFlow> {
  late final MonthFlowState _state = MonthFlowState([
    for (final e in widget.entries) e.memberId,
  ]);

  @override
  void initState() {
    super.initState();
    unawaited(_read([for (final e in widget.entries) e.memberId]));
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  InvoiceIssuance get _issuance => InvoiceIssuance(
    ref.read(invoiceCommandsProvider),
    ref.read(invoiceQueriesProvider),
    ref.read(invoiceActionCommandsProvider),
  );

  /// Rows render at once; their status fills in as each read answers.
  Future<void> _read(List<String> memberIds) {
    _state.readingAgain(memberIds);
    return readMonthReadiness(
      queries: ref.read(invoiceQueriesProvider),
      workspaceId: widget.workspaceId,
      period: widget.period,
      memberIds: memberIds,
      onEach: (id, readiness) {
        if (mounted) _state.readinessArrived(id, readiness);
      },
    );
  }

  Future<void> _fixCustomer(String memberId) async {
    await widget.onFixCustomer(memberId);
    if (mounted) await _read([memberId]);
  }

  Future<void> _fixBusiness() async {
    await widget.onFixBusiness();
    if (mounted) await _read([for (final e in widget.entries) e.memberId]);
  }

  Future<void> _issue() async {
    if (_state.selected.isEmpty || _state.busy) return;
    _state.started();
    final report = await issueMonth(
      issuance: _issuance,
      workspaceId: widget.workspaceId,
      period: widget.period,
      // In the order the list shows them.
      memberIds: [
        for (final e in widget.entries)
          if (_state.isSelected(e.memberId)) e.memberId,
      ],
      onProgress: _progress,
    );
    _finish(report);
  }

  Future<void> _retry() async {
    final report = _state.report;
    if (report == null || _state.busy) return;
    _state.started();
    _finish(
      await retryNotDone(
        issuance: _issuance,
        report: report,
        onProgress: _progress,
      ),
    );
  }

  /// The run goes on if the person leaves; its progress then has no one to
  /// tell.
  void _progress(String memberId, MonthLineProgress p) {
    if (mounted) _state.progress(memberId, p);
  }

  void _finish(MonthIssueReport report) {
    ref
      ..invalidate(invoicesProvider)
      ..invalidate(invoicingOverviewProvider);
    if (mounted) _state.finished(report);
  }

  Future<void> _proforma(String memberId) async {
    final invoice = await proformaForMonth(
      ref,
      memberId: memberId,
      period: widget.period,
    );
    if (!mounted || invoice == null) return;
    await shareProforma(context, ref, invoice);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: _state,
      builder: (context, child) => PopScope(
        // Issuing is running: leaving would hide what it did.
        canPop: !_state.busy,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(content: Text(l10n.invoiceMonthLeaveBlocked)),
            );
          }
        },
        child: child!,
      ),
      child: Scaffold(
        appBar: pageBar(context,
          title: l10n.invoiceMonthTitle(monthLabel(context, widget.period)),
        ),
        body: ListenableBuilder(
          listenable: _state,
          builder: (context, _) {
            final report = _state.report;
            return report == null ? _review(context) : _result(context, report);
          },
        ),
      ),
    );
  }

  // ── review ───────────────────────────────────────────────────────

  Widget _review(BuildContext context) {
    final l10n = context.l10n;
    final money = ref.watch(appFormatProvider).moneyIn(widget.currency);
    final business = _state.readiness.businessMissing;
    final free = [
      for (final e in widget.entries)
        if (!_state.readiness.needsFix(e.memberId)) e,
    ];
    final chosen = [
      for (final e in widget.entries)
        if (_state.isSelected(e.memberId)) e,
    ];
    final total = chosen.fold<int>(0, (sum, e) => sum + e.totalCents);
    final amount = money.formatMinor(total);
    final allValue = chosen.isEmpty
        ? false
        : chosen.length == free.length
        ? true
        : null;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: AppSpacing.mdAll,
            children: [
              QuietLine(l10n.invoiceMonthNote, icon: Icons.info_outline),
              const SizedBox(height: AppSpacing.md),
              if (business.isNotEmpty) ...[
                MonthBusinessNotice(
                  text: l10n.invoiceMonthBusinessFix(
                    monthMissingWords(l10n, business),
                  ),
                  fixLabel: l10n.invoiceMonthFix,
                  onFix: _state.busy ? null : _fixBusiness,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              KitLabel(
                l10n.invoiceMonthSelected(
                  chosen.length,
                  widget.entries.length,
                  amount,
                ),
              ),
              if (_state.readiness.needsFixCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    l10n.invoiceMonthNeedsFixCount(
                      _state.readiness.needsFixCount,
                    ),
                    key: const ValueKey('invoice-month-needs-fix-count'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              MonthAllRow(
                key: const ValueKey('invoice-month-all'),
                label: l10n.invoiceMonthAll,
                value: allValue,
                onTap: _state.busy || free.isEmpty
                    ? null
                    : () => _state.toggleAll(free.map((e) => e.memberId)),
              ),
              RowList(
                rows: [
                  for (final e in widget.entries) _line(context, e, money),
                ],
              ),
            ],
          ),
        ),
        BottomActionBar(
          actions: [
            KitActionButton(
              key: const ValueKey('invoice-month-issue'),
              busy: _state.busy,
              onPressed: chosen.isEmpty || business.isNotEmpty ? null : _issue,
              label: _state.busy
                  ? l10n.invoiceMonthIssuing
                  : l10n.invoiceMonthIssue(chosen.length, amount),
            ),
          ],
        ),
      ],
    );
  }

  Widget _line(BuildContext context, ToInvoiceEntry e, MoneyFormat money) {
    final l10n = context.l10n;
    final fix = _state.readiness.needsFix(e.memberId);
    final issuing = _state.progressOf(e.memberId) == MonthLineProgress.issuing;
    return Row(
      key: ValueKey('invoice-month-line-${e.memberId}'),
      children: [
        Expanded(
          child: SelectRow(
            key: ValueKey('invoice-month-select-${e.memberId}'),
            selected: _state.isSelected(e.memberId),
            enabled: !fix,
            onChanged: _state.busy || fix
                ? (_) {}
                : (on) => _state.toggle(e.memberId, on: on),
            title: e.name,
            caption: fix
                ? Text(
                    l10n.invoiceMonthNeedsFixLine(
                      monthMissingWords(
                        l10n,
                        _state.readiness.customerMissing(e.memberId),
                      ),
                    ),
                    key: ValueKey('invoice-month-status-${e.memberId}'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  )
                : issuing
                ? Text(l10n.invoiceMonthIssuing)
                : const SizedBox.shrink(),
            amount: money.formatMinor(e.totalCents),
          ),
        ),
        if (fix)
          TextButton(
            key: ValueKey('invoice-month-fix-${e.memberId}'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _state.busy ? null : () => _fixCustomer(e.memberId),
            child: Text(l10n.invoiceMonthFix),
          )
        else
          IconButton(
            key: ValueKey('invoice-month-proforma-${e.memberId}'),
            tooltip: l10n.invoiceMonthProforma,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            icon: const Icon(Icons.visibility_outlined),
            onPressed: _state.busy ? null : () => _proforma(e.memberId),
          ),
      ],
    );
  }

  Widget _result(BuildContext context, MonthIssueReport report) =>
      MonthResultView(
        report: report,
        entries: widget.entries,
        currency: widget.currency,
        busy: _state.busy,
        onRetry: _retry,
        onFixCustomer: _fixCustomer,
        onFixBusiness: _fixBusiness,
      );
}
