// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2557 C2 — My data composes the person's own records, one source per
// view, each with its own state: the personal part read on the personal
// home (`export_my_personal_data_v1`) and offered as that very file through
// the truthful delivery; the reservations on the selected workspace's host
// in #2553's body, with the guest visits beside them. A personal home that
// fails, refuses or has no reader says so in its card, with Try again where
// asking again can help, and the reservations view is not touched.
import 'dart:convert';
import 'dart:typed_data';

import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/me/data/supabase_me_repository.dart';
import 'package:deskilo/features/me/domain/personal_export.dart';
import 'package:deskilo/features/me/providers/personal_shell_providers.dart';
import 'package:deskilo/features/reservations/domain/my_reservations.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:deskilo/features/visits/domain/guest_participation.dart';
import 'package:deskilo/features/visits/providers/visits_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../helpers/mock_providers.dart';
import 'me_app.dart';

Map<String, Object?> _export({
  Object? format = personalExportFormat,
  Object? version = personalExportVersion,
  Object? exportedAt = '2026-10-24T08:30:00Z',
}) => {
  'format': format,
  'version': version,
  'exported_at': exportedAt,
  'profile': {'id': 'user-1', 'full_name': 'Test User'},
  'account_conversations': [
    {'id': 'c-1'},
    {'id': 'c-2'},
  ],
  'account_messages': [
    {'id': 'm-1'},
    {'id': 'm-2'},
    {'id': 'm-3'},
  ],
  'account_group_messages': [
    {'id': 'g-1'},
  ],
  'workspace_refs': [
    {'network_id': 'a:b'},
  ],
};

/// The device saver, scripted: what it answers and what it was handed.
class _Saver {
  SaveOutcome answer = const SavedFile('Download/deskilo-personal-data.json');
  final files = <String, Uint8List>{};

  Future<SaveOutcome> save({
    required Uint8List bytes,
    required String fileName,
  }) async {
    files[fileName] = bytes;
    return answer;
  }
}

/// One host page of reservations, or a refusal.
class _Reservations implements MyReservationsRepository {
  _Reservations({this.failure});

  Exception? failure;

  @override
  Future<MyReservationsLimits> limits() async =>
      const MyReservationsLimits(
        windowDays: 7,
        maxDays: 60,
        concurrency: 4,
        timeout: Duration(seconds: 12),
      );

  @override
  Future<MyReservationsPage> page(
    MyReservationsSource source,
    MyReservationsQuery query,
  ) async {
    final refused = failure;
    if (refused != null) throw refused;
    final start = DateTime(kTestNow.year, kTestNow.month, kTestNow.day, 9);
    return MyReservationsPage(
      source: 'inst-a',
      items: [
        MyReservationItem(
          id: 'r-1',
          workspaceId: 'ws-1',
          workspaceName: 'One',
          placeKind: MyReservationPlaceKind.seat,
          placeId: 'seat-1',
          placeLabel: 'A1',
          startsAt: start,
          endsAt: start.add(const Duration(hours: 4)),
          status: ReservationStatus.reserved,
          checkedInAt: null,
          checkedOutAt: null,
        ),
      ],
      next: null,
      hasMore: false,
    );
  }
}

Finder _key(String key) => find.byKey(ValueKey(key));

Future<GoRouter> _pump(
  WidgetTester tester, {
  FakeMeRepository? me,
  _Saver? saver,
  _Reservations? reservations,
  List<GuestParticipation> visits = const [],
}) => pumpMeApp(
  tester,
  workspace: FakeWorkspaceRepository(workspaces: []),
  me: me,
  extraOverrides: <Override>[
    personalShellEnabledProvider.overrideWithValue(true),
    fileDeliveryModeProvider.overrideWithValue(FileDeliveryMode.direct),
    typedFileSaverProvider.overrideWithValue((saver ?? _Saver()).save),
    myReservationsRepositoryProvider.overrideWithValue(
      reservations ?? _Reservations(),
    ),
    // #2553 C2: the hosts My reservations reads.
    myReservationsSourcesProvider.overrideWith((ref) async => const [
          MyReservationsSource(
            installationId: 'inst-a',
            workspaceIds: ['ws-1'],
            hostedHere: true,
            labels: ['One'],
          ),
        ]),
    myGuestVisitsProvider.overrideWith((ref) async => visits),
  ],
);

