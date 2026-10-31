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
import '../../../core/net/public_endpoint.dart';
import '../../../core/settings/setting_defaults.g.dart';
import '../../../core/settings/settings.dart';

/// #2488 -- where a map endpoint came from.
enum MapServiceSource {
  /// The platform's operator stored it in the settings.
  managed,

  /// This build was given it.
  build,

  /// The documented default the app ships.
  bundled,
}

/// The third parties the map reaches once it is open: the tile server
/// that draws it, and the geocoder that places a published address
/// without coordinates.
class MapServices {
  const MapServices({
    required this.tiles,
    required this.geocoder,
    this.tilesSource = MapServiceSource.bundled,
    this.geocoderSource = MapServiceSource.bundled,
  });

  /// The build's own choice: what `--dart-define` names, else the
  /// documented default. Used where no settings are read (and in tests).
  static final configured = resolve(null);

  /// #2488 -- the two endpoints in order of precedence: a value the
  /// platform's operator stored (`directory.tile_url_template`,
  /// `directory.geocoder_url`) wins; absent that, a value this build was
  /// given (`MAP_TILE_URL`, `DIRECTORY_GEOCODER_URL`); else the registry's
  /// documented default. A stored value that is not a valid public endpoint
  /// is ignored, never used: the next source stands in. A build constant is
  /// never written back to the shared registry.
  static MapServices resolve(
    SettingsSet? settings, {
    String buildTiles = const String.fromEnvironment('MAP_TILE_URL'),
    String buildGeocoder = const String.fromEnvironment('DIRECTORY_GEOCODER_URL'),
    bool allowLocal = localEndpointsAllowed,
  }) {
    final tiles = _pick(settings, tilesKey, buildTiles,
        SettingDefaults.directoryTileUrlTemplate, PublicEndpointKind.tileTemplate, allowLocal);
    final geocoder = _pick(settings, geocoderKey, buildGeocoder,
        SettingDefaults.directoryGeocoderUrl, PublicEndpointKind.geocoder, allowLocal);
    return MapServices(
      tiles: tiles.$1,
      tilesSource: tiles.$2,
      geocoder: geocoder.$1,
      geocoderSource: geocoder.$2,
    );
  }

  static const tilesKey = 'directory.tile_url_template';
  static const geocoderKey = 'directory.geocoder_url';

  static (String, MapServiceSource) _pick(
    SettingsSet? settings,
    String key,
    String build,
    String documented,
    PublicEndpointKind kind,
    bool allowLocal,
  ) {
    bool valid(String v) =>
        v.isNotEmpty && publicEndpointProblem(v, kind, allowLocal: allowLocal) == null;
    if (settings != null &&
        settings.definitions.containsKey(key) &&
        settings.originOf(key) == SettingOrigin.platform) {
      final managed = settings.read<String>(key);
      if (valid(managed)) return (managed, MapServiceSource.managed);
    }
    if (valid(build)) return (build, MapServiceSource.build);
    final registryDefault = settings != null && settings.definitions.containsKey(key)
        ? settings.definitions[key]!.defaultValue
        : documented;
    return (
      registryDefault is String && valid(registryDefault) ? registryDefault : documented,
      MapServiceSource.bundled,
    );
  }

  /// Where [tiles] and [geocoder] came from, shown to the person.
  final MapServiceSource tilesSource, geocoderSource;

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
