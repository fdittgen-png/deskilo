// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A capacity repository with no server behind it: every read answers
// `KpiUnavailable`, so a test can prove the tile says so rather than
// inventing a figure.
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/domain/kpi_customers.dart';
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
