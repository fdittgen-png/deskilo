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
import 'package:deskilo/features/workspace/domain/conversation.dart';
import 'package:deskilo/features/workspace/domain/member_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';

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
    ..memberNotes.addAll(notes)
    // #687 — messages live in a CONVERSATION now. The inbox that used
    // to list them carries no notes any more, so the thread is reached
    // through the messaging centre; seed both so the list has a row and
    // the row has content.
    ..conversationMessages['conv-ana'] = [...notes]
    ..conversations.add(Conversation(
      id: 'conv-ana',
      kind: ConversationKind.direct,
      otherMemberId: 'member-2',
      lastBody: notes.isEmpty ? '' : notes.last.body,
      lastFromMemberId: notes.isEmpty ? null : notes.last.fromMemberId,
      lastAt: notes.isEmpty
          ? DateTime.utc(2026, 5, 12, 9)
          : notes.last.createdAt,
      // Derived the way `my_conversations` derives it: messages from
      // someone else that I have not read. Seeding 0 would have made
      // every row look read and hidden the badge these tests check.
      unread: notes
          .where((n) => n.fromMemberId != 'member-1' && n.readAt == null)
          .length,
    ));
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

/// Opens the thread with Ana through the MESSAGING CENTRE (#687).
///
/// Named for what it does rather than where it goes: these tests are
/// about the conversation — previews, references, receipts, delete — and
/// only the route to it changed when messages left the events inbox.
Future<void> _openEvents(WidgetTester tester) async {
  await tapNavIcon(tester, Icons.forum_outlined);
  await tester.pumpAndSettle();
  final row = find.byKey(const ValueKey('conversation-conv-ana'));
  if (row.evaluate().isNotEmpty) {
    await tester.tap(row);
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
      'the row PREVIEWS; the thread has the whole message (#523/#687)',
      (tester) async {
    const long = 'The projector in the main room keeps dropping the '
        'signal every ten minutes, can someone have a look at the cable?';
    await _pump(tester, notes: [_noteFromAna(long)]);
    await tapNavIcon(tester, Icons.forum_outlined);
    await tester.pumpAndSettle();

    // #687 — the row truncates at the width AVAILABLE (maxLines +
    // ellipsis) rather than at a guessed 64 characters, which is the
    // better mechanism for the same #523 intent: a preview on the list,
    // the whole thing in the thread. A hard character count either
    // wasted a wide row or overflowed a narrow one.
    final preview = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('conversation-conv-ana')),
        matching: find.text(long),
      ),
    );
    expect(preview.maxLines, 1);
    expect(preview.overflow, TextOverflow.ellipsis);

    await tester.tap(find.byKey(const ValueKey('conversation-conv-ana')));
    await tester.pumpAndSettle();
    // The CONVERSATION opens and shows the COMPLETE message as a
    // bubble, with the shared composer ready to reply to Ana.
    expect(
        find.byKey(const ValueKey('conversation-thread')), findsOneWidget);
    // Scoped to the THREAD: the list row behind the sheet holds the same
    // text, truncated — an unscoped finder matches both and proves
    // nothing about which one is showing the whole message.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('conversation-thread')),
        matching: find.textContaining('have a look at the cable?',
            findRichText: true),
      ),
      findsOneWidget,
    );
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
    await tapNavIcon(tester, Icons.forum_outlined);
    await tester.pumpAndSettle();

    // #687 — the LIST preview reads labels, never raw tokens. Markup
    // leaking into someone's inbox is what `notePlainText` exists to
    // prevent, and the new row had to be taught it too.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('conversation-conv-ana')),
        matching: find.textContaining('Still need A1 · tomorrow?'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('[res:'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('conversation-conv-ana')));
    await tester.pumpAndSettle();

    // Links are REAL widgets (field-report fix): plain taps hit them.
    await tester.tap(find.text('A1 · tomorrow'));
    await tester.pumpAndSettle();
    // My own upcoming reservation → its detail sheet with Cancel.
    expect(find.byKey(const ValueKey('reservation-cancel')), findsOneWidget);
    // Dismissing by tapping the barrier closes the THREAD underneath
    // too — one tap, two modal routes. Re-open it rather than hunting
    // for a pixel that is over one sheet and not the other.
    await tester.tapAt(const Offset(400, 50));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('conversation-conv-ana')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('A1'));
    await tester.pumpAndSettle();
    // The seat's booking sheet, ready to reserve the future slot.
    expect(find.byKey(const ValueKey('space-seat-seat-4')), findsOneWidget);

    // SHOW ON PLAN (field request): the jump closes EVERY sheet —
    // including the conversation underneath — and lands on the plan.
    await tester.tap(find.byKey(const ValueKey('space-show-plan')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('conversation-thread')), findsNothing);
    expect(
        find.byKey(const ValueKey('reserve-plan-view')), findsOneWidget);
  });

  testWidgets(
      'a RECEIVED message deletes from the thread — cancel keeps it, '
      'confirm removes it (#523/#687)', (tester) async {
    // The swipe-a-row gesture retired with the events inbox that owned
    // it: the centre lists CONVERSATIONS, and swiping one away would
    // mean something else entirely. Deleting a message is long-press on
    // its bubble, which is also WhatsApp's idiom and works on both
    // sides — RLS allows the sender AND the direct recipient.
    final workspace =
        await _pump(tester, notes: [_noteFromAna('Lamp is on.')]);
    await _openEvents(tester);

    final bubble = find.byKey(const ValueKey('bubble-note-in'));
    expect(bubble, findsOneWidget);

    await tester.longPress(bubble);
    await tester.pumpAndSettle();
    expect(find.text('Delete this message? This cannot be undone.'),
        findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(workspace.memberNotes, hasLength(1));
    expect(bubble, findsOneWidget);

    await tester.longPress(bubble);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-delete-confirm')));
    await tester.pumpAndSettle();
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
    // #687 — the thread is reached from the messaging centre; the
    // inbox row it used to be opened from no longer exists.
    await _openEvents(tester);

    // BOTH sides of the exchange read in full.
    expect(
        find.byKey(const ValueKey('conversation-thread')), findsOneWidget);
    Finder inSheet(String text) => find.descendant(
        of: find.byKey(const ValueKey('conversation-thread')),
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

    // CONTRAST (field report): my bubble paints primaryContainer —
    // which stays LIGHT in the dark theme — so its body, links and
    // timestamp must carry onPrimaryContainer, never the theme's
    // surface ink. Structural pin: the style is the on-color.
    final bubbleContext =
        tester.element(find.byKey(const ValueKey('bubble-note-mine')));
    final scheme = Theme.of(bubbleContext).colorScheme;
    Color? bodyInk(String bubbleKey) {
      final rich = tester.widget<RichText>(find
          .descendant(
              of: find.byKey(ValueKey(bubbleKey)),
              matching: find.byType(RichText))
          .first);
      // The ink sits on the first STYLED text segment — Text.rich
      // wraps the note's spans in unstyled parents.
      Color? firstInk(InlineSpan span) {
        if (span is! TextSpan) return null;
        if (span.text != null) return span.style?.color;
        for (final child in span.children ?? const <InlineSpan>[]) {
          final ink = firstInk(child);
          if (ink != null) return ink;
        }
        return null;
      }

      return firstInk(rich.text);
    }

    expect(bodyInk('bubble-note-mine'), scheme.onPrimaryContainer);
    // Ana's bubble sits on surfaceContainerHighest and keeps onSurface.
    expect(bodyInk('bubble-note-in'), scheme.onSurface);

    // Long-press my message → confirm → gone everywhere.
    await tester.longPress(find.byKey(const ValueKey('bubble-note-mine')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-delete-confirm')));
    await tester.pumpAndSettle();
    expect(workspace.memberNotes.where((n) => n.id == 'note-mine'),
        isEmpty);
  });

  testWidgets(
      'READ RECEIPTS (0105/#539): my sent note carries a grey check, a '
      'read one a blue check, received notes none — and opening the '
      'CONVERSATION (not the inbox) stamps them read', (tester) async {
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
    // #687 — the LIST first: opening the messaging centre must not read
    // anything. Only opening the conversation does. That was #539's
    // point when the intermediate surface was the events inbox, and it
    // survives the move — a list you glance at is not a message you
    // read.
    await tapNavIcon(tester, Icons.forum_outlined);
    await tester.pumpAndSettle();
    expect(
      workspace.memberNotes.singleWhere((n) => n.id == 'note-in').readAt,
      isNull,
    );
    // The row says so: an unread count, and the name in a heavier weight.
    expect(find.byKey(const ValueKey('conversation-unread-conv-ana')),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('conversation-conv-ana')));
    await tester.pumpAndSettle();

    // In the thread: my delivered bubble grey, my read one blue,
    // received ones no check at all.
    final grey = tester.widget<Icon>(
        find.byKey(const ValueKey('note-check-note-sent')));
    expect(grey.color, isNot(readBlue));
    final blue = tester.widget<Icon>(
        find.byKey(const ValueKey('note-check-note-read')));
    expect(blue.color, readBlue);
    expect(find.byKey(const ValueKey('note-check-note-in')), findsNothing);

    // …and opening it stamped the receipt — Ana's client would now show
    // her check in blue.
    expect(
      workspace.memberNotes.singleWhere((n) => n.id == 'note-in').readAt,
      isNotNull,
    );
  });

  testWidgets(
      'MESSAGES ARE NOT ON THE BELL (#687): the notification screen '
      'carries events only, and the unread count with them',
      (tester) async {
    // #546 gave the bell its own unread filter over messages. They left
    // that feed entirely: a message in two places is one you can mark
    // read in one and still see unread in the other, and the bell
    // counted your OWN sent messages on the way.
    await _pump(tester, notes: [
      MemberNote(
        id: 'note-sent',
        workspaceId: 'ws-1',
        fromMemberId: 'member-1',
        toMemberId: 'member-2',
        body: 'Sent and delivered.',
        createdAt: DateTime.utc(2026, 5, 12, 8),
      ),
      _noteFromAna('Hello!'),
    ]);

    await tester.tap(find.byTooltip('Events'));
    await tester.pumpAndSettle();

    // Neither side of the exchange appears here any more.
    expect(find.textContaining('Hello!'), findsNothing);
    expect(find.textContaining('Sent and delivered.'), findsNothing);

    // And they are one tab away, where tapping them leads. Back out of
    // the pushed Events route first — the bottom bar is not on it.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapNavIcon(tester, Icons.forum_outlined);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('conversation-conv-ana')), findsOneWidget);
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

  testWidgets(
      'the KEYBOARD never buries the composer (field report): the '
      'conversation sheet lifts and shrinks with the view inset',
      (tester) async {
    await _pump(tester, notes: [_noteFromAna('Hello!')]);
    // #687 — reached through the messaging centre now.
    await _openEvents(tester);
    expect(
        find.byKey(const ValueKey('conversation-thread')), findsOneWidget);

    // The keyboard opens: 400 physical px of bottom inset (dpr 1).
    tester.view.viewInsets = const FakeViewPadding(bottom: 400);
    addTearDown(() => tester.view.resetViewInsets());
    await tester.pumpAndSettle();

    // The composer stays fully ABOVE the keyboard band.
    final composer =
        find.byKey(const ValueKey('member-note-body'));
    expect(composer, findsOneWidget);
    final keyboardTop = tester.view.physicalSize.height /
            tester.view.devicePixelRatio -
        400;
    expect(tester.getBottomLeft(composer).dy, lessThan(keyboardTop));
  });
}
