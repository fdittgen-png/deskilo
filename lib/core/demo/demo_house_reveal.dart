// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4005 — the visitor adds a house abroad in the Demo: the dormant house
// (Atelier Kraków) appears, owned by the persona, and receives what the server
// carries from the head. The head's services and packages arrive inactive;
// their amounts are 0, because the house's currency is not the head's; no rate
// travels. The head's rate category for each row stays in the birth record as
// a hint. The birth record says its prices are still to be named.
import '../../features/money/domain/service_item.dart';
import '../../features/workspace/domain/organisation.dart';
import 'demo_fixture.dart';
import 'demo_space_ids.dart';

/// Reveals the Demo's house and answers its birth record. A session reveals
/// it once: asked again, it answers the same record.
/// The house takes the [name] the visitor gave it.
Future<HouseBirth> revealDemoHouse(DemoFixture f, {String? name}) async {
  final head = f.money.commercialTerms;
  final house = f.house.money.commercialTerms;
  final headServices = await head.fetchServices(
    demoFirstSpaceId,
    includeInactive: true,
  );
  final headPackages = await head.fetchPackages(
    demoFirstSpaceId,
    includeInactive: true,
  );
  if (!f.houseRevealed) {
    f.revealHouse();
    final rows = f.workspaces.workspaces;
    final at = rows.indexWhere((w) => w.id == demoHouseSpaceId);
    if (at >= 0 && name != null && name.trim().isNotEmpty) {
      rows[at] = rows[at].copyWith(name: name.trim());
    }
    for (final s in headServices) {
      final made = await house.createService(
        demoHouseSpaceId,
        name: s.name,
        priceCents: 0,
      );
      await house.updateService(made.id, const ServiceChange(active: false));
    }
    for (final p in headPackages) {
      final made = await house.createPackage(
        demoHouseSpaceId,
        name: p.name,
        days: p.days,
        priceCents: 0,
      );
      await house.updatePackage(made.id, active: false);
    }
  }
  final rates = await f.money.taxReporting.fetchVatRates(demoFirstSpaceId);
  String? category(String rateId) =>
      (rateId.isEmpty
              ? rates.where((r) => r.isDefault).firstOrNull
              : rates.where((r) => r.id == rateId).firstOrNull)
          ?.category;
  return HouseBirth(
    workspaceId: demoHouseSpaceId,
    headWorkspaceId: demoFirstSpaceId,
    plans: 0,
    services: headServices.length,
    packages: headPackages.length,
    validationPolicies: 0,
    features: 0,
    // The head counts in euros, the house in złoty: no amount travels.
    amountsKept: false,
    // The head's other owner, added at birth as co-owner.
    coOwnersAdded: 1,
    pricesPending: true,
    createdAt: f.seededAt,
    rateHints: {
      for (final s in headServices)
        'services:${s.name}': ?category(s.vatRateId),
      for (final p in headPackages)
        'packages:${p.name}': ?category(p.vatRateId),
    },
  );
}
