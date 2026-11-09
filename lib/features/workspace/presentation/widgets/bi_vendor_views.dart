// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 step 2 — how the vendor figures read: the cost and its parts, the
// share paid on time, the days a bill takes to arrive, what the period
// cannot know, the rows of the table by name (a supplier, a category, a
// cohort), and how each is computed.
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/bi_result.dart';
import '../../domain/kpi_vendors.dart';
import 'bi_module_section.dart';

VendorQualityKpi? _kpi(BiMeasure m) => m.detail as VendorQualityKpi?;

/// Days with one decimal; a dash when undefined.
String _days(num? v, String locale, String? currency) => v == null
    ? '—'
    : NumberFormat.decimalPatternDigits(
        locale: locale,
        decimalDigits: 1,
      ).format(v);

/// What every vendor card says about its period and its amounts.
List<String> _notes(BiMeasure m, AppLocalizations l10n) => [
  if (m.reasons.contains('currency_mix')) l10n.biFinanceCurrencyMix,
  if (m.reasons.contains('amount_not_exact')) l10n.biFinanceNotExact,
  if (m.reasons.contains('period_not_over')) l10n.biFinancePartial,
  if (m.reasons.contains('nothing_to_share')) l10n.biVendorNothingToMeasure,
];

String _cohortName(PayableCohort c, AppLocalizations l10n) => switch (c) {
  PayableCohort.onTime => l10n.biVendorCohortOnTime,
  PayableCohort.late => l10n.biVendorCohortLate,
  PayableCohort.undated => l10n.biVendorCohortUndated,
  PayableCohort.partial => l10n.biVendorCohortPartial,
  PayableCohort.open => l10n.biVendorCohortOpen,
  PayableCohort.held => l10n.biVendorCohortHeld,
  PayableCohort.unknownDue => l10n.biVendorCohortUnknownDue,
};

String _deliveryCohortName(DeliveryCohort c, AppLocalizations l10n) =>
    switch (c) {
      DeliveryCohort.onTime => l10n.biVendorDeliveryOnTime,
      DeliveryCohort.late => l10n.biVendorDeliveryLate,
      DeliveryCohort.unknownExpected => l10n.biVendorDeliveryUnknownExpected,
      DeliveryCohort.partial => l10n.biVendorDeliveryPartial,
      DeliveryCohort.overdue => l10n.biVendorDeliveryOverdue,
      DeliveryCohort.open => l10n.biVendorDeliveryOpen,
    };

