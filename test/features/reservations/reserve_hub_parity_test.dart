// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #685 — the Réserver hub draws the same canvas as the Plan tab, so it
// should carry the same affordances.
//
// Asked for as: "Add the plan editor icon here and that you here have
// all functionalities that you have on the plan form."
//
// Two gaps, both about being stranded on the surface people actually
// book from:
//
//  1. The editor lived on the Plan tab ONLY. An owner who spotted a
//     wrong desk while booking had to leave the hub, switch tab and
//     come back — for a fix they could have made where they saw the
//     problem.
//  2. The hub had no way back to now. Browsing to another date was one
//     tap; returning meant opening the picker and hunting for today.

import 'package:flutter_test/flutter_test.dart';
import '../../helpers/source_of.dart';

void main() {
  group('the editor is reachable from the map surface', () {
    late String shell;

    setUpAll(() {
      shell = sourceOf('lib/app/shell/shell_app_bar.dart');  // #2493: the app bar's actions moved here
    });

    // #685 put the editor on BOTH map surfaces. #687 then deleted the
    // Plan tab, so "both" is now one — the assertion follows the
    // architecture rather than freezing a step of it.
    test('the button is gated on the hub, the only map surface', () {
      expect(shell, contains('ShellBranch.reserve'));
      expect(shell, contains("ValueKey('shell-editor-button')"));
      expect(shell, isNot(contains('ShellBranch.plan ||')),
          reason: 'there is no Plan tab to gate on any more');
    });

    test('it stays with the plan\'s editors: the owner or manageSites', () {
      // The editor rewrites the workspace's geometry. Widening the
      // surface must not widen who may use it — /editor's own route
      // guard and the plan tables' RLS (0363: owner or manageSites) both
      // still apply, and this is the affordance agreeing with them.
      final block = shell.substring(shell.indexOf('shell-editor-button') - 600);
      expect(block.substring(0, 700), contains('isOwner ||'));
      expect(block.substring(0, 700),
          contains('WorkspacePermission.manageSites'));
    });
  });

  group('the hub can get back to now', () {
    late String hub;

    setUpAll(() {
      hub = sourceOf('lib/features/reservations/presentation/screens/'
              'reserve_screen.dart') + sourceOf('lib/features/reservations/presentation/screens/reserve_hub_header.dart') + sourceOf('lib/features/reservations/presentation/screens/reserve_hub_views.dart') + sourceOf('lib/features/reservations/presentation/widgets/'
              'reserve_hub_layout.dart');
    });

    test('a Back-to-now button exists, named in words', () {
      expect(hub, contains("ValueKey('reserve-now-button')"));
      // #2016 — the Plan tab is gone, and a bare clock read as a time
      // editor on touch: the action carries its own visible name.
      expect(hub, contains('reserveBackToNow'));
    });

    test('it is CONTEXTUAL — hidden while already live', () {
      // An always-visible disabled button is header noise; Plan made
      // that call in #184 and the hub follows it.
      expect(hub, contains('if (!_selectedDay.isAtSameMomentAs(_today) ||'));
    });

    test('it clears the WINDOW too, not only the day', () {
      // Leaving a hand-picked window on today reads as live while
      // showing a slot that may already be past.
      final block = hub.substring(hub.indexOf('reserve-now-button'));
      expect(block.substring(0, 500), contains('_windowStart = null'));
      expect(block.substring(0, 500), contains('_windowEnd = null'));
      expect(block.substring(0, 500), contains('_selectedDay = _today'));
    });
  });

  group('the affordances the hub already had are not disturbed', () {
    late String hub;

    setUpAll(() {
      hub = sourceOf('lib/features/reservations/presentation/screens/'
              'reserve_screen.dart') + sourceOf('lib/features/reservations/presentation/screens/reserve_hub_header.dart') + sourceOf('lib/features/reservations/presentation/screens/reserve_hub_views.dart') + sourceOf('lib/features/reservations/presentation/widgets/'
              'reserve_hub_layout.dart');
    });

    test('scan, date and the four views survive', () {
      // #699 — the scan button still exists, but in the shell's app bar
      // (with its key unchanged), so it is checked there. It left the
      // control rows because its width was what pushed the window chips
      // onto a third one.
      expect(
        sourceOf('lib/app/shell/shell_app_bar.dart'),
        contains("ValueKey('reserve-scan-button')"),
      );
      for (final key in [
        'reserve-date-button',
        'reserve-plan-view',
        'reserve-day-view',
        'reserve-week-view',
        'reserve-month-view',
      ]) {
        expect(hub, contains("ValueKey('$key')"), reason: '$key is missing');
      }
    });

    test('the seat LIST is already covered by the Day view', () {
      // The Plan tab's list toggle has no hub equivalent and needs
      // none: the hub's Day view renders every seat row and books a
      // free one, which is a superset rather than a gap.
      expect(hub, contains('showFreeSeats: true'));
      expect(hub, contains('onFreeSeatTap'));
    });
  });
}
