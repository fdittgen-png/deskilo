// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1908 — the outcomes of the concurrency guards read as what happened.
// The hierarchy guard's refusal names the space chain (it used to read as
// "the level has reservations" for a seat under a whole-reserved desk); a
// checkout that lost the race to another checkout or to the day-end sweep
// says the reservation is already closed instead of a generic failure.
import 'package:deskilo/features/reservations/domain/booking_error_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

void main() {
  String map(String message) =>
      bookingErrorText(null, PostgrestException(message: message), 'fallback');

  test('the hierarchy guard names the space chain, not the level', () {
    final text = map('that space is already reserved in that period');
    expect(text, contains('a space it belongs to'));
    expect(text, isNot(contains('level')));
  });

  test('a lost checkout race says the reservation is already closed', () {
    expect(map('not checked in'), contains('no longer checked in'));
  });

  test('the whole-level wording still answers its own refusals', () {
    expect(
      map('the level has reservations in that period'),
      'The level has reservations in that period.',
    );
  });

  test('the hierarchy refusal still counts as blocked by another member', () {
    expect(
      isBlockedByOtherError(
        const PostgrestException(
          message: 'that space is already reserved in that period',
        ),
      ),
      isTrue,
    );
  });
}
