// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

import '../domain/directory_location.dart';

/// Only user-requested public addresses; no autocomplete or bulk geocoding.
/// Photon permits moderate use; deployments can supply their own endpoint.
class PhotonDirectoryGeocoder implements DirectoryGeocoder {
  PhotonDirectoryGeocoder(this.client, {Uri? endpoint})
    : endpoint =
          endpoint ??
          Uri.parse(
            const String.fromEnvironment(
              'DIRECTORY_GEOCODER_URL',
              defaultValue: 'https://photon.komoot.io/api/',
            ),
          );
  final http.Client client;
  final Uri endpoint;
  static const cacheLimit = 128;
  static const requestTimeout = Duration(seconds: 10);
  final _cache = <String, Future<DirectoryLocation?>>{};

  @override
  Future<DirectoryLocation?> locate(String address) {
    final query = address.trim();
    if (query.isEmpty) return Future.value();
    if (_cache.containsKey(query)) return _cache[query]!;
    if (_cache.length >= cacheLimit) {
      unawaited(_cache.remove(_cache.keys.first));
    }
    final result = _lookup(query);
    _cache[query] = result;
    return result;
  }

  Future<DirectoryLocation?> _lookup(String query) async {
    try {
      final response = await client
          .get(endpoint.replace(queryParameters: {'q': query, 'limit': '1'}))
          .timeout(requestTimeout);
      if (response.statusCode != 200) {
        throw StateError('Address lookup unavailable');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final features = body['features'] as List<dynamic>;
      if (features.isEmpty) return null;
      final feature = features.first as Map<String, dynamic>;
      final geometry = feature['geometry'] as Map<String, dynamic>;
      if (geometry['type'] != 'Point') return null;
      final coordinates = geometry['coordinates'] as List<dynamic>;
      if (coordinates.length < 2) return null;
      final properties = feature['properties'] as Map<String, dynamic>;
      final label =
          ['name', 'housenumber', 'street', 'postcode', 'city', 'country']
              .map((key) => properties[key])
              .whereType<String>()
              .where((value) => value.isNotEmpty)
              .toSet()
              .join(', ');
      return DirectoryLocation.parse(
        coordinates[1],
        coordinates[0],
        label: label,
      );
    } catch (e, st) {
      unawaited(_cache.remove(query));
      // trace-exempt: the provider logs the failure without the public address.
      Error.throwWithStackTrace(e, st);
    }
  }
}
