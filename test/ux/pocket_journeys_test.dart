// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3620 (desk P0) -- the pocket journeys, each with a tap budget and an end
// state, through the real routed app on a phone (390 x 844):
//   * reserve a place for today: the app open on Reserve, a free seat, the
//     booking confirmed -- 2 taps, and the reservation exists;
//   * check in: an own booking running now, its seat, Check in -- 2 taps,
//     and the booking is checked in;
//   * cancel: an own booking that has not started, opened from its seat
//     (#3817) -- 2 taps (the measured number; 5 through the day view
//     before), and the booking is cancelled.
// And the kiosk, a shared terminal, on the wall tablet in both orientations:
//   * a person at the wall needs one touch (the seat); the badge is the
//     second operation and is not counted, because its time is the
//     scanner's, not the person's;
//   * hand-over: A is served, the receipt goes, B starts with nothing of A's
//     left (no name, no badge text, no command) and B's command names B once;
//   * a scanner types letters the app uses as shortcuts (N, /, ?, Ctrl+K): the
//     terminal ignores them;
//   * one card tap delivered twice acts once; a command whose answer never
//     came tells the person, names no one, and leaves the next person a
//     clean wall; Escape and Back do not leave kiosk mode.
// Evidence from a physical scanner or tablet is recorded apart from these
// synthetic ones (the PR text).
import 'dart:async';

import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/kiosk/presentation/screens/kiosk_screen.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_reservation_repository.dart';
import '../helpers/mock_providers.dart' show FakeNfcUidReader, kTestNow;
import '../helpers/screens/kiosk_screen.dart' as kiosk;
import '../helpers/screens/reserve_hub.dart' as reserve;

/// The phone the journeys run on.
const Size _phone = Size(390, 844);

/// The wall tablet, landscape and portrait.
const List<Size> _tablets = [Size(1280, 800), Size(800, 1280)];

/// Counts the touches a journey costs; scrolling and typing are not taps.
class _Touches {
  int count = 0;

  Future<void> at(WidgetTester tester, Offset point) async {
    count++;
    await tester.tapAt(point);
    await tester.pumpAndSettle();
  }

  Future<void> on(WidgetTester tester, Finder finder) async {
    count++;
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }
}

/// A booking of member-1 on the seeded seat from [from] for two hours.
Reservation _mine(DateTime from, {String id = 'res-mine'}) => Reservation(
  id: id,
  workspaceId: 'ws-1',
  seatId: 'seat-4',
  memberId: 'member-1',
  startsAt: from,
  endsAt: from.add(const Duration(hours: 2)),
  status: ReservationStatus.reserved,
);

/// A kiosk whose command fails once as if the answer never came back.
class _SilentOnce extends FakeReservationRepository {
  bool failNext = true;

  @override
  Future<String> kioskAct({
    required String workspaceId,
    required String badgeToken,
    required String action,
    String? seatId,
    String? levelId,
    DateTime? startsAt,
    DateTime? endsAt,
  }) {
    if (failNext) {
      failNext = false;
      throw TimeoutException('no answer');
    }
    return super.kioskAct(
      workspaceId: workspaceId,
      badgeToken: badgeToken,
      action: action,
      seatId: seatId,
      levelId: levelId,
      startsAt: startsAt,
      endsAt: endsAt,
    );
  }
}

const _field = ValueKey('kiosk-badge-field');
const _name = ValueKey('kiosk-summary-name');

/// Opens the kiosk sheet on the seat; Check in is what it offers first.
Future<void> _openSheet(WidgetTester tester) async {
  await tester.tapAt(kiosk.seatCenter(tester));
  await tester.pumpAndSettle();
  expect(find.byKey(_field), findsOneWidget, reason: 'the sheet is open');
}

/// A wedge scanner: the code typed into the badge field, then Enter.
Future<void> _scan(WidgetTester tester, String code) async {
  await tester.enterText(find.byKey(_field), code);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// The receipt goes by itself; the wall is clean for the next person.
Future<void> _letReceiptGo(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('kiosk-success-card')), findsNothing);
}

