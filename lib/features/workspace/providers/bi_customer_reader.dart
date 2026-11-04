// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 — the customer figures of the analytics page, read from
// `kpi_customer_quality` (0671): one read per workspace and months, shared
// by the four cards, turned into the page's measure and its table rows.
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/bi_query.dart';
import '../domain/bi_result.dart';
import '../domain/kpi_contract.dart';
import '../domain/kpi_customers.dart';
import 'bi_providers.dart';
import 'customer_kpi_providers.dart';

/// The two customer figures that are counts: another currency in scope
/// leaves them exact.
const _countModules = {'customers.payment_behaviour', 'customers.dunning_load'};

/// The figure [moduleId] shows of [k], as numerator and denominator; a
/// null numerator is unknown, never 0.
({int? numerator, int? denominator}) _figure(
  CustomerQualityKpi k,
  String moduleId,
) => switch (moduleId) {
  'customers.payment_behaviour' => (
    numerator: k.onTimeCount,
    denominator: k.completedCount,
  ),
  'customers.dunning_load' => (numerator: k.dunning?.reminders, denominator: null),
  'customers.credit_and_writeoff' => (
    numerator: k.creditedAndWrittenOffMinor,
    denominator: null,
  ),
  _ => (numerator: k.topNetMinor, denominator: k.netMinor),
};

/// #3294 — one customer figure of [k]. Unknown when the amount is (another
/// currency, an inexact amount), when dunning is off for the dunning load,
/// or when a share has nothing to share.
@visibleForTesting
BiMeasure customerMeasure(
  CustomerQualityKpi k,
  String moduleId, {
  bool currencyCompatible = true,
}) {
  final count = _countModules.contains(moduleId);
  final f = _figure(k, moduleId);
  final countSurvives =
      count &&
      k.reasons.contains('currency_mix') &&
      !k.reasons.contains('amount_not_exact');
  // A share of nothing, or of a net the credits outweigh, is undefined.
  final undefinedShare = f.denominator != null && f.denominator! <= 0;
  final dunningOff =
      moduleId == 'customers.dunning_load' && k.dunning == null;
  // A net the server could not prove leaves this module's net partial.
  final netLeftOut = switch (moduleId) {
    'customers.credit_and_writeoff' => k.creditNetUnknown > 0,
    'customers.concentration' => k.netUnknown > 0,
    _ => false,
  };
  final quality = {
    for (final q in k.quality)
      if (!countSurvives || q != KpiQuality.unavailable) q,
    if (f.numerator == null || (!count && !currencyCompatible) || undefinedShare)
      KpiQuality.unavailable,
    if (netLeftOut) KpiQuality.partial,
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
      ...k.reasons.where(
        (r) =>
            (r != 'dunning_off' || dunningOff) &&
            (r != 'net_not_proven' || netLeftOut),
      ),
      if (!count && !currencyCompatible) 'currency_mix',
      if (undefinedShare) 'nothing_to_share',
    ],
    detail: k,
  );
}

BiMeasure _row(CustomerQualityKpi k, int? numerator, [int? denominator]) =>
    BiMeasure(
      numerator: numerator ?? 0,
      denominator: denominator,
      quality: {
        if (numerator == null || denominator == 0) KpiQuality.unavailable,
      },
      detail: k,
    );

/// The table's rows of [moduleId]: the cohorts, the reminder levels, the
/// months, or the largest customers by rank. [BiRow.label] stays null:
/// the module's view names each row in the reader's language.
@visibleForTesting
List<BiRow> customerRows(CustomerQualityKpi k, String moduleId) {
  switch (moduleId) {
    case 'customers.payment_behaviour':
      final due = k.cohorts.values.fold<int>(0, (s, c) => s + c.count);
      return [
        for (final c in PaymentCohort.values)
          if (k.cohorts[c] case final f? when f.count > 0)
            BiRow(key: c.wire, label: null, current: _row(k, f.count, due)),
      ];
    case 'customers.dunning_load':
      final levels = k.dunning?.byLevel ?? const <int, int>{};
      return [
        for (final level in levels.keys.toList()..sort())
          BiRow(
            key: 'level-$level',
            label: null,
            current: _row(k, levels[level]),
          ),
      ];
    case 'customers.credit_and_writeoff':
      return [
        for (final m in k.creditMonths)
          BiRow(
            key: m.month,
            label: null,
            current: _row(
              k,
              m.creditedMinor == null || m.writtenOffMinor == null
                  ? null
                  : m.creditedMinor! + m.writtenOffMinor!,
            ),
          ),
      ];
    default:
      return [
        for (final c in k.customers)
          BiRow(
            key: 'rank-${c.rank}',
            label: null,
            current: _row(k, c.minor, k.netMinor),
          ),
      ];
  }
}

/// The customer module [moduleId] over [period], against [compared].
Future<BiResult> biCustomerResult(
  Ref ref,
  String workspaceId,
  String moduleId,
  BiPeriod period,
  BiPeriod? compared,
) async {
  Future<CustomerQualityKpi> watch(BiPeriod p) {
    final m = biMonths(p);
    return ref.watch(customerQualityProvider(workspaceId, m.from, m.to).future);
  }

  // Both watched before the first await (provider_watch_before_await).
  final now = watch(period);
  final then = compared == null ? null : watch(compared);
  final current = await now;
  final before = then == null ? null : await then;
  final currencies = {current.currency, ?before?.currency};
  final compatible = currencies.length == 1 && current.currency.isNotEmpty;
  final money = moduleId == 'customers.credit_and_writeoff';
  return BiResult(
    period: period,
    comparedPeriod: compared,
    total: BiRow(
      key: BiRow.totalKey,
      label: null,
      current: customerMeasure(
        current,
        moduleId,
        currencyCompatible: compatible,
      ),
      compared: before == null
          ? null
          : customerMeasure(before, moduleId, currencyCompatible: compatible),
    ),
    groups: customerRows(current, moduleId),
    computedAt: current.computedAt,
    // The amounts of the rows and the total; the shares carry none.
    currency: money && compatible ? current.currency : null,
  );
}
