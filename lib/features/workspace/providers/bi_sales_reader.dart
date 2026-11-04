// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 step 3 — the sales figures of the analytics page, read from
// `kpi_sales_quality` (0674): one read per workspace and months, shared by
// the three cards, turned into the page's measure and its table rows.
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/bi_query.dart';
import '../domain/bi_result.dart';
import '../domain/kpi_contract.dart';
import '../domain/kpi_sales.dart';
import 'bi_providers.dart';
import 'sales_kpi_providers.dart';

/// The figure [moduleId] shows of [k]; null is unknown, never 0.
int? _figure(SalesQualityKpi k, String moduleId) => switch (moduleId) {
  'sales.revenue_by_service' => k.serviceNetMinor,
  'sales.room_margin' => k.rooms?.marginMinor,
  _ => k.netMinor,
};

/// #3294 — one sales figure of [k]. Unknown when the amount is (another
/// currency, an inexact amount), or for the room margin while the space
/// rents no rooms.
@visibleForTesting
BiMeasure salesMeasure(
  SalesQualityKpi k,
  String moduleId, {
  bool currencyCompatible = true,
}) {
  final value = _figure(k, moduleId);
  final roomsOff = moduleId == 'sales.room_margin' && k.rooms == null;
  final quality = {
    ...k.quality,
    if (value == null || !currencyCompatible) KpiQuality.unavailable,
  };
  final unknown = quality.contains(KpiQuality.unavailable);
  return BiMeasure(
    numerator: value ?? 0,
    quality: {...quality, if (!unknown && value == 0) KpiQuality.knownZero},
    reasons: [
      ...k.reasons.where((r) => r != 'external_rooms_off' || roomsOff),
      if (!currencyCompatible) 'currency_mix',
    ],
    detail: k,
  );
}

BiMeasure _row(SalesQualityKpi k, int? amount) => BiMeasure(
  numerator: amount ?? 0,
  quality: {if (amount == null) KpiQuality.unavailable},
  detail: k,
);

/// The table's rows of [moduleId]: the kinds of line, the services by
/// description, or the rented rooms. A service and a room carry their own
/// name; the view names the kinds in the reader's language.
@visibleForTesting
List<BiRow> salesRows(SalesQualityKpi k, String moduleId) => switch (moduleId) {
  'sales.revenue_by_service' => [
    for (final s in k.services)
      BiRow(
        key: 'service-${s.rank}',
        label: s.name.isEmpty ? null : s.name,
        current: _row(k, s.netMinor),
      ),
  ],
  'sales.room_margin' => [
    for (final room in k.rooms?.rows ?? const <RoomMargin>[])
      BiRow(
        key: 'room-${room.officeId}',
        label: room.name,
        current: _row(k, room.marginMinor),
      ),
  ],
  _ => [
    for (final kind in k.kinds)
      BiRow(key: kind.kind, label: null, current: _row(k, kind.netMinor)),
  ],
};

/// The sales module [moduleId] over [period], against [compared].
Future<BiResult> biSalesResult(
  Ref ref,
  String workspaceId,
  String moduleId,
  BiPeriod period,
  BiPeriod? compared,
) async {
  Future<SalesQualityKpi> watch(BiPeriod p) {
    final m = biMonths(p);
    return ref.watch(salesQualityProvider(workspaceId, m.from, m.to).future);
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
      current: salesMeasure(current, moduleId, currencyCompatible: compatible),
      compared: before == null
          ? null
          : salesMeasure(before, moduleId, currencyCompatible: compatible),
    ),
    groups: salesRows(current, moduleId),
    computedAt: current.computedAt,
    currency: compatible ? current.currency : null,
  );
}
