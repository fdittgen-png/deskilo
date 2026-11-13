// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3884 -- one reservation row with a status this build does not know (a
// newer server's) no longer fails the whole list, and never changes an
// answer without saying so: the known rows are kept, the row is left out
// (never read as a known status), traced once per kind, counted PER READ
// (the next read of the same window replaces the count), returned to the
// caller (an export, an availability decision) and said in one line on every
// screen that draws bookings. A booking read by id that exists but cannot be
// read is "unreadable", never "gone".
import 'dart:convert';

import 'package:deskilo/core/data/unreadable_rows.dart';
import 'package:deskilo/core/demo/data/reservation_repository.dart';
import 'package:deskilo/core/demo/data/stores.dart';
import 'package:deskilo/core/trace/trace_logger.dart';
import 'package:deskilo/core/ui/unreadable_rows_notice.dart';
import 'package:deskilo/features/reservations/data/supabase_reservation_repository.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/domain/reservation_repository.dart';
import 'package:deskilo/features/reservations/presentation/widgets/unread_bookings_notice.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

const _area = 'reservations:ws-1';

ReadWithUnreadable<List<Reservation>> _read(List<Map<String, dynamic>> rows,
        {String window = 'w1', String area = _area}) =>
    reservationsFromRows(rows, area: area, read: window);

/// A repository over a fake PostgREST: every `reservations` select answers
/// [rows]; the sweep is accepted.
SupabaseReservationRepository _repo(List<Map<String, dynamic>> rows) {
  final client = SupabaseClient(
    'http://127.0.0.1:54321',
    'sb_publishable_test',
    httpClient: MockClient((request) async {
      final body = request.url.path == '/rest/v1/reservations'
          ? (request.headers['Accept']?.contains('vnd.pgrst.object') ?? false)
              ? jsonEncode(rows.first)
              : jsonEncode(rows)
          : jsonEncode(null);
      return http.Response(body, 200, request: request, headers: {
        'content-type': 'application/json',
      });
    }),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  return SupabaseReservationRepository(client, InMemoryCacheStore());
}

/// A repository whose window read goes through the real row reader.
class _Window extends FakeReservationRepository {
  _Window(this.rows);

  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Reservation>> fetchWindow(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  }) async =>
      _read(rows, window: '${from.toUtc()}|${to.toUtc()}').rows;
}

void main() {
  setUp(UnreadableRows.instance.reset);

  test('three rows, one with a future status: two come back, one is counted, '
      'returned and traced', () {
    final before = TraceLogger.instance.entries.length;
    final read = _read(
      [_row('a', 'reserved'), _row('b', 'future_state'), _row('c', 'checked_in')],
    );
    expect(read.rows.map((r) => (r.id, r.status)), [
      ('a', ReservationStatus.reserved),
      ('c', ReservationStatus.checkedIn),
    ]);
    expect(read.unreadable, 1, reason: 'the caller is told, not only the screen');
    expect(UnreadableRows.instance.count(_area), 1);
    expect(TraceLogger.instance.entries.length - before, 1);
    expect(TraceLogger.instance.entries.first.message, contains('future_state'));
  });

  test('the count belongs to the read: the next read of the same window '
      'replaces it; another window adds its own', () {
    _read([_row('b', 'future_state'), _row('d', 'other_state')]);
    expect(UnreadableRows.instance.count(_area), 2);
    _read([_row('b', 'future_state')]);
    expect(UnreadableRows.instance.count(_area), 1,
        reason: 'd is no longer in the window');
    _read([_row('e', 'future_state')], window: 'w2');
    expect(UnreadableRows.instance.count(_area), 2);
    _read([_row('a', 'reserved')]);
    expect(UnreadableRows.instance.count(_area), 1,
        reason: 'a window read with nothing unreadable clears its record');
    _read([_row('a', 'reserved')], window: 'w2');
    expect(UnreadableRows.instance.count(_area), 0);
  });

  test('a second kind of value is a second trace; the same kind is not', () {
    final before = TraceLogger.instance.entries.length;
    final list = [_row('b', 'future_state'), _row('d', 'other_state')];
    _read(list);
    _read(list);
    expect(TraceLogger.instance.entries.length - before, 2);
  });

  test('a null status is not guessed either', () {
    final read = _read([_row('a', 'reserved'), {..._row('b', 'x'), 'status': null}]);
    expect(read.rows.map((r) => r.id), ['a']);
    expect(read.unreadable, 1);
  });

  test('areas do not share a count; clearing (sign-out, account change) '
      'forgets every one', () {
    _read([_row('b', 'future_state')]);
    _read([_row('b', 'future_state')], area: 'reservations:ws-2');
    expect(UnreadableRows.instance.count(_area), 1);
    expect(UnreadableRows.instance.count('reservations:ws-2'), 1);
    UnreadableRows.instance.clear();
    expect(UnreadableRows.instance.count(_area), 0);
    expect(UnreadableRows.instance.count('reservations:ws-2'), 0);
  });

  test('the export read returns the rows it understood AND how many it left '
      'out', () async {
    final read = await _repo([
      _row('a', 'reserved'),
      _row('b', 'future_state'),
    ]).fetchAllForExportRead('ws-1');
    expect(read.rows.map((r) => r.id), ['a']);
    expect(read.unreadable, 1);
  });

  test('a booking read by id that exists but cannot be read is unreadable, '
      'never null ("gone")', () async {
    await expectLater(
      _repo([_row('b', 'future_state')]).fetchById('b'),
      throwsA(isA<ReservationUnreadable>()
          .having((e) => e.reservationId, 'id', 'b')),
    );
    final known = await _repo([_row('a', 'reserved')]).fetchById('a');
    expect(known?.id, 'a');
  });

  testWidgets('the line under a list says how many entries could not be shown',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: UnreadableRowsNotice(areas: [_area])),
      ),
    );
    expect(find.byKey(const ValueKey('unreadable-rows-notice')), findsNothing);
    _read([_row('b', 'future_state')]);
    await tester.pump();
    expect(find.textContaining('1 entry could not be shown'), findsOneWidget);
    _read([_row('b', 'future_state'), _row('c', 'other_state')]);
    await tester.pump();
    expect(find.textContaining('2 entries could not be shown'), findsOneWidget);
    UnreadableRows.instance.clear();
    await tester.pump();
    expect(find.byKey(const ValueKey('unreadable-rows-notice')), findsNothing);
  });

  testWidgets('the notice every bookings screen carries is fed by a real '
      'window read through the provider', (tester) async {
    final container = ProviderContainer(
      overrides: [
        reservationRepositoryProvider.overrideWithValue(
          _Window([_row('a', 'reserved'), _row('b', 'future_state')]),
        ),
        currentWorkspaceProvider.overrideWith(
          (ref) async => const Workspace(
            id: 'ws-1',
            name: 'Atelier',
            countryCode: 'FR',
            currencyCode: 'EUR',
            timezone: 'Europe/Paris',
            inviteCode: 'x',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(currentWorkspaceProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: UnreadBookingsNotice()),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('unreadable-rows-notice')), findsNothing,
        reason: 'nothing was read yet');
    final day = await container.read(reservationsForDayProvider('2031-03-02').future);
    expect(day.map((r) => r.id), ['a']);
    await tester.pump();
    expect(find.textContaining('1 entry could not be shown'), findsOneWidget);
  });
}
