// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

/// #3065 — whether the address itself names the Alerts view
/// (`/calendar?view=alerts`, where `/events` lands): a reload or a shared
/// link opens the alerts, not the calendar's first view.
bool _addressAsksAlerts(BuildContext context) =>
    GoRouter.maybeOf(context)
        ?.routeInformationProvider
        .value
        .uri
        .queryParameters['view'] ==
    'alerts';

/// Puts the hub on its Alerts view when the address asks for it.
void requestAlertsIfAddressAsks(BuildContext context, WidgetRef ref) {
  if (_addressAsksAlerts(context)) {
    ref.read(calendarAlertsRequestProvider.notifier).request();
  }
}
