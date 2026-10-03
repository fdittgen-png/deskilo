// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1923 B — one query per module and context. The key is the workspace,
// the module and the whole immutable context, so a changed toolbar or a
// workspace switch reads a NEW provider: a late answer to the old
// question lands in a provider nobody watches any more and is never
// shown under the new one. Groups are bounded; past the budget the
// grouping is refused with its reason rather than fanned out.
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/time/clock.dart';
import '../../../core/time/workspace_time.dart';
import '../../plan/providers/floor_plan_providers.dart';
import '../domain/bi_modules.dart';
import '../domain/bi_query.dart';
import '../data/supabase_bi_view_repository.dart';
import '../domain/bi_result.dart';
import '../domain/bi_saved_view.dart';
import '../domain/kpi_contract.dart';
import 'kpi_providers.dart';

part 'bi_providers.g.dart';

/// The most groups one module asks the server for at once.
const biGroupBudget = 12;

/// The workspace date the relative periods resolve against.
DateTime biToday(Ref ref) =>
    WorkspaceTime.dateOf(ref.read(clockProvider).now());

/// `[from, to)` of [p] on the workspace clock: local midnight of its
/// first day to local midnight after its last, whatever DST does.
({DateTime from, DateTime to}) biInterval(BiPeriod p) => (
  from: WorkspaceTime.at(p.year, p.startMonth, 1),
  to: WorkspaceTime.at(p.year, p.startMonth + p.grain.months, 1),
);

@riverpod
Future<BiResult> biModuleResult(
  Ref ref,
  String workspaceId,
  String moduleId,
  BiQueryContext context,
) async {
  final module = biModules.firstWhere((m) => m.id == moduleId);
  final unsupported = module.unsupported(context);
  if (unsupported.isNotEmpty) throw BiRefused(unsupported);
  final today = biToday(ref);
  final period = context.current(today);
  final compared = context.compared(today);
  return switch (moduleId) {
    'capacity.seat_utilisation' => _capacity(
      ref,
      workspaceId,
      context,
      period,
      compared,
    ),
    'finance.invoiced' || 'finance.collected' => _finance(
      ref,
      workspaceId,
      moduleId,
      period,
      compared,
    ),
    _ => throw KpiUnavailable('no reader for $moduleId'),
  };
}

/// The whole months of [p], `YYYY-MM` first and last (#1924).
({String from, String to}) biMonths(BiPeriod p) {
  String m(int month) => '${p.year}-${month.toString().padLeft(2, '0')}';
  return (from: m(p.startMonth), to: m(p.startMonth + p.grain.months - 1));
}

/// One finance figure of [k]; a missing amount is unknown, never 0.
BiMeasure financeMeasure(FinanceSummaryKpi k, String moduleId) {
  final minor = moduleId == 'finance.invoiced'
      ? k.invoicedMinor
      : k.collectedMinor;
  final quality = {
    ...k.quality,
    if (minor == null) KpiQuality.unavailable,
  };
  final unknown = quality.contains(KpiQuality.unavailable);
  return BiMeasure(
    numerator: minor ?? 0,
    quality: {...quality, if (!unknown && minor == 0) KpiQuality.knownZero},
    reasons: k.reasons,
    detail: k,
  );
}

Future<BiResult> _finance(
  Ref ref,
  String workspaceId,
  String moduleId,
  BiPeriod period,
  BiPeriod? compared,
) async {
  Future<FinanceSummaryKpi> watch(BiPeriod p) {
    final m = biMonths(p);
    return ref.watch(financeSummaryProvider(workspaceId, m.from, m.to).future);
  }

  // Both watched before the first await (provider_watch_before_await).
  final now = watch(period);
  final then = compared == null ? null : watch(compared);
  final current = await now;
  final before = then == null ? null : await then;
  final currencies = {current.currency, ?before?.currency};
  return BiResult(
    period: period,
    comparedPeriod: compared,
    total: BiRow(
      key: BiRow.totalKey,
      label: null,
      current: financeMeasure(current, moduleId),
      compared: before == null ? null : financeMeasure(before, moduleId),
    ),
    computedAt: current.computedAt,
    // Two periods in two currencies do not compare: no currency, no
    // amount.
    currency: currencies.length == 1 && current.currency.isNotEmpty
        ? current.currency
        : null,
  );
}

