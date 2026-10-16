// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/vat/supply_class.dart';
import 'fee_band.dart';
import 'package.dart';
import 'price_negotiation.dart';
import 'service_item.dart';
import 'subscription_levels.dart';

/// #2591 C4 — what the space sells and at which price: fee bands,
/// subscription levels, the service catalogue, packages and a member's
/// negotiated deal. The PURCHASE price a member pays for a package or a
/// service charge stays a purchase concern (#2573); the sales price lives
/// here and the two are never conflated.
abstract interface class CommercialTermsRepository {
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
    String? vatRateId,
    SupplyClass supplyClass = SupplyClass.property,
  });

  /// Owner-only: partial update of name, price, VAT rate and active flag.
  /// Deactivate = `updateService(active: false)` — services are never
  /// deleted (bill lines reference them).
  Future<ServiceItem> updateService(
    String serviceId, {
    String? name,
    int? priceCents,
    bool? active,
    String? vatRateId,
    SupplyClass? supplyClass,
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
    String? vatRateId,
  });

  /// Owner-only: partial update. Deactivate = `updatePackage(active: false)`
  /// — packages are never deleted (bill lines reference the purchase).
  Future<Package> updatePackage(
    String packageId, {
    String? name,
    int? days,
    int? priceCents,
    bool? active,
    String? vatRateId,
  });

  /// #739 — a member's deal: default, active, pending. Owner, finance
  /// admins and the member; a read by anyone else than the member is
  /// logged server-side.
  Future<PriceNegotiation> fetchPriceNegotiation(String memberId);

  /// #739 — propose a deal for [memberId]; lands pending for validation.
  Future<void> proposePriceNegotiation({
    required String memberId,
    int? feeCents,
    int? overageFeeCents,
    double? discountPercent,
    String note = '',
    DateTime? validFrom,
    int? subscriptionPct,
    Map<String, Map<String, int>> items = const {},
  });
}