void main() {
  group('the personal export, decoded', () {
    test('counts what the home holds and keeps the answer as the file', () {
      final export = PersonalExport.decode(_export());
      expect(export.conversations, 2);
      expect(export.messages, 4);
      expect(export.workspaces, 1);
      expect(export.count('account_blocks'), 0);
      expect(export.fileName, 'deskilo-personal-data-2026-10-24.json');
      expect(jsonDecode(utf8.decode(export.bytes())), _export());
    });

    test('an answer that is not a personal export is refused, never empty', () {
      for (final raw in <Object?>[
        null,
        'export',
        _export(format: 'deskilo.export'),
        _export(version: 2),
        _export(exportedAt: 'yesterday'),
      ]) {
        expect(
          () => PersonalExport.decode(raw),
          throwsA(
            isA<PersonalExportRefused>().having(
              (e) => e.failure,
              'failure',
              PersonalExportFailure.malformed,
            ),
          ),
          reason: '$raw',
        );
      }
    });

    test(
      'the refusals the home raises on purpose are typed; others are not',
      () {
        PersonalExportFailure? of(String code, [String message = '']) =>
            personalExportRefusalOf(
              PostgrestException(message: message, code: code),
            );
        expect(of('PGRST202'), PersonalExportFailure.unsupported);
        expect(of('42501'), PersonalExportFailure.forbidden);
        expect(
          of('P0001', 'identity_session_refused'),
          PersonalExportFailure.forbidden,
        );
        expect(of('P0001', 'something else'), isNull);
        expect(of('57014'), isNull);
      },
    );
  });

  group('My data › Personal information', () {
    testWidgets('the home answers: what it holds, and the very answer is '
        'saved as a file the person can open', (tester) async {
      final me = FakeMeRepository()..personalExport = _export();
      final saver = _Saver();
      final router = await _pump(tester, me: me, saver: saver);
      await goTo(tester, router, '/me/data?view=profile');
      expect(_key('me-data-personal-loaded'), findsOneWidget);
      expect(
        find.text('Conversations: 2 · Messages: 4 · Workspaces named: 1'),
        findsOneWidget,
      );
      await tester.tap(_key('me-data-personal-export'));
      await tester.pumpAndSettle();
      final bytes = saver.files['deskilo-personal-data-2026-10-24.json'];
      expect(bytes, isNotNull);
      expect(jsonDecode(utf8.decode(bytes!)), _export());
      expect(
        find.text('Saved to Download/deskilo-personal-data.json'),
        findsOneWidget,
      );
    });

    testWidgets('a private copy is named as kept inside the app, never as '
        'saved to a place', (tester) async {
      final saver = _Saver()
        ..answer = const SavedPrivately(
          '/data/user/0/app/files/deskilo-personal-data-2026-10-24.json',
        );
      final router = await _pump(tester, saver: saver);
      await goTo(tester, router, '/me/data?view=profile');
      await tester.tap(_key('me-data-personal-export'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Kept inside Deskilo'), findsOneWidget);
      expect(find.textContaining('Saved to'), findsNothing);
    });

    testWidgets('a home without the reader is unavailable, with nothing to '
        'export and no pointless retry', (tester) async {
      final me = FakeMeRepository()
        ..exportFailure = const PersonalExportRefused(
          PersonalExportFailure.unsupported,
        );
      final router = await _pump(tester, me: me);
      await goTo(tester, router, '/me/data?view=profile');
      expect(_key('me-data-personal-unavailable'), findsOneWidget);
      expect(
        find.text(
          'Your personal home does not offer this export yet. '
          'Nothing was exported.',
        ),
        findsOneWidget,
      );
      expect(_key('me-data-personal-export'), findsNothing);
      expect(_key('me-data-personal-retry'), findsNothing);
      // The profile rows of the view are still there.
      expect(_key('settings-photo'), findsOneWidget);
    });

    testWidgets('a home that does not answer says so; Try again reads it '
        'anew and the export comes back', (tester) async {
      final me = FakeMeRepository()..exportFailure = Exception('offline');
      final router = await _pump(tester, me: me);
      await goTo(tester, router, '/me/data?view=profile');
      expect(_key('me-data-personal-failed'), findsOneWidget);
      expect(
        find.text('Your personal home did not answer. Nothing was exported.'),
        findsOneWidget,
      );
      expect(_key('me-data-personal-export'), findsNothing);
      final reads = me.exportReads;
      me.exportFailure = null;
      await tester.tap(_key('me-data-personal-retry'));
      await tester.pumpAndSettle();
      expect(me.exportReads, reads + 1);
      expect(_key('me-data-personal-loaded'), findsOneWidget);
      expect(_key('me-data-personal-export'), findsOneWidget);
    });

    testWidgets('a malformed answer offers no file', (tester) async {
      final me = FakeMeRepository()..personalExport = _export(version: 9);
      final router = await _pump(tester, me: me);
      await goTo(tester, router, '/me/data?view=profile');
      expect(_key('me-data-personal-failed'), findsOneWidget);
      expect(find.textContaining('cannot read'), findsOneWidget);
      expect(_key('me-data-personal-export'), findsNothing);
    });
  });

  group('My data › Reservations', () {
    testWidgets('the bookings on the host, and the guest visits beside '
        'them', (tester) async {
      final router = await _pump(
        tester,
        visits: [
          GuestParticipation(
            id: 'v-1',
            workspaceId: 'w-1',
            workspaceName: 'Kraftwerk',
            siteName: 'Hall',
            status: GuestVisitStatus.values.first,
            startsAt: DateTime.utc(2026, 10, 10, 8),
            endsAt: DateTime.utc(2026, 10, 10, 12),
          ),
        ],
      );
      await goTo(tester, router, '/me/data?view=reservations');
      expect(_key('me-data-reservations'), findsOneWidget);
      expect(find.text('A1'), findsWidgets);
      expect(find.text('Visits as a guest: 1'), findsOneWidget);
      await tester.tap(_key('me-data-guest-visits'));
      await tester.pumpAndSettle();
      expect(_key('me-visits'), findsOneWidget);
    });

    testWidgets('a host that refuses is named with Try again, and the '
        'personal view still reads its own source', (tester) async {
      final reservations = _Reservations(failure: Exception('host down'));
      final router = await _pump(tester, reservations: reservations);
      await goTo(tester, router, '/me/data?view=reservations');
      const retry = 'my-reservations-source-retry-inst-a';
      expect(_key(retry), findsOneWidget);
      reservations.failure = null;
      await tester.tap(_key(retry));
      await tester.pumpAndSettle();
      expect(_key(retry), findsNothing);
      expect(find.text('A1'), findsWidgets);
      await goTo(tester, router, '/me/data?view=profile');
      expect(_key('me-data-personal-loaded'), findsOneWidget);
    });
  });
}
