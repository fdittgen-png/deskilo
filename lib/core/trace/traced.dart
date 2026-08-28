// SPDX-License-Identifier: 0BSD
import 'trace_logger.dart';

/// Runs [body] and TRACES anything it throws before rethrowing (#692).
///
/// A Riverpod provider that fails lands in `AsyncError`, the screen
/// renders its generic line, and nothing is written down. The first
/// messaging beta did exactly that: the list said "an error occurred"
/// and the device trace — the one thing that could have named the
/// cause — had no entry for it at all.
///
/// Rethrows, so the UI still shows its own error state. This adds the
/// record; it never swallows the failure. Shared here (#709) so every
/// data provider traces the same way rather than each feature keeping
/// its own copy that is one refactor away from being dropped.
Future<T> traced<T>(
  String domain,
  String what,
  Future<T> Function() body,
) async {
  try {
    return await body();
  } catch (e, st) {
    TraceLogger.instance.error(domain, '$what failed', error: e, stackTrace: st);
    rethrow;
  }
}