/// The vendor modules' views (#3294 steps 2 and 5).
final vendorModuleViews = <String, BiModuleView>{
  'vendors.spend': BiModuleView(
    title: (l10n) => l10n.biVendorSpendTitle,
    value: biMoneyCell,
    basis: (m, l10n, locale) => m.unknown
        ? ''
        : switch (_kpi(m)) {
            final k? => l10n.biVendorSpendBasis(
              '${k.documents}',
              '${k.supplierCount}',
              '${k.topCount}',
              biMoneyCell(k.topCostMinor, locale, k.currency),
            ),
            null => '',
          },
    notes: (m, l10n, locale) => _notes(m, l10n),
    details: (m, l10n, locale) => switch (_kpi(m)) {
      final k? => [
        l10n.biVendorSpendDefinition,
        if (!m.unknown && k.creditNotes > 0)
          l10n.biVendorCredited(
            biMoneyCell(k.creditedMinor, locale, k.currency),
            '${k.creditNotes}',
          ),
        if (!m.unknown && (k.unassignedMinor ?? 0) != 0)
          l10n.biVendorUnassigned(
            biMoneyCell(k.unassignedMinor, locale, k.currency),
          ),
      ],
      null => const [],
    },
  ),
  'vendors.category_spend': BiModuleView(
    title: (l10n) => l10n.biVendorCategoryTitle,
    value: biMoneyCell,
    basis: (m, l10n, locale) => switch (_kpi(m)) {
      final k? => l10n.biVendorCategoryBasis('${k.categoryCount}'),
      null => '',
    },
    notes: (m, l10n, locale) => _notes(m, l10n),
    details: (m, l10n, locale) => [l10n.biVendorSpendDefinition],
    rowLabel: (row, l10n, locale) =>
        row.key == 'category-' ? l10n.biVendorNoCategory : null,
  ),
  'vendors.payment_punctuality': BiModuleView(
    title: (l10n) => l10n.biVendorPunctualityTitle,
    value: biPercentCell,
    basis: (m, l10n, locale) => switch (_kpi(m)) {
      final k? => l10n.biVendorPunctualityBasis(
        '${k.onTimeCount}',
        '${k.completedCount}',
      ),
      null => '',
    },
    notes: (m, l10n, locale) => _notes(m, l10n),
    details: (m, l10n, locale) => switch (_kpi(m)) {
      final k? => [
        l10n.biVendorPunctualityDefinition,
        if (k.medianDays != null)
          l10n.biVendorDelay(
            '${k.medianDays}',
            '${k.p90Days}',
            switch (k.weightedDays) {
              final w? => NumberFormat.decimalPattern(locale).format(w),
              null => '—',
            },
          ),
        for (final c in PayableCohort.values)
          if (k.cohorts[c] case final f? when f.count > 0)
            l10n.biVendorCohortLine(
              _cohortName(c, l10n),
              '${f.count}',
              biMoneyCell(f.minor, locale, k.currency),
            ),
        for (final v in k.punctuality)
          l10n.biVendorPunctualityLine(
            v.name,
            '${v.onTime}',
            '${v.late}',
            '${v.due}',
          ),
      ],
      null => const [],
    },
    rowLabel: (row, l10n, locale) => switch (PayableCohort.values
        .where((c) => c.wire == row.key)
        .firstOrNull) {
      final c? => _cohortName(c, l10n),
      null => null,
    },
  ),
  'vendors.billing_lag': BiModuleView(
    title: (l10n) => l10n.biVendorLagTitle,
    value: _days,
    basis: (m, l10n, locale) => switch (_kpi(m)) {
      final k? => l10n.biVendorLagBasis(
        '${k.lagDocuments}',
        '${k.lagMedianDays ?? '—'}',
        '${k.lagP90Days ?? '—'}',
      ),
      null => '',
    },
    notes: (m, l10n, locale) => [
      ..._notes(m, l10n),
      if (_kpi(m) case final k? when k.lagUndated > 0)
        l10n.biVendorLagUndated('${k.lagUndated}'),
    ],
    details: (m, l10n, locale) => [l10n.biVendorLagDefinition],
  ),
  'vendors.delivery': BiModuleView(
    title: (l10n) => l10n.biVendorDeliveryTitle,
    value: biPercentCell,
    basis: (m, l10n, locale) => switch (_kpi(m)) {
      final k? => l10n.biVendorDeliveryBasis(
        '${k.deliveryOnTimeCount}',
        '${k.deliveryCompletedCount}',
      ),
      null => '',
    },
    notes: (m, l10n, locale) => [
      ..._notes(m, l10n),
      if (m.reasons.contains('purchase_orders_off')) l10n.biVendorDeliveryOff,
    ],
    details: (m, l10n, locale) => switch (_kpi(m)) {
      final k? => [
        l10n.biVendorDeliveryDefinition,
        if (k.deliveryMedianLeadDays != null)
          l10n.biVendorDeliveryLead(
            '${k.deliveryMedianLeadDays}',
            '${k.deliveryP90LeadDays}',
          ),
        if (k.deliveryMedianDelayDays != null)
          l10n.biVendorDeliveryDelay(
            '${k.deliveryMedianDelayDays}',
            '${k.deliveryP90DelayDays}',
          ),
        for (final c in DeliveryCohort.values)
          if ((k.deliveryCohorts[c] ?? 0) > 0)
            l10n.biVendorDeliveryCohortLine(
              _deliveryCohortName(c, l10n),
              '${k.deliveryCohorts[c]}',
            ),
        for (final v in k.deliveries)
          l10n.biVendorDeliveryLine(
            v.name,
            '${v.onTime}',
            '${v.late}',
            '${v.orders}',
          ),
      ],
      null => const [],
    },
    rowLabel: (row, l10n, locale) => switch (DeliveryCohort.values
        .where((c) => c.wire == row.key)
        .firstOrNull) {
      final c? => _deliveryCohortName(c, l10n),
      null => null,
    },
  ),
};
