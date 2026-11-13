// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #934 — the treasurer's view: what the workspace invoiced, collected,
// reimbursed and shared out over a range of months, then member by
// member. The numbers are `workspace_status`'s (0167); this screen only
// chooses the range and prints them.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/adaptive/page_measures.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/kit/dashboard_grid.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/ui/print_or_retry.dart';
import '../../domain/workspace_status.dart';
import '../../providers/money_providers.dart';
import '../invoice_actions.dart' show workspaceTaxReference;
import '../invoice_documents.dart';
import '../report_actions.dart';
import '../report_layout_actions.dart';
import '../status_report_data.dart';

class WorkspaceStatusScreen extends ConsumerStatefulWidget {
  const WorkspaceStatusScreen({super.key, this.from, this.to});

  /// The months a drill-through opens on (`YYYY-MM`, #2578); a month outside
  /// the 24 offered, or a pair that does not read, falls back to the default.
  final String? from;
  final String? to;
  @override
  ConsumerState<WorkspaceStatusScreen> createState() => _State();
}

class _State extends ConsumerState<WorkspaceStatusScreen> {
  late String _from;
  late String _to;
  late final List<String> _months;

  static String _ym(DateTime d) =>
      yearMonth(d.year, d.month);

  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider).now();
    _months = [
      for (var i = 0; i < 24; i++) _ym(DateTime(now.year, now.month - i)),
    ];
    _to = _months.first;
    _from = _months[2];
    final f = widget.from, t = widget.to;
    if (f != null && t != null && _months.contains(f) && _months.contains(t)) {
      // Months are `YYYY-MM`: string order is date order.
      _from = f.compareTo(t) <= 0 ? f : t;
      _to = f.compareTo(t) <= 0 ? t : f;
    }
  }

  Future<void> _print(WorkspaceStatus status) async {
    await readDocumentPolicies(ref); // #3742 — the template and rules, read
    if (!mounted) return;
    final l10n = context.l10n;
    if (workspaceTaxReference(ref) == null) {
      AppSnack.error(context, l10n.workspaceTaxContextNotReady);
      return;
    }
    final data = workspaceStatusReportData(context, ref, status);
    final report = renderLetterDoc(context, ref, docId: 'status', data: data);
    final title = l10n.reportDocStatus;
    await runReportActions(
      context,
      ref,
      keyPrefix: 'status-doc',
      logMessage: 'status report pdf failed',
      render: () => report,
      buildPdf: () async {
        final pdf = await letterDocPdf(
          context,
          ref,
          report: report,
          title: title,
          layoutXml: letterLayoutXml(ref, docId: 'status'),
          data: data,
        );
        return (bytes: pdf.bytes, fileName: pdf.fileName);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = ref.watch(workspaceStatusProvider(_from, _to));
    final monthLabel = appFormatOf(context).dates(DateShape.monthYearShort);
    String label(String ym) =>
        monthLabel.format(DateTime(int.parse(ym.substring(0, 4)), int.parse(ym.substring(5, 7))));
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.statusTitle),
        actions: [
          if (status.value case final s?)
            IconButton(
              key: const ValueKey('status-print'),
              tooltip: l10n.statusPrint,
              icon: const Icon(Icons.print_outlined),
              onPressed: () =>
                  printOrRetry(context, 'status report', () => _print(s)),
            ),
        ],
      ),
      // #3617 — the dashboard page: the months in one bar that stays, the
      // figures as tiles on the grid, the members below.
      body: DashboardScrollView(
        key: const ValueKey('status-page'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        filterBar: FilterBar(
          key: const ValueKey('status-filter-bar'),
          // Room above the fields for their floating labels.
          filters: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: const ValueKey('status-from'),
                  initialValue: _from,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.statusFrom),
                  items: [
                    for (final m in _months)
                      DropdownMenuItem(value: m, child: Text(label(m))),
                  ],
                  onChanged: (v) => setState(() {
                    _from = v ?? _from;
                    if (_from.compareTo(_to) > 0) _to = _from;
                  }),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: const ValueKey('status-to'),
                  initialValue: _to,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.statusTo),
                  items: [
                    for (final m in _months)
                      DropdownMenuItem(value: m, child: Text(label(m))),
                  ],
                  onChanged: (v) => setState(() {
                    _to = v ?? _to;
                    if (_from.compareTo(_to) > 0) _from = _to;
                  }),
                ),
              ),
            ],
          ),
          ),
        ),
        children: [
          const SizedBox(height: AppSpacing.md),
          switch (status) {
            AsyncData(value: final s) => _StatusBody(status: s),
            AsyncError(:final error) => Text(error.toString()),
            _ => const LoadingView(),
          },
        ],
      ),
    );
  }
}

class _StatusBody extends StatelessWidget {
  const _StatusBody({required this.status});
  final WorkspaceStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final currency = appFormatOf(context).moneyIn(status.currency);
    Widget tile(String label, int cents, {bool negative = false, Key? key}) =>
        KpiTile(
          key: key,
          label: label,
          figure: currency.formatMinor(negative ? -cents : cents),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashboardGrid(
          key: const ValueKey('status-grid'),
          minTileWidth: kpiTileMinWidth,
          children: [
            tile(l10n.statusInvoiced, status.invoicedCents, key: const ValueKey('status-invoiced')),
            tile(l10n.statusCreditNotes, status.creditNotesCents, negative: true),
            tile(l10n.statusPaymentsMatched, status.paymentsMatchedCents),
            tile(l10n.statusPaymentsReceived, status.paymentsReceivedCents),
            tile(l10n.statusReimbursed, status.reimbursedCents, negative: true),
            tile(l10n.statusRepartitioned, status.repartitionedCents),
            if (status.awaitingCents > 0)
              tile(l10n.statusAwaiting, status.awaitingCents),
            tile(l10n.statusCredits, status.creditsGrantedCents, negative: true),
            DashboardTile(
              span: 2,
              child: tile(l10n.statusNet, status.netCents,
                  key: const ValueKey('status-net')),
            ),
          ],
        ),
        // What the net is, whole, under the figures.
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kReadingColumnWidth),
              child: Text(l10n.statusNetExplanation, style: theme.textTheme.bodySmall),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.statusMembers, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        for (final (m, pct, figures) in [
          for (final m in status.members)
            (m, appFormatOf(context).ratePercent(m.subscriptionPct), '${currency.formatMinor(m.invoicedCents)} / ${currency.formatMinor(m.paidCents)}'),
        ])
          ListTile(
            key: ValueKey('status-member-${m.memberId}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Text(m.memberNumber, style: theme.textTheme.bodySmall),
            title: Text(m.name),
            subtitle: Text(pct),
            trailing: Text(
              figures,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
      ],
    );
  }
}
