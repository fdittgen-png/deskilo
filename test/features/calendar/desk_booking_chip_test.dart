// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3843 — a booking's chip says its hours first and whole: at 1440 every
// chip of the Demo's week shows its whole time range, the name after it,
// cut if it must be. Measured in the app's own font, as people read it.
import 'package:deskilo/app/desk_calendar/desk_booking_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/desk_calendar.dart';
import '../../ux/experience_guards.dart' show loadRealFonts;

void main() {
  // Measured in the app's own font: the test font draws every glyph an em
  // wide.
  setUpAll(loadRealFonts);

  testWidgets('at 1440 every chip of the Demo week shows its whole time '
      'range', (tester) async {
    await pumpDeskCalendar(tester, query: '?view=week&day=${demoToday()}');
    final chips = find.byType(DeskBookingChip);
    expect(chips, findsWidgets, reason: 'the Demo week has bookings');
    final cut = <String>[];
    for (final element in chips.evaluate()) {
      final id = (element.widget as DeskBookingChip).booking.id;
      final range = find.byKey(deskBookingRangeKey(id));
      expect(range, findsOneWidget, reason: 'the hours of $id are drawn');
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: range, matching: find.byType(RichText)),
      );
      if (paragraph.didExceedMaxLines) cut.add(id);
    }
    expect(cut, isEmpty, reason: 'the hours of these chips are cut');
    expect(tester.takeException(), isNull);
  });
}
