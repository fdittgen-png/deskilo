// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A capacity repository with no server behind it: every read answers
// `KpiUnavailable`, so a test can prove the tile says so rather than
// inventing a figure.
import 'package:deskilo/features/workspace/domain/cost_allocation_rules.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/domain/kpi_customers.dart';
import 'package:deskilo/features/workspace/domain/kpi_items.dart';
import 'package:deskilo/features/workspace/domain/kpi_purchases.dart';
import 'package:deskilo/features/workspace/domain/kpi_sales.dart';
import 'package:deskilo/features/workspace/domain/kpi_vendors.dart';

class UnavailableKpiRepository implements KpiRepository {
  const UnavailableKpiRepository();

  @override
  Future<SeatCapacityKpi> seatCapacity(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
    String? levelId,
  }) async => throw const KpiUnavailable('no server in this mode');
}

/// #3294 — no server to read the customer figures from.
class UnavailableCustomerKpiRepository implements CustomerKpiRepository {
  const UnavailableCustomerKpiRepository();

  @override
  Future<CustomerQualityKpi> quality(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async => throw const KpiUnavailable('no server in this mode');
}

/// #3294 step 2 — no server to read the vendor figures from.
class UnavailableVendorKpiRepository implements VendorKpiRepository {
  const UnavailableVendorKpiRepository();

  @override
  Future<VendorQualityKpi> quality(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async => throw const KpiUnavailable('no server in this mode');
}

/// #3294 step 3 — no server to read the sales figures from.
class UnavailableSalesKpiRepository implements SalesKpiRepository {
  const UnavailableSalesKpiRepository();

  @override
  Future<SalesQualityKpi> quality(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async => throw const KpiUnavailable('no server in this mode');
}

/// #3294 step 4 — no server to read the item figures from.
class UnavailableItemKpiRepository implements ItemKpiRepository {
  const UnavailableItemKpiRepository();

  @override
  Future<ItemMarginsKpi> quality(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async => throw const KpiUnavailable('no server in this mode');
}

/// #2582 C2 — no server to read the cost figures from.
class UnavailableCostKpiRepository implements CostKpiRepository {
  const UnavailableCostKpiRepository();

  @override
  Future<CostSummaryKpi> summary(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async => throw const KpiUnavailable('no server in this mode');
}

/// #2582 C2 — no server to read or keep the cost allocation.
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
