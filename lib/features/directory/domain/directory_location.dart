// SPDX-License-Identifier: AGPL-3.0-or-later
/// An approximate address search result never overwrites published coordinates.
class DirectoryLocation {
  const DirectoryLocation(this.latitude, this.longitude, {this.label = ''});
  final double latitude, longitude;
  final String label;
  static DirectoryLocation? parse(
    Object? latitude,
    Object? longitude, {
    String label = '',
  }) {
    final lat = double.tryParse('$latitude');
    final lon = double.tryParse('$longitude');
    if (lat == null ||
        lon == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180) {
      return null;
    }
    return DirectoryLocation(lat, lon, label: label);
  }
}

abstract interface class DirectoryGeocoder {
  Future<DirectoryLocation?> locate(String address);
}
