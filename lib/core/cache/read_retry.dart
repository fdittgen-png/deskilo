// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3103 (PERF-10) — the app's one retry policy for provider reads,
// installed on the root ProviderScope. Riverpod's default tries a failing
// provider 10 times over about 38 s, and nested providers stack their
// tries. A denial or a contract fault will fail the same way again, so it
// is not retried; a transient failure (network, timeout, 5xx) is tried
// twice more, quickly. A provider with its own `retry:` keeps it.
import 'read_failure.dart';

Duration? readRetry(int retryCount, Object error) {
  if (retryCount >= 2) return null;
  return switch (classifyReadFailure(error)) {
    ReadFailure.transient => Duration(milliseconds: 200 << retryCount),
    ReadFailure.denied || ReadFailure.other => null,
  };
}
