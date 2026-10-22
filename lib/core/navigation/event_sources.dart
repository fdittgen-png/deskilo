// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2573 -- the record an event was filed as, opened from the event itself: an
// expense request is filed as a purchase document. The feature that owns the
// record supplies an opener per event type, and the composition root puts
// them in its scope's overrides (`eventSourceOpenersFromMoney`); until then
// there are none, and the events page names no other feature.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the record an event of one type was filed as.
abstract interface class EventSourceOpener {
  /// Opens the record [eventId] was filed as in [workspaceId]; false when
  /// there is none (yet) or the reader may not see it.
  Future<bool> open(BuildContext context, String workspaceId, String eventId);
}

/// The openers by event type (its database name); empty until wired.
final eventSourceOpenersProvider = Provider<Map<String, EventSourceOpener>>(
  (ref) => const {},
);
