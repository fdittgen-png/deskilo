// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1855 — the recovery sheet and the hub banner: an intent whose answer
// was lost is checked by its original id (committed → the booking can be
// opened), resumed as the same request (one booking, never two), or let
// go once the server said nothing was booked. The banner appears only
// while an answer is owed.
import 'package:deskilo/core/demo/data/reservation_repository.dart';
import 'package:deskilo/core/storage/booking_intent_store.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/reservations/domain/booking_intent.dart';
import 'package:deskilo/features/reservations/presentation/widgets/booking_recovery_sheet.dart';
import 'package:deskilo/features/reservations/presentation/widgets/pending_booking_banner.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

final _now = DateTime.utc(2026, 10, 7, 8);

/// The scope standardTestOverrides fixes for every test.
const _scope = BookingIntentScope(
  account: 'user-1',
  origin: 'https://test.local',
);

BookingIntent _intent({String requestId = 'r-lost'}) => BookingIntent(
  requestId: requestId,
  scope: _scope,
  workspaceId: 'ws-1',
  seatId: 'seat-1',
  startsAt: DateTime.utc(2026, 10, 7, 9),
  endsAt: DateTime.utc(2026, 10, 7, 13),
  checkIn: false,
  schemaVersion: 350,
  createdAt: _now.subtract(const Duration(minutes: 10)),
  status: BookingIntentStatus.unknown,
);

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required FakeReservationRepository repo,
  required InMemoryBookingIntentStore store,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        reservations: repo,
        bookingIntents: store,
        clock: FixedClock(_now),
      ),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

FakeReservationRepository _repo() =>
    FakeReservationRepository(myMemberId: 'member-1')..allowPastBookings = true;

InMemoryBookingIntentStore _store(BookingIntent intent) =>
    InMemoryBookingIntentStore(
      BookingIntentLedger.empty.upsert(intent).encode(),
    );

void main() {
  testWidgets('the server has the booking: Check finds it, View opens it', (
    tester,
  ) async {
    final repo = _repo();
    final intent = _intent();
    // The server committed this very request before the answer was lost.
    await repo.create(
      workspaceId: 'ws-1',
      seatId: 'seat-1',
      startsAt: intent.startsAt,
      endsAt: intent.endsAt,
      requestId: intent.requestId,
    );
    final store = _store(intent);
    await _pump(
      tester,
      BookingRecoverySheet(intent: intent, spaceName: 'Desk 4'),
      repo: repo,
      store: store,
    );
    expect(_key('booking-recovery-status-unknown'), findsOneWidget);
    expect(find.textContaining('Desk 4'), findsOneWidget);
    expect(_key('booking-recovery-view'), findsNothing);

    await tester.tap(_key('booking-recovery-check'));
    await tester.pumpAndSettle();
    expect(_key('booking-recovery-status-committed'), findsOneWidget);
    expect(_key('booking-recovery-view'), findsOneWidget);
    expect(_key('booking-recovery-resume'), findsNothing);
    expect(repo.outcomeCalls, 1);
    expect(repo.createCalls, 1, reason: 'a check never books');
    expect(
      BookingIntentLedger.decode(store.value).intents,
      isEmpty,
      reason: 'a known commit settles the intent',
    );
  });

  testWidgets(
    'nothing was booked: Check says so, Resume books the same request once',
    (tester) async {
      final repo = _repo();
      final intent = _intent();
      final store = _store(intent);
      await _pump(
        tester,
        BookingRecoverySheet(intent: intent),
        repo: repo,
        store: store,
      );
      expect(_key('booking-recovery-discard'), findsNothing);

      await tester.tap(_key('booking-recovery-check'));
      await tester.pumpAndSettle();
      expect(_key('booking-recovery-status-notCommitted'), findsOneWidget);
      expect(_key('booking-recovery-discard'), findsOneWidget);
      expect(repo.reservations, isEmpty);

      await tester.tap(_key('booking-recovery-resume'));
      await tester.pumpAndSettle();
      expect(_key('booking-recovery-status-resumed'), findsOneWidget);
      expect(_key('booking-recovery-view'), findsOneWidget);
      expect(repo.reservations, hasLength(1));
      expect(repo.lastRequestId, intent.requestId, reason: 'the ORIGINAL id');
      expect(BookingIntentLedger.decode(store.value).intents, isEmpty);
    },
  );

  testWidgets('beyond retention the server cannot say: no resume, let it go', (
    tester,
  ) async {
    final repo = _repo();
    final intent = BookingIntent(
      requestId: 'r-old',
      scope: _scope,
      workspaceId: 'ws-1',
      seatId: 'seat-1',
      startsAt: DateTime.utc(2026, 6, 1, 9),
      endsAt: DateTime.utc(2026, 6, 1, 13),
      checkIn: false,
      schemaVersion: 350,
      createdAt: _now.subtract(const Duration(days: 120)),
      status: BookingIntentStatus.unknown,
    );
    final store = _store(intent);
    await _pump(
      tester,
      BookingRecoverySheet(intent: intent),
      repo: repo,
      store: store,
    );
    await tester.tap(_key('booking-recovery-check'));
    await tester.pumpAndSettle();
    expect(_key('booking-recovery-status-unresolved'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(_key('booking-recovery-resume')).onPressed,
      isNull,
      reason: 'absence proves nothing either way',
    );
    await tester.tap(_key('booking-recovery-discard'));
    await tester.pumpAndSettle();
    expect(BookingIntentLedger.decode(store.value).intents, isEmpty);
    expect(repo.createCalls, 0);
  });

  testWidgets('the hub banner appears only while an answer is owed', (
    tester,
  ) async {
    final repo = _repo();
    final empty = InMemoryBookingIntentStore();
    await _pump(tester, const PendingBookingBanner(), repo: repo, store: empty);
    expect(_key('pending-booking-banner'), findsNothing);

    final store = _store(_intent());
    await _pump(tester, const PendingBookingBanner(), repo: repo, store: store);
    expect(_key('pending-booking-banner'), findsOneWidget);
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(_key('booking-recovery-title'), findsOneWidget);
  });

  testWidgets('another account\'s intent is not this device\'s question', (
    tester,
  ) async {
    final repo = _repo();
    final foreign = BookingIntent(
      requestId: 'r-foreign',
      scope: const BookingIntentScope(
        account: 'somebody-else',
        origin: 'https://test.local',
      ),
      workspaceId: 'ws-1',
      seatId: 'seat-1',
      startsAt: DateTime.utc(2026, 10, 7, 9),
      endsAt: DateTime.utc(2026, 10, 7, 13),
      checkIn: false,
      schemaVersion: 350,
      createdAt: _now,
      status: BookingIntentStatus.unknown,
    );
    await _pump(
      tester,
      const PendingBookingBanner(),
      repo: repo,
      store: _store(foreign),
    );
    expect(_key('pending-booking-banner'), findsNothing);
  });
}
