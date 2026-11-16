// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4069 — a member's page shows their next bookings up to the kit's limit
// (`KitMetrics.previewRows`), then "All bookings (14)", which opens the
// calendar filtered to that member: the desk calendar and the phone hub
// both read `/calendar?member=ID`. A member with no booking gets nothing
// extra.
import 'package:deskilo/app/desk_calendar/desk_calendar.dart';
import 'package:deskilo/core/ui/kit/kit_metrics.dart';
import 'package:deskilo/features/members/domain/directory_status.dart';
import 'package:deskilo/features/members/presentation/widgets/member_header_cards.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _start = DateTime.utc(2026, 11, 16, 9);

List<Reservation> _bookings(int n) => [
  for (var i = 0; i < n; i++)
    Reservation(
      id: 'res-$i',
      workspaceId: 'ws-1',
      seatId: 'seat-1',
      memberId: 'member-3',
      startsAt: _start.add(Duration(days: i)),
      endsAt: _start.add(Duration(days: i, hours: 2)),
      status: ReservationStatus.reserved,
    ),
];

Future<List<String>> _pump(
  WidgetTester tester,
  List<Reservation> upcoming,
) async {
  final opened = <String>[];
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: MemberNowCard(
              info: upcoming.isEmpty
                  ? null
                  : UpcomingReservation(upcoming.first),
              upcoming: upcoming,
              targets: const {'seat-1': 'A1'},
              onOpen: (r) => opened.add(r.id),
              onAll: () => opened.add('all'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return opened;
}

Finder get _rows => find.byWidgetPredicate(
  (w) => '${w.key}'.contains('member-page-reservation-'),
);

void main() {
  testWidgets('fourteen bookings: the next one, the kit\'s few after it, and '
      '"All bookings (14)"', (tester) async {
    final opened = await _pump(tester, _bookings(14));
    expect(_rows, findsNWidgets(KitMetrics.previewRows));
    final all = find.byKey(const ValueKey('member-page-all-bookings'));
    expect(
      find.descendant(of: all, matching: find.text('All bookings (14)')),
      findsOneWidget,
    );
    await tester.tap(all);
    expect(opened, ['all']);
  });

  testWidgets('as many as the limit: every one, and no link', (tester) async {
    await _pump(tester, _bookings(1 + KitMetrics.previewRows));
    expect(_rows, findsNWidgets(KitMetrics.previewRows));
    expect(
      find.byKey(const ValueKey('member-page-all-bookings')),
      findsNothing,
    );
  });

  testWidgets('no booking: nothing extra', (tester) async {
    await _pump(tester, const []);
    expect(_rows, findsNothing);
    expect(
      find.byKey(const ValueKey('member-page-all-bookings')),
      findsNothing,
    );
  });

  test('the desk calendar reads the member its address names', () {
    final today = DateTime(2026, 11, 15);
    expect(
      DeskCalendarAddress.parse({'member': 'member-3'}, today: today).memberId,
      'member-3',
    );
    expect(DeskCalendarAddress.parse(const {}, today: today).memberId, isNull);
    expect(
      DeskCalendarAddress.parse({'member': ''}, today: today).memberId,
      isNull,
    );
    // The filter it sets is not carried on the address the calendar keeps.
    expect(
      DeskCalendarAddress.parse({'member': 'member-3'}, today: today).location,
      isNot(contains('member')),
    );
  });
}
