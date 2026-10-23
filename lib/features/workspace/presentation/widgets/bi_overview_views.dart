// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2583 — how the overview's own figures read: today's value, what it
// counts apart, and that a past period gets today's value.
import 'package:intl/intl.dart';

import '../../../../core/time/workspace_time.dart';
import '../../domain/bi_result.dart';
import '../../domain/kpi_overview.dart';
import 'bi_module_section.dart';

OverviewFigure? _figure(BiMeasure m) => m.detail as OverviewFigure?;

/// The overview modules' views (#2583).
final overviewModuleViews = <String, BiModuleView>{
  'people.active_memberships_current': BiModuleView(
    title: (l10n) => l10n.overviewActiveMemberships,
    value: (v, locale, currency) =>
        v == null ? '—' : NumberFormat.decimalPattern(locale).format(v),
    basis: (m, l10n, locale) => '',
    notes: (m, l10n, locale) => [
      if (m.reasons.contains('current_state')) l10n.overviewCurrentState,
    ],
    details: (m, l10n, locale) => [
      l10n.overviewMembershipsDefinition,
      if (_figure(m) case final f?)
        l10n.biFinanceComputed(
          DateFormat.yMd(locale).format(WorkspaceTime.wall(f.computedAt)),
        ),
    ],
  ),
  'sales.overdue_receivables': BiModuleView(
    title: (l10n) => l10n.overviewOverdueTitle,
    value: biMoneyCell,
    basis: (m, l10n, locale) => switch (_figure(m)) {
      final f? => l10n.overviewOverdueBasis(
        '${f.count}',
        '${f.unknownDueCount}',
        '${f.heldCount}',
      ),
      _ => '',
    },
    notes: (m, l10n, locale) => [
      if (m.reasons.contains('currency_mix')) l10n.biFinanceCurrencyMix,
      if (m.reasons.contains('amount_not_exact')) l10n.biFinanceNotExact,
      if (m.reasons.contains('current_state')) l10n.overviewCurrentState,
    ],
    details: (m, l10n, locale) => [
      l10n.overviewOverdueDefinition,
      if (_figure(m) case final f?)
        l10n.biFinanceComputed(
          DateFormat.yMd(locale).format(WorkspaceTime.wall(f.computedAt)),
        ),
    ],
  ),
};
