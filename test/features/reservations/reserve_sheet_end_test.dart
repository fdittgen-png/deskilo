// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — where the booking sheet's end opens, as a table on
// ReserveWindowRules.sheetEnd: a reservation keeps the tapped window, a
// walk-up its own end, and the next booking on the seat caps either; the
// walk-up the sheet may switch to is capped the same way.
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/reservations/presentation/screens/reserve_window_rules.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _at(int h, [int m = 0]) => WorkspaceTime.at(2026, 5, 13, h, m);

void main() {
  final booked = (start: _at(9), end: _at(12));
  final walkUpEnd = _at(13);

  group('the end the sheet opens with', () {
    final table = <String, (bool walkUp, DateTime? next, DateTime, bool)>{
      'a reservation keeps the tapped window': (false, null, _at(12), false),
      'a walk-up ends with its own stint': (true, null, _at(13), false),
      'a later booking does not cap': (false, _at(14), _at(12), false),
      'the next booking caps a reservation': (false, _at(11), _at(11), true),
      'the next booking caps a walk-up': (true, _at(12, 30), _at(12, 30), true),
      'a booking starting at the end is no cap': (
        false,
        _at(12),
        _at(12),
        false,
      ),
    };
    for (final MapEntry(key: name, value: (walkUp, next, end, capped))
        in table.entries) {
      test(name, () {
        final opening = ReserveWindowRules.sheetEnd(
          booked,
          walkUpEnd: walkUpEnd,
          nextStart: next,
          walkUp: walkUp,
          offerWalkUp: false,
        );
        expect(opening.end, end);
        expect(opening.capped, capped);
        expect(opening.walkUpOption, isNull);
      });
    }
  });

  group('the walk-up the sheet may switch to', () {
    test('uncapped, it runs from the window start to the walk-up end', () {
      final option = ReserveWindowRules.sheetEnd(
        booked,
        walkUpEnd: walkUpEnd,
        nextStart: null,
        walkUp: false,
        offerWalkUp: true,
      ).walkUpOption;
      expect(option, (start: _at(9), end: _at(13), cap: null, capped: false));
    });

    test('the next booking caps it, even when the reservation is not', () {
      final opening = ReserveWindowRules.sheetEnd(
        booked,
        walkUpEnd: walkUpEnd,
        nextStart: _at(12, 30),
        walkUp: false,
        offerWalkUp: true,
      );
      expect(opening.capped, isFalse);
      expect(opening.walkUpOption, (
        start: _at(9),
        end: _at(12, 30),
        cap: _at(12, 30),
        capped: true,
      ));
    });
  });
}
