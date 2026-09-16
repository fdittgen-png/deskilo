// SPDX-License-Identifier: 0BSD
import 'dart:async';
import 'dart:math';

import '../trace/trace_logger.dart';

// #1303 — moved to core/ids so a screen can mint one without reaching into
// data/; re-exported here for the repositories that already import it.
export '../ids/request_id.dart' show newRequestId;

/// #1241 step 2 — retry a call that failed because the connection did.
///
/// The one offline affordance this app had was
/// [isTransientNetworkFailure], and its only job was to downgrade a log
/// level so a dropped connection was not filed as an app error. It drove
/// no recovery: a booking made in a lift was simply lost.
///
/// This drives one. It retries ONLY what that predicate recognises — a
/// transport failure, never a server refusal — because a 403 retried
/// three times is still a 403, and the member waits three times as long
/// to read it.
///
/// ## What may be wrapped
///
/// Anything idempotent: every read, and any write whose replay the
/// server makes safe. `create_reservation_once` (0214) is the first
/// write in that second category — it claims a client-generated key
/// before it books, so a replay returns the first booking rather than
/// making a second one. An ordinary write must NOT be wrapped: if the
/// request reached the server and only the answer was lost, the retry
/// does it twice.
///
/// ## The delays
///
/// Three attempts over roughly a second and a half, with jitter. Long
/// enough to cross a cell handover or a wifi roam, which is the failure
/// this is for; short enough that a member who is genuinely offline gets
/// told so rather than watching a spinner. A longer wait belongs to a
/// queue, not to a call somebody is standing in front of.
const List<Duration> kRetryDelays = [
  Duration(milliseconds: 200),
  Duration(milliseconds: 500),
];

final _jitter = Random();

/// Runs [body], retrying it while the failure is a transport failure.
///
/// [what] names the call in the trace, so a slow booking reads as two
/// lines that say why rather than one silence. [delays] is injectable so
/// tests do not spend real time asleep.
Future<T> retryTransient<T>(
  String what,
  Future<T> Function() body, {
  List<Duration> delays = kRetryDelays,
}) async {
  for (var attempt = 0;; attempt++) {
    try {
      return await body();
    } catch (e, st) {
      if (attempt >= delays.length || !isTransientNetworkFailure(e)) {
        rethrow;
      }
      // Full jitter on the backoff: every device in the room lost the
      // same access point at the same instant, and a fixed delay walks
      // them all back onto it together.
      final base = delays[attempt].inMilliseconds;
      final wait = Duration(milliseconds: base ~/ 2 + _jitter.nextInt(base));
      TraceLogger.instance.warn(
        'net',
        '$what — connection dropped, retrying in ${wait.inMilliseconds} ms '
            '(attempt ${attempt + 2} of ${delays.length + 1})',
        error: e,
        stackTrace: st,
      );
      await Future<void>.delayed(wait);
    }
  }
}

