// SPDX-License-Identifier: 0BSD
//
// #1306 — deciding a pending event, from wherever the question is asked.
//
// The events face asked it alone until the bell could be switched off;
// the calendar asks it too now. Both surfaces say "Accept" or "Decline" —
// ADR 0024 puts what that MEANS here: record the decision, then refresh
// every surface that renders bookings, money or the decision trail,
// because a quorum may keep the event pending and only the fresh decision
// row moves it off this member's pile.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/server_error.dart';
import '../../../core/trace/trace_logger.dart';
import '../providers/event_providers.dart';

/// Records this member's decision on [eventId].
///
/// Returns null when it landed. On a refusal it returns the server's own
/// reason — an empty string when the failure carried none — because a
/// hidden reason cost a debug round-trip once already (#107).
Future<String?> decideEvent(WidgetRef ref, String eventId,
    {required bool accept}) async {
  try {
    await ref.read(eventRepositoryProvider).respond(eventId, accept: accept);
  } catch (e, st) {
    TraceLogger.instance
        .error('events', 'respond failed', error: e, stackTrace: st);
    return serverErrorMessage(e) ?? '';
  }
  invalidateBookingData(ref);
  return null;
}
