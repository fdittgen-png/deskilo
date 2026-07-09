// SPDX-License-Identifier: MIT
import 'fee_band.dart';
import 'ledger_entry.dart';
import 'service_item.dart';
import 'statement.dart';
import 'subscription_levels.dart';

/// Money boundary (spec §7). Payments are only *recorded* — the pending
/// event created by [recordPayment] must be confirmed by the other side
/// before a ledger credit exists.
abstract class MoneyRepository {
  Future<Statement> fetchStatement(String memberId, String period);

  Future<List<LedgerEntry>> fetchLedger(String memberId);

  /// Returns the pending event id.
  Future<String> recordPayment({
    required String workspaceId,
    required String memberId,
    required int amountCents,
    String note,
  });

  /// Fee bands of the workspace ordered by [FeeBand.fromPct]
  /// (member-readable, ADR 0008 / #128).
  Future<List<FeeBand>> fetchFeeBands(String workspaceId);

  /// Owner-only (RPC `replace_fee_bands`): atomically replaces the whole
  /// band set. Bands must tile (0, 100] contiguously — validated
  /// server-side too.
  Future<void> replaceFeeBands(String workspaceId, List<FeeBand> bands);

  /// The owner-curated subscription levels of the workspace (#128).
  Future<SubscriptionLevels> fetchSubscriptionLevels(String workspaceId);

  /// Owner-only (RLS on workspaces): persists the offered levels.
  Future<void> setSubscriptionLevels(
    String workspaceId,
    SubscriptionLevels levels,
  );

  /// Consumable services of the workspace, name-ordered (member-readable).
  /// Owners pass [includeInactive] for the catalog editor (#123).
  Future<List<ServiceItem>> fetchServices(
    String workspaceId, {
    bool includeInactive = false,
  });

  /// Owner-only (RLS services_write): creates a service.
  Future<ServiceItem> createService(
    String workspaceId, {
    required String name,
    required int priceCents,
  });

  /// Owner-only: partial update of name, price and active flag.
  /// Deactivate = `updateService(active: false)` — services are never
  /// deleted (bill lines reference them).
  Future<ServiceItem> updateService(
    String serviceId, {
    String? name,
    int? priceCents,
    bool? active,
  });

  /// Submits a community expense (spec §9); another admin must approve
  /// before the credit exists. Returns the pending event id.
  Future<String> submitExpense({
    required String workspaceId,
    required int amountCents,
    required String category,
    String description,
  });
}
