// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4413 -- the one conversion from what was caught to an [AppFailure], at the
// data boundary. It reads the SDK through `server_error.dart` (the one file
// that knows what a server error is made of) and never lets an SDK type pass
// above `data/`.
library;

import 'dart:async' show TimeoutException;
import 'dart:io' show SocketException;

import '../failure/app_failure.dart';
import '../trace/trace_logger.dart';
import 'server_error.dart';

final _httpStatus = RegExp(r'^\d{3}$');

/// [error] as an [AppFailure]. A failure already converted passes through.
///
/// - A three-digit code is the gateway's HTTP status: a transport failure (a
///   502 or 504 says nothing about the commit).
/// - An answer the server sent with its own message is a [Refusal].
/// - A [StateError] is a local refusal raised before anything was sent.
/// - A lost socket, a timeout, an authentication fetch that did not answer:
///   [TransportFailure].
/// - An answer whose shape could not be read: [Unreadable].
/// - Anything else: [Defect].
AppFailure appFailureFrom(Object error) {
  if (error is AppFailure) return error;
  if (error is TypedRefusal) return Refusal(cause: error);
  final code = serverErrorCode(error);
  if (code != null && _httpStatus.hasMatch(code)) {
    return TransportFailure(error, status: int.parse(code));
  }
  final message = serverErrorMessage(error);
  if (message != null && !isAuthTransportError(error)) {
    return Refusal(code: code, message: message, details: serverErrorDetails(error), cause: error);
  }
  return switch (error) {
    StateError(:final message) => Refusal(message: message, cause: error),
    SocketException() || TimeoutException() => TransportFailure(error),
    _ when isAuthTransportError(error) => TransportFailure(error),
    FormatException() || TypeError() => Unreadable(error),
    _ => Defect(error),
  };
}

/// Runs [action] and answers with its outcome: done, refused (definite), or
/// not reached. An error of the app is answered as [CommandUnreached] with a
/// [Defect], never rethrown: the screen says so and the trace keeps it.
/// [what] names the command in the trace.
Future<CommandOutcome<T>> runCommand<T>(
  Future<T> Function() action, {
  String what = 'a command did not complete',
}) async {
  try {
    return CommandDone(await action());
  } on Object catch (e, st) {
    final failure = appFailureFrom(e);
    TraceLogger.instance.warn('command', '$what: $failure', error: e, stackTrace: st);
    return switch (failure) {
      final Refusal r => CommandRefused(r),
      final other => CommandUnreached(other),
    };
  }
}
