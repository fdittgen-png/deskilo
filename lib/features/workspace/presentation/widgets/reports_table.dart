// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3617 (desk M4) — the reports at the desk: one records table (#3606) of
// the reports that are pages (report_pages.dart): the name and what it
// covers, their section as a chip with its count; a row opens the report.
// No "last run": none is stored, so none is shown (the decision on #3617).
// The exports, imports and prints of the workspace stay as their tiles,
// under Tools.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/kit/records_table.dart';
import '../../../../l10n/app_localizations.dart';
import 'report_pages.dart';

/// The reports as a table, the tools under it.
class ReportsTable extends StatelessWidget {
  const ReportsTable({super.key, required this.pages, required this.tools});

  final List<ReportPage> pages;

  /// The workspace's exports, imports and prints, and the templates.
  final List<Widget> tools;

  static String _sectionName(AppLocalizations l, ReportSection s) =>
      switch (s) {
        ReportSection.overview => l.overviewTitle,
        ReportSection.finance => l.uxReportsFinance,
        ReportSection.analytics => l.biTitle,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: RecordsTable<ReportPage>(
            tableId: 'reports',
            rows: pages,
            keyOf: (p) => p.id,
            searchText: (p) => '${p.name(l)} ${p.covers(l)}',
            onOpen: (p) => context.push(p.route),
            empty: Center(child: Text(l.uxReportsHint)),
            chips: [
              for (final s in ReportSection.values)
                if (pages.any((p) => p.section == s))
                  RecordChip(
                    id: s.name,
                    label: _sectionName(l, s),
                    keeps: (p) => p.section == s,
                  ),
            ],
            columns: [
              RecordColumn(
                id: 'name',
                label: l.reportsColumnName,
                flex: 2,
                hideable: false,
                sortKey: (p) => p.name(l),
                cell: (_, p) => Row(
                  children: [
                    Icon(p.icon, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(p.name(l), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              RecordColumn(
                id: 'covers',
                label: l.reportsColumnCovers,
                flex: 5,
                cell: (_, p) => Text(p.covers(l)),
              ),
            ],
            cardBuilder: (context, p) => ListTile(
              leading: Icon(p.icon),
              title: Text(p.name(l)),
              subtitle: Text(p.covers(l)),
            ),
          ),
        ),
        if (tools.isNotEmpty)
          ExpansionTile(
            key: const ValueKey('reports-tools'),
            title: Text(l.reportsTools),
            children: tools,
          ),
      ],
    );
  }
}
