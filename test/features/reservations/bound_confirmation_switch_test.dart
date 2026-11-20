// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4157 (A2 of #4174) — the real confirmations, on A, with B selected while
// they are open. B is the same local workspace and reservation ids on another
// installation. Confirming must send nothing to either, say so in words, and
// show no success; in an unchanged context the same confirmation writes to A
// alone. Each test drives the screen the person uses, so the application method
// the UI actually calls is the one under test.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/data/event_repository.dart';
import 'package:deskilo/core/demo/data/reservation_repository.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/presentation/widgets/booking_sheet.dart';
import 'package:deskilo/features/reservations/presentation/widgets/reservation_detail_sheet.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart' show openReserveHub;
import '../../helpers/pump_app.dart';
import '../../helpers/screens/reserve_hub.dart'
    show pickHubDate, reservationOn, seatCenter;
import '../../helpers/test_workspace_context.dart';

final _en = AppLocalizationsEn();
final _tomorrow = kTestNow.add(const Duration(days: 1));

/// What the screen's repositories do with a write: it goes to the repository
/// of the installation selected NOW (the real provider is built from the
/// selected workspace's host the same way).
class _SwitchingReservations extends FakeReservationRepository {
  _SwitchingReservations(this._pick);

  final FakeReservationRepository Function() _pick;

  @override
  Future<void> cancel(String reservationId) => _pick().cancel(reservationId);

  @override
  Future<String> create({
    required String workspaceId,
    String? seatId,
    String? deskId,
    String? officeId,
    String? levelId,
    required DateTime startsAt,
    required DateTime endsAt,
    bool checkIn = false,
    String? requestId,
  }) => _pick().create(
    workspaceId: workspaceId,
    seatId: seatId,
    deskId: deskId,
    officeId: officeId,
    levelId: levelId,
    startsAt: startsAt,
    endsAt: endsAt,
    checkIn: checkIn,
    requestId: requestId,
  );
}

class _SwitchingEvents extends FakeEventRepository {
  _SwitchingEvents(this._pick);

  final FakeEventRepository Function() _pick;

  @override
  Future<String> requestReservationDeletion(
    String reservationId, {
    String reason = '',
  }) => _pick().requestReservationDeletion(reservationId, reason: reason);
}

/// A and B: two installations that answer to the same local ids.
class _Two {
  _Two() {
    for (final repo in [a, b]) {
      repo.reservations.add(
        reservationOn(_tomorrow, id: 'r-mine', startHour: 0, endHour: 23),
      );
    }
    shown.reservations.addAll(a.reservations);
  }

  final a = FakeReservationRepository();
  final b = FakeReservationRepository();
  final eventsA = FakeEventRepository();
  final eventsB = FakeEventRepository();
  String selected = 'inst-a';

  late final shown = _SwitchingReservations(() => selected == 'inst-a' ? a : b);
  late final shownEvents = _SwitchingEvents(
    () => selected == 'inst-a' ? eventsA : eventsB,
  );

  List<Override> get overrides => [
    ...standardTestOverrides(
      floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
      reservations: shown,
      events: shownEvents,
    ),
    testSelectableReadyWorkspaceContext(),
  ];

  void switchToB(WidgetTester tester) {
    selected = 'inst-b';
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .read(testContextInstallation.notifier)
        .select('inst-b');
  }
}

bool _stillReserved(FakeReservationRepository repo) =>
    repo.reservations.single.status == ReservationStatus.reserved;

Future<void> _pumpSheet(
  WidgetTester tester,
  _Two two,
  Reservation reservation,
) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpApp(
    tester,
    Scaffold(body: ReservationDetailSheet(reservation: reservation)),
    overrides: two.overrides,
  );
  await tester.pumpAndSettle();
}

/// The Reserve hub on A, on tomorrow, where [two]'s booking stands.
Future<void> _pumpHub(WidgetTester tester, _Two two) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(overrides: two.overrides, child: const DeskiloApp()),
  );
  await tester.pumpAndSettle();
  await openReserveHub(tester);
  await pickHubDate(tester, _tomorrow);
}

