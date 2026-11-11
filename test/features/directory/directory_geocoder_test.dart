// SPDX-License-Identifier: AGPL-3.0-or-later
// Address lookup preserves lon/lat order, validates points, caches shared
// requests and permits retry after failure without mutating public documents.
import 'dart:convert';

import 'package:deskilo/features/directory/data/photon_directory_geocoder.dart';
import 'package:deskilo/features/directory/data/prefs_directory_location_memory.dart';
import 'package:deskilo/features/directory/domain/directory_location.dart';
import 'package:deskilo/features/directory/domain/directory_location_memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('point validation rejects non-finite and out-of-range coordinates', () {
    for (final latitude in ['NaN', 'Infinity', '91', '']) {
      expect(DirectoryLocation.parse(latitude, '3'), isNull);
    }
    expect(DirectoryLocation.parse(43, 181), isNull);
    expect(DirectoryLocation.parse(0, 0)?.latitude, 0);
  });
  test(
    'public address lookup caches and decodes GeoJSON longitude first',
    () async {
      var requests = 0;
      final geocoder = PhotonDirectoryGeocoder(
        MockClient((request) async {
          requests++;
          expect(request.url.queryParameters, {
            'q': 'Avenue, Pézenas',
            'limit': '1',
          });
          return http.Response(
            jsonEncode({
              'features': [
                {
                  'geometry': {
                    'type': 'Point',
                    'coordinates': [3.42, 43.46],
                  },
                  'properties': {'name': 'Avenue', 'city': 'Pézenas'},
                },
              ],
            }),
            200,
          );
        }),
      );
      final results = await Future.wait([
        geocoder.locate('Avenue, Pézenas'),
        geocoder.locate(' Avenue, Pézenas '),
      ]);
      expect(requests, 1);
      expect(results.first?.latitude, 43.46);
      expect(results.first?.longitude, 3.42);
      expect(results.first?.label, 'Avenue, Pézenas');
    },
  );
  test(
    'empty responses stay unavailable and failed requests can retry',
    () async {
      var requests = 0;
      final geocoder = PhotonDirectoryGeocoder(
        MockClient((_) async {
          requests++;
          return requests == 1
              ? http.Response('', 503)
              : http.Response('{"features":[]}', 200);
        }),
      );
      expect(await geocoder.locate(' '), isNull);
      expect(requests, 0);
      await expectLater(geocoder.locate('Public address'), throwsStateError);
      expect(await geocoder.locate('Public address'), isNull);
      expect(requests, 2);
    },
  );
  test('#3684: the native apps name the app in the User-Agent; the web '
      'leaves it to the browser', () async {
    final agents = <String?>[];
    http.Client client() => MockClient((request) async {
      agents.add(request.headers['User-Agent']);
      return http.Response('{"features":[]}', 200);
    });
    await PhotonDirectoryGeocoder(client(), identified: true).locate('A');
    await PhotonDirectoryGeocoder(client(), identified: false).locate('A');
    expect(agents, ['DesKilo (org.deskilo.app)', null]);
  });
  test('#3684: found places are kept on the device by their normalised '
      'address, and an unreadable entry reads as none', () async {
    SharedPreferences.setMockInitialValues({});
    const memory = PrefsDirectoryLocationMemory();
    expect(await memory.read(), isEmpty);
    await memory.write({
      directoryAddressKey('  Avenue,   Pézenas '): const DirectoryLocation(
        43.46,
        3.42,
        label: 'Avenue, Pézenas',
      ),
    });
    final back = await memory.read();
    expect(back.keys, ['avenue, pézenas']);
    expect(back.values.single.latitude, 43.46);
    expect(back.values.single.label, 'Avenue, Pézenas');

    SharedPreferences.setMockInitialValues({'directory_locations': '[1]'});
    expect(await memory.read(), isEmpty);
  });
}
