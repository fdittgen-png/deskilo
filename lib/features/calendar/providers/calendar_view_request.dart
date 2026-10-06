// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A request to put the calendar hub on its Alerts view — made by the bell,
/// the `/events` path and a tapped alert row, consumed by the hub.
///
/// Kept alive and delivered once, like the inbox tab it replaces: the hub
/// sits in the shell's indexed stack, so a request made from another tab has
/// to survive until the switch builds it.
class CalendarAlertsRequest extends Notifier<bool> {
  @override
  bool build() => false;

  void request() => state = true;

  /// The hub took it.
  void consume() => state = false;
}

final calendarAlertsRequestProvider =
    NotifierProvider<CalendarAlertsRequest, bool>(CalendarAlertsRequest.new);
