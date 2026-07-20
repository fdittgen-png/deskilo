// SPDX-License-Identifier: MIT
import 'fee_band.dart';
import 'ledger_entry.dart';
import 'package.dart';
import 'payment_method.dart';
import 'service_item.dart';
import 'statement.dart';
import 'subscription_levels.dart';

/// Money boundary (spec §7). Payments are only *recorded* — the pending
/// event created by [recordPayment] must be confirmed by the other side
/// before a ledger credit exists.
abstract class MoneyRepository {
  Future<Statement> fetchStatement(String memberId, String period);

  Future<List<LedgerEntry>> fetchLedger(String memberId);

  /// Returns the pending event id. [method] is how the money moved
  /// (#154); null = not specified (renders method-less, like pre-#154
  /// events).
  Future<String> recordPayment({
    required String workspaceId,
    required String memberId,
    required int amountCents,
    String note,
    PaymentMethod? method,
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

  /// Records consumed services onto the monthly bill (#129, ADR 0008).
  /// Creates a PENDING service_charge event with a name+price snapshot —
  /// the ledger charge posts only on confirmation. Members self-report
  /// (subject = self); admins/owner may record for any member. [period]
  /// is 'yyyy-MM' and defaults server-side to the current month.
  Future<void> recordServiceCharge({
    required String workspaceId,
    required String subjectMemberId,
    required String serviceId,
    required int quantity,
    String? period,
  });

  /// Submits a community expense (spec §9); another admin must approve
  /// before the credit exists. Returns the pending event id.
  Future<String> submitExpense({
    required String workspaceId,
    required int amountCents,
    required String category,
    String description,
  });

  /// Owner-defined day packages (migration 0042). Members read the active
  /// ones (the buy sheet); owners pass [includeInactive] for the editor.
  Future<List<Package>> fetchPackages(
    String workspaceId, {
    bool includeInactive = false,
  });

  /// Owner-only (RLS packages_write): creates a package.
  Future<Package> createPackage(
    String workspaceId, {
    required String name,
    required int days,
    required int priceCents,
  });

  /// Owner-only: partial update. Deactivate = `updatePackage(active: false)`
  /// — packages are never deleted (bill lines reference the purchase).
  Future<Package> updatePackage(
    String packageId, {
    String? name,
    int? days,
    int? priceCents,
    bool? active,
  });

  /// Buys a package (RPC `buy_package`): raises the caller's cap for the
  /// current period and posts the price as a charge on their bill. Only a
  /// member whose over-consumption policy is 'package' may buy. Returns the
  /// quota-extension id.
  Future<String> buyPackage(String workspaceId, String packageId);

  /// Starts an online payment for [amountCents] of the member's bill via
  /// the server-side payment function (`create-payment-order`, see
  /// docs/design/payments-integration.md). Returns the payment provider's
  /// approval URL to open, or null when online payments are not configured
  /// on this deployment (the function replies `not_configured`). Throws on
  /// transport/provider errors.
  Future<Uri?> createPaymentOrder({
    required String workspaceId,
    required String memberId,
    required int amountCents,
    required String period,
  });
}
