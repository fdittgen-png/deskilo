// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3627 (desk M8) — the month at the desk: a dashboard of the statement's
// figures (the balance, what was used of what is included, the subscription,
// the payments and credits) over the lines of the month as a records table.
// Every line is a figure the server computed (`member_statement`), signed as
// the balance is — negative is owed — so the lines add up to the balance
// under them. A tile shows only its own lines; choosing it again shows all.
import 'package:flutter/material.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/kit/dashboard_grid.dart';
import '../../../../core/ui/kit/records_table.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/statement.dart';

/// What a line of the month is, and the tile it belongs to.
enum StatementLineKind { subscription, overage, supplement, credits }

/// One line of the month: a figure of the statement, signed as the balance.
typedef StatementLine = ({
  String id,
  StatementLineKind kind,
  String label,
  int cents,
});

/// The month's lines, from the statement alone: their sum is its balance.
List<StatementLine> statementLines(AppLocalizations l, Statement s) => [
  (
    id: 'fee',
    kind: StatementLineKind.subscription,
    label: l.ledgerCategorySubscription,
    cents: -s.feeCents,
  ),
  if (s.overageCents != 0)
    (
      id: 'overage',
      kind: StatementLineKind.overage,
      label: l.billOverage(s.extraHalfDays),
      cents: -s.overageCents,
    ),
  for (final (id, label, cents) in [
    ('accessories', l.billAccessorySupplements, s.accessorySupplementCents),
    ('levels', l.levelSupplementLabel, s.levelSupplementCents),
    ('offices', l.officeSupplementLabel, s.officeSupplementCents),
    ('desks', l.deskSupplementLabel, s.deskSupplementCents),
  ])
    if (cents != 0)
      (id: id, kind: StatementLineKind.supplement, label: label, cents: -cents),
  (
    id: 'credits',
    kind: StatementLineKind.credits,
    label: l.billPaymentsCredits,
    cents: s.creditsCents,
  ),
];

class StatementDesk extends StatefulWidget {
  const StatementDesk({
    super.key,
    required this.statement,
    required this.currencyCode,
  });

  final Statement statement;
  final String currencyCode;

  @override
  State<StatementDesk> createState() => _StatementDeskState();
}

class _StatementDeskState extends State<StatementDesk> {
  StatementLineKind? _only;

  void _choose(StatementLineKind kind) =>
      setState(() => _only = _only == kind ? null : kind);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = widget.statement;
    final money = appFormatOf(context).moneyIn(widget.currencyCode);
    final lines = statementLines(l, s);
    final shown = [
      for (final line in lines)
        if (_only == null || line.kind == _only) line,
    ];
    final allowance = s.includedHalfDays + s.grantedHalfDays;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashboardGrid(
          minTileWidth: kpiTileMinWidth,
          children: [
            KpiTile(
              label: l.bookReportBalance,
              figure: money.formatMinor(s.balanceCents),
              figureKey: const ValueKey('statement-desk-balance'),
            ),
            KpiTile(
              label: l.entitlementTitle,
              figure: '${s.usedHalfDays} / $allowance',
              figureKey: const ValueKey('statement-desk-used'),
              tapKey: const ValueKey('statement-desk-tile-overage'),
              onTap: () => _choose(StatementLineKind.overage),
            ),
            KpiTile(
              label: l.ledgerCategorySubscription,
              figure: money.formatMinor(s.feeCents),
              tapKey: const ValueKey('statement-desk-tile-subscription'),
              onTap: () => _choose(StatementLineKind.subscription),
            ),
            KpiTile(
              label: l.billPaymentsCredits,
              figure: money.formatMinor(s.creditsCents),
              tapKey: const ValueKey('statement-desk-tile-credits'),
              onTap: () => _choose(StatementLineKind.credits),
            ),
          ],
        ),
        const SizedBox(height: dashboardGap * 2),
        Expanded(
          child: RecordsTable<StatementLine>(
            key: const ValueKey('statement-desk-lines'),
            tableId: 'statement-lines',
            rows: shown,
            keyOf: (line) => line.id,
            searchText: (line) => line.label,
            onOpen: (line) => _choose(line.kind),
            cardBuilder: (context, line) => ListTile(
              title: Text(line.label),
              trailing: Text(money.formatMinor(line.cents)),
            ),
            empty: const SizedBox.shrink(),
            amountOf: (line) =>
                (currency: widget.currencyCode, minor: line.cents),
            amountColumn: 'amount',
            formatAmount: (code, minor) =>
                appFormatOf(context).moneyIn(code).formatMinor(minor),
            columns: [
              RecordColumn(
                id: 'line',
                label: l.statementDeskColLine,
                flex: 3,
                hideable: false,
                sortKey: (line) => line.kind.index,
                cell: (_, line) => Text(line.label),
              ),
              RecordColumn(
                id: 'amount',
                label: l.financesColumnAmount,
                flex: 2,
                numeric: true,
                sortKey: (line) => line.cents,
                cell: (_, line) => Text(money.formatMinor(line.cents)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
