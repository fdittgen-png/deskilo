// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3785 — the cost allocation of a Demo space: its rules kept in memory,
// every revision appended as `save_cost_allocation_rule_v1` does (0531), and
// the spread computed with the rules of `kpi_cost_allocation` (0531):
//
//   * the operating lines of the months, at 0532's cost of a line, dated by
//     the document;
//   * for each line and rule, the rule's highest revision whose interval
//     holds the line's day; a retired one applies no more;
//   * a line rule beats a category rule; two live rules of the same reach
//     claim the line and leave it unallocated (`rule_conflict`);
//   * each revision's total is spread once by largest remainder, a tie to
//     the resource that sorts first (kind, then id): direct when one
//     resource carries weight, shared when several do; what no rule spreads
//     is unallocated, so direct + shared + unallocated = the operating costs.
//
// A Demo purchase line has no id of its own: a line rule names it as
// `<purchase id>#<line number>`.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../features/money/domain/purchase.dart';
import '../../../features/workspace/domain/cost_allocation.dart';
import '../../../features/workspace/domain/cost_allocation_rules.dart';
import '../../../features/workspace/domain/kpi_contract.dart';
import 'demo_cost_kpi_repository.dart';
import 'floor_plan_repository.dart';
import 'purchase_repository.dart';

/// One operating line of the months.
typedef _Line = ({String key, String category, DateTime dated, int cost});

/// One rule revision's total and what it gave each resource.
typedef _Group = ({
  AllocationRule rule,
  int amount,
  List<AllocationShare>? shares,
});

class DemoCostAllocationRepository implements CostAllocationRepository {
  DemoCostAllocationRepository({
    required this.purchases,
    required this.plan,
    required this.currencyOf,
    required this.now,
    Iterable<AllocationRule> rules = const [],
  }) : _rules = [...rules];

  final FakePurchaseRepository purchases;
  final FakeFloorPlanRepository plan;

  /// The space's currency, as its workspace record states it.
  final String Function(String workspaceId) currencyOf;
  final DateTime now;
  final List<AllocationRule> _rules;
  final Map<String, AllocationRule> _answers = {};
  var _next = 1;

  static const _kinds = {'level', 'office', 'desk', 'seat'};

  /// The key a Demo line rule names a purchase line by.
  static String lineKey(String purchaseId, int lineNo) => '$purchaseId#$lineNo';

  @override
  Future<List<AllocationRule>> rules(String workspaceId) async =>
      [..._rules]..sort(
        (a, b) => a.ruleId != b.ruleId
            ? a.ruleId.compareTo(b.ruleId)
            : b.revision.compareTo(a.revision),
      );

  @override
  Future<AllocationRule> save(
    String workspaceId, {
    required String? ruleId,
    required int expectedRevision,
    required AllocationRuleDraft draft,
    required String requestId,
  }) async {
    final replay = _answers[requestId];
    if (replay != null) return replay;
    final revisions = [
      for (final r in _rules)
        if (r.ruleId == ruleId) r.revision,
    ];
    final latest = revisions.isEmpty
        ? 0
        : revisions.reduce((a, b) => a > b ? a : b);
    if (ruleId != null && revisions.isEmpty) {
      throw StateError('unknown allocation rule');
    }
    if (latest != expectedRevision) {
      throw StateError('the rule changed meanwhile: reload it');
    }
    _check(draft);
    final rule = AllocationRule(
      ruleId: ruleId ?? 'demo-allocation-rule-${_next++}',
      revision: latest + 1,
      category: draft.purchaseLineId == null ? draft.category.trim() : '',
      purchaseLineId: draft.purchaseLineId,
      effectiveFrom: draft.effectiveFrom,
      effectiveTo: draft.effectiveTo,
      basis: draft.basis,
      weights: [...draft.weights]
        ..sort(
          (a, b) => a.resourceKind != b.resourceKind
              ? a.resourceKind.compareTo(b.resourceKind)
              : a.resourceId.compareTo(b.resourceId),
        ),
      retired: draft.retired,
    );
    _rules.add(rule);
    return _answers[requestId] = rule;
  }

  /// The checks `save_cost_allocation_rule_v1` makes before it appends.
  void _check(AllocationRuleDraft draft) {
    if ((draft.purchaseLineId == null) == draft.category.trim().isEmpty) {
      throw StateError('a rule scopes one purchase line or one category');
    }
    if (draft.weights.length > 100 ||
        (!draft.retired && draft.weights.isEmpty)) {
      throw StateError('a rule names between 1 and 100 resources');
    }
    final seen = <String>{};
    for (final w in draft.weights) {
      if (!_kinds.contains(w.resourceKind) || w.weight < 0) {
        throw StateError(
          'a weight names a level, office, desk or seat and a whole number '
          'from 0',
        );
      }
      if (!seen.add('${w.resourceKind}:${w.resourceId}')) {
        throw StateError('a resource is named twice');
      }
      if (_nameOf(w.resourceKind, w.resourceId) == null) {
        throw StateError('unknown resource ${w.resourceKind}:${w.resourceId}');
      }
    }
  }

  String? _nameOf(String kind, String id) => switch (kind) {
    'level' => plan.levels.where((x) => x.id == id).firstOrNull?.name,
    'office' => plan.offices.where((x) => x.id == id).firstOrNull?.name,
    'desk' => plan.desks.where((x) => x.id == id).firstOrNull?.name,
    'seat' => plan.seats.where((x) => x.id == id).firstOrNull?.name,
    _ => null,
  };

