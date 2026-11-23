// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/app_failure_from.dart';
import '../../../core/data/server_error.dart';
import '../../../core/failure/app_failure.dart';

/// #2585 — whether a failed financial command is a DEFINITE refusal.
///
/// Only an answer the function itself raised is one. A three-digit code is
/// the gateway's HTTP status (a 502 or 504 says nothing about the commit); a
/// [StateError] is a local refusal raised before anything was sent.
/// Everything else — a lost socket, an answer that does not decode — leaves
/// the commit unknown, and the caller must never send it again.
///
/// #4413 -- read through the app's one conversion ([appFailureFrom]): a
/// [Refusal] is definite. An authentication fetch that did not answer carries
/// a message and was counted definite before; it stays so here until the
/// money commands answer with a CommandOutcome (#4413).
bool isDefiniteRefusal(Object e) => switch (appFailureFrom(e)) {
      Refusal() => true,
      _ => isAuthTransportError(e),
    };
