// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/server_error.dart';

/// #2585 — whether a failed financial command is a DEFINITE refusal.
///
/// Only an answer the function itself raised is one. A three-digit code is
/// the gateway's HTTP status (a 502 or 504 says nothing about the commit); a
/// [StateError] is a local refusal raised before anything was sent.
/// Everything else — a lost socket, an answer that does not decode — leaves
/// the commit unknown, and the caller must never send it again.
bool isDefiniteRefusal(Object e) {
  final code = serverErrorCode(e);
  if (code != null && RegExp(r'^\d{3}$').hasMatch(code)) return false;
  return serverErrorMessage(e) != null || e is StateError;
}
