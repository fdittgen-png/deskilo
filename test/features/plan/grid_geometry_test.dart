// SPDX-License-Identifier: MIT
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SeatFootprint pinning (product brief)', () {
    test('a bookable slot is 6 squares long and 4 squares deep', () {
      expect(SeatFootprint.length, 6);
      expect(SeatFootprint.depth, 4);
    });
  });

  group('GridRect', () {
    const a = GridRect(x: 0, y: 0, w: 4, h: 4);

    test('overlaps detects intersection and rejects edge-touching', () {
      expect(a.overlaps(const GridRect(x: 3, y: 3, w: 4, h: 4)), isTrue);
      expect(a.overlaps(const GridRect(x: 4, y: 0, w: 4, h: 4)), isFalse);
      expect(a.overlaps(const GridRect(x: 0, y: 4, w: 4, h: 4)), isFalse);
      expect(a.overlaps(const GridRect(x: 10, y: 10, w: 1, h: 1)), isFalse);
    });

    test('containsRect requires full containment', () {
      const big = GridRect(x: 0, y: 0, w: 10, h: 10);
      expect(big.containsRect(const GridRect(x: 2, y: 2, w: 6, h: 4)), isTrue);
      expect(big.containsRect(const GridRect(x: 6, y: 8, w: 6, h: 4)), isFalse);
      expect(big.containsRect(big), isTrue);
    });

    test('containsCell is inclusive of origin, exclusive of far edge', () {
      expect(a.containsCell(0, 0), isTrue);
      expect(a.containsCell(3, 3), isTrue);
      expect(a.containsCell(4, 0), isFalse);
    });
  });

  group('Seat.footprint by orientation', () {
    Seat seat(SeatOrientation o) => Seat(
          id: 's',
          workspaceId: 'w',
          deskId: 'd',
          name: '',
          x: 10,
          y: 20,
          orientation: o,
          chair: '',
          amenities: const [],
        );

    test('n/s: 6 wide × 4 deep', () {
      for (final o in [SeatOrientation.n, SeatOrientation.s]) {
        expect(seat(o).footprint, const GridRect(x: 10, y: 20, w: 6, h: 4));
      }
    });

    test('e/w: 4 wide × 6 deep', () {
      for (final o in [SeatOrientation.e, SeatOrientation.w]) {
        expect(seat(o).footprint, const GridRect(x: 10, y: 20, w: 4, h: 6));
      }
    });
  });

  group('Seat.isBlockedAt', () {
    final seat = Seat(
      id: 's',
      workspaceId: 'w',
      deskId: 'd',
      name: '',
      x: 0,
      y: 0,
      orientation: SeatOrientation.n,
      chair: '',
      amenities: const [],
      blockedFrom: DateTime.utc(2026, 7, 1),
      blockedTo: DateTime.utc(2026, 7, 10),
    );

    test('inside, before, after and open-ended ranges', () {
      expect(seat.isBlockedAt(DateTime.utc(2026, 7, 5)), isTrue);
      expect(seat.isBlockedAt(DateTime.utc(2026, 6, 30)), isFalse);
      expect(seat.isBlockedAt(DateTime.utc(2026, 7, 10)), isFalse);

      final forever = seat.copyWith(blockedTo: null);
      expect(forever.isBlockedAt(DateTime.utc(2030)), isTrue);

      final never = seat.copyWith(blockedFrom: null, blockedTo: null);
      expect(never.isBlockedAt(DateTime.utc(2026, 7, 5)), isFalse);
    });
  });
}
