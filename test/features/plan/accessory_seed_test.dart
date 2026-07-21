// SPDX-License-Identifier: 0BSD
import 'dart:io';

import 'package:deskilo/features/plan/domain/accessory_seed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccessorySeed (#166)', () {
    test('pins the amenity-key → display-name mapping', () {
      // The exact mapping migration 0022 seeded catalogs with — the keys
      // are kSeatAmenities, the names the editor's English fallbacks.
      // Changing either side is a data-compatibility decision, not a rename.
      expect(AccessorySeed.amenityDisplayNames, const {
        'monitor': 'Monitor',
        'standing_desk': 'Standing desk',
        'window': 'Window seat',
        'dock': 'Docking station',
        'ergonomic': 'Ergonomic chair',
      });
    });

    test('unknown keys keep the raw key as the name', () {
      expect(AccessorySeed.nameForKey('whiteboard'), 'whiteboard');
      expect(AccessorySeed.nameForKey('monitor'), 'Monitor');
    });

    test('migration 0022 seeds with the same mapping', () {
      final sql = File('supabase/migrations/0022_accessories.sql')
          .readAsStringSync();
      for (final entry in AccessorySeed.amenityDisplayNames.entries) {
        final arm = "when '${entry.key}' then '${entry.value}'";
        // Once in the catalog seed, once in the join-row backfill.
        expect(
          arm.allMatches(sql).length,
          2,
          reason: 'expected "$arm" in both CASE blocks of 0022_accessories.sql',
        );
      }
    });
  });
}