  @override
  Future<CostAllocationKpi> summary(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async {
    final currency = currencyOf(workspaceId).trim().toUpperCase();
    if (currency.isEmpty) {
      throw const KpiUnavailable('the workspace has no currency');
    }
    final (lines, mixed) = _lines(
      await demoPurchaseDocuments(purchases, workspaceId),
      currency,
      fromMonth,
      toMonth,
    );
    final (groups, conflicts) = _groups(lines);
    final total = lines.fold<int>(0, (s, l) => s + l.cost);
    var direct = 0, shared = 0;
    for (final g in groups) {
      final positive = g.rule.weights.where((w) => w.weight > 0).length;
      final spread = (g.shares ?? const <AllocationShare>[]).fold<int>(
        0,
        (s, x) => s + x.minor,
      );
      if (positive == 1) direct += spread;
      if (positive > 1) shared += spread;
    }
    final partial = toMonth.compareTo(yearMonth(now.year, now.month)) >= 0;
    return CostAllocationKpi(
      fromMonth: fromMonth,
      toMonth: toMonth,
      currency: currency,
      operatingCostsMinor: total,
      directMinor: direct,
      sharedMinor: shared,
      unallocatedMinor: total - direct - shared,
      conflictingLines: conflicts,
      resources: _resources(groups),
      rulesUsed: [
        for (final g in [
          ...groups,
        ]..sort((a, b) => a.rule.ruleId.compareTo(b.rule.ruleId)))
          if (g.shares != null) (g.rule.basis, g.rule.revision),
      ],
      quality: {
        if (mixed) KpiQuality.unavailable,
        if (partial) KpiQuality.partial,
      },
      reasons: [
        if (mixed) 'currency_mix',
        if (partial) 'period_not_over',
        if (conflicts > 0) 'rule_conflict',
        if (total - direct - shared != 0) 'unallocated',
      ],
      computedAt: now,
    );
  }

  /// The operating lines of the months, and whether one is in another
  /// currency.
  (List<_Line>, bool) _lines(
    List<PurchaseDetail> documents,
    String currency,
    String from,
    String to,
  ) {
    final out = <_Line>[];
    var mixed = false;
    for (final doc in documents) {
      final s = doc.summary;
      final dated = s.originalDate ?? s.receivedOn;
      if (s.state != PurchaseState.approved || dated == null) continue;
      final month = yearMonth(dated.year, dated.month);
      if (month.compareTo(from) < 0 || month.compareTo(to) > 0) continue;
      final sign = s.kind == PurchaseKind.creditNote ? -1 : 1;
      for (final l in doc.lines) {
        if (l.recognitionKind != 'operating') continue;
        mixed |= s.currency.toUpperCase() != currency;
        out.add((
          key: lineKey(s.id, l.lineNo),
          category: s.category,
          dated: DateTime(dated.year, dated.month, dated.day),
          cost: sign * DemoCostKpiRepository.lineCost(l),
        ));
      }
    }
    return (out, mixed);
  }

  /// The revision of each rule that governs [line] on its day, if any.
  List<AllocationRule> _governing(_Line line) {
    final byRule = <String, AllocationRule>{};
    for (final r in _rules) {
      final reaches = r.purchaseLineId != null
          ? r.purchaseLineId == line.key
          : r.category == line.category;
      final inForce =
          !line.dated.isBefore(r.effectiveFrom) &&
          (r.effectiveTo == null || !line.dated.isAfter(r.effectiveTo!));
      if (!reaches || !inForce) continue;
      final known = byRule[r.ruleId];
      if (known == null || r.revision > known.revision) byRule[r.ruleId] = r;
    }
    return [
      for (final r in byRule.values)
        if (!r.retired) r,
    ];
  }

  /// Each governing revision with its lines' total and its spread, and how
  /// many lines two rules claim.
  (List<_Group>, int) _groups(List<_Line> lines) {
    final amounts = <AllocationRule, int>{};
    var conflicts = 0;
    for (final line in lines) {
      final live = _governing(line);
      if (live.isEmpty) continue;
      final byLine = live.any((r) => r.purchaseLineId != null);
      final claims =
          live.where((r) => (r.purchaseLineId != null) == byLine).toList()
            ..sort((a, b) => a.ruleId.compareTo(b.ruleId));
      if (claims.length > 1) {
        conflicts++;
        continue;
      }
      amounts[claims.single] = (amounts[claims.single] ?? 0) + line.cost;
    }
    return (
      [
        for (final e in amounts.entries)
          (
            rule: e.key,
            amount: e.value,
            shares: allocateByLargestRemainder(e.value, e.key.weights),
          ),
      ],
      conflicts,
    );
  }

  /// What each resource received, with the revisions behind it, by kind
  /// then id; a resource without a share is left out, one whose
  /// shares net to zero is listed at 0.
  List<ResourceAllocation> _resources(List<_Group> groups) {
    final minor = <(String, String), int>{};
    final revisions = <(String, String), Set<(String, int)>>{};
    for (final g in groups) {
      // A zero share is no share; shares that net to zero are (0531).
      for (final s in g.shares ?? const <AllocationShare>[]) {
        if (s.minor == 0) continue;
        final key = (s.resourceKind, s.resourceId);
        minor[key] = (minor[key] ?? 0) + s.minor;
        (revisions[key] ??= {}).add((g.rule.ruleId, g.rule.revision));
      }
    }
    final keys = minor.keys.toList()
      ..sort(
        (a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2),
      );
    return [
      for (final k in keys)
        ResourceAllocation(
          resourceKind: k.$1,
          resourceId: k.$2,
          name: _nameOf(k.$1, k.$2) ?? '',
          allocatedMinor: minor[k],
          revisions: revisions[k]!.toList(),
        ),
    ];
  }
}
