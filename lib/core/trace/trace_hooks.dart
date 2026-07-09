// SPDX-License-Identifier: MIT
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
