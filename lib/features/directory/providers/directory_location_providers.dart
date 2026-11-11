// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/trace/trace_logger.dart';
import '../data/directory_lookups.dart';
import '../data/photon_directory_geocoder.dart';
import '../data/prefs_directory_location_memory.dart';
import '../domain/directory_location.dart';
import '../domain/directory_location_memory.dart';
import 'discovery_view_providers.dart';
part 'directory_location_providers.g.dart';

@Riverpod(keepAlive: true)
DirectoryGeocoder directoryGeocoder(Ref ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  // #2488 -- the endpoint the platform settings name (else the build's,
  // else the default); a changed endpoint rebuilds the geocoder and its
  // cache.
  return PhotonDirectoryGeocoder(
    client,
    endpoint: Uri.parse(ref.watch(mapServicesProvider).geocoder),
  );
}

/// #3684 -- the places found on this device, so a second visit asks the
/// geocoder nothing again.
@Riverpod(keepAlive: true)
DirectoryLocationMemory directoryLocationMemory(Ref ref) =>
    const PrefsDirectoryLocationMemory();

/// #3684 -- the one queue every address lookup waits in: one request at a
/// time, paused between them, remembered answers first.
@Riverpod(keepAlive: true)
DirectoryLookups directoryLookups(Ref ref) => DirectoryLookups(
  ref.watch(directoryGeocoderProvider),
  ref.watch(directoryLocationMemoryProvider),
);

Duration? _noRetry(int count, Object error) => null;

@Riverpod(retry: _noRetry)
Future<DirectoryLocation?> directoryAddressLocation(
  Ref ref,
  String address,
) async {
  try {
    return await ref
        .watch(directoryLookupsProvider)
        .locate(address, wanted: () => ref.mounted);
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
