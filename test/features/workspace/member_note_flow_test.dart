// SPDX-License-Identifier: 0BSD
//
// Messenger extension (#523): the Events list shows only the first 64
// characters of a message; tapping the row opens the full message with
// its reference links live — a reservation link opens that
// reservation, a space link opens the space's booking sheet. Deleting
// (swipe OR button) always asks for confirmation first. The composer
// attaches references from pickers.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/member_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';

/// Tomorrow 9–11 relative to the standard FixedClock — upcoming, so it
/// lists in the composer picker and shows Cancel in its detail sheet.
Reservation _myReservation() => Reservation(
      id: 'res-link-1',
      workspaceId: 'ws-1',
      seatId: 'seat-4',
      memberId: 'member-1',
      startsAt:
          DateTime(kTestNow.year, kTestNow.month, kTestNow.day + 1, 9),
      endsAt:
          DateTime(kTestNow.year, kTestNow.month, kTestNow.day + 1, 11),
      status: ReservationStatus.reserved,
    );

/// Pumps the app with Ana, a small floor plan (seat-4 = "A1") and one
/// upcoming reservation of mine, seeded with [notes].
Future<FakeWorkspaceRepository> _pump(
  WidgetTester tester, {
  List<MemberNote> notes = const [],
}) async {
  tester.view.physicalSize = const Size(800, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final workspace = FakeWorkspaceRepository.withWorkspace()
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
    ..otherMembers.add(
      const Member(
        id: 'member-2',
        workspaceId: 'ws-1',
        userId: 'user-2',
        isAdmin: false,
        isOwner: false,
        status: MemberStatus.active,
      ),
    )
    ..memberNotes.addAll(notes);
  final plan = FakeFloorPlanRepository()..seedSmallPlan();
  final reservations = FakeReservationRepository()
    ..reservations.add(_myReservation())
    // Ana is checked in RIGHT NOW — her check-in must be linkable too.
    ..reservations.add(Reservation(
      id: 'res-ana',
      workspaceId: 'ws-1',
      seatId: 'seat-4',
      memberId: 'member-2',
      startsAt:
          DateTime(kTestNow.year, kTestNow.month, kTestNow.day, 9),
      endsAt:
          DateTime(kTestNow.year, kTestNow.month, kTestNow.day, 18),
      status: ReservationStatus.checkedIn,
    ));
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        workspace: workspace,
        floorPlan: plan,
        reservations: reservations,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  return workspace;
}

MemberNote _noteFromAna(String body, {String id = 'note-in'}) => MemberNote(
      id: id,
      workspaceId: 'ws-1',
      fromMemberId: 'member-2',
      toMemberId: 'member-1',
      body: body,
      createdAt: DateTime.utc(2026, 5, 12, 9),
    );

Future<void> _openEvents(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Events'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'the list shows only the FIRST 64 CHARS; tapping opens the full '
      'message (#523)', (tester) async {
    const long = 'The projector in the main room keeps dropping the '
        'signal every ten minutes, can someone have a look at the cable?';
    await _pump(tester, notes: [_noteFromAna(long)]);
    await _openEvents(tester);

    final preview = '${long.substring(0, 64)}…';
    expect(find.text(preview), findsOneWidget);
    expect(find.text(long), findsNothing);

    await tester.tap(find.text(preview));
    await tester.pumpAndSettle();
    // The CONVERSATION opens (refactor) and shows the COMPLETE message
    // as a bubble, with the shared composer ready to reply to Ana.
    expect(
        find.byKey(const ValueKey('conversation-sheet')), findsOneWidget);
    expect(find.textContaining('have a look at the cable?', findRichText: true),
        findsOneWidget);
    expect(find.byKey(const ValueKey('member-note-body')), findsOneWidget);
  });

  testWidgets(
      'a reservation reference renders as a link and opens THAT '
      'reservation; a space reference opens the booking sheet (#523)',
      (tester) async {
    await _pump(tester, notes: [
      _noteFromAna('Still need [res:res-link-1|A1 · tomorrow]? '
          'Else I take [space:seat:seat-4|A1] 😀'),
    ]);
    await _openEvents(tester);

    // The list preview reads labels, never raw tokens.
    expect(find.textContaining('Still need A1 · tomorrow?'), findsOneWidget);
    expect(find.textContaining('[res:'), findsNothing);

    await tester.tap(find.textContaining('Still need A1 · tomorrow?'));
    await tester.pumpAndSettle();

    // Links are REAL widgets (field-report fix): plain taps hit them.
    await tester.tap(find.text('A1 · tomorrow'));
    await tester.pumpAndSettle();
    // My own upcoming reservation → its detail sheet with Cancel.
    expect(find.byKey(const ValueKey('reservation-cancel')), findsOneWidget);
    await tester.tapAt(const Offset(400, 50)); // dismiss the detail sheet
    await tester.pumpAndSettle();

    await tester.tap(find.text('A1'));
    await tester.pumpAndSettle();
    // The seat's booking sheet, ready to reserve the future slot.
    expect(find.byKey(const ValueKey('space-seat-seat-4')), findsOneWidget);
  });

  testWidgets(
      'swiping LEFT asks for confirmation — cancel keeps the message, '
      'confirm deletes it (#523)', (tester) async {
    final workspace =
        await _pump(tester, notes: [_noteFromAna('Lamp is on.')]);
    await _openEvents(tester);

    final row = find.byKey(const ValueKey('note-dismiss-note-in'));
    await tester.drag(row, const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('Delete this message? This cannot be undone.'),
        findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(workspace.memberNotes, hasLength(1));
    expect(row, findsOneWidget);

    await tester.drag(row, const Offset(-400, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-delete-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Message deleted.'), findsOneWidget);
    expect(workspace.memberNotes, isEmpty);
  });

  testWidgets(
      'CONVERSATION (refactor): the thread shows both sides oldest-up, '
      'and long-pressing my bubble deletes after confirmation',
      (tester) async {
    final workspace = await _pump(tester, notes: [
      MemberNote(
        id: 'note-mine',
        workspaceId: 'ws-1',
        fromMemberId: 'member-1',
        toMemberId: 'member-2',
        body: 'Coffee at ten?',
        createdAt: DateTime.utc(2026, 5, 12, 8),
      ),
      _noteFromAna('Yes! ☕'),
    ]);
    await _openEvents(tester);
    await tester.tap(find.byKey(const ValueKey('note-dismiss-note-in')));
    await tester.pumpAndSettle();

    // BOTH sides of the exchange read in full.
    expect(
        find.byKey(const ValueKey('conversation-sheet')), findsOneWidget);
    Finder inSheet(String text) => find.descendant(
        of: find.byKey(const ValueKey('conversation-sheet')),
        matching: find.text(text, findRichText: true));
    expect(inSheet('Coffee at ten?'), findsOneWidget);
    expect(inSheet('Yes! ☕'), findsOneWidget);
    // My bubble carries the delivery check (scoped: the inbox row
    // behind the sheet shows the same check).
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('bubble-note-mine')),
            matching: find.byKey(const ValueKey('note-check-note-mine'))),
        findsOneWidget);

    // Long-press my message → confirm → gone everywhere.
    await tester.longPress(find.byKey(const ValueKey('bubble-note-mine')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-delete-confirm')));
    await tester.pumpAndSettle();
    expect(workspace.memberNotes.where((n) => n.id == 'note-mine'),
        isEmpty);
  });

  testWidgets(
      'READ RECEIPTS (0105): my sent note carries a grey check, a read '
      'one a blue check, received notes none — and opening Events '
      'stamps my received notes read on the server', (tester) async {
    const readBlue = Color(0xFF42A5F5);
    final workspace = await _pump(tester, notes: [
      // Mine, delivered but unread.
      MemberNote(
        id: 'note-sent',
        workspaceId: 'ws-1',
        fromMemberId: 'member-1',
        toMemberId: 'member-2',
        body: 'Sent and delivered.',
        createdAt: DateTime.utc(2026, 5, 12, 8),
      ),
      // Mine, already read by Ana.
      MemberNote(
        id: 'note-read',
        workspaceId: 'ws-1',
        fromMemberId: 'member-1',
        toMemberId: 'member-2',
        body: 'Sent and read.',
        createdAt: DateTime.utc(2026, 5, 12, 8, 30),
        readAt: DateTime.utc(2026, 5, 12, 9),
      ),
      // From Ana to me, unread — Events opening must stamp it.
      _noteFromAna('Hello!'),
    ]);
    await _openEvents(tester);

    final grey = tester.widget<Icon>(
        find.byKey(const ValueKey('note-check-note-sent')));
    expect(grey.color, isNot(readBlue));
    final blue = tester.widget<Icon>(
        find.byKey(const ValueKey('note-check-note-read')));
    expect(blue.color, readBlue);
    // Received notes carry no check at all.
    expect(find.byKey(const ValueKey('note-check-note-in')), findsNothing);

    // Opening the surface marked MY received note read server-side —
    // Ana's client would now show her check in blue.
    final mine =
        workspace.memberNotes.singleWhere((n) => n.id == 'note-in');
    expect(mine.readAt, isNotNull);
  });

  testWidgets(
      'the composer chips attach a space and a reservation as tokens '
      '(#523)', (tester) async {
    final workspace = await _pump(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Members & plans'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('member-note-body')), 'About tomorrow:');

    await tester.tap(find.byKey(const ValueKey('member-note-ref-space')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('note-ref-space-seat-seat-4')));
    await tester.pumpAndSettle();

    await tester
        .tap(find.byKey(const ValueKey('member-note-ref-reservation')));
    await tester.pumpAndSettle();
    // BOTH participants' bookings list — my reservation FIRST, then
    // Ana's live check-in (even though hers started earlier).
    final mineTile = find.byKey(const ValueKey('note-ref-res-res-link-1'));
    final anaTile = find.byKey(const ValueKey('note-ref-res-res-ana'));
    expect(mineTile, findsOneWidget);
    expect(anaTile, findsOneWidget);
    expect(tester.getTopLeft(mineTile).dy,
        lessThan(tester.getTopLeft(anaTile).dy));
    await tester.tap(anaTile);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('member-note-send')));
    await tester.pumpAndSettle();

    final body = workspace.memberNotes.single.body;
    expect(body, startsWith('About tomorrow:'));
    expect(body, contains('[space:seat:seat-4|A1]'));
    // The label names the participant: who · space · when.
    expect(body, contains('[res:res-ana|Ana · A1 ·'));
  });
}
