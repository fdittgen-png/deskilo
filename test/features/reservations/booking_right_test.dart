// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3269 (0661) -- a reservation is made only by someone who holds
// makeReservations, on every path that books for the caller. The server
// refuses 'not allowed to make reservations' (42501); the fake repository
// refuses the same way behind a hook; the Demo wires that hook to the
// persona's real permissions, so taking the right away in the Demo refuses
// the next booking in words, and giving it back books again. Check-out at the
// kiosk is not a booking and still works.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/data/booking_right_reservations.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_session.dart';
import 'package:deskilo/core/l10n/context_l10n.dart';
import 'package:deskilo/features/plan/domain/half_day_windows.dart';
import 'package:deskilo/features/reservations/domain/booking_error_text.dart';
import 'package:deskilo/features/reservations/domain/reservation_repository.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../helpers/screens/demo_journeys.dart' show pumpDemo;

const _refusal = 'not allowed to make reservations';

Future<Object?> _refused(Future<Object?> Function() call) async {
  try {
    await call();
    return null;
  } on PostgrestException catch (e) {
    return e;
  }
}

void main() {
  group('the fake repository', () {
    late RightsCheckedReservationRepository repo;
    late DateTime from;
    late DateTime to;

    setUp(() {
      repo = RightsCheckedReservationRepository();
      final window = HalfDayWindows.morning(repo.now().add(const Duration(days: 1)));
      from = window.start;
      to = window.end;
    });

    test('books for everybody until a hook says otherwise', () async {
      expect(
        await repo.create(workspaceId: 'ws-1', seatId: 'seat-1', startsAt: from, endsAt: to),
        isNotEmpty,
      );
    });

    test('refuses a booking and a series without the right, and writes nothing',
        () async {
      repo.mayBook = () => false;
      final single = await _refused(
        () => repo.create(workspaceId: 'ws-1', seatId: 'seat-1', startsAt: from, endsAt: to),
      );
      expect((single! as PostgrestException).code, '42501');
      expect((single as PostgrestException).message, _refusal);
      final series = await _refused(
        () => repo.createSeries(
          workspaceId: 'ws-1',
          seatId: 'seat-1',
          firstStart: from,
          firstEnd: to,
          pattern: SeriesPattern.daily,
          until: from.add(const Duration(days: 2)),
        ),
      );
      expect((series! as PostgrestException).message, _refusal);
      expect(repo.reservations, isEmpty);
    });

    test('the kiosk refuses to reserve or walk up for a badge without the '
        'right, but still checks out', () async {
      for (final action in ['reserve', 'check_in']) {
        final e = await _refused(
          () => repo.kioskAct(
            workspaceId: 'ws-1',
            badgeToken: 'no-right-badge',
            action: action,
            seatId: 'seat-1',
            startsAt: from,
            endsAt: to,
          ),
        );
        expect((e! as PostgrestException).message, _refusal, reason: action);
      }
      final other = await _refused(
        () => repo.kioskAct(
          workspaceId: 'ws-1',
          badgeToken: 'no-right-badge',
          action: 'check_out',
        ),
      );
      expect(
        other,
        isNot(isA<PostgrestException>().having((e) => e.message, 'message', _refusal)),
        reason: 'check-out is not a booking',
      );
    });
  });

  test('the member is told in words, in the member\'s language', () {
    expect(
      bookingErrorText(englishL10n, const PostgrestException(message: _refusal), 'fallback'),
      contains('Ask an owner to let members book'),
    );
  });

  group('in the Demo', () {
    testWidgets('taking the right away refuses the next booking, giving it '
        'back books again', (tester) async {
      final journey = await pumpDemo(tester, persona: DemoPersona.member, openHub: false);
      final fixture = journey.fixture;
      final app = ProviderScope.containerOf(tester.element(find.byType(DeskiloApp)));
      final repo = app.read(reservationRepositoryProvider);
      final seat = fixture.floorPlan.seats.first.id;
      // A working day on which the seat holds no booking at all: the Demo
      // seeds bookings (some recurring) for the coming weeks.
      var day = fixture.seededAt.add(const Duration(days: 14));
      bool taken(DateTime d) => fixture.reservations.reservations.any(
        (r) =>
            r.seatId == seat &&
            r.startsAt.isBefore(d.add(const Duration(days: 1))) &&
            r.endsAt.isAfter(d.subtract(const Duration(days: 1))),
      );
      while (day.weekday > DateTime.friday || taken(day)) {
        day = day.add(const Duration(days: 1));
      }
      final morning = HalfDayWindows.morning(day);
      final afternoon = HalfDayWindows.afternoon(day);
      expect(
        app.read(myPermissionsProvider),
        contains(WorkspacePermission.makeReservations),
        reason: 'the Demo matrix grants the everyday rights to members',
      );

      // The right is there: the member books.
      expect(
        await repo.create(workspaceId: 'ws-1', seatId: seat, startsAt: morning.start, endsAt: morning.end),
        isNotEmpty,
      );

      // An owner takes it away; the next booking is refused in the server's words.
      Future<void> ownerSets({required bool enabled}) async {
        final session = journey.root.read(demoSessionControllerProvider.notifier)
          ..viewAs(DemoPersona.owner);
        await fixture.workspaces.setRolePermission(
          'ws-1', 'member', 'makeReservations', enabled: enabled);
        session.viewAs(DemoPersona.member);
        app.invalidate(currentWorkspaceProvider);
        await tester.pumpAndSettle();
      }

      await ownerSets(enabled: false);
      expect(app.read(myPermissionsProvider), isNot(contains(WorkspacePermission.makeReservations)));
      final refusal = await _refused(
        () => repo.create(workspaceId: 'ws-1', seatId: seat, startsAt: afternoon.start, endsAt: afternoon.end),
      );
      expect((refusal! as PostgrestException).message, _refusal);

      // Given back, the same booking is made.
      await ownerSets(enabled: true);
      expect(
        await repo.create(workspaceId: 'ws-1', seatId: seat, startsAt: afternoon.start, endsAt: afternoon.end),
        isNotEmpty,
      );
    });
  });
}
