// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4170 -- which places form one site. UNTIL #4293 gives the site its own
// level, a site is the root ancestor of a place (the place with no parent
// above it); #4293 replaces this definition and the server's `stock_site_of`
// together. A transfer inside a site is one step; between sites it is loaded
// and received.
import 'stock_config.dart';

/// The root ancestor of [placeId] among [places], or null when it is unknown.
String? stockSiteOf(String placeId, Iterable<StockPlaceConfig> places) {
  final byId = {for (final p in places) p.id: p};
  var at = byId[placeId];
  final seen = <String>{};
  while (at != null && at.parentId != null && seen.add(at.id)) {
    at = byId[at.parentId];
  }
  return at?.id;
}

/// The places goods can be put on or taken from: real, active, and not the
/// system's own in-transit place.
List<StockPlaceConfig> stockRealPlaces(Iterable<StockPlaceConfig> places) => [
  for (final p in places)
    if (p.active && p.isAddressable) p,
];
