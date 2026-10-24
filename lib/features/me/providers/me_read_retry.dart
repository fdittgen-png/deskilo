// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/server_error.dart';

/// #2558 — how a read of my own account retries. An answer of the personal
/// home itself is final: asking again returns the same, and the default
/// (ten tries, minutes in all) would keep the editor on a spinner instead
/// of saying that the settings cannot be read. Only a failure that did not
/// come from the server is tried again, twice and quickly.
Duration? meReadRetry(int retryCount, Object error) {
  if (retryCount >= 2) return null;
  final transport = isAuthTransportError(error);
  if (error is ArgumentError ||
      (!transport &&
          (serverErrorCode(error) != null ||
              serverErrorMessage(error) != null))) {
    return null;
  }
  return Duration(milliseconds: 200 << retryCount);
}
