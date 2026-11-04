// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 — how the customer figures read: the share and its two sides, what
// the period cannot know, the rows of the table by name (a cohort, a
// reminder level, a month, a customer or only its rank), and how each is
// computed.
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/bi_result.dart';
import '../../domain/kpi_customers.dart';
import 'bi_module_section.dart';

CustomerQualityKpi? _kpi(BiMeasure m) => m.detail as CustomerQualityKpi?;

String _count(num? v, String locale, String? currency) =>
    v == null ? '—' : NumberFormat.decimalPattern(locale).format(v);

/// What every customer card says about its period and its amounts.
List<String> _notes(BiMeasure m, AppLocalizations l10n) => [
  if (m.reasons.contains('currency_mix')) l10n.biFinanceCurrencyMix,
  if (m.reasons.contains('amount_not_exact')) l10n.biFinanceNotExact,
  if (m.reasons.contains('period_not_over')) l10n.biFinancePartial,
  if (m.reasons.contains('dunning_off')) l10n.biCustomerDunningOff,
  if (m.reasons.contains('nothing_to_share')) l10n.biCustomerNothingToShare,
  if (m.reasons.contains('net_not_proven')) l10n.biCustomerNetNotProven,
];

String _cohortName(PaymentCohort c, AppLocalizations l10n) => switch (c) {
  PaymentCohort.onTime => l10n.biCustomerCohortOnTime,
  PaymentCohort.late => l10n.biCustomerCohortLate,
  PaymentCohort.undated => l10n.biCustomerCohortUndated,
  PaymentCohort.partial => l10n.biCustomerCohortPartial,
  PaymentCohort.open => l10n.biCustomerCohortOpen,
  PaymentCohort.held => l10n.biCustomerCohortHeld,
  PaymentCohort.writtenOff => l10n.biCustomerCohortWrittenOff,
  PaymentCohort.unknownDue => l10n.biCustomerCohortUnknownDue,
};

/// The name of a customer row: the name when the server sent it, its rank
/// otherwise.
String _customerRowName(BiRow row, BiMeasure m, AppLocalizations l10n) {
  final rank = int.tryParse(row.key.replaceFirst('rank-', ''));
  final named = _kpi(m)?.customers.where((c) => c.rank == rank).firstOrNull;
  return named?.name ?? l10n.biCustomerRank('${rank ?? row.key}');
}

/// The customer modules' views (#3294).
final customerModuleViews = <String, BiModuleView>{
  'customers.payment_behaviour': BiModuleView(
    title: (l10n) => l10n.biCustomerPaymentTitle,
    value: biPercentCell,
    basis: (m, l10n, locale) => switch (_kpi(m)) {
      final k? => l10n.biCustomerPaymentBasis(
        '${k.onTimeCount}',
        '${k.completedCount}',
      ),
      null => '',
    },
    notes: (m, l10n, locale) => _notes(m, l10n),
    details: (m, l10n, locale) => switch (_kpi(m)) {
      final k? => [
        l10n.biCustomerPaymentDefinition,
        if (k.medianDays != null)
          l10n.biCustomerDelay(
            '${k.medianDays}',
            '${k.p90Days}',
            switch (k.weightedDays) {
              final w? => NumberFormat.decimalPattern(locale).format(w),
              null => '—',
            },
          ),
        for (final c in PaymentCohort.values)
          if (k.cohorts[c] case final f? when f.count > 0)
            l10n.biCustomerCohortLine(
              _cohortName(c, l10n),
              '${f.count}',
              biMoneyCell(f.minor, locale, k.currency),
            ),
      ],
      null => const [],
    },
    rowLabel: (row, l10n, locale) => switch (PaymentCohort.values
        .where((c) => c.wire == row.key)
        .firstOrNull) {
      final c? => _cohortName(c, l10n),
      null => null,
    },
  ),
  'customers.dunning_load': BiModuleView(
    title: (l10n) => l10n.biCustomerDunningTitle,
    value: _count,
    basis: (m, l10n, locale) => switch (_kpi(m)?.dunning) {
      final d? => l10n.biCustomerDunningBasis(
        '${d.reminders}',
        '${d.remindedInvoices}',
        '${d.dueInvoices}',
      ),
      null => '',
    },
    notes: (m, l10n, locale) => _notes(m, l10n),
    details: (m, l10n, locale) => switch (_kpi(m)) {
      final k? => [
        l10n.biCustomerDunningDefinition,
        if (k.dunning case final d? when d.remindedInvoices > 0)
          l10n.biCustomerPaidAfterReminder(
            '${d.paidAfterReminder}',
            '${d.remindedInvoices}',
          ),
      ],
      null => const [],
    },
    rowLabel: (row, l10n, locale) =>
        l10n.biCustomerDunningLevel(row.key.replaceFirst('level-', '')),
  ),
  'customers.credit_and_writeoff': BiModuleView(
    title: (l10n) => l10n.biCustomerCreditTitle,
    value: biMoneyCell,
    basis: (m, l10n, locale) => m.unknown ? '' : switch (_kpi(m)) {
      final k? => l10n.biCustomerCreditBasis(
        biMoneyCell(k.creditedMinor, locale, k.currency),
        '${k.creditNotes}',
        biMoneyCell(k.writtenOffMinor, locale, k.currency),
        '${k.writeOffs}',
      ),
      null => '',
    },
    notes: (m, l10n, locale) => _notes(m, l10n),
    details: (m, l10n, locale) => [l10n.biCustomerCreditDefinition],
    rowLabel: (row, l10n, locale) => switch (DateTime.tryParse(
      '${row.key}-01',
    )) {
      final d? => DateFormat.yMMMM(locale).format(d),
      null => null,
    },
  ),
  'customers.concentration': BiModuleView(
    title: (l10n) => l10n.biCustomerConcentrationTitle,
    value: biPercentCell,
    basis: (m, l10n, locale) => m.unknown ? '' : switch (_kpi(m)) {
      final k? => l10n.biCustomerConcentrationBasis(
        '${k.topCount}',
        '${k.customerCount}',
        biMoneyCell(k.topNetMinor, locale, k.currency),
        biMoneyCell(k.netMinor, locale, k.currency),
      ),
      null => '',
    },
    notes: (m, l10n, locale) => [
      ..._notes(m, l10n),
      if (_kpi(m) case final k? when !k.namesVisible)
        l10n.biCustomerNamesHidden,
    ],
    details: (m, l10n, locale) => switch (_kpi(m)) {
      final k? => [
        l10n.biCustomerConcentrationDefinition,
        if (!m.unknown) ...[
          l10n.biCustomerConcentrationOpen(
            '${k.topCount}',
            '${k.debtorCount}',
            biMoneyCell(k.topOpenMinor, locale, k.currency),
            biMoneyCell(k.openMinor, locale, k.currency),
          ),
          for (final d in k.debtors)
            l10n.biCustomerDebtorLine(
              d.name ?? l10n.biCustomerRank('${d.rank}'),
              biMoneyCell(d.minor, locale, k.currency),
            ),
        ],
      ],
      null => const [],
    },
    rowLabel: (row, l10n, locale) => _customerRowName(row, row.current, l10n),
  ),
};
