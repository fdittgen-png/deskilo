// SPDX-License-Identifier: 0BSD
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'trace_logger.dart';

/// #742 — every provider failure on the record. A repository call inside
/// `traced()` logs itself; the other providers surface their failure as
/// an `AsyncError` the screen renders — silently, as far as the trace
/// was concerned. This observer sits on the root [ProviderScope] and
/// writes the provider's name, the error and the stack for all of them,
/// so "the screen said something went wrong" always has a line behind it.
final class TraceProviderObserver extends ProviderObserver {
  const TraceProviderObserver();

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    final provider = context.provider;
    TraceLogger.instance.error(
      'provider',
      '${provider.name ?? provider.runtimeType} failed',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
