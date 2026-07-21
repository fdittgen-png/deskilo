// SPDX-License-Identifier: 0BSD

/// The amenity-key → English display-name mapping migration
/// 0022_accessories.sql used to seed each workspace's accessory catalog
/// from the legacy hard-coded seat amenity keys (kSeatAmenities).
///
/// Pinned by test against the migration file: if either side changes,
/// the pinning test fails. Unknown keys keep the raw key as the name.
abstract final class AccessorySeed {
  static const Map<String, String> amenityDisplayNames = {
    'monitor': 'Monitor',
    'standing_desk': 'Standing desk',
    'window': 'Window seat',
    'dock': 'Docking station',
    'ergonomic': 'Ergonomic chair',
  };

  /// Catalog name a legacy amenity key was seeded under.
  static String nameForKey(String key) => amenityDisplayNames[key] ?? key;
}
