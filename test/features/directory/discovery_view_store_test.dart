// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The discovery view preference on the device, and who the map provider is.
//
// Invariant: the device store keeps one preference per namespace under
// `discovery_view.<namespace>`, round-trips the view and the accepted
// provider, and reads an unreadable entry as no choice (the list, and the
// map asks again). The provider identity is the tile host and the geocoder
// host together, without a template's subdomain placeholder, so changing
// either one is another provider.
import 'package:deskilo/features/directory/data/prefs_discovery_view_store.dart';
import 'package:deskilo/features/directory/domain/discovery_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('one preference per namespace round-trips', () async {
    SharedPreferences.setMockInitialValues({});
    const store = PrefsDiscoveryViewStore();
    await store.write(
      'ns1',
      const DiscoveryViewPreference(map: true, acceptedProvider: 'a b'),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {'discovery_view.ns1'});
    final read = await store.read('ns1');
    expect(read!.map, isTrue);
    expect(read.opensMap('a b'), isTrue);
    expect(read.opensMap('c d'), isFalse);
    expect(await store.read('ns2'), isNull);
  });

  test('an unreadable entry is no choice', () async {
    SharedPreferences.setMockInitialValues({
      'discovery_view.ns1': 'not json',
      'discovery_view.ns2': '[1]',
    });
    const store = PrefsDiscoveryViewStore();
    expect(await store.read('ns1'), isNull);
    expect(await store.read('ns2'), isNull);
  });

  test('the provider is the tile host and the geocoder host', () {
    const services = MapServices(
      tiles: 'https://{s}.tile.example/{z}/{x}/{y}.png',
      geocoder: 'https://geo.example:8443/api/',
    );
    expect(services.tilesHost, 'tile.example');
    expect(services.geocoderHost, 'geo.example');
    expect(services.identity, 'tile.example geo.example');
    expect(
      const MapServices(
        tiles: 'https://tile.example/{z}/{x}/{y}.png',
        geocoder: 'https://other.example/api/',
      ).identity,
      isNot(services.identity),
    );
  });
}
