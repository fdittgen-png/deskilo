// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2603 — which header controls each Reserve hub view shows, as a table on
// ReserveView (no taps). The hub keeps one wiring test per control.
import 'package:deskilo/features/reservations/presentation/widgets/reserve_view_menu.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // (window chips, map ↔ list switch, closed days in the legend)
  const table = <ReserveView, (bool, bool, bool)>{
    ReserveView.plan: (true, true, false),
    ReserveView.list: (true, true, false),
    ReserveView.day: (true, false, true),
    ReserveView.week: (false, false, true),
    ReserveView.month: (false, false, true),
  };

  test('every view has a row', () {
    expect(table.keys.toSet(), ReserveView.values.toSet());
  });

  for (final MapEntry(key: view, value: (chips, seatSwitch, closed))
      in table.entries) {
    test(view.name, () {
      expect(
        (
          view.showsWindowControls,
          view.showsSeatViewSwitch,
          view.legendShowsClosed,
        ),
        (chips, seatSwitch, closed),
      );
    });
  }
}
