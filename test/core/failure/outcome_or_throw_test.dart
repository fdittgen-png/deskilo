// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4444 -- a caller on the guarded path gets the value of a done command, and
// every other outcome thrown again as it was caught, so runGuarded says it as
// it did before the command answered an outcome.
import 'dart:io';

import 'package:deskilo/core/failure/app_failure.dart';
import 'package:deskilo/core/failure/outcome_or_throw.dart';
import 'package:deskilo/core/validation/pending_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('done is its value', () {
    expect(valueOrThrow(const CommandDone<int>(7)), 7);
  });

  test('held is the pending validation, with its event', () {
    expect(
      () => valueOrThrow(const CommandHeld<int>('ev-1')),
      throwsA(
        isA<PendingValidationException>().having(
          (e) => e.eventId,
          'eventId',
          'ev-1',
        ),
      ),
    );
  });

  test('a refusal is its cause, the server\'s own exception', () {
    final cause = StateError('already recorded');
    expect(
      () => valueOrThrow(CommandRefused<int>(Refusal(cause: cause))),
      throwsA(same(cause)),
    );
  });

  test('a lost answer is the failure that lost it', () {
    const lost = SocketException('no route to host');
    expect(
      () => valueOrThrow(const CommandUnreached<int>(TransportFailure(lost))),
      throwsA(same(lost)),
    );
  });
}