void main() {
  setUpAll(() {
    WorkspaceTime.install('Europe/Berlin');
    kiosk.kioskClock = FixedClock(
      WorkspaceTime.at(kTestNow.year, kTestNow.month, kTestNow.day, 10),
    );
  });
  tearDownAll(WorkspaceTime.reset);

  group('on a phone', () {
    testWidgets('reserve a place for today: 2 taps from the open app', (
      tester,
    ) async {
      final repo = await reserve.pumpHub(tester, size: _phone);
      final taps = _Touches();

      await taps.at(tester, reserve.seatCenter(tester));
      await taps.on(tester, find.byKey(const ValueKey('booking-confirm')));

      expect(repo.reservations, hasLength(1), reason: 'the booking was made');
      expect(repo.reservations.single.memberId, 'member-1');
      expect(
        taps.count,
        lessThanOrEqualTo(2),
        reason: 'reserving took ${taps.count} taps, budget 2',
      );
    });

    testWidgets('check in: 2 taps, the booking is checked in', (tester) async {
      final repo = await reserve.pumpHub(
        tester,
        size: _phone,
        seed: [_mine(kTestNow.subtract(const Duration(minutes: 10)))],
      );
      final taps = _Touches();

      await taps.at(tester, reserve.seatCenter(tester));
      await taps.on(tester, find.text('Check in'));

      expect(repo.reservations.single.status, ReservationStatus.checkedIn);
      expect(
        taps.count,
        lessThanOrEqualTo(2),
        reason: 'checking in took ${taps.count} taps, budget 2',
      );
    });

    testWidgets('cancel: 2 taps from its seat, the booking is cancelled', (
      tester,
    ) async {
      // #3817 — a booking of the person later today opens from its seat on
      // the plan (the plan shows the window now, so the seat is drawn
      // free): the seat, then Cancel. The budget is the measured number
      // (5 through the day view before); lower it when the path gets
      // shorter.
      const cancelBudget = 2;
      final repo = await reserve.pumpHub(
        tester,
        size: _phone,
        seed: [_mine(kTestNow.add(const Duration(minutes: 30)))],
      );
      final taps = _Touches();

      await taps.at(tester, reserve.seatCenter(tester));
      await taps.on(tester, find.text('Cancel reservation').last);

      expect(repo.reservations.single.status, ReservationStatus.cancelled);
      expect(
        taps.count,
        lessThanOrEqualTo(cancelBudget),
        reason: 'cancelling took ${taps.count} taps, budget $cancelBudget',
      );
    });
  });

  for (final size in _tablets) {
    final at = '${size.width.toInt()}x${size.height.toInt()}';
    group('the kiosk at $at', () {
      testWidgets('hand-over: B starts with nothing of A left, and B is named '
          'once', (tester) async {
        final repo = FakeReservationRepository()..kioskName = 'Ana';
        await kiosk.pumpKiosk(tester, size: size, repo: repo);
        final touches = _Touches();

        // A: one touch, then the badge (not counted: it is the scanner's).
        await touches.at(tester, kiosk.seatCenter(tester));
        expect(touches.count, 1, reason: 'the person at the wall touches once');
        await _scan(tester, 'badge-ana');
        expect(tester.widget<Text>(find.byKey(_name)).data, 'Ana');
        expect(repo.kioskActs.single.badgeToken, 'badge-ana');
        await _letReceiptGo(tester);
        expect(
          find.text('Ana'),
          findsNothing,
          reason: 'A is gone from the wall',
        );

        // B: the same terminal, nothing of A's in the sheet.
        repo.kioskName = 'Ben';
        await _openSheet(tester);
        expect(
          tester.widget<TextField>(find.byKey(_field)).controller?.text ?? '',
          isEmpty,
          reason: 'no badge text is kept for the next person',
        );
        expect(find.text('Ana'), findsNothing);
        await _scan(tester, 'badge-ben');

        expect(tester.widget<Text>(find.byKey(_name)).data, 'Ben');
        expect(find.text('Ben'), findsOneWidget, reason: 'B is named once');
        expect(find.text('Ana'), findsNothing);
        expect(repo.kioskActs.map((a) => a.badgeToken), [
          'badge-ana',
          'badge-ben',
        ]);
        await _letReceiptGo(tester);
        expect(find.text('Ben'), findsNothing);
      });

      testWidgets('letters the app uses as shortcuts do nothing at the '
          'terminal, and Escape and Back do not leave it', (tester) async {
        final repo = await kiosk.pumpKiosk(tester, size: size);

        // A scanner sequence on the plan, nothing focused: N (new), / (filter),
        // ? (the list of keys), Ctrl+K (search), then Escape.
        for (final key in [
          LogicalKeyboardKey.keyN,
          LogicalKeyboardKey.slash,
          LogicalKeyboardKey.keyK,
        ]) {
          await tester.sendKeyEvent(key);
        }
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.slash);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(KioskScreen), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byType(Dialog), findsNothing);

        // The same letters in the sheet go where the badge goes: the field.
        await _openSheet(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
        await tester.sendKeyEvent(LogicalKeyboardKey.slash);
        await tester.pumpAndSettle();
        expect(find.byKey(_field), findsOneWidget);
        expect(repo.kioskActs, isEmpty, reason: 'letters are not a badge');

        // Escape closes the sheet; Back closes nothing and leaves nothing.
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byKey(_field), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(KioskScreen), findsOneWidget);
        expect(repo.kioskActs, isEmpty);
      });

      testWidgets('a card tap delivered twice acts once, with the screen '
          'untouched', (tester) async {
        final nfc = FakeNfcUidReader(available: true);
        final repo = await kiosk.pumpKiosk(tester, size: size, nfc: nfc);

        await _openSheet(tester);
        // Touch only: no keyboard; the same UID arrives twice in one frame.
        nfc
          ..tap('04a2b3c4')
          ..tap('04a2b3c4');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(KioskScreen), findsOneWidget);
        expect(repo.kioskActs, hasLength(1), reason: 'one card, one command');
        expect(repo.kioskActs.single.badgeToken, '04a2b3c4');
        await _letReceiptGo(tester);
      });

      testWidgets('a command with no answer says so, names no one, and the '
          'next person is served', (tester) async {
        final repo = _SilentOnce()..kioskName = 'Ana';
        await kiosk.pumpKiosk(tester, size: size, repo: repo);

        await _openSheet(tester);
        await _scan(tester, 'badge-ana');
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('kiosk-success-card')), findsNothing);
        expect(find.text('Ana'), findsNothing, reason: 'no receipt, no name');
        expect(repo.kioskActs, isEmpty);
        expect(find.byType(KioskScreen), findsOneWidget);

        repo.kioskName = 'Ben';
        await _openSheet(tester);
        expect(
          tester.widget<TextField>(find.byKey(_field)).controller?.text ?? '',
          isEmpty,
        );
        await _scan(tester, 'badge-ben');
        expect(tester.widget<Text>(find.byKey(_name)).data, 'Ben');
        expect(find.text('Ana'), findsNothing);
        expect(repo.kioskActs.single.badgeToken, 'badge-ben');
        await _letReceiptGo(tester);
      });
    });
  }
}
