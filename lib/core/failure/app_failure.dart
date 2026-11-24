// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4413 -- one failure type for the whole app. Whatever failed -- a server
// refusal, a network that did not answer, an answer that could not be read, a
// bug -- reaches the application as one of four cases, and a command answers
// with one outcome type. Pure Dart: no SDK, no Flutter, no localisation. The
// SDK's exceptions are turned into these in the data layer alone
// (`lib/core/data/app_failure_from.dart`); the words are chosen in
// presentation, from a refusal's code.
library;

/// A failure of the app, in one of four kinds.
sealed class AppFailure implements Exception {
  const AppFailure(this.cause);

  /// What was caught, kept for the trace; never shown to a person.
  final Object? cause;
}

/// The server (or the command itself, before anything was sent) refused, and
/// said why. Definite: nothing was done, and the same request is refused again.
final class Refusal extends AppFailure {
  const Refusal({this.code, this.message, this.details, Object? cause}) : super(cause);

  /// The refusal's code (`DKL04`, `23505`, `P0001`), or null for a local
  /// refusal raised before anything was sent.
  final String? code;

  /// The server's own sentence, for the trace and for a code no table maps.
  final String? message;

  /// What the refusal carried besides its sentence (a field, a list of ids).
  final String? details;

  @override
  String toString() => 'Refusal(${code ?? 'local'}: ${message ?? ''})';
}

/// The request or its answer was lost on the way: a socket, a timeout, a
/// gateway status. Whether the server acted is unknown, so a write is never
/// sent again under a new request id.
final class TransportFailure extends AppFailure {
  const TransportFailure(super.cause, {this.status});

  /// The gateway's HTTP status, when one answered (502, 504).
  final int? status;

  @override
  String toString() => 'TransportFailure(${status ?? cause})';
}

/// An answer arrived but could not be read: its shape is not the one this app
/// knows (an older or newer server, a broken row).
final class Unreadable extends AppFailure {
  const Unreadable(super.cause);

  @override
  String toString() => 'Unreadable($cause)';
}

/// A defect of the app itself: anything else.
final class Defect extends AppFailure {
  const Defect(super.cause);

  @override
  String toString() => 'Defect($cause)';
}

/// What a command answered: done with its value, refused (definite), or not
/// reached (the outcome is unknown or the app failed).
sealed class CommandOutcome<T> {
  const CommandOutcome();
}

final class CommandDone<T> extends CommandOutcome<T> {
  const CommandDone(this.value);
  final T value;
}

final class CommandRefused<T> extends CommandOutcome<T> {
  const CommandRefused(this.refusal);
  final Refusal refusal;
}

final class CommandUnreached<T> extends CommandOutcome<T> {
  const CommandUnreached(this.failure);

  /// A [TransportFailure], an [Unreadable] answer or a [Defect].
  final AppFailure failure;
}

/// A refusal a feature typed at its own boundary, with what its screens need
/// to word it (a quote refused as stale, with the facts it misses). It
/// reaches a command's outcome as a [Refusal] whose [AppFailure.cause] is the
/// typed refusal itself.
abstract interface class TypedRefusal implements Exception {}
