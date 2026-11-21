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
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/domain/reservation_repository.dart';
import 'package:deskilo/features/reservations/domain/series_preview.dart';
import 'package:deskilo/features/reservations/presentation/widgets/booking_sheet.dart';
import 'package:deskilo/features/reservations/presentation/widgets/reservation_detail_sheet.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
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

/// One installation's reservations, counting the writes the confirmations of
/// #4283 make beside the ones the first four cases already read off the data.
class _Counting extends FakeReservationRepository {
  int updateCalls = 0;
  int seriesCalls = 0;
  int convertCalls = 0;

  /// Every write this installation received.
  int get writes => createCalls + updateCalls + seriesCalls + convertCalls;

  @override
  Future<void> updateTimes(
    String reservationId, {
    required DateTime startsAt,
    required DateTime endsAt,
  }) {
    updateCalls++;
    return super.updateTimes(
      reservationId,
      startsAt: startsAt,
      endsAt: endsAt,
    );
  }

  @override
  Future<SeriesResult> createSeries({
    required String workspaceId,
    String? seatId,
    String? deskId,
    String? officeId,
    String? levelId,
    required DateTime firstStart,
    required DateTime firstEnd,
    required SeriesPattern pattern,
    required DateTime until,
  }) {
    seriesCalls++;
    return super.createSeries(
      workspaceId: workspaceId,
      seatId: seatId,
      deskId: deskId,
      officeId: officeId,
      levelId: levelId,
      firstStart: firstStart,
      firstEnd: firstEnd,
      pattern: pattern,
      until: until,
    );
  }

  @override
  Future<SeriesResult> convertToSeries(
    String reservationId, {
    required DateTime start,
    required DateTime end,
    required SeriesPattern pattern,
    required DateTime until,
  }) {
    convertCalls++;
    return super.convertToSeries(
      reservationId,
      start: start,
      end: end,
      pattern: pattern,
      until: until,
    );
  }
}

/// A preview that names one failing date, so the hub asks before it books.
class _FailingPreview implements SeriesPreviewer {
  @override
  Future<SeriesResult> preview(SeriesAsk ask) async => SeriesResult(
    seriesId: '',
    booked: [ask.firstStart.add(const Duration(days: 1))],
    skipped: [ask.firstStart],
  );
}

/// What the screen's repositories do with a write: it goes to the repository
/// of the installation selected NOW (the real provider is built from the
/// selected workspace's host the same way).
class _SwitchingReservations extends FakeReservationRepository {
  _SwitchingReservations(this._pick);

  final _Counting Function() _pick;

  @override
  Future<void> cancel(String reservationId) => _pick().cancel(reservationId);

  @override
  Future<void> updateTimes(
    String reservationId, {
    required DateTime startsAt,
    required DateTime endsAt,
  }) => _pick().updateTimes(
    reservationId,
    startsAt: startsAt,
    endsAt: endsAt,
  );

  @override
  Future<SeriesResult> createSeries({
    required String workspaceId,
    String? seatId,
    String? deskId,
    String? officeId,
    String? levelId,
    required DateTime firstStart,
    required DateTime firstEnd,
    required SeriesPattern pattern,
    required DateTime until,
  }) => _pick().createSeries(
    workspaceId: workspaceId,
    seatId: seatId,
    deskId: deskId,
    officeId: officeId,
    levelId: levelId,
    firstStart: firstStart,
    firstEnd: firstEnd,
    pattern: pattern,
    until: until,
  );

  @override
  Future<SeriesResult> convertToSeries(
    String reservationId, {
    required DateTime start,
    required DateTime end,
    required SeriesPattern pattern,
    required DateTime until,
  }) => _pick().convertToSeries(
    reservationId,
    start: start,
    end: end,
    pattern: pattern,
    until: until,
  );

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
  /// With a [granularity] the business keeps Berlin time, the clock stands at
  /// ten in the morning of today and the workspace offers that granularity: the
  /// detail's pickers are then the canonical windows, which a test can tap.
  _Two({this.granularity}) {
    for (final repo in [a, b]) {
      if (granularity != null) repo.now = () => berlin(10);
      repo.reservations.add(
        reservationOn(_tomorrow, id: 'r-mine', startHour: 0, endHour: 23),
      );
    }
    shown.reservations.addAll(a.reservations);
  }

  final BookingGranularity? granularity;
  final a = _Counting();
  final b = _Counting();
  final eventsA = FakeEventRepository();
  final eventsB = FakeEventRepository();
  String selected = 'inst-a';

