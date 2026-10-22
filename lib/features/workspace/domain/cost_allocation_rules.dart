// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2582 C2 — the cost allocation as the server returns it (0531): the rules,
// every revision kept, and what `kpi_cost_allocation` spread over the
// resources in a period. A missing amount is null, never 0.
//
// Pure Dart: no Flutter, no l10n.
library;

import '../../../core/data/json_reader.dart';
import '../../../core/time/date_text.dart';
import 'cost_allocation.dart';
import 'kpi_contract.dart';

/// One revision of an allocation rule.
class AllocationRule {
  const AllocationRule({
    required this.ruleId,
    required this.revision,
    required this.category,
    required this.purchaseLineId,
    required this.effectiveFrom,
    required this.effectiveTo,
    required this.basis,
    required this.weights,
    required this.retired,
  });

  final String ruleId;
  final int revision;

  /// The purchase documents' category the rule spreads, or '' for a line.
  final String category;
  final String? purchaseLineId;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final String basis;
  final List<AllocationWeight> weights;
  final bool retired;
}

DateTime _day(String wire) => DateTime.parse(wire);

AllocationWeight _weightFromJson(Object? raw) {
  final r = JsonReader.of(raw, context: 'allocation_weight');
  return AllocationWeight(
    resourceKind: r.string('resource_kind'),
    resourceId: r.string('resource_id'),
    weight: r.integer('weight'),
  );
}

/// Parses one revision of `cost_allocation_rules_v1`.
AllocationRule allocationRuleFromJson(Object? raw) {
  final r = JsonReader.of(raw, context: 'cost_allocation_rule');
  final to = r.stringOrNull('effective_to');
  return AllocationRule(
    ruleId: r.string('rule_id'),
    revision: r.integer('revision'),
    category: r.stringOr('category'),
    purchaseLineId: r.stringOrNull('purchase_line_id'),
    effectiveFrom: _day(r.string('effective_from')),
    effectiveTo: to == null ? null : _day(to),
    basis: r.stringOr('basis'),
    weights: [for (final w in r.list('weights')) _weightFromJson(w)],
    retired: r.boolOr('retired', fallback: false),
  );
}

/// The newest revision of each rule, in rule order; retired ones included,
/// so the editor can say they stopped.
List<AllocationRule> latestRevisions(List<AllocationRule> all) {
  final latest = <String, AllocationRule>{};
  for (final rule in all) {
    final known = latest[rule.ruleId];
    if (known == null || rule.revision > known.revision) {
      latest[rule.ruleId] = rule;
    }
  }
  return latest.values.toList();
}

/// What a person enters for a revision.
class AllocationRuleDraft {
  const AllocationRuleDraft({
    required this.category,
    required this.effectiveFrom,
    required this.basis,
    required this.weights,
    this.purchaseLineId,
    this.effectiveTo,
    this.retired = false,
  });

  final String category;
  final String? purchaseLineId;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final String basis;
  final List<AllocationWeight> weights;
  final bool retired;

  /// The `p_rule` of `save_cost_allocation_rule_v1`.
  Map<String, Object?> toJson() => {
    if (purchaseLineId == null) 'category': category,
    'purchase_line_id': ?purchaseLineId,
    'effective_from': isoDay(effectiveFrom),
    if (effectiveTo != null) 'effective_to': isoDay(effectiveTo!),
    'basis': basis,
    'retired': retired,
    'weights': [
      for (final w in weights)
        {
          'resource_kind': w.resourceKind,
          'resource_id': w.resourceId,
          'weight': w.weight,
        },
    ],
  };
}

/// What one resource received in the period, and from which revisions.
class ResourceAllocation {
  const ResourceAllocation({
    required this.resourceKind,
    required this.resourceId,
    required this.name,
    required this.allocatedMinor,
    required this.revisions,
  });

  final String resourceKind;
  final String resourceId;
  final String name;
  final int? allocatedMinor;

  /// The (rule id, revision) pairs behind the share.
  final List<(String, int)> revisions;
}

/// What `kpi_cost_allocation` returned for the whole months
/// [fromMonth, toMonth]. direct + shared + unallocated = operating costs.
class CostAllocationKpi {
  const CostAllocationKpi({
    required this.fromMonth,
    required this.toMonth,
    required this.currency,
    required this.operatingCostsMinor,
    required this.directMinor,
    required this.sharedMinor,
    required this.unallocatedMinor,
    required this.conflictingLines,
    required this.resources,
    required this.rulesUsed,
    required this.quality,
    required this.reasons,
    required this.computedAt,
  });

