// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2582 C1 — the purchase figures of the analytics page, read from
// `kpi_purchases_summary` (0527): one read per workspace and months, shared
// by the four cards, turned into the page's measure.
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/bi_query.dart';
import '../domain/bi_result.dart';
import '../domain/kpi_contract.dart';
import '../domain/kpi_purchases.dart';
import 'bi_providers.dart';
import 'kpi_providers.dart';

/// #2582 — one purchase figure of [k]; a missing amount is unknown, never
/// 0. The review queue is a count, in no currency.
@visibleForTesting
BiMeasure purchaseMeasure(
  PurchaseSummaryKpi k,
  String moduleId, {
  bool currencyCompatible = true,
}) {
  final count = moduleId == 'purchases.pending_reviews';
  final figure = k.figure(moduleId);
  // Another currency in scope leaves the count of documents to review
  // exact: only the amounts become unknown.
  final countSurvives =
      count &&
      k.reasons.contains('currency_mix') &&
      !k.reasons.contains('amount_not_exact');
  final quality = {
    for (final q in k.quality)
      if (!countSurvives || q != KpiQuality.unavailable) q,
    if (figure == null || (!count && !currencyCompatible))
      KpiQuality.unavailable,
  };
  final unknown = quality.contains(KpiQuality.unavailable);
  return BiMeasure(
    numerator: figure ?? 0,
    quality: {...quality, if (!unknown && figure == 0) KpiQuality.knownZero},
    reasons: [...k.reasons, if (!count && !currencyCompatible) 'currency_mix'],
    detail: k,
  );
}

/// The purchase module [moduleId] over [period], against [compared].
Future<BiResult> biPurchaseResult(
  Ref ref,
  String workspaceId,
  String moduleId,
  BiPeriod period,
  BiPeriod? compared,
) async {
  Future<PurchaseSummaryKpi> watch(BiPeriod p) {
    final m = biMonths(p);
    return ref.watch(purchaseSummaryProvider(workspaceId, m.from, m.to).future);
  }

  // Both watched before the first await (provider_watch_before_await).
  final now = watch(period);
  final then = compared == null ? null : watch(compared);
  final current = await now;
  final before = then == null ? null : await then;
  final currencies = {current.currency, ?before?.currency};
  final compatible = currencies.length == 1 && current.currency.isNotEmpty;
  return BiResult(
    period: period,
    comparedPeriod: compared,
    total: BiRow(
      key: BiRow.totalKey,
      label: null,
      current: purchaseMeasure(
        current,
        moduleId,
        currencyCompatible: compatible,
      ),
      compared: before == null
          ? null
          : purchaseMeasure(before, moduleId, currencyCompatible: compatible),
    ),
    computedAt: current.computedAt,
    currency: moduleId == 'purchases.pending_reviews' || !compatible
        ? null
        : current.currency,
  );
}
