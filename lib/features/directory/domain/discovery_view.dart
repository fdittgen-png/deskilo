// SPDX-License-Identifier: AGPL-3.0-or-later
//
// How a person looks at discovery on this device, list or map, and which
// map provider they agreed to load tiles from.
//
// The map is drawn from a third party's tiles: opening it sends that
// provider the device's connection (its IP address) and the area shown.
// Nothing reaches the provider before the person has read who it is and
// chosen the map. The choice belongs to that provider: a build that draws
// from another one asks again. The preference is kept on the device under
// the same namespace as saved places, the person at their personal home;
// while nobody is signed in it lives only as long as the screen.
import '../../../core/data/json_reader.dart';

/// The third parties the map reaches once it is open: the tile server
/// that draws it, and the geocoder that places a published address
/// without coordinates.
class MapServices {
  const MapServices({required this.tiles, required this.geocoder});

  /// The deployment's map services: the build may name its own.
  static const configured = MapServices(
    tiles: String.fromEnvironment(
      'MAP_TILE_URL',
      defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    ),
    geocoder: String.fromEnvironment(
      'DIRECTORY_GEOCODER_URL',
      defaultValue: 'https://photon.komoot.io/api/',
    ),
  );

  /// The tile URL template and the geocoder endpoint.
  final String tiles, geocoder;

  static String _host(String url) {
    final host =
        RegExp(r'^[a-z][a-z0-9+.-]*://([^/:?#]+)')
            .firstMatch(url.trim().toLowerCase())
            ?.group(1) ??
        url.trim();
    // A template's subdomain placeholder is not part of who the provider is.
    return host.replaceFirst(RegExp(r'^\{[a-z]+\}\.'), '');
  }

  String get tilesHost => _host(tiles);
  String get geocoderHost => _host(geocoder);

  /// Who the person agrees to: both hosts. Another host on either side is
  /// another provider, asked about afresh.
  String get identity => '$tilesHost $geocoderHost';
}

/// List or map, and the provider identity the map was accepted for.
class DiscoveryViewPreference {
  const DiscoveryViewPreference({this.map = false, this.acceptedProvider});

  factory DiscoveryViewPreference.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'discovery_view');
    final accepted = r.stringOr('accepted_provider');
    return DiscoveryViewPreference(
      map: r.stringOr('view') == 'map',
      acceptedProvider: accepted.isEmpty ? null : accepted,
    );
  }

  /// The last view chosen; the map only counts with an accepted provider.
  final bool map;

  /// The [MapServices.identity] the person agreed to load the map from.
  final String? acceptedProvider;

  Map<String, String> toJson() => {
    'view': map ? 'map' : 'list',
    'accepted_provider': ?acceptedProvider,
  };

  /// Whether the map may load from [provider] without asking first.
  bool accepts(String provider) => acceptedProvider == provider;

  /// Whether discovery opens on the map for [provider]: the map was the
  /// last view and that same provider was accepted.
  bool opensMap(String provider) => map && accepts(provider);

  DiscoveryViewPreference showing({required bool map}) =>
      DiscoveryViewPreference(map: map, acceptedProvider: acceptedProvider);

  DiscoveryViewPreference accepting(String provider) =>
      DiscoveryViewPreference(map: map, acceptedProvider: provider);
}

/// The device-local store of the view preference, one per namespace.
abstract interface class DiscoveryViewStore {
  Future<DiscoveryViewPreference?> read(String namespace);
  Future<void> write(String namespace, DiscoveryViewPreference preference);
}

/// In-memory [DiscoveryViewStore]: what tests and a Demo session hold.
/// [byNamespace] is readable so a test can prove under which key a
/// preference was written.
class InMemoryDiscoveryViewStore implements DiscoveryViewStore {
  final Map<String, DiscoveryViewPreference> byNamespace = {};

  @override
  Future<DiscoveryViewPreference?> read(String namespace) async =>
      byNamespace[namespace];

  @override
  Future<void> write(
    String namespace,
    DiscoveryViewPreference preference,
  ) async => byNamespace[namespace] = preference;
}