  final String fromMonth;
  final String toMonth;
  final String currency;
  final int? operatingCostsMinor;
  final int? directMinor;
  final int? sharedMinor;
  final int? unallocatedMinor;

  /// Lines two rules claim: left unallocated until one of them goes.
  final int conflictingLines;
  final List<ResourceAllocation> resources;

  /// The rule revisions that spread the period's costs: (basis, revision).
  final List<(String, int)> rulesUsed;
  final Set<KpiQuality> quality;
  final List<String> reasons;
  final DateTime computedAt;

  /// The allocated part (direct + shared), the card's figure.
  int? get allocatedMinor => directMinor == null || sharedMinor == null
      ? null
      : directMinor! + sharedMinor!;
}

ResourceAllocation _resourceFromJson(Object? raw) {
  final r = JsonReader.of(raw, context: 'cost_allocation_resource');
  return ResourceAllocation(
    resourceKind: r.string('resource_kind'),
    resourceId: r.string('resource_id'),
    name: r.stringOr('name'),
    allocatedMinor: exactMinor(r.raw('allocated_minor')),
    revisions: [for (final x in r.list('rules')) _revisionOf(x)],
  );
}

(String, int) _revisionOf(Object? raw) {
  final r = JsonReader.of(raw, context: 'cost_allocation_revision');
  return (r.string('rule_id'), r.integer('revision'));
}

/// Parses `kpi_cost_allocation`'s jsonb; an inexact amount is unknown.
CostAllocationKpi costAllocationFromJson(Map<String, Object?> json) {
  final r = JsonReader(json, context: 'kpi_cost_allocation');
  final total = exactMinor(r.raw('operating_costs_minor'));
  final direct = exactMinor(r.raw('direct_minor'));
  final shared = exactMinor(r.raw('shared_minor'));
  final unallocated = exactMinor(r.raw('unallocated_minor'));
  final resources = [for (final x in r.list('resources')) _resourceFromJson(x)];
  final inexact =
      total == null ||
      direct == null ||
      shared == null ||
      unallocated == null ||
      resources.any((x) => x.allocatedMinor == null);
  final currency = r.stringOr('currency');
  return CostAllocationKpi(
    fromMonth: r.stringOr('from'),
    toMonth: r.stringOr('to'),
    currency: currency,
    operatingCostsMinor: total,
    directMinor: direct,
    sharedMinor: shared,
    unallocatedMinor: unallocated,
    conflictingLines: r.integer('conflicting_lines'),
    resources: resources,
    rulesUsed: [
      for (final x in r.list('rules'))
        if (JsonReader.of(x, context: 'cost_allocation_rule_used') case final u
            when u.boolOr('allocated', fallback: false))
          (u.stringOr('basis'), u.integer('revision')),
    ],
    quality: {
      for (final q in r.strings('quality'))
        kpiQualityOf(q) ?? KpiQuality.unavailable,
      if (inexact || currency.isEmpty) KpiQuality.unavailable,
    },
    reasons: [...r.strings('reasons'), if (inexact) 'amount_not_exact'],
    computedAt: r.dateTime('computed_at'),
  );
}

/// Reads and writes the cost allocation (#2582). Every call is authorized
/// there: reading needs the finance right, writing manageBilling.
abstract interface class CostAllocationRepository {
  /// The allocation of the whole months [fromMonth, toMonth] (`YYYY-MM`).
  Future<CostAllocationKpi> summary(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  });

  /// Every revision of every rule.
  Future<List<AllocationRule>> rules(String workspaceId);

  /// Appends a revision; [ruleId] null starts a rule. A stale
  /// [expectedRevision] is refused.
  Future<AllocationRule> save(
    String workspaceId, {
    required String? ruleId,
    required int expectedRevision,
    required AllocationRuleDraft draft,
    required String requestId,
  });
}

/// No server in the demonstration: the card says so; nothing is saved.
class UnavailableCostAllocationRepository implements CostAllocationRepository {
  const UnavailableCostAllocationRepository();

  @override
  Future<CostAllocationKpi> summary(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async => throw const KpiUnavailable('no server in this mode');

  @override
  Future<List<AllocationRule>> rules(String workspaceId) async =>
      throw const KpiUnavailable('no server in this mode');

  @override
  Future<AllocationRule> save(
    String workspaceId, {
    required String? ruleId,
    required int expectedRevision,
    required AllocationRuleDraft draft,
    required String requestId,
  }) async => throw const KpiUnavailable('no server in this mode');
}
