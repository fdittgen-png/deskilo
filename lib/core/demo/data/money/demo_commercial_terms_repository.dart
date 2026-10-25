// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/core/demo/data/fixture_clock.dart';
import 'package:deskilo/core/vat/supply_class.dart';
import 'package:deskilo/features/money/domain/commercial_terms_repository.dart';
import 'package:deskilo/features/money/domain/fee_band.dart';
import 'package:deskilo/features/money/domain/package.dart';
import 'package:deskilo/features/money/domain/price_negotiation.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:deskilo/features/money/domain/subscription_levels.dart';

import '../money_repository.dart';

/// #2591 — the demo's fee bands, levels, services, packages and negotiations,
/// answered from one space's in-memory money store ([FakeMoneyRepository]);
/// every other port of that space reads and writes the same store.
class DemoCommercialTerms implements CommercialTermsRepository {
  DemoCommercialTerms(this._m);

  final FakeMoneyRepository _m;

  @override
  Future<List<FeeBand>> fetchFeeBands(String workspaceId) async =>
      List.of(_m.feeBands)..sort((a, b) => a.fromPct.compareTo(b.fromPct));

  @override
  Future<void> replaceFeeBands(String workspaceId, List<FeeBand> bands) async {
    // Same contiguity contract as the replace_fee_bands RPC.
    var expected = 0;
    for (final band
        in bands.toList()..sort((a, b) => a.fromPct.compareTo(b.fromPct))) {
      if (band.fromPct != expected) throw StateError('bands not contiguous');
      expected = band.toPct;
    }
    if (expected != 100) throw StateError('bands must cover up to 100');
    _m.feeBands
      ..clear()
      ..addAll([
        for (final (i, band) in bands.indexed)
          band.copyWith(id: 'band-${i + 1}', workspaceId: workspaceId),
      ]);
  }

  @override
  Future<SubscriptionLevels> fetchSubscriptionLevels(
    String workspaceId,
  ) async => _m.subscriptionLevels;

  @override
  Future<void> setSubscriptionLevels(
    String workspaceId,
    SubscriptionLevels levels,
  ) async {
    _m.subscriptionLevels = levels;
  }

  @override
  Future<List<ServiceItem>> fetchServices(
    String workspaceId, {
    bool includeInactive = false,
  }) async =>
      _m.services.where((s) => includeInactive || s.active).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  @override
  Future<ServiceItem> createService(
    String workspaceId, {
    required String name,
    required int priceCents,
    String? vatRateId,
    SupplyClass supplyClass = SupplyClass.property,
  }) async {
    final service = ServiceItem(
      supplyClass: supplyClass,
      id: 'service-${_m.services.length + 1}',
      workspaceId: workspaceId,
      name: name,
      priceCents: priceCents,
      active: true,
      vatRateId: vatRateId ?? '',
    );
    _m.services.add(service);
    return service;
  }

  @override
  Future<ServiceItem> updateService(
    String serviceId, {
    String? name,
    int? priceCents,
    bool? active,
    String? vatRateId,
    SupplyClass? supplyClass,
  }) async {
    final i = _m.services.indexWhere((s) => s.id == serviceId);
    if (i < 0) throw StateError('unknown service');
    final updated = _m.services[i].copyWith(
      supplyClass: supplyClass ?? _m.services[i].supplyClass,
      name: name ?? _m.services[i].name,
      priceCents: priceCents ?? _m.services[i].priceCents,
      active: active ?? _m.services[i].active,
      vatRateId: vatRateId ?? _m.services[i].vatRateId,
    );
    _m.services[i] = updated;
    return updated;
  }

  @override
  Future<List<Package>> fetchPackages(
    String workspaceId, {
    bool includeInactive = false,
  }) async =>
      _m.packages.where((p) => includeInactive || p.active).toList()
        ..sort((a, b) => a.days.compareTo(b.days));

  @override
  Future<Package> createPackage(
    String workspaceId, {
    required String name,
    required int days,
    required int priceCents,
    String? vatRateId,
  }) async {
    final package = Package(
      id: 'package-${_m.packages.length + 1}',
      workspaceId: workspaceId,
      name: name,
      days: days,
      priceCents: priceCents,
      vatRateId: vatRateId ?? '',
    );
    _m.packages.add(package);
    return package;
  }

  @override
  Future<Package> updatePackage(
    String packageId, {
    String? name,
    int? days,
    int? priceCents,
    bool? active,
    String? vatRateId,
  }) async {
    final i = _m.packages.indexWhere((p) => p.id == packageId);
    if (i < 0) throw StateError('unknown package');
    final updated = _m.packages[i].copyWith(
      name: name ?? _m.packages[i].name,
      days: days ?? _m.packages[i].days,
      priceCents: priceCents ?? _m.packages[i].priceCents,
      active: active ?? _m.packages[i].active,
      vatRateId: vatRateId ?? _m.packages[i].vatRateId,
    );
    _m.packages[i] = updated;
    return updated;
  }

  @override
  Future<PriceNegotiation> fetchPriceNegotiation(String memberId) async {
    _m.negotiationReads++;
    return _m.negotiations[memberId] ??
        const PriceNegotiation(
          defaultFeeCents: 25000,
          defaultOverageFeeCents: 1200,
        );
  }

  @override
  Future<void> proposePriceNegotiation({
    required String memberId,
    int? feeCents,
    int? overageFeeCents,
    double? discountPercent,
    String note = '',
    DateTime? validFrom,
    int? subscriptionPct,
    Map<String, Map<String, int>> items = const {},
  }) async {
    _m.proposedNegotiations.add((
      memberId: memberId,
      feeCents: feeCents,
      overageFeeCents: overageFeeCents,
      discountPercent: discountPercent,
      note: note,
      subscriptionPct: subscriptionPct,
      items: items,
    ));
    _m.negotiations[memberId] =
        (_m.negotiations[memberId] ??
                const PriceNegotiation(
                  defaultFeeCents: 25000,
                  defaultOverageFeeCents: 1200,
                ))
            .copyWith(
              pending: NegotiationDeal(
                feeCents: feeCents,
                overageFeeCents: overageFeeCents,
                discountPercent: discountPercent,
                note: note,
                validFrom: validFrom ?? kTestNow,
                status: 'pending',
                subscriptionPct: subscriptionPct,
                items: items,
              ),
            );
  }
}
