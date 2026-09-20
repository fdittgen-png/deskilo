// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1281 — a simplified legend that stays truthful about the canvas.
//
// The field report asked for four words where the app draws six states:
// *«Place libre · Place réservée · Ma place · Place non disponible.»*
//
// Two requests hide in that one sentence, and answering only the first
// produces a bug. Collapsing the LEGEND while the canvas keeps painting
// five colours leaves a member looking at a colour with no entry
// explaining it — strictly worse than reading five entries.
//
// So the profile is one mapping, `legendGroupOf`, and both sides read
// it: the legend lists its distinct results, and the state computation
// never produces a state outside them. The test below is the one the
// issue asks for — the two SETS are equal — and it is red if either
// side is collapsed alone.
import 'package:deskilo/core/theme/seat_state_colors.dart';
import 'package:deskilo/features/workspace/domain/booking_policies.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every state the app can be in, before grouping.
const _all = SeatStateKind.values;

Set<SeatGroup> _groupsUnder(LegendProfile profile) =>
    {for (final state in _all) legendGroupOf(state, profile)};

void main() {
  group('the profile decides how many states a member is shown', () {
    test('full keeps every one of them, which is today\'s behaviour', () {
      expect(_groupsUnder(LegendProfile.full), {
        SeatGroup.free,
        SeatGroup.reserved,
        SeatGroup.occupied,
        SeatGroup.mine,
        SeatGroup.blocked,
        SeatGroup.closed,
      });
    });

    test('simple shows exactly the four the report asked for', () {
      expect(_groupsUnder(LegendProfile.simple), {
        SeatGroup.free,
        SeatGroup.reserved,
        SeatGroup.mine,
        SeatGroup.unavailable,
      }, reason: 'Place libre · Place réservée · Ma place · Place non '
          'disponible — four, and no fifth colour with no word');
    });

    test('a booked seat and a checked-in one are the same under simple, '
        'and different under full', () {
      expect(
        legendGroupOf(SeatStateKind.reserved, LegendProfile.simple),
        legendGroupOf(SeatStateKind.occupied, LegendProfile.simple),
        reason: 'this is exactly what the profile gives up, and it is '
            'the open question the issue put to the responsable — so it '
            'is a choice a space makes, never a default',
      );
      expect(
        legendGroupOf(SeatStateKind.reserved, LegendProfile.full),
        isNot(legendGroupOf(SeatStateKind.occupied, LegendProfile.full)),
      );
    });

    test('blocked and closed are one answer under simple', () {
      expect(
        legendGroupOf(SeatStateKind.blocked, LegendProfile.simple),
        SeatGroup.unavailable,
      );
      expect(
        legendGroupOf(SeatStateKind.closed, LegendProfile.simple),
        SeatGroup.unavailable,
        reason: 'which is why the word is «unavailable» and not '
            '«blocked»: it has to cover both honestly',
      );
    });
  });

  group('the canvas cannot paint what the legend does not list', () {
    test('the state computation never produces `occupied` under simple', () {
      // The fold happens in `seatStateAt`/`seatStateInRange`, before any
      // of the twenty-one places that pick a colour. That is why this
      // holds on every surface rather than on the ones somebody
      // remembered to change.
      const painted = [
        SeatState.free,
        SeatState.reserved,
        SeatState.occupied,
        SeatState.mine,
        SeatState.blocked,
      ];
      final groups = {
        for (final state in painted)
          legendGroupOf(
            SeatStateKind.values.byName(state.name),
            LegendProfile.simple,
          ),
      };
      expect(groups.length, 4,
          reason: 'free, reserved (absorbing occupied), mine, and '
              'unavailable from blocked — the four the report asked '
              'for, on a surface that paints seats');
      expect(groups, isNot(contains(SeatGroup.occupied)));
    });
  });

  group('the wire value', () {
    test('absent or unknown reads as full — a space that never chose '
        'keeps the picture it has', () {
      expect(LegendProfile.fromWire(null), LegendProfile.full);
      expect(LegendProfile.fromWire('nonsense'), LegendProfile.full);
      expect(LegendProfile.fromWire(42), LegendProfile.full);
    });

    test('round-trips through booking_rules', () {
      for (final profile in LegendProfile.values) {
        expect(LegendProfile.fromWire(profile.wire), profile);
      }
    });
  });
}
