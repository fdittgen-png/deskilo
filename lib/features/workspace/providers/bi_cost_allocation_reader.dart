// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2582 C2 — the cost allocation card of the analytics page: the allocated
// part of the operating costs as its figure, one row per resource, each
// traceable to the rule revisions behind it.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/bi_query.dart';
import '../domain/bi_result.dart';
import '../domain/cost_allocation_rules.dart';
import '../domain/kpi_contract.dart';
import 'bi_providers.dart';
import 'cost_allocation_providers.dart';

/// [minor] of [k] as a measure; a missing amount is unknown, never 0.
BiMeasure _allocationMeasure(
  CostAllocationKpi k,
  int? minor, {
  bool currencyCompatible = true,
}) {
  final quality = {
    ...k.quality,
    if (minor == null || !currencyCompatible) KpiQuality.unavailable,
  };
  final unknown = quality.contains(KpiQuality.unavailable);
  return BiMeasure(
    numerator: minor ?? 0,
    quality: {...quality, if (!unknown && minor == 0) KpiQuality.knownZero},
    reasons: [...k.reasons, if (!currencyCompatible) 'currency_mix'],
    detail: k,
  );
}

/// The allocation over [period], against [compared], one row per resource.
Future<BiResult> biCostAllocationResult(
  Ref ref,
  String workspaceId,
  BiPeriod period,
  BiPeriod? compared,
) async {
  Future<CostAllocationKpi> watch(BiPeriod p) {
    final m = biMonths(p);
    return ref.watch(costAllocationProvider(workspaceId, m.from, m.to).future);
  }

  // Both watched before the first await (provider_watch_before_await).
  final now = watch(period);
  final then = compared == null ? null : watch(compared);
  final current = await now;
  final before = then == null ? null : await then;
  final currencies = {current.currency, ?before?.currency};
  final compatible = currencies.length == 1 && current.currency.isNotEmpty;
  BiMeasure measure(CostAllocationKpi k, int? minor) =>
      _allocationMeasure(k, minor, currencyCompatible: compatible);
  String key(ResourceAllocation r) => '${r.resourceKind}:${r.resourceId}';
  final earlier = {
    for (final r in before?.resources ?? const <ResourceAllocation>[])
      key(r): r,
  };
  return BiResult(
    period: period,
    comparedPeriod: compared,
    total: BiRow(
      key: BiRow.totalKey,
      label: null,
      current: measure(current, current.allocatedMinor),
      compared: before == null ? null : measure(before, before.allocatedMinor),
    ),
    groups: [
      for (final r in current.resources)
        BiRow(
          key: key(r),
          label: r.name.isEmpty ? r.resourceKind : r.name,
          current: measure(current, r.allocatedMinor),
          compared: before == null
              ? null
              : measure(before, earlier[key(r)]?.allocatedMinor ?? 0),
        ),
    ],
    computedAt: current.computedAt,
    currency: compatible ? current.currency : null,
  );
}
