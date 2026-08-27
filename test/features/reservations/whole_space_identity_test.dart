// SPDX-License-Identifier: 0BSD
//
// #670 — two field reports about whole-space bookings, one visual and
// one a dead end.
//
// 1. "The reservations for a floor, room or table are not identifiable
//    as such." A booked room already had a coloured wash and a border,
//    but the seats inside tint too — so a table whose six seats happen
//    to be individually booked looked EXACTLY like one whole-table
//    reservation. Colour alone could not carry the difference, because
//    both use the same state colours. Hatching does: nothing else on
//    the canvas is striped.
//
// 2. "When selecting the level again (with an already existing
//    reservation/check-in) deleting is not suggested/possible." The
//    sheet stated the conflict and stopped — even when the conflict was
//    the caller's OWN booking. A whole-space reservation could be made
//    and never undone from the place it was made.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a whole-space booking is drawn differently, not just tinted', () {
    // The primitives were lifted into plan_paint_helpers.dart when the
    // painter outgrew its length budget; the painter must still CALL
    // them. Both halves are asserted, because an extraction that drops
    // the call site is exactly as broken as a missing helper.
    late String helpers;
    late String painter;

    setUpAll(() {
      helpers = File('lib/features/plan/presentation/widgets/'
              'plan_paint_helpers.dart')
          .readAsStringSync();
      painter = File('lib/features/plan/presentation/widgets/'
              'floor_plan_painter.dart')
          .readAsStringSync();
    });

    test('the hatch exists and is applied to BOTH rooms and tables', () {
      expect(helpers, contains('void drawHatch('),
          reason: 'the pattern is what makes a whole-space booking '
              'readable without relying on hue');
      // Once in the office branch, once in the desk branch. A table
      // booked as a whole is the case the report named first.
      expect('drawHatch('.allMatches(painter).length, 2,
          reason: 'a room AND a table must both be hatched');
    });

    test('the hatch is clipped, or it bleeds across the whole plan', () {
      // drawLine runs past the rect by design (that is what makes the
      // stripes continuous); without a clip it would paint over the
      // entire canvas.
      final body = helpers.substring(helpers.indexOf('void drawHatch('));
      expect(body.substring(0, 900), contains('clipRect'),
          reason: 'the stripes overrun the rect deliberately and MUST be '
              'clipped to it');
    });

    test('the desk application clips to the ROUNDED rect', () {
      // A desk is an RRect; clipping to its plain Rect would leak the
      // stripes into the corners the rounding removed.
      expect(painter, contains('clipRRect(rrect);'),
          reason: 'a desk is drawn as an RRect, so its hatch must be '
              'clipped the same way');
    });
  });

  group('a whole-space booking of your own can be undone from the sheet',
      () {
    // The behaviour lives in the extracted widget; the sheet must still
    // MOUNT it. Asserting on both is what stops an extraction from
    // silently dropping the affordance — this test already failed once
    // that way, when the block moved out of space_scan.dart.
    late String actions;
    late String sheet;

    setUpAll(() {
      actions = File('lib/features/reservations/presentation/widgets/'
              'space_conflict_actions.dart')
          .readAsStringSync();
      sheet = File('lib/features/reservations/presentation/widgets/'
              'space_scan.dart')
          .readAsStringSync();
    });

    test('the sheet still mounts the conflict actions', () {
      expect(sheet, contains('SpaceConflictActions('),
          reason: 'extracting the widget must not drop it from the sheet');
    });

    test('the sheet offers to manage a conflict that is YOURS', () {
      expect(actions, contains("ValueKey('space-manage-mine')"),
          reason: 'without this the sheet is a dead end: Reserve is '
              'refused by the server and nothing cancels');
      expect(actions, contains('showReservationDetail'),
          reason: 'route to the sheet that already owns cancel / end '
              'earlier / request deletion — reimplementing those rules '
              'here is how they drift');
    });

    test('it distinguishes your own booking from someone else\'s', () {
      expect(actions, contains('blocking.memberId == myMemberId'),
          reason: 'the manage action must appear only for your own');
      expect(actions, contains('if (mine)'),
          reason: 'the branch must be explicit — messaging the holder '
              'is only for someone ELSE, and offering to message '
              'yourself is nonsense');
    });

    test('both branches are reachable — the message path is preserved',
        () {
      expect(actions, contains('canMessageReserver'),
          reason: '#622 messaging must survive this change');
    });
  });
}
