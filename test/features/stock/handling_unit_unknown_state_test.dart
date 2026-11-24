// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3730 -- a handling unit in a state a newer server sent is read as an
// explicit unknown: it is listed, it is not open, so it is neither moved nor
// unpacked on a guess.
import 'package:deskilo/features/stock/domain/handling_units.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _row(String? state) => {
  'id': 'u1',
  'code': 'PAL-1',
  'kind': 'pallet',
  'state': state,
  'location_id': 'l1',
  'revision': 1,
};

void main() {
  test('the known states read as themselves', () {
    for (final s in ['open', 'unpacked', 'retired']) {
      expect(HandlingUnit.fromJson(_row(s)).state.name, s);
    }
    expect(HandlingUnit.fromJson(_row('open')).isOpen, isTrue);
  });

  test('a state from the future is unknown and allows nothing', () {
    final unit = HandlingUnit.fromJson(_row('future_sealed'));
    expect(unit.state, HandlingUnitState.unknown);
    expect(unit.isOpen, isFalse);
  });

  test('the name unknown on the wire is not a way in', () {
    expect(HandlingUnitState.of('unknown'), HandlingUnitState.unknown);
    expect(HandlingUnitState.of(null), HandlingUnitState.unknown);
  });
}
