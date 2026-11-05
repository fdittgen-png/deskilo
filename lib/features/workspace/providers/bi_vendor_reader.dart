// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 step 2 — the vendor figures of the analytics page, read from
// `kpi_vendor_quality` (0673): one read per workspace and months, shared by
// the four cards, turned into the page's measure and its table rows.
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/bi_query.dart';
import '../domain/bi_result.dart';
import '../domain/kpi_contract.dart';
import '../domain/kpi_vendors.dart';
import 'bi_providers.dart';
import 'vendor_kpi_providers.dart';

/// The two vendor figures that are counts or days: another currency in
/// scope leaves them exact.
const _countModules = {'vendors.payment_punctuality', 'vendors.billing_lag'};

/// The figure [moduleId] shows of [k], as numerator and denominator; a
/// null numerator is unknown, never 0.
({int? numerator, int? denominator}) _figure(
  VendorQualityKpi k,
  String moduleId,
) => switch (moduleId) {
  'vendors.payment_punctuality' => (
    numerator: k.onTimeCount,
    denominator: k.completedCount,
  ),
  'vendors.billing_lag' => (numerator: k.lagDays, denominator: k.lagDocuments),
  _ => (numerator: k.costMinor, denominator: null),
};

/// #3294 — one vendor figure of [k]. Unknown when the amount is (another
/// currency, an inexact amount), or when a ratio has nothing to divide.
@visibleForTesting
BiMeasure vendorMeasure(
  VendorQualityKpi k,
  String moduleId, {
  bool currencyCompatible = true,
}) {
  final count = _countModules.contains(moduleId);
  final f = _figure(k, moduleId);
  final countSurvives =
      count &&
      k.reasons.contains('currency_mix') &&
      !k.reasons.contains('amount_not_exact');
  final undefinedRatio = f.denominator == 0;
  final quality = {
    for (final q in k.quality)
      if (!countSurvives || q != KpiQuality.unavailable) q,
    if (f.numerator == null ||
        (!count && !currencyCompatible) ||
        undefinedRatio)
      KpiQuality.unavailable,
  };
  final unknown = quality.contains(KpiQuality.unavailable);
  return BiMeasure(
    numerator: f.numerator ?? 0,
    denominator: f.denominator,
    quality: {
      ...quality,
      if (!unknown && f.numerator == 0) KpiQuality.knownZero,
    },
    reasons: [
      ...k.reasons,
      if (!count && !currencyCompatible) 'currency_mix',
      if (undefinedRatio) 'nothing_to_share',
    ],
    detail: k,
  );
}

BiMeasure _row(VendorQualityKpi k, int? numerator, [int? denominator]) =>
    BiMeasure(
      numerator: numerator ?? 0,
      denominator: denominator,
      quality: {
        if (numerator == null || denominator == 0) KpiQuality.unavailable,
      },
      detail: k,
    );

/// The table's rows of [moduleId]: the suppliers by cost, the categories,
/// the payable cohorts, or the suppliers by billing lag. A supplier row
/// carries the supplier's name; the view names the others in the reader's
/// language.
@visibleForTesting
List<BiRow> vendorRows(VendorQualityKpi k, String moduleId) {
  switch (moduleId) {
    case 'vendors.category_spend':
      return [
        for (final c in k.categories)
          BiRow(
            key: 'category-${c.category}',
            label: c.category.isEmpty ? null : c.category,
            current: _row(k, c.costMinor),
          ),
      ];
    case 'vendors.payment_punctuality':
      final due = k.cohorts.values.fold<int>(0, (s, c) => s + c.count);
      return [
        for (final c in PayableCohort.values)
          if (k.cohorts[c] case final f? when f.count > 0)
            BiRow(key: c.wire, label: null, current: _row(k, f.count, due)),
      ];
    case 'vendors.billing_lag':
      return [
        for (final v in k.lags)
          BiRow(
            key: 'supplier-${v.supplierId}',
            label: v.name,
            current: _row(k, v.lagDays, v.documents),
          ),
      ];
    default:
      return [
        for (final v in k.vendors)
          BiRow(
            key: 'supplier-${v.supplierId}',
            label: v.name,
            current: _row(k, v.costMinor),
          ),
      ];
  }
}

/// The vendor module [moduleId] over [period], against [compared].
Future<BiResult> biVendorResult(
  Ref ref,
  String workspaceId,
  String moduleId,
  BiPeriod period,
  BiPeriod? compared,
) async {
  Future<VendorQualityKpi> watch(BiPeriod p) {
    final m = biMonths(p);
    return ref.watch(vendorQualityProvider(workspaceId, m.from, m.to).future);
  }

  // Both watched before the first await (provider_watch_before_await).
  final now = watch(period);
  final then = compared == null ? null : watch(compared);
  final current = await now;
  final before = then == null ? null : await then;
  final currencies = {current.currency, ?before?.currency};
  final compatible = currencies.length == 1 && current.currency.isNotEmpty;
  final money = !_countModules.contains(moduleId);
  return BiResult(
    period: period,
    comparedPeriod: compared,
    total: BiRow(
      key: BiRow.totalKey,
      label: null,
      current: vendorMeasure(current, moduleId, currencyCompatible: compatible),
      compared: before == null
          ? null
          : vendorMeasure(before, moduleId, currencyCompatible: compatible),
    ),
    groups: vendorRows(current, moduleId),
    computedAt: current.computedAt,
    // The amounts of the rows and the total; the shares and days carry none.
    currency: money && compatible ? current.currency : null,
  );
}
