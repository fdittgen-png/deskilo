// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1881 B — the calendar through its real screens: the hub's views,
// steps, filters and rows, the classic calendar's month, scope and
// cancel, and a decision answered on the calendar. Each step keeps a
// category (a view, a direction, a kind, mine/everyone) and never an
// entry, a member, a name or a date; the cancel and the decision record
// their attempt before the command and its real result after, and the
// business result is the same with the recorder off.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/calendar/calendar_item.dart';
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/task_recorder/application/calendar_observation.dart';
import 'package:deskilo/features/task_recorder/application/recorder_controller.dart';
import 'package:deskilo/features/task_recorder/data/recorder_store.dart';
import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording_codec.dart';
import 'package:deskilo/features/task_recorder/providers/recorder_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_calendar_repository.dart';
import '../../helpers/fake_event_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/screens/events.dart' show event;
import 'fixtures/recording_fixtures.dart';

class _RefusingReservations extends FakeReservationRepository {
  @override
  Future<void> cancel(String reservationId) async =>
      throw StateError('not cancellable');
}

Reservation _today(String id) {
  final start = WorkspaceTime.at(
    kTestNow.year,
    kTestNow.month,
    kTestNow.day,
    9,
  );
  return Reservation(
    id: id,
    workspaceId: 'ws-1',
    seatId: 'seat-4',
    memberId: 'member-1',
    startsAt: start,
    endsAt: start.add(const Duration(hours: 2)),
    status: ReservationStatus.reserved,
  );
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required bool record,
  Map<String, dynamic> flags = const {},
  FakeReservationRepository? reservations,
  FakeCalendarRepository? calendar,
  FakeEventRepository? events,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final workspace = FakeWorkspaceRepository.withWorkspace(featureFlags: flags)
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'};
  final c = ProviderContainer(
    overrides: [
      ...standardTestOverrides(
        workspace: workspace,
        reservations: reservations,
        calendar: calendar,
        events: events,
      ),
      recorderStoreProvider.overrideWithValue(
        RecorderStore(
          backend: MemoryRecorderLogBackend(),
          namespace: canaryNamespace,
        ),
      ),
      recorderScopeProvider.overrideWithValue(canaryScope),
    ],
  );
  if (record) {
    expect(
      await c.read(recorderControllerProvider).start(scope: canaryScope),
      isTrue,
    );
    // As the recorder's own screen does when it starts one.
    c.read(recorderOpenedProvider.notifier).open();
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(container: c, child: const DeskiloApp()),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Calendar'));
  await tester.pumpAndSettle();
  return c;
}

Future<TaskRecording> _stop(WidgetTester tester, ProviderContainer c) async {
  final r = (await c.read(recorderControllerProvider).stop())!;
  await tester.pumpWidget(const SizedBox());
  c.dispose();
  return r;
}

List<String> _actions(TaskRecording r) => [
  for (final s in r.steps)
    if (s.kind == StepKind.action &&
        !s.isAttempt &&
        s.action!.startsWith('calendar.'))
      '${s.action} ${s.target ?? '-'} ${s.payload.toJson()}',
];

void main() {
  setUpAll(() => WorkspaceTime.install('Europe/Berlin'));
  tearDownAll(WorkspaceTime.reset);

  test('the accepted calendar kinds are exactly the enum', () {
    expect(calendarKindKeys, CalendarKind.values.map((k) => k.wire).toSet());
  });

  test('a kind filter names the chip that moved, and "all" as itself', () {
    const inv = CalendarKind.invoice;
    const msg = CalendarKind.message;
    expect(calendarKindChange(null, {inv}), (
      target: 'invoice',
      switchTo: 'on',
    ));
    expect(calendarKindChange({inv, msg}, {inv}), (
      target: 'message',
      switchTo: 'off',
    ));
    expect(calendarKindChange({inv}, null), (target: 'all', switchTo: 'on'));
    expect(calendarKindChange(null, null), isNull);
  });

  test('a reservation row is not a calendar step: its sheet records it', () {
    CalendarItem item(CalendarKind kind, CalendarLink link) => CalendarItem(
      kind: kind,
      id: 'x',
      at: DateTime.utc(2026, 5, 4),
      memberId: 'member-1',
      title: 't',
      link: link,
    );
    expect(
      calendarOpenedKind(
        item(CalendarKind.reservation, const ReservationLink('r')),
      ),
      isNull,
    );
    expect(
      calendarOpenedKind(item(CalendarKind.validation, const EventLink('e'))),
      'decision',
    );
    expect(
      calendarOpenedKind(item(CalendarKind.event, const EventLink('e'))),
      'alert',
    );
    expect(
      calendarOpenedKind(item(CalendarKind.invoice, const InvoiceLink('i'))),
      'invoice',
    );
  });

  testWidgets('the hub: views, steps and filters, as categories', (
    tester,
  ) async {
    final calendar = FakeCalendarRepository()
      ..items.add(
        CalendarItem(
          kind: CalendarKind.message,
          id: 'm-canary',
          at: DateTime.utc(kTestNow.year, kTestNow.month, kTestNow.day, 10),
          memberId: 'member-1',
          title: 'Private title',
          link: const EventLink('e-canary'),
        ),
      );
    final c = await _pump(tester, record: true, calendar: calendar);
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('calendar-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('calendar-today')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('calendar-kind-message')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('calendar-kind-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Private title'));
    await tester.pumpAndSettle();
    final r = await _stop(tester, c);
    expect(_actions(r), [
      'calendar.switch_view - {view_mode: week}',
      'calendar.move - {direction: next}',
      'calendar.move - {direction: today}',
      'calendar.filter_kind message {switch_to: on}',
      'calendar.filter_kind all {switch_to: on}',
      'calendar.open_item - {item_kind: alert}',
    ]);
    // #2142 — opening it is the generic layer's step, by its pattern.
    expect(
      r.steps.where(
        (s) =>
            s.action == RecorderActions.uiOpenScreen && s.target == '/calendar',
      ),
      hasLength(1),
    );
    // The alert opens the inbox: a protected screen, one marker.
    expect(r.steps.last.kind, StepKind.excluded);
    final text = encodeRecordingText(r);
    for (final secret in ['m-canary', 'e-canary', 'Private title', 'Flo']) {
      expect(text.contains(secret), isFalse, reason: secret);
    }
  });

  testWidgets('the classic calendar: month, scope, then a cancel', (
    tester,
  ) async {
    final reservations = FakeReservationRepository()
      ..reservations.add(_today('res-canary'));
    final c = await _pump(
      tester,
      record: true,
      flags: const {'calendarHub': false},
      reservations: reservations,
    );
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Everyone'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel reservation'));
    await tester.pumpAndSettle();
    final r = await _stop(tester, c);
    expect(_actions(r), [
      'calendar.move - {direction: next}',
      'calendar.move - {direction: previous}',
      'calendar.choose_whose - {calendar_of: everyone}',
    ]);
    final attempt = r.steps.singleWhere((s) => s.isAttempt);
    expect(attempt.action, RecorderActions.calendarCancelReservation);
    expect(attempt.payload.toJson(), {'repeat': 'once'});
    final outcome = r.steps.singleWhere(
      (s) => s.op == attempt.op && !s.isAttempt,
    );
    expect(outcome.outcome, RecorderOutcomes.cancelled);
    expect(
      reservations.reservations.single.status,
      ReservationStatus.cancelled,
    );
    expect(encodeRecordingText(r).contains('res-canary'), isFalse);
  });

  testWidgets('a refused cancel is recorded as refused, never as done', (
    tester,
  ) async {
    final reservations = _RefusingReservations()
      ..reservations.add(_today('res-1'));
    final c = await _pump(
      tester,
      record: true,
      flags: const {'calendarHub': false},
      reservations: reservations,
    );
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel reservation'));
    await tester.pumpAndSettle();
    final r = await _stop(tester, c);
    final outcome = r.steps.singleWhere(
      (s) => s.kind == StepKind.observation && !s.isAttempt,
    );
    expect(outcome.outcome, RecorderOutcomes.reservationRefused);
    expect(reservations.reservations.single.status, ReservationStatus.reserved);
  });

  testWidgets('the same cancel with the recorder off', (tester) async {
    final reservations = FakeReservationRepository()
      ..reservations.add(_today('res-1'));
    final c = await _pump(
      tester,
      record: false,
      flags: const {'calendarHub': false},
      reservations: reservations,
    );
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel reservation'));
    await tester.pumpAndSettle();
    expect(
      reservations.reservations.single.status,
      ReservationStatus.cancelled,
    );
    expect(c.read(recorderControllerProvider).state, RecorderState.idle);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('a decision on the calendar: attempt, then the real answer', (
    tester,
  ) async {
    final events = FakeEventRepository()
      ..events.add(
        event(
          actor: 'member-2',
          subject: 'member-1',
          status: EventStatus.pending,
        ),
      );
    final c = await _pump(
      tester,
      record: true,
      events: events,
      flags: const {
        'eventsTab': false,
        'calendarTab': true,
        'calendarHub': true,
        'calendarValidations': true,
      },
    );
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    final r = await _stop(tester, c);
    final attempt = r.steps.singleWhere((s) => s.isAttempt);
    expect(attempt.action, RecorderActions.decideEvent);
    expect(attempt.payload.toJson(), {'decision': 'accept'});
    final outcome = r.steps.singleWhere(
      (s) => s.op == attempt.op && !s.isAttempt,
    );
    expect(outcome.outcome, RecorderOutcomes.eventDecided);
    expect(events.events.single.status, EventStatus.confirmed);
  });
}
