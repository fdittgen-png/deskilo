// SPDX-License-Identifier: AGPL-3.0-or-later
// #2488 -- the map's tile server and the address lookup follow the
// platform settings: a stored value wins, then the build's own, then the
// documented default; an invalid stored value is never used; the geocoder
// takes the registry URL, sends no credentials and follows no redirect.
import 'dart:convert';

import 'package:deskilo/core/settings/active_settings.dart';
import 'package:deskilo/core/settings/setting_defaults.g.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/features/directory/data/photon_directory_geocoder.dart';
import 'package:deskilo/features/directory/domain/discovery_view.dart';
import 'package:deskilo/features/directory/providers/discovery_view_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _tilesDefault = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _geoDefault = 'https://photon.komoot.io/api/';

SettingDefinition _def(String key, String unit, String fallback) =>
    SettingDefinition(
      key: key,
      type: SettingType.text,
      defaultValue: fallback,
      max: 512,
      unit: unit,
      group: 'region',
      scopes: {SettingScope.platform},
    );

/// The platform settings with [tiles]/[geocoder] stored by the operator
/// (origin platform), or only the registry defaults when null.
SettingsSet _settings({String? tiles, String? geocoder}) => SettingsSet(
      {
        MapServices.tilesKey: _def(MapServices.tilesKey, 'url template', _tilesDefault),
        MapServices.geocoderKey: _def(MapServices.geocoderKey, 'url', _geoDefault),
      },
      {
        MapServices.tilesKey: tiles ?? _tilesDefault,
        MapServices.geocoderKey: geocoder ?? _geoDefault,
      },
      origins: {
        MapServices.tilesKey:
            tiles == null ? SettingOrigin.registryDefault : SettingOrigin.platform,
        MapServices.geocoderKey:
            geocoder == null ? SettingOrigin.registryDefault : SettingOrigin.platform,
      },
    );

http.Response _point() => http.Response(
      jsonEncode({
        'features': [
          {
            'geometry': {'type': 'Point', 'coordinates': [3.42, 43.46]},
            'properties': {'name': 'Avenue'},
          },
        ],
      }),
      200,
    );

void main() {
  test('the registry defaults are the documented public services', () {
    expect(SettingDefaults.directoryTileUrlTemplate, _tilesDefault);
    expect(SettingDefaults.directoryGeocoderUrl, _geoDefault);
  });

  group('precedence', () {
    test('nothing stored and no build value: the documented default', () {
      final s = MapServices.resolve(_settings());
      expect(s.tiles, _tilesDefault);
      expect(s.geocoder, _geoDefault);
      expect(s.tilesSource, MapServiceSource.bundled);
      expect(s.geocoderSource, MapServiceSource.bundled);
    });

    test('no settings at all (signed out, server away): the bundle fallback', () {
      final s = MapServices.resolve(null);
      expect(s.tiles, _tilesDefault);
      expect(s.geocoder, _geoDefault);
      expect(s.geocoderSource, MapServiceSource.bundled);
    });

    test('a build value beats the default, but not a stored platform value', () {
      const build = 'https://build.example.org/api';
      final unmanaged =
          MapServices.resolve(_settings(), buildGeocoder: build);
      expect(unmanaged.geocoder, build);
      expect(unmanaged.geocoderSource, MapServiceSource.build);

      const managed = 'https://geo.operator.example/api';
      final s = MapServices.resolve(_settings(geocoder: managed), buildGeocoder: build);
      expect(s.geocoder, managed);
      expect(s.geocoderSource, MapServiceSource.managed);
      expect(s.tilesSource, MapServiceSource.bundled, reason: 'each endpoint on its own');
    });

    test('an invalid stored value is never used: the next source stands in', () {
      for (final bad in [
        'http://geo.operator.example/api',
        'https://user:pw@geo.operator.example/api',
        'https://192.168.0.2/api',
        'https://localhost/api',
        '',
      ]) {
        final s = MapServices.resolve(_settings(geocoder: bad));
        expect(s.geocoder, _geoDefault, reason: bad);
        expect(s.geocoderSource, MapServiceSource.bundled, reason: bad);
      }
      final tiles = MapServices.resolve(
          _settings(tiles: 'https://t.example.org/{z}/{x}.png'));
      expect(tiles.tiles, _tilesDefault);
    });

    test('an invalid build value is ignored too', () {
      final s = MapServices.resolve(_settings(),
          buildTiles: 'https://t.example.org/static.png',
          buildGeocoder: 'https://10.1.1.1/api');
      expect(s.tiles, _tilesDefault);
      expect(s.geocoder, _geoDefault);
    });

    test('a new stored tile host is a new provider identity (asked again)', () {
      final before = MapServices.resolve(_settings());
      final after = MapServices.resolve(
          _settings(tiles: 'https://tiles.operator.example/{z}/{x}/{y}.png'));
      expect(after.identity, isNot(before.identity));
      expect(const DiscoveryViewPreference(map: true)
          .accepting(before.identity)
          .accepts(after.identity), isFalse);
    });
  });

  group('the address lookup', () {
    test('a URL changed in the settings is used by the next lookup', () async {
      final container = ProviderContainer(overrides: [
        platformSettingsProvider.overrideWith(
            (ref) async => _settings(geocoder: 'https://geo.operator.example/v1/')),
      ]);
      addTearDown(container.dispose);
      await container.read(platformSettingsProvider.future);
      final services = container.read(mapServicesProvider);
      expect(services.geocoder, 'https://geo.operator.example/v1/');

      final seen = <Uri>[];
      final geocoder = PhotonDirectoryGeocoder(
        MockClient((r) async {
          seen.add(r.url);
          return _point();
        }),
        endpoint: Uri.parse(services.geocoder),
      );
      expect((await geocoder.locate('Avenue'))?.latitude, 43.46);
      expect(seen.single.host, 'geo.operator.example');
      expect(seen.single.path, '/v1/');
      expect(seen.single.queryParameters, {'q': 'Avenue', 'limit': '1'});
    });

    test('with no platform settings the provider keeps the build choice', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(mapServicesProvider).geocoder,
          MapServices.configured.geocoder);
    });

    test('carries no credentials and refuses to follow a redirect', () async {
      http.BaseRequest? sent;
      final geocoder = PhotonDirectoryGeocoder(
        MockClient((r) async {
          sent = r;
          return http.Response('', 302,
              headers: {'location': 'https://10.0.0.1/steal'});
        }),
        endpoint: Uri.parse('https://geo.operator.example/api'),
      );
      await expectLater(geocoder.locate('Avenue'), throwsA(isA<StateError>()));
      expect(sent!.followRedirects, isFalse);
      expect(sent!.headers.keys.map((k) => k.toLowerCase()),
          isNot(anyOf(contains('authorization'), contains('apikey'), contains('cookie'))));
    });
  });
}
