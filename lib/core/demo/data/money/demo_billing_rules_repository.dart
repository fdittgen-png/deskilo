// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/core/demo/data/workspace_status_computation.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/billing_rules_repository.dart';
import 'package:deskilo/features/money/domain/workspace_status.dart';

import '../money_repository.dart';

/// #2591 — the demo's billing rules, the repartition rule and the workspace
/// status, answered from one space's in-memory money store
/// ([FakeMoneyRepository]); every other port of that space reads and writes the
/// same store.
class DemoBillingRules implements BillingRulesRepository {
  DemoBillingRules(this._m);

  final FakeMoneyRepository _m;

  @override
  Future<BillingRules> fetchBillingRules(String workspaceId) async =>
      _m.billingRules;

  @override
  Future<WorkspaceStatus> fetchWorkspaceStatus(
    String workspaceId,
    String from,
    String to,
  ) async => _m.status ?? demoWorkspaceStatus(_m, from, to);

  @override
  Future<RepartitionRule> fetchRepartitionRule(String workspaceId) async =>
      _m.repartitionRule;

  @override
  Future<void> setRepartitionRule(
    String workspaceId,
    RepartitionRule rule,
  ) async {
    _m.repartitionRule = rule;
  }

  @override
  Future<void> setBillingRules(String workspaceId, BillingRules rules) async {
    _m.billingRules = rules;
  }

  @override
  Future<int> sweepBillingInvoices(String workspaceId) async {
    _m.billingSweeps.add(workspaceId);
    return 0;
  }
}
