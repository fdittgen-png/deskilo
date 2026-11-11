// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3684 -- where a published address was found, remembered on this
// device so the next visit to the map asks the public geocoder nothing
// again. Only answers that placed a pin are kept: a refusal or an address
// that was not found is asked again next time. Nothing here reaches a
// server, and nothing here is about the person: the keys are public
// addresses of published pages.
import 'directory_location.dart';

/// The key an address is remembered under: case, surrounding space and
/// runs of whitespace do not make another address.
String directoryAddressKey(String address) =>
    address.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// The device-local memory of found addresses, oldest first.
abstract interface class DirectoryLocationMemory {
  Future<Map<String, DirectoryLocation>> read();
  Future<void> write(Map<String, DirectoryLocation> locations);
}

/// In-memory [DirectoryLocationMemory]: what tests and a Demo session hold.
class InMemoryDirectoryLocationMemory implements DirectoryLocationMemory {
  final Map<String, DirectoryLocation> saved = {};

  @override
  Future<Map<String, DirectoryLocation>> read() async => {...saved};

  @override
  Future<void> write(Map<String, DirectoryLocation> locations) async {
    saved
      ..clear()
      ..addAll(locations);
  }
}
