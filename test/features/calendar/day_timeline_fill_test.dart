// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Day view uses the room the screen has: a few seat rows do not leave
// the lower part empty — they grow into it, to a readable maximum — and a
// long list keeps the compact rows and scrolls.
import 'package:deskilo/features/calendar/presentation/widgets/day_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

import 'day_timeline_test.dart' show pumpTimeline, todayReservation;

void main() {
  testWidgets('a few seats share the screen: rows grow past the compact '
      'height, capped', (tester) async {
    await pumpTimeline(tester, seed: [todayReservation()]);
    await tester.pumpAndSettle();
    final track = find.byKey(DayTimeline.trackKey('seat-4'));
    expect(track, findsOneWidget);
    final h = tester.getSize(track).height;
    expect(h, greaterThan(TimelineAxis.rowHeight));
    expect(h, lessThanOrEqualTo(TimelineAxis.maxRowHeight));
  });
}
