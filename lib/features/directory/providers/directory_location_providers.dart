// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/trace/trace_logger.dart';
import '../data/photon_directory_geocoder.dart';
import '../domain/directory_location.dart';
part 'directory_location_providers.g.dart';

@Riverpod(keepAlive: true)
DirectoryGeocoder directoryGeocoder(Ref ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return PhotonDirectoryGeocoder(client);
}

Duration? _noRetry(int count, Object error) => null;

@Riverpod(retry: _noRetry)
Future<DirectoryLocation?> directoryAddressLocation(
  Ref ref,
  String address,
) async {
  try {
    return await ref.watch(directoryGeocoderProvider).locate(address);
  } catch (e, st) {
    TraceLogger.instance.error(
      'directory',
      'public address lookup failed',
      error: e.runtimeType,
      stackTrace: st,
    );
    rethrow;
  }
}
