// SPDX-License-Identifier: 0BSD
//
// #1030 — a pilot tapped a free seat and read "Réservation impossible —
// la place vient peut-être d'être prise." The seat was free. The server
// had answered `not an active member`: the member's row had been paused
// the evening before, and every booking, message and sweep from that
// phone was being refused for the same reason.
//
// The message blamed a race the member cannot win, named nothing an
// administrator could fix, and the trace recorded the exception's
// sentence without the server's own fields. Both halves are tested
// here: the refusal now says which, and the trace carries the server's
// answer in one greppable field.
import 'package:deskilo/core/trace/act_trace.dart';
import 'package:deskilo/features/reservations/domain/booking_error_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException;

const _fallback = 'Could not reserve — the seat may have just been taken.';

String _map(String serverMessage) => bookingErrorText(
      null,
      PostgrestException(message: serverMessage, code: 'P0001'),
      _fallback,
    );

void main() {
  group('a membership refusal says so', () {
    test('a paused member is told the membership is paused', () {
      final text = _map('not an active member');
      expect(text, isNot(_fallback),
          reason: 'the seat was free — blaming the seat sends the member '
              'to tap it again forever');
      expect(text.toLowerCase(), contains('paused'));
      expect(text.toLowerCase(), contains('administrator'),
          reason: 'only an administrator can undo it, so the sentence '
              'has to name one');
    });

    test('a removed member is told they are not a member', () {
      final text = _map('not a member of this workspace');
      expect(text, isNot(_fallback));
      expect(text.toLowerCase(), contains('member'));
      expect(text.toLowerCase(), contains('invitation'),
          reason: 'the way back in is an invitation, not a retry');
    });

    test('the two refusals do not collapse into one sentence', () {
      expect(_map('not an active member'),
          isNot(_map('not a member of this workspace')));
    });

    test('an unmapped server error still falls back', () {
      expect(_map('some future guard nobody has mapped yet'), _fallback);
    });

    test('the server message may carry a plpgsql prefix', () {
      expect(_map('ERROR: not an active member (SQLSTATE P0001)'),
          _map('not an active member'),
          reason: 'the mapper matches a substring, not the whole line');
    });
  });

  group('the trace carries what the server answered', () {
    test('code, message, details and hint reach one field', () {
      final line = ActTrace.serverAnswer(const PostgrestException(
        message: 'not an active member',
        code: 'P0001',
        details: 'members.status=paused',
        hint: 'reactivate in Members',
      ));
      for (final part in [
        'P0001',
        'not_an_active_member',
        'members.status=paused',
        'reactivate_in_Members',
      ]) {
        expect(line, contains(part));
      }
    });

    test('no spaces, so key=value parses back apart', () {
      final line = ActTrace.serverAnswer(
          const PostgrestException(message: 'not an active member'));
      expect(line, isNot(contains(' ')),
          reason: 'a trace line is grepped as key=value pairs');
    });

    test('a non-server error is still recorded, not swallowed', () {
      expect(ActTrace.serverAnswer(StateError('offline')),
          contains('offline'));
      expect(ActTrace.serverAnswer(null), 'null');
    });
  });
}