  late final shown = _SwitchingReservations(() => selected == 'inst-a' ? a : b);
  late final shownEvents = _SwitchingEvents(
    () => selected == 'inst-a' ? eventsA : eventsB,
  );

  /// A business-local hour of today, the way the granularity cases seed it.
  static DateTime berlin(int hour) =>
      WorkspaceTime.at(kTestNow.year, kTestNow.month, kTestNow.day, hour);

  List<Override> get overrides => [
    ...standardTestOverrides(
      floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
      reservations: shown,
      events: shownEvents,
      workspace: granularity == null
          ? null
          : (FakeWorkspaceRepository.withWorkspace()
              ..memberNames = {'member-1': 'Flo'}
              ..openWeekdays['ws-1'] = [1, 2, 3, 4, 5, 6, 7]
              ..bookingGranularities['ws-1'] = granularity!),
      clock: granularity == null ? null : FixedClock(berlin(10)),
    ),
    testSelectableReadyWorkspaceContext(),
    if (previewer != null) seriesPreviewerProvider.overrideWithValue(previewer!),
  ];

  /// A preview the hub asks about, when a case needs the question.
  SeriesPreviewer? previewer;

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
  if (two.granularity != null) {
    // The sheet reads the granularity, never watches it: held here, as the
    // hub holds it, so the pickers are the business's own.
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .listen(bookingGranularityProvider, (_, _) {});
  }
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
    testWidgets('ReservationDetailActions.cancel, chosen after the switch, sends '
        'nothing and shows no success', (tester) async {
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

    testWidgets('ReservationDetailActions.requestDeletion, submitted after the '
        'switch, files nothing on either installation', (tester) async {
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

  // #4283 — the confirmations #4157 left unpumped. Each goes through the
  // production handler the sheet's button calls (named in the title: the lint
  // beside this file reads the names), twice: confirmed after the context
  // changed to B (equal local ids) it writes to neither and says so; confirmed
  // without a change it sends exactly its own command to A.
  group('the booking detail sheet: edit times, extend, end early', () {
    setUp(() => WorkspaceTime.install('Europe/Berlin'));
    tearDown(WorkspaceTime.reset);

    /// A running booking (checked in) on both installations, the same id.
    _Two running(int from, int to) {
      final two = _Two(granularity: BookingGranularity.halfDay);
      final live = Reservation(
        id: 'r-mine',
        workspaceId: 'ws-1',
        seatId: 'seat-4',
        memberId: 'member-1',
        startsAt: _Two.berlin(from),
        endsAt: _Two.berlin(to),
        status: ReservationStatus.checkedIn,
        checkedInAt: _Two.berlin(from),
      );
      for (final repo in [two.a, two.b, two.shown]) {
        repo.reservations
          ..clear()
          ..add(live);
      }
      return two;
    }

    void expectSaid(WidgetTester tester) {
      expect(find.text(_en.reservationContextChanged), findsOneWidget);
      expect(find.text(_en.reservationUpdatedSnack), findsNothing);
    }

    Future<void> openEdit(WidgetTester tester, _Two two) async {
      await _pumpSheet(tester, two, two.a.reservations.single);
      await tester.tap(find.byKey(const ValueKey('reservation-edit')));
      await tester.pumpAndSettle();
    }

    Future<void> chooseWindow(WidgetTester tester, String repeat) async {
      await tester.tap(find.byKey(const ValueKey('edit-window-pm')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(repeat)));
      await tester.pumpAndSettle();
    }

    testWidgets('ReservationDetailActions.editTimes, confirmed after the '
        'switch, writes to neither installation', (tester) async {
      final two = _Two(granularity: BookingGranularity.halfDay);
      await openEdit(tester, two);
      two.switchToB(tester);
      await tester.pump();
      await chooseWindow(tester, 'edit-repeat-none');

      expect(two.a.writes, 0);
      expect(two.b.writes, 0);
      expectSaid(tester);
    });

    testWidgets('ReservationDetailActions.editTimes with a repeat chosen, '
        'confirmed after the switch, writes to neither installation', (
      tester,
    ) async {
      final two = _Two(granularity: BookingGranularity.halfDay);
      await openEdit(tester, two);
      two.switchToB(tester);
      await tester.pump();
      await chooseWindow(tester, 'edit-repeat-weekly');

      expect(two.a.writes, 0);
      expect(two.b.writes, 0);
      expectSaid(tester);
      expect(_stillReserved(two.a), isTrue);
    });

    testWidgets('in an unchanged context the time edit moves A alone', (
      tester,
    ) async {
      final two = _Two(granularity: BookingGranularity.halfDay);
      await openEdit(tester, two);
      await chooseWindow(tester, 'edit-repeat-none');

      expect(two.a.updateCalls, 1);
      expect(two.a.writes, 1);
      expect(two.b.writes, 0);
    });

    testWidgets('in an unchanged context the edit with a repeat converts A '
        'alone', (tester) async {
      final two = _Two(granularity: BookingGranularity.halfDay);
      await openEdit(tester, two);
      await chooseWindow(tester, 'edit-repeat-weekly');

      expect(two.a.convertCalls, 1);
      expect(two.b.writes, 0);
    });

    testWidgets('ReservationDetailActions.extendEnd, confirmed after the '
        'switch, writes to neither installation', (tester) async {
      final two = running(8, 12);
      await _pumpSheet(tester, two, two.a.reservations.single);
      two.switchToB(tester);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('reservation-extend')));
      await tester.pumpAndSettle();

      expect(two.a.writes, 0);
      expect(two.b.writes, 0);
      expect(two.a.reservations.single.endsAt, _Two.berlin(12));
      expectSaid(tester);
    });

    testWidgets('in an unchanged context the extension moves A alone', (
      tester,
    ) async {
      final two = running(8, 12);
      await _pumpSheet(tester, two, two.a.reservations.single);
      await tester.tap(find.byKey(const ValueKey('reservation-extend')));
      await tester.pumpAndSettle();

      expect(two.a.updateCalls, 1);
      expect(two.a.reservations.single.endsAt, _Two.berlin(17));
      expect(two.b.writes, 0);
    });

    testWidgets('ReservationDetailActions.endEarly, confirmed after the '
        'switch, writes to neither installation', (tester) async {
      final two = running(8, 17);
      await _pumpSheet(tester, two, two.a.reservations.single);
      two.switchToB(tester);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('reservation-end-early')));
      await tester.pumpAndSettle();

      expect(two.a.writes, 0);
      expect(two.b.writes, 0);
      expect(two.a.reservations.single.endsAt, _Two.berlin(17));
      expectSaid(tester);
    });

    testWidgets('in an unchanged context ending early frees A alone', (
      tester,
    ) async {
      final two = running(8, 17);
      await _pumpSheet(tester, two, two.a.reservations.single);
      await tester.tap(find.byKey(const ValueKey('reservation-end-early')));
      await tester.pumpAndSettle();

      expect(two.a.updateCalls, 1);
      expect(two.a.reservations.single.endsAt, _Two.berlin(12));
      expect(two.b.writes, 0);
    });
  });

