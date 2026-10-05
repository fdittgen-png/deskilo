// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../data/server_error.dart';

/// Why a network read failed, as far as the cache may care (#1849).
///
/// Only [transient] unavailability lets a read fall back to a stale entry.
/// A denial or revocation is not "offline", and a failure nobody classified
/// must not silently grant protected stale access — so it is not served
/// either.
enum ReadFailure {
  /// No network, a timeout, a gateway/server fault: try again later, and the
  /// last validated answer may stand in meanwhile (labelled stale).
  transient,

  /// The server refused: unauthenticated, expired, revoked, or not permitted.
  /// Whatever protected data this key held must not be shown again.
  denied,

  /// Anything else — a programming or contract fault. Surface it.
  other,
}

ReadFailure classifyReadFailure(Object error) {
  if (error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException ||
      isAuthTransportError(error)) {
    return ReadFailure.transient;
  }
  if (isAuthError(error)) {
    final status = authStatusCode(error);
    return status == 401 || status == 403
        ? ReadFailure.denied
        : ReadFailure.other;
  }
  final code = serverErrorCode(error);
  if (code != null) {
    if (code == '42501' ||
        code == '401' ||
        code == '403' ||
        code == 'PGRST301' ||
        code == 'PGRST302') {
      return ReadFailure.denied;
    }
    // 5xx from the gateway or a database connection class (08xxx) or the
    // PostgREST connectivity family: the service is unavailable, not wrong.
    if (code.startsWith('5') ||
        code.startsWith('08') ||
        const {'PGRST000', 'PGRST001', 'PGRST002', 'PGRST003'}.contains(code)) {
      return ReadFailure.transient;
    }
  }
  return ReadFailure.other;
}

/// A network answer that arrived intact but did not parse into the domain
/// value. Never cached, never marked fresh, never answered from stale: a
/// schema or contract failure must not hide behind an old copy.
class CachedReadInvalid implements Exception {
  const CachedReadInvalid(this.key, this.cause);
  final String key;
  final Object cause;

  @override
  String toString() => 'CachedReadInvalid($key)';
}
