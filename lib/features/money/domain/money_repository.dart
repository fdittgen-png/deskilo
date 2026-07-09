// SPDX-License-Identifier: MIT
import 'ledger_entry.dart';
import 'plan.dart';
import 'service_item.dart';
import 'statement.dart';

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

  /// Plans of the workspace (member-readable). Owners pass
  /// [includeInactive] for the plan editor (#105).
  Future<List<Plan>> fetchPlans(
    String workspaceId, {
    bool includeInactive = false,
  });

  /// Owner-only (RLS plans_write): creates a plan. null
  /// [includedHalfDays] = unlimited.
  Future<void> createPlan({
    required String workspaceId,
    required String name,
    required int baseFeeCents,
    int? includedHalfDays,
    required int overageFeeCents,
  });

  /// Owner-only: updates name, fees, quota and active flag.
  Future<void> updatePlan(Plan plan);

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