  group('the series preview of the Reserve hub', () {
    /// A repeating booking asked for on a free seat, the preview naming a
    /// failing date, the question open.
    Future<_Two> askSeries(WidgetTester tester) async {
      final two = _Two()
        ..a.reservations.clear()
        ..b.reservations.clear()
        ..shown.reservations.clear()
        ..previewer = _FailingPreview();
      await _pumpHub(tester, two);
      await tester.tapAt(seatCenter(tester));
      await tester.pumpAndSettle();
      for (final key in ['booking-more-options', 'booking-repeat']) {
        await tester.ensureVisible(find.byKey(ValueKey(key)));
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text(_en.repeatDaily).last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('booking-confirm')));
      await tester.tap(find.byKey(const ValueKey('booking-confirm')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('series-preview-dialog')),
        findsOneWidget,
        reason: 'the preview is the confirmation under test',
      );
      return two;
    }

    testWidgets('the series booked from the preview after the switch is '
        'dropped: no write on either, and it says so', (tester) async {
      final two = await askSeries(tester);
      two.switchToB(tester);
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('series-preview-book-others')),
      );
      await tester.pumpAndSettle();

      expect(two.a.writes, 0);
      expect(two.b.writes, 0);
      expect(find.text(_en.reservationContextChanged), findsOneWidget);
    });

    testWidgets('in an unchanged context the same confirmation books the '
        'series on A alone', (tester) async {
      final two = await askSeries(tester);
      await tester.tap(
        find.byKey(const ValueKey('series-preview-book-others')),
      );
      await tester.pumpAndSettle();

      expect(two.a.seriesCalls, 1);
      expect(two.b.writes, 0);
    });
  });
}
