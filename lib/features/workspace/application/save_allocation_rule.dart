// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2582 C2 (0531) — appending a revision of a cost allocation rule. A new
// rule starts at revision 1; a change or a stop names the revision it was
// made from, so a concurrent edit is refused instead of overwritten.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/ids/request_id.dart';
import '../domain/cost_allocation_rules.dart';
import '../providers/cost_allocation_providers.dart';

part 'save_allocation_rule.g.dart';

class SaveAllocationRule {
  const SaveAllocationRule(this._repository, this._saved);
  final CostAllocationRepository _repository;

  /// What a saved revision makes stale: the rules and every allocation.
  final void Function(String workspaceId) _saved;

  /// Saves [draft] as the next revision of [rule], or as a new rule when
  /// [rule] is null. A server refusal propagates.
  Future<AllocationRule> call(
    String workspaceId,
    AllocationRule? rule,
    AllocationRuleDraft draft,
  ) async {
    final saved = await _repository.save(
      workspaceId,
      ruleId: rule?.ruleId,
      expectedRevision: rule?.revision ?? 0,
      draft: draft,
      requestId: newRequestId(),
    );
    _saved(workspaceId);
    return saved;
  }
}

/// #2582 — saving a revision of an allocation rule.
@riverpod
SaveAllocationRule saveAllocationRule(Ref ref) => SaveAllocationRule(
  ref.watch(costAllocationRepositoryProvider),
  (workspaceId) => ref
    ..invalidate(allocationRulesProvider(workspaceId))
    ..invalidate(costAllocationProvider),
);
