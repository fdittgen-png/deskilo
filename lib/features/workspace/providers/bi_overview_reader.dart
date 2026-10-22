// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2583 — the overview's own figures as analytics modules: today's value,
// a stock compared as such, unknown never 0.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/bi_query.dart';
import '../domain/bi_result.dart';
import '../domain/kpi_contract.dart';
import '../domain/kpi_overview.dart';
import 'bi_providers.dart';
import 'overview_kpi_providers.dart';

BiMeasure _overviewMeasure(OverviewFigure f) {
  final unknown = f.quality.contains(KpiQuality.unavailable);
  return BiMeasure(
    numerator: f.value ?? 0,
    quality: {...f.quality, if (!unknown && f.value == 0) KpiQuality.knownZero},
    reasons: f.reasons,
    detail: f,
  );
}

/// The module [moduleId] over [period], against [compared].
Future<BiResult> biOverviewResult(
  Ref ref,
  String workspaceId,
  String moduleId,
  BiPeriod period,
  BiPeriod? compared,
) async {
  Future<OverviewFigure> watch(BiPeriod p) {
    final m = biMonths(p);
    return ref.watch(
      overviewFigureProvider(workspaceId, moduleId, m.from, m.to).future,
    );
  }

  // Both watched before the first await (provider_watch_before_await).
  final now = watch(period);
  final then = compared == null ? null : watch(compared);
  final current = await now;
  final before = then == null ? null : await then;
  return BiResult(
    period: period,
    comparedPeriod: compared,
    total: BiRow(
      key: BiRow.totalKey,
      label: null,
      current: _overviewMeasure(current),
      compared: before == null ? null : _overviewMeasure(before),
    ),
    computedAt: current.computedAt,
    currency: current.currency.isEmpty ? null : current.currency,
  );
}