BiMeasure _seatMeasure(SeatCapacityKpi k) => BiMeasure(
  numerator: k.reservedSeatHours,
  denominator: k.offeredSeatHours,
  quality: k.quality,
  reasons: k.reasons,
  historySince: k.historySince,
  detail: k,
);

Future<BiResult> _capacity(
  Ref ref,
  String workspaceId,
  BiQueryContext context,
  BiPeriod period,
  BiPeriod? compared,
) async {
  final kpis = ref.watch(kpiRepositoryProvider);
  final levelsFuture = context.groupBy == 'level'
      ? ref.watch(levelsProvider.future)
      : null;
  Future<BiMeasure> read(BiPeriod p, String? levelId) async {
    final i = biInterval(p);
    return _seatMeasure(
      await kpis.seatCapacity(
        workspaceId,
        from: i.from,
        to: i.to,
        levelId: levelId,
      ),
    );
  }

  final levels = levelsFuture == null ? null : await levelsFuture;
  if (levels != null && levels.length > biGroupBudget) {
    throw const BiRefused({}, groupBudgetExceeded: true);
  }
  final periods = [period, ?compared];
  final keys = <String?>[null, ...?levels?.map((l) => l.id)];
  final measures = await Future.wait([
    for (final p in periods)
      for (final k in keys) read(p, k),
  ]);
  BiMeasure at(int p, int k) => measures[p * keys.length + k];
  BiRow row(int k, String key, String? label) => BiRow(
    key: key,
    label: label,
    current: at(0, k),
    compared: compared == null ? null : at(1, k),
  );

  final total = row(0, BiRow.totalKey, null);
  final groups = <BiRow>[
    if (levels != null)
      for (final (i, l) in levels.indexed) row(i + 1, l.id, l.name),
  ];
  final remainder = groups.isEmpty
      ? null
      : remainderOf(total.current, groups.map((g) => g.current));
  final comparedRemainder = groups.isEmpty || total.compared == null
      ? null
      : remainderOf(total.compared!, groups.map((g) => g.compared!));
  return BiResult(
    period: period,
    comparedPeriod: compared,
    total: total,
    groups: [
      ...sortRows(groups, context.sort, KpiAggregation.ratioOfSums),
      if (remainder != null || comparedRemainder != null)
        BiRow(
          key: BiRow.remainderKey,
          label: null,
          current: remainder ?? const BiMeasure(numerator: 0, denominator: 0),
          compared: compared == null
              ? null
              : comparedRemainder ??
                    const BiMeasure(numerator: 0, denominator: 0),
        ),
    ],
    computedAt: (total.current.detail! as SeatCapacityKpi).computedAt,
  );
}

/// #1923 C — the saved views, through their definer RPCs.
@Riverpod(keepAlive: true)
BiViewRepository biViewRepository(Ref ref) =>
    SupabaseBiViewRepository(Supabase.instance.client);

/// The reader's private views and the workspace's team views.
@riverpod
Future<List<BiSavedView>> biViews(Ref ref, String workspaceId) =>
    ref.watch(biViewRepositoryProvider).list(workspaceId);

/// The writes a views bar makes; each re-reads the list afterwards, so
/// what is shown is what the server holds.
class BiViewActions {
  BiViewActions(this._ref);

  final Ref _ref;

  BiViewRepository get _repo => _ref.read(biViewRepositoryProvider);

  Future<BiSavedView> save(
    String workspaceId, {
    BiSavedView? over,
    required BiViewScope scope,
    required String name,
    required BiViewDefinition definition,
  }) async {
    try {
      return await _repo.save(
        workspaceId,
        id: over?.id,
        scope: scope,
        name: name,
        definition: definition,
        expectedRevision: over?.revision ?? 0,
      );
    } finally {
      _ref.invalidate(biViewsProvider(workspaceId));
    }
  }

  Future<void> delete(String workspaceId, BiSavedView view) async {
    try {
      await _repo.delete(workspaceId, view.id, view.revision);
    } finally {
      _ref.invalidate(biViewsProvider(workspaceId));
    }
  }

  Future<void> setDefault(
    String workspaceId,
    BiViewScope scope,
    String? id,
  ) async {
    try {
      await _repo.setDefault(workspaceId, scope, id);
    } finally {
      _ref.invalidate(biViewsProvider(workspaceId));
    }
  }
}

@Riverpod(keepAlive: true)
BiViewActions biViewActions(Ref ref) => BiViewActions(ref);
