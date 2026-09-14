// SPDX-License-Identifier: 0BSD
//
// #1240 — the diagnostic log carries nothing personal.
//
// The trace is device-local and goes nowhere on its own, which is the
// privacy position. But it exists to be SHARED: the Developer screen
// offers it as a file to send to support. The one moment it leaves the
// device is the moment it must carry nothing the reader did not ask
// for — and `no_silent_catch_test` requires every catch to trace, so
// the volume of server error text reaching it is a deliberate maximum,
// and a Postgrest message quotes the row it refused.
import 'package:deskilo/core/trace/redaction.dart';
import 'package:deskilo/core/trace/trace_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('what is masked', () {
    test('an e-mail address, whole', () {
      expect(
        redactTraceLine('duplicate key: ana.perez@clairdelune.fr'),
        'duplicate key: <email>',
      );
    });

    test('the domain goes too — in a small space it identifies the person '
        'nearly as well as the address', () {
      expect(redactTraceLine('to=a@b.co'), isNot(contains('b.co')));
    });

    test('an IBAN', () {
      expect(
        redactTraceLine('payment_instructions FR7610278090530002067120122'),
        contains('<iban>'),
      );
    });

    test('a card-shaped number', () {
      expect(redactTraceLine('card 4111 1111 1111 1111'), contains('<card>'));
    });

    test('an international phone number', () {
      expect(redactTraceLine('whatsapp +33 7 62 45 63 25'), contains('<phone>'));
    });

    test('a bearer token and an API key — the one live credential here', () {
      expect(
        redactTraceLine('Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.abc'),
        contains('<token>'),
      );
      expect(redactTraceLine('key sb_publishable_0123456789abcdefghij'),
          contains('<token>'));
    });
  });

  group('what survives, because a redacted log still has to be debuggable',
      () {
    test('the shape is kept — that a mail address was involved is usually '
        'the fact that matters', () {
      expect(redactTraceLine('invite to x@y.fr failed'),
          'invite to <email> failed');
    });

    test('amounts, counts and ids are left alone', () {
      const line = 'ledger 12500 cents, member 9677d129, 3 rows';
      expect(redactTraceLine(line), line);
    });

    test('a plain run of digits is not a phone number', () {
      expect(redactTraceLine('rows 1234567890'), contains('1234567890'));
    });

    test('an error name and a stack frame survive', () {
      const line = 'PostgrestException(message: not a member, code: P0001) '
          '| #0 SupabaseReservationRepository.create';
      expect(redactTraceLine(line), line);
    });
  });

  test('every entry goes through it, at the one point they all pass', () {
    final formatted = TraceLogger.formatEntry(
      TraceEntry(
        ts: DateTime.utc(2026, 9, 13, 12),
        level: TraceLevel.error,
        area: 'invite',
        message: 'send failed to flo@example.com',
      ),
    );
    expect(formatted, contains('<email>'));
    expect(formatted, isNot(contains('flo@example.com')),
        reason: 'redacting at the call sites would mean trusting several '
            'hundred of them; this is the one place they all pass through',
    );
  });
}
