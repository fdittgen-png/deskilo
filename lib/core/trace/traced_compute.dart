// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4416 -- work run off the interface's isolate reports its failure to the
// main isolate's trace. `compute` already hands an error of the callback back
// to the caller; this helper writes it to the trace there, once, with the
// work's name, and rethrows it unchanged, so no caller forgets to.
import 'package:flutter/foundation.dart';

import 'trace_logger.dart';

/// Runs [callback] on [message] with `compute`; a failure is traced under
/// [area] as "[what] failed" and rethrown with its stack.
Future<R> tracedCompute<M, R>(
  ComputeCallback<M, R> callback,
  M message, {
  required String area,
  required String what,
}) async {
  try {
    return await compute(callback, message);
  } on Object catch (e, st) {
    TraceLogger.instance.error(area, '$what failed', error: e, stackTrace: st);
    rethrow;
  }
}
