// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'trace_logger.dart';

/// Builds the app's file-backed [TraceLogger]: entries persist to
/// `<application support>/deskilo-trace.log` (#144).
TraceLogger createAppTraceLogger() =>
    TraceLogger(directoryProvider: getApplicationSupportDirectory);

/// Routes framework and platform errors through [logger] without changing
/// existing crash semantics: the previous [FlutterError.onError] handler
/// still runs, and [PlatformDispatcher.onError] returns false so errors
/// keep propagating exactly as before (#144).
///
/// #4416 -- there is no `runZonedGuarded` around start-up, on purpose. An
/// error no zone handles (an unawaited future, a timer, a stream with no
/// listener for its error) reaches [PlatformDispatcher.onError] on every
/// target this app ships to: Android, iOS, macOS, Windows, Linux and the web.
/// A guarded zone around `runApp` would catch the same errors a second time
/// and put the app in a zone other than the binding's, which Flutter reports
/// as a zone mismatch. Work run on another isolate reports through
/// `tracedCompute` (traced_compute.dart).
void installGlobalTraceHooks(TraceLogger logger) {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    logger.error(
      'flutter',
      details.exceptionAsString(),
      error: details.exception,
      stackTrace: details.stack,
    );
    previous?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.error(
      'platform',
      error.toString(),
      error: error,
      stackTrace: stack,
    );
    return false;
  };
}
