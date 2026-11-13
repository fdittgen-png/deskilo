// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3884 -- one reservation row with a status this build does not know
// (a newer server's) no longer fails the whole list: the known rows are
// kept, the row is left out -- never read as a known status -- traced once
// per kind, counted, and the reservations screen says so in one line.
import 'package:deskilo/core/data/unreadable_rows.dart';
import 'package:deskilo/core/trace/trace_logger.dart';
import 'package:deskilo/core/ui/unreadable_rows_notice.dart';
import 'package:deskilo/features/reservations/data/supabase_reservation_repository.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row(String id, String status) => {
      'id': id,
      'workspace_id': 'ws-1',
      'seat_id': 'seat-$id',
      'member_id': 'm-1',
      'starts_at': '2031-03-02T08:00:00+00:00',
      'ends_at': '2031-03-02T12:00:00+00:00',
      'status': status,
      'created_at': '2031-03-01T08:00:00+00:00',
      'updated_at': '2031-03-01T08:00:00+00:00',
    };

void main() {
  setUp(UnreadableRows.instance.reset);

  test('three rows, one with a future status: two come back, one is counted and traced', () {
    final before = TraceLogger.instance.entries.length;
    final rows = reservationsFromRows(
      [_row('a', 'reserved'), _row('b', 'future_state'), _row('c', 'checked_in')],
      area: 'reservations:ws-1',
    );
    expect(rows.map((r) => (r.id, r.status)), [
      ('a', ReservationStatus.reserved),
      ('c', ReservationStatus.checkedIn),
    ]);
    expect(UnreadableRows.instance.count('reservations:ws-1'), 1);
    expect(TraceLogger.instance.entries.length - before, 1);
    expect(TraceLogger.instance.entries.first.message, contains('future_state'));
  });

  test('the same row read again counts once; a second kind of value is a second trace', () {
    final before = TraceLogger.instance.entries.length;
    final list = [_row('b', 'future_state'), _row('d', 'other_state')];
    reservationsFromRows(list, area: 'reservations:ws-1');
    reservationsFromRows(list, area: 'reservations:ws-1');
    expect(UnreadableRows.instance.count('reservations:ws-1'), 2);
    expect(TraceLogger.instance.entries.length - before, 2);
  });

  test('a null status is not guessed either', () {
    final rows = reservationsFromRows(
      [_row('a', 'reserved'), {..._row('b', 'x'), 'status': null}],
      area: 'reservations:ws-1',
    );
    expect(rows.map((r) => r.id), ['a']);
    expect(UnreadableRows.instance.count('reservations:ws-1'), 1);
  });

  testWidgets('the notice says in one line how many entries could not be shown', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: UnreadableRowsNotice(area: 'reservations:ws-1')),
      ),
    );
    expect(find.byKey(const ValueKey('unreadable-rows-notice')), findsNothing);
    reservationsFromRows([_row('b', 'future_state')], area: 'reservations:ws-1');
    await tester.pump();
    expect(find.textContaining('1 entry could not be shown'), findsOneWidget);
    reservationsFromRows([_row('c', 'other_state')], area: 'reservations:ws-1');
    await tester.pump();
    expect(find.textContaining('2 entries could not be shown'), findsOneWidget);
  });
}
