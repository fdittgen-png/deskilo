// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4404 -- the answers a Demo fake already gave, by request id: a request that comes again gets its first answer, whatever it asks the
// second time. The server does the same; the fakes wrote the lookup and the keeping each time.
final class Replay<R> {
  final Map<String, R> _answers = {};

  /// The first answer of [requestId], or null when it never came.
  R? seen(String requestId) => _answers[requestId];

  /// Keeps [answer] as the answer of [requestId] and gives it back.
  R keep(String requestId, R answer) => _answers[requestId] = answer;

  /// Runs [body] once per request id: the same id again answers the first answer and does not run it.
  Future<R> once(String requestId, Future<R> Function() body) async {
    final first = _answers[requestId];
    if (first != null) return first;
    return _answers[requestId] = await body();
  }

  /// The same, for a body that needs no waiting.
  R onceSync(String requestId, R Function() body) => _answers[requestId] ??= body();
}
