// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4444 -- for a caller that still runs a command through the guarded path
// (`runGuarded`, which says a refusal, a lost connection or a held request in
// its own words): the outcome's value, or what the outcome stands for thrown
// again as it was caught.
import '../validation/pending_validation.dart';
import 'app_failure.dart';

/// The value of a done [outcome]; otherwise throws what was caught: the
/// refusal's or the failure's cause (the server's own exception, a lost
/// socket), or a [PendingValidationException] for a held command.
T valueOrThrow<T>(CommandOutcome<T> outcome) => switch (outcome) {
  CommandDone(:final value) => value,
  CommandHeld(:final eventId) => throw PendingValidationException(eventId),
  CommandRefused(:final refusal) => Error.throwWithStackTrace(
    refusal.cause ?? refusal,
    StackTrace.current,
  ),
  CommandUnreached(:final failure) => Error.throwWithStackTrace(
    failure.cause ?? failure,
    StackTrace.current,
  ),
};