void main() {
  group('the own-seat sheet of the Reserve hub', () {
    testWidgets('cancel, confirmed after the context switched to B with the '
        'same local ids, sends nothing to either and says so', (tester) async {
      final two = _Two();
      await _pumpHub(tester, two);
      await tester.tapAt(seatCenter(tester));
      await tester.pumpAndSettle();
      expect(find.text('Cancel reservation'), findsOneWidget);

      two.switchToB(tester);
      await tester.pump();
      await tester.tap(find.text('Cancel reservation'));
      await tester.pumpAndSettle();

      expect(_stillReserved(two.a), isTrue, reason: 'A was not written');
      expect(_stillReserved(two.b), isTrue, reason: 'B was not written');
      expect(find.text(_en.reservationContextChanged), findsOneWidget);
      expect(find.text(_en.reservationCancelledSnack), findsNothing);
    });

    testWidgets('in an unchanged context the same tap cancels A alone', (
      tester,
    ) async {
      final two = _Two();
      await _pumpHub(tester, two);
      await tester.tapAt(seatCenter(tester));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel reservation'));
      await tester.pumpAndSettle();

      expect(two.a.reservations.single.status, ReservationStatus.cancelled);
      expect(_stillReserved(two.b), isTrue);
      expect(find.text(_en.reservationContextChanged), findsNothing);
    });

    testWidgets('closing the sheet without choosing writes nothing, even '
        'after a switch', (tester) async {
      final two = _Two();
      await _pumpHub(tester, two);
      await tester.tapAt(seatCenter(tester));
      await tester.pumpAndSettle();
      two.switchToB(tester);
      await tester.pump();
      Navigator.of(tester.element(find.text('Cancel reservation'))).pop();
      await tester.pumpAndSettle();

      expect(_stillReserved(two.a), isTrue);
      expect(_stillReserved(two.b), isTrue);
    });
  });

  group('the booking sheet of the Reserve hub', () {
    testWidgets('a booking confirmed after the switch is dropped: no create '
        'on either, and it says so', (tester) async {
      final two = _Two()
        ..a.reservations.clear()
        ..b.reservations.clear()
        ..shown.reservations.clear();
      await _pumpHub(tester, two);
      await tester.tapAt(seatCenter(tester));
      await tester.pumpAndSettle();
      expect(find.byType(BookingSheet), findsOneWidget);

      two.switchToB(tester);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('booking-confirm')));
      await tester.pumpAndSettle();

      expect(two.a.createCalls, 0);
      expect(two.b.createCalls, 0);
      expect(find.text(_en.reservationContextChanged), findsOneWidget);
    });

    testWidgets('in an unchanged context the same confirmation books on A '
        'alone', (tester) async {
      final two = _Two()
        ..a.reservations.clear()
        ..b.reservations.clear()
        ..shown.reservations.clear();
      await _pumpHub(tester, two);
      await tester.tapAt(seatCenter(tester));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('booking-confirm')));
      await tester.pumpAndSettle();

      expect(two.a.createCalls, 1);
      expect(two.b.createCalls, 0);
    });
  });

  group('the booking detail sheet', () {
    testWidgets('cancel, chosen after the switch, sends nothing and shows no '
        'success', (tester) async {
      final two = _Two();
      final mine = two.a.reservations.single;
      await _pumpSheet(tester, two, mine);
      await tester.tap(find.byKey(const ValueKey('reservation-cancel')));
      await tester.pumpAndSettle();

      two.switchToB(tester);
      await tester.pump();
      await tester.tap(
        find.byKey(
          const ValueKey(
            'reservation-detail-sheet-plan-cancel-reservation-button',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_stillReserved(two.a), isTrue);
      expect(_stillReserved(two.b), isTrue);
      expect(find.text(_en.reservationContextChanged), findsOneWidget);
      expect(find.text(_en.reservationCancelledSnack), findsNothing);
    });

    testWidgets('in an unchanged context the same choice cancels A alone', (
      tester,
    ) async {
      final two = _Two();
      await _pumpSheet(tester, two, two.a.reservations.single);
      await tester.tap(find.byKey(const ValueKey('reservation-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey(
            'reservation-detail-sheet-plan-cancel-reservation-button',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(two.a.reservations.single.status, ReservationStatus.cancelled);
      expect(_stillReserved(two.b), isTrue);
    });

    testWidgets('the deletion request, submitted after the switch, files '
        'nothing on either installation', (tester) async {
      final two = _Two();
      // A started booking: the person may only ask for its deletion.
      final started = reservationOn(
        kTestNow,
        id: 'r-started',
        startHour: 0,
        endHour: 23,
      ).copyWith(status: ReservationStatus.checkedIn);
      await _pumpSheet(tester, two, started);
      await tester.tap(
        find.byKey(const ValueKey('reservation-delete-request')),
      );
      await tester.pumpAndSettle();

      two.switchToB(tester);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('reservation-delete-submit')));
      await tester.pumpAndSettle();

      expect(two.eventsA.events, isEmpty);
      expect(two.eventsB.events, isEmpty);
      expect(find.text(_en.reservationContextChanged), findsOneWidget);
      expect(find.text(_en.reservationDeleteSubmitted), findsNothing);
    });

    testWidgets('in an unchanged context the deletion request is filed on A '
        'alone', (tester) async {
      final two = _Two();
      final started = reservationOn(
        kTestNow,
        id: 'r-started',
        startHour: 0,
        endHour: 23,
      ).copyWith(status: ReservationStatus.checkedIn);
      await _pumpSheet(tester, two, started);
      await tester.tap(
        find.byKey(const ValueKey('reservation-delete-request')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reservation-delete-submit')));
      await tester.pumpAndSettle();

      expect(two.eventsA.events.length, 1);
      expect(two.eventsB.events, isEmpty);
    });
  });
}
