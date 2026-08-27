// SPDX-License-Identifier: 0BSD
//
// #663 — a booking attempt must END IN AN ANSWER: the reservation or
// check-in the member asked for, named and dated, or the reason it was
// refused. Never silence.
//
// Refusals were already explained everywhere (`bookingErrorText`, itself
// extracted because the switch had been pasted across four screens and
// drifted). SUCCESS was not. On the plan and in the Reserve hub the two
// most-used paths — an ordinary booking, and a walk-up check-in —
// completed with no message: the seat quietly changed colour once the
// data refreshed. On a slow connection, where the repaint lags the
// write, that is indistinguishable from nothing having happened, and the
// member's only recourse is to try again and risk booking twice.
import 'dart:io';

import 'package:deskilo/features/reservations/domain/booking_success_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    for (final locale in ['en', 'fr', 'de']) {
      await initializeDateFormatting(locale);
    }
  });

  group('a check-in says when it runs until', () {
    test('names the space when there is one', () {
      final text = bookingSuccessText(
        null,
        'en',
        checkedIn: true,
        start: DateTime(2026, 8, 26, 10, 13),
        end: DateTime(2026, 8, 26, 12),
        spaceName: 'A1',
      );
      expect(text, contains('A1'));
      expect(text, contains('12:00'),
          reason: 'the END is what a member checks against the clock');
    });

    test('drops the space cleanly when it is unknown or blank', () {
      for (final name in [null, '', '   ']) {
        final text = bookingSuccessText(
          null,
          'en',
          checkedIn: true,
          start: DateTime(2026, 8, 26, 10),
          end: DateTime(2026, 8, 26, 12),
          spaceName: name,
        );
        expect(text, contains('12:00'));
        expect(text, isNot(contains('  ')),
            reason: 'a missing name must not leave a hole in the sentence');
        expect(text.trim(), isNotEmpty);
      }
    });

    test('a check-in does NOT lead with its start — it is happening now',
        () {
      final text = bookingSuccessText(
        null,
        'en',
        checkedIn: true,
        start: DateTime(2026, 8, 26, 10, 13),
        end: DateTime(2026, 8, 26, 12),
        spaceName: 'A1',
      );
      expect(text, isNot(contains('10:13')));
    });
  });

  group('a reservation carries its date, because it may be for another day',
      () {
    test('a same-day window shows the date once and both times', () {
      final text = bookingSuccessText(
        null,
        'en',
        checkedIn: false,
        start: DateTime(2026, 8, 27, 8),
        end: DateTime(2026, 8, 27, 12),
        spaceName: 'A1',
      );
      expect(text, contains('08:00'));
      expect(text, contains('12:00'));
      expect(text, contains('A1'));
      // "Thu, Aug 27" — the weekday is what makes a future booking
      // checkable at a glance.
      expect(text, contains('Aug 27'));
    });

    test('the walk-up that runs to midnight names BOTH days, so it cannot '
        'read as ending this morning', () {
      // #644 keeps a booking inside one day, and its end may be local
      // midnight — which formats as 00:00 and would look like the START
      // of the day it actually ends.
      final text = bookingSuccessText(
        null,
        'en',
        checkedIn: false,
        start: DateTime(2026, 8, 26, 18),
        end: DateTime(2026, 8, 27),
        spaceName: 'A1',
      );
      expect(text, contains('Aug 26'));
      expect(text, contains('Aug 27'),
          reason: 'an 18:00 → 00:00 window spans two calendar dates; '
              'showing only the first makes the end ambiguous');
    });
  });

  test('the message is locale-aware, never a raw DateTime', () {
    final start = DateTime(2026, 8, 27, 8);
    final end = DateTime(2026, 8, 27, 12);
    for (final locale in ['en', 'fr', 'de']) {
      final text = bookingSuccessText(null, locale,
          checkedIn: false, start: start, end: end, spaceName: 'A1');
      expect(text, isNot(contains('2026-08-27')),
          reason: 'a raw ISO timestamp is a HARD RULE violation');
      expect(text, isNot(contains('00:00:00.000')));
      expect(text.trim(), isNotEmpty);
    }
  });

  test('an UNINITIALISED locale still produces a usable message — the '
      'confirmation runs inside the success path and must never throw',
      () {
    // A throw here would be caught by the same try/catch that reports
    // refusals, so a booking that WORKED would be announced as failed.
    final text = bookingSuccessText(
      null,
      'zz-ZZ',
      checkedIn: true,
      start: DateTime(2026, 8, 26, 10),
      end: DateTime(2026, 8, 26, 12),
      spaceName: 'A1',
    );
    expect(text, contains('12:00'));
    expect(text, contains('A1'));
  });

  group('the call sites actually answer', () {
    // Guards the property, not the wording: both screens must report a
    // success as well as a failure. A future edit that removes the
    // confirmation puts the silent path back, and this catches it —
    // it already did once, when the call sites moved to the shared
    // helper and this assertion still named the old symbol.
    // #687 — plan_screen.dart is DELETED; the hub inherited the whole
    // booking path, and the seat-ACTION half of it then moved into
    // ReserveSeatActions. The assertion follows the code: what matters
    // is that the path which BOOKS also speaks.
    test('the seat booking path announces success AND failure', () {
      for (final path in [
        'lib/features/reservations/presentation/reserve_seat_actions.dart',
      ]) {
        final source = File(path).readAsStringSync();
        // announceBooking is the shared confirmation call — the screens
        // reach the message through it rather than building the string
        // themselves, so THAT is the token that proves the success path
        // still speaks.
        expect(source, contains('announceBooking'),
            reason: '$path must confirm a booking it made');
        expect(source, contains('bookingErrorText'),
            reason: '$path must explain a booking it could not make');
      }
    });
  });
}
