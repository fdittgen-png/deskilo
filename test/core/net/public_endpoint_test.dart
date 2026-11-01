// SPDX-License-Identifier: AGPL-3.0-or-later
// #2488 -- a configurable public endpoint is parsed, not prefix-matched:
// plain text, credentials, fragments, private networks and (for the
// geocoder) a query are refused; localhost only under the local policy.
import 'package:deskilo/core/net/public_endpoint.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const geo = PublicEndpointKind.geocoder;
  const tiles = PublicEndpointKind.tileTemplate;

  PublicEndpointProblem? g(String v, {bool local = false}) =>
      publicEndpointProblem(v, geo, allowLocal: local);
  PublicEndpointProblem? t(String v, {bool local = false}) =>
      publicEndpointProblem(v, tiles, allowLocal: local);

  test('the shipped defaults and ordinary self-hosted services are accepted', () {
    expect(g('https://photon.komoot.io/api/'), isNull);
    expect(g('https://geo.example.org:8443/api'), isNull);
    expect(t('https://tile.openstreetmap.org/{z}/{x}/{y}.png'), isNull);
    expect(t('https://{s}.tiles.example.org/{z}/{x}/{y}@2x.png'), isNull);
    expect(t('https://tiles.example.org/{z}/{x}/{y}.png?style=light'), isNull);
  });

  test('a plain-text, credentialed, fragmented or malformed address is refused', () {
    expect(g('http://photon.komoot.io/api/'), PublicEndpointProblem.notHttps);
    expect(g('ftp://photon.komoot.io/api/'), PublicEndpointProblem.notHttps);
    expect(g('https://user:secret@geo.example.org/api'),
        PublicEndpointProblem.hasCredentials);
    expect(g('https://token@geo.example.org/api'),
        PublicEndpointProblem.hasCredentials);
    expect(g('https://geo.example.org/api#x'), PublicEndpointProblem.hasFragment);
    expect(g('https://geo.example.org/api?key=abc'), PublicEndpointProblem.hasQuery);
    expect(g('geo.example.org/api'), PublicEndpointProblem.notAUrl);
    expect(g(' https://geo.example.org/api'), PublicEndpointProblem.notAUrl);
    expect(g(''), PublicEndpointProblem.notAUrl);
  });

  test('a tile template needs all three placeholders', () {
    expect(t('https://tile.openstreetmap.org/{z}/{x}.png'),
        PublicEndpointProblem.missingTilePlaceholders);
    expect(t('https://tile.openstreetmap.org/tile.png'),
        PublicEndpointProblem.missingTilePlaceholders);
  });

  test('the device network and private ranges are refused', () {
    for (final host in [
      '10.0.0.5',
      '172.16.1.1',
      '172.31.255.255',
      '192.168.1.10',
      '169.254.169.254',
      '100.64.0.1',
      '0.0.0.0',
      '[fd00::1]',
      '[fe80::1]',
      '[::ffff:10.0.0.1]',
      'printer.local',
      'metadata.internal',
    ]) {
      expect(g('https://$host/api'), PublicEndpointProblem.privateHost, reason: host);
    }
    expect(g('https://172.32.0.1/api'), isNull, reason: 'public range');
  });

  test('localhost only under the explicit local policy, never in public input', () {
    for (final host in ['localhost', '127.0.0.1', '[::1]', 'api.localhost']) {
      expect(g('https://$host:2322/api'), PublicEndpointProblem.privateHost,
          reason: host);
      expect(g('https://$host:2322/api', local: true), isNull, reason: host);
    }
    // The local stack may run plain http, but only on the device itself.
    expect(g('http://localhost:2322/api', local: true), isNull);
    expect(g('http://localhost:2322/api'), PublicEndpointProblem.notHttps);
    expect(g('http://10.0.0.5/api', local: true), PublicEndpointProblem.notHttps);
    expect(localEndpointsAllowed, isFalse, reason: 'off unless the build says so');
  });

  group('the settings editor checks an endpoint unit the same way', () {
    SettingDefinition def(String unit) => SettingDefinition(
          key: 'directory.geocoder_url',
          type: SettingType.text,
          defaultValue: 'https://photon.komoot.io/api/',
          max: 512,
          unit: unit,
          group: 'region',
          scopes: {SettingScope.platform},
        );

    test('url and url template units refuse what the reader would ignore', () {
      expect(def('url').check('https://geo.example.org/api'), isNull);
      expect(def('url').check(''), isNull, reason: 'empty = not managed here');
      expect(def('url').check('https://u:p@geo.example.org/api'),
          SettingProblem.notAnEndpoint);
      expect(def('url template').check('https://t.example.org/{z}/{x}.png'),
          SettingProblem.notAnEndpoint);
      expect(def('url template').check('https://t.example.org/{z}/{x}/{y}.png'),
          isNull);
    });

    test('plain text is not checked as an endpoint', () {
      expect(def('').check('http://anything'), isNull);
    });
  });
}
